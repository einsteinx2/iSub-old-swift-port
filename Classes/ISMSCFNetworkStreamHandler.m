//
//  ISMSCFNetworkStreamHandler.m
//  Anghami
//
//  Created by Ben Baron on 7/4/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "ISMSCFNetworkStreamHandler.h"
#import "BassGaplessPlayer.h"

@interface ISMSCFNetworkStreamHandler ()
{
	UInt8		_buffer[16 * 1024];				//	Create a 16K buffer
	CFIndex		_bytesRead;
	CFReadStreamRef _readStreamRef;
	NSTimeInterval _lastThrottle;
}
@property (nonatomic) BOOL isPrecacheSleeping;
@property (strong) ISMSCFNetworkStreamHandler *selfRef;
- (void)readStreamClientCallBack:(CFReadStreamRef)stream type:(CFStreamEventType)type;
@end

@implementation ISMSCFNetworkStreamHandler

// Logging
#define isProgressLoggingEnabled 0
#define isThrottleLoggingEnabled 1
#define isSpeedLoggingEnabled 0

LOG_LEVEL_ISUB_DEFAULT

static const CFOptionFlags kNetworkEvents = kCFStreamEventOpenCompleted | kCFStreamEventHasBytesAvailable | kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred;

- (void)dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[self terminateDownload];
}

- (void)start:(BOOL)resume
{
	[self terminateDownload];
	
	self.selfRef = self;
	
	//DLog(@"downloadCFNetA url: %@", [url absoluteString]);
	
	/*if (throttlingDate)
	 [throttlingDate release];
	 throttlingDate = nil;
	 bytesTransferred = 0;*/
	
	self.totalBytesTransferred = 0;
	self.bytesTransferred = 0;
	self.byteOffset = 0;
    	
	// Create the file handle
	self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.filePath];
	
	if (self.fileHandle)
	{
		if (resume)
		{
			// File exists so seek to end
			self.totalBytesTransferred = [self.fileHandle seekToEndOfFile];
			self.byteOffset += self.totalBytesTransferred;
		}
		else
		{
			// File exists so remove it
			[self.fileHandle closeFile];
			self.fileHandle = nil;
			[[NSFileManager defaultManager] removeItemAtPath:self.filePath error:NULL];
		}
	}
    
    if (!resume)
	{
		// Create the file
		self.totalBytesTransferred = 0;
		[[NSFileManager defaultManager] createFileAtPath:self.filePath contents:[NSData data] attributes:nil];
		self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.filePath];
	}
	
	self.bitrate = self.mySong.estimatedBitrate;
    
    if (self.maxBitrateSetting == NSIntegerMax)
    {
        self.maxBitrateSetting = settingsS.currentMaxBitrate;
    }
	
    NSURLRequest *request;
	if ([settingsS.serverType isEqualToString:SUBSONIC] || [settingsS.serverType isEqualToString:UBUNTU_ONE])
	{
		NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(self.mySong.songId), @"id", nil];
		[parameters setObject:@"true" forKey:@"estimateContentLength"];
		
		if (self.maxBitrateSetting != 0)
		{
			NSString *maxBitRate = [[NSString alloc] initWithFormat:@"%i", self.maxBitrateSetting];
			[parameters setObject:n2N(maxBitRate) forKey:@"maxBitRate"];
		}
		request = [NSMutableURLRequest requestWithSUSAction:@"stream" parameters:parameters byteOffset:self.byteOffset];
	}
	else if ([settingsS.serverType isEqualToString:WAVEBOX])
	{
        NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObject:self.mySong.songId forKey:@"id"];
        
        if (self.maxBitrateSetting < 192)
        {
            [parameters setObject:@"MP3" forKey:@"transType"];
            
            NSString *transQuality;
            switch (self.maxBitrateSetting)
            {
                case 64: transQuality = @"Low"; break;
                case 96: transQuality = @"Medium"; break;
                case 128: transQuality = @"High"; break;
                case 160:
                default: transQuality = @"Extreme"; break;
            }
            [parameters setObject:transQuality forKey:@"transQuality"];
        }
        
		request = [NSMutableURLRequest requestWithPMSAction:@"stream" parameters:parameters byteOffset:self.byteOffset];
	}
    
	if (!request)
	{
		[self downloadFailed];
		return;
	}
	
	CFHTTPMessageRef messageRef = NULL;
	CFStreamClientContext ctxt = {0, (__bridge void*)self, NULL, NULL, NULL};
	
	// Create the POST request
	messageRef = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("POST"), (__bridge CFURLRef)request.URL, kCFHTTPVersion1_1);
	if (messageRef == NULL) goto Bail;
	
	CFHTTPMessageSetBody(messageRef, (__bridge CFDataRef)request.HTTPBody);
	
	CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("HOST"), (__bridge CFStringRef)[request.URL host]);    
	//CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("Content-Length"), (__bridge CFStringRef)[NSString stringWithFormat:@"%d", [request.HTTPBody length]]);    
	CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("Content-Type"), CFSTR("application/x-www-form-urlencoded"));//CFSTR("charset=utf-8"));
	
	CFDataRef body = CFHTTPMessageCopyBody(messageRef);
	DDLogInfo(@"body: %@", [[NSString alloc] initWithData:(__bridge NSData *)body encoding:NSUTF8StringEncoding]);
	
	// Create the stream for the request.
	_readStreamRef = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, messageRef);
	if (_readStreamRef == NULL) goto Bail;
	
	CFRetain(_readStreamRef);
	
	//	There are times when a server checks the User-Agent to match a well known browser.  This is what Safari used at the time the sample was written
	//CFHTTPMessageSetHeaderFieldValue( messageRef, CFSTR("User-Agent"), CFSTR("Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/125.5.5 (KHTML, like Gecko) Safari/125")); 
	
	// Set a no cache policy
	CFHTTPMessageSetHeaderFieldValue( messageRef, CFSTR("Cache-Control"), CFSTR("no-cache"));
	
	// Enable stream redirection
	if (CFReadStreamSetProperty(_readStreamRef, kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanTrue) == false)
		goto Bail;
	
	// Handle SSL connections
	if([[request.URL absoluteString] rangeOfString:@"https"].location != NSNotFound)
	{
		NSDictionary *sslSettings =
		[NSDictionary dictionaryWithObjectsAndKeys:
		 (NSString *)kCFStreamSocketSecurityLevelNegotiatedSSL, kCFStreamSSLLevel,
		 [NSNumber numberWithBool:YES], kCFStreamSSLAllowsExpiredCertificates,
		 [NSNumber numberWithBool:YES], kCFStreamSSLAllowsExpiredRoots,
		 [NSNumber numberWithBool:YES], kCFStreamSSLAllowsAnyRoot,
		 [NSNumber numberWithBool:NO], kCFStreamSSLValidatesCertificateChain,
		 [NSNull null], kCFStreamSSLPeerName,
		 nil];
		
		CFReadStreamSetProperty(_readStreamRef, kCFStreamPropertySSLSettings, (__bridge CFDictionaryRef)sslSettings);
	}
	
	// Handle proxy
	CFDictionaryRef proxyDict = CFNetworkCopySystemProxySettings();
	CFReadStreamSetProperty(_readStreamRef, kCFStreamPropertyHTTPProxy, proxyDict);
	
	// Set the client notifier
	if (CFReadStreamSetClient(_readStreamRef, kNetworkEvents, ReadStreamClientCallBack, &ctxt) == false)
		goto Bail;
	
	if ([self.mySong isEqualToSong:[playlistS currentSong]])
	{
		self.isCurrentSong = YES;
	}
	
	// Schedule the stream
	CFReadStreamScheduleWithRunLoop(_readStreamRef, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    
    [self startTimeOutTimer];
	
	self.isDownloading = YES;
	[EX2NetworkIndicator usingNetwork];
	
	// Start the HTTP connection
	if (CFReadStreamOpen(_readStreamRef) == false)
		goto Bail;
	
	//DLog(@"--- STARTING HTTP CONNECTION");
	
	if (messageRef != NULL) CFRelease(messageRef);
	return;
	
Bail:
	if (messageRef != NULL) CFRelease(messageRef);
	[self terminateDownload];
	
	return;
}

- (void)cancel
{
	DDLogVerbose(@"Stream handler request canceled for %@", self.mySong);

	[self terminateDownload];
	
	self.isDownloading = NO;
	self.isCanceled = YES;
	
	// Close the file handle
	[self.fileHandle closeFile];
	self.fileHandle = nil;
	
	self.selfRef = nil;
}

- (void)connectionTimedOut
{
	//DLog(@"connection timed out");
    
	[self downloadFailed];
}

- (void)terminateDownload
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	[EX2Dispatch runInMainThreadAndWaitUntilDone:YES block:^
	 {
		 if (self.isDownloading)
			 [EX2NetworkIndicator doneUsingNetwork];
		 
		 self.isDownloading = NO;
		 
		 if (_readStreamRef == NULL)
		 {
			 //DLog(@"------------------------------ stream is nil so returning");
			 return;
		 }
		 //DLog(@"------------------------------ stream is not nil so closing the stream");
		 
		 //***	ALWAYS set the stream client (notifier) to NULL if you are releasing it
		 //	otherwise your notifier may be called after you released the stream leaving you with a 
		 //	bogus stream within your notifier.
		 //DLog(@"canceling stream: %@", readStreamRef);
		 CFReadStreamSetClient(_readStreamRef, kCFStreamEventNone, NULL, NULL);
		 CFReadStreamUnscheduleFromRunLoop(_readStreamRef, CFRunLoopGetMain(), kCFRunLoopCommonModes);
		 CFReadStreamClose(_readStreamRef);
		 CFRelease(_readStreamRef);
		 
		 _readStreamRef = NULL;
	 }];
}

static void ReadStreamClientCallBack(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo)
{
	@autoreleasepool 
	{
		[(__bridge ISMSCFNetworkStreamHandler *)clientCallBackInfo readStreamClientCallBack:stream type:type];
	}
}

- (void)continueDownload
{
	if (self.isCanceled)
		return;
	
	if (_readStreamRef != NULL)
	{
		// Schedule the stream
		_lastThrottle = CFAbsoluteTimeGetCurrent();
		CFReadStreamScheduleWithRunLoop(_readStreamRef, CFRunLoopGetMain(), kCFRunLoopCommonModes);
	}
}

- (void)readStreamClientCallBack:(CFReadStreamRef)stream type:(CFStreamEventType)type
{	
	if (self.isCanceled)
		return;
	
	if (type == kCFStreamEventOpenCompleted)
	{
        // Reset the time out timer since the connection responded
        [self startTimeOutTimer];
        
		DDLogCVerbose(@"Stream handler: kCFStreamEventOpenCompleted occured");
		if (!self.isTempCache)
			self.mySong.isPartiallyCached = YES;
		
		if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerStarted:)])
			[self.delegate ISMSStreamHandlerStarted:self];
	}
	else if (type == kCFStreamEventHasBytesAvailable)
	{
		_bytesRead = CFReadStreamRead(stream, _buffer, sizeof(_buffer));
				
		if (_bytesRead > 0)	// If zero bytes were read, wait for the EOF to come.
		{
            // Reset the time out timer since some bytes were received
            [self startTimeOutTimer];
            
            if (self.fileHandle)
            {
                // Save the data to the file
                @try
                {
                    [self.fileHandle writeData:[NSData dataWithBytesNoCopy:_buffer length:_bytesRead freeWhenDone:NO]];
                }
                @catch (NSException *exception)
                {
                    DDLogCError(@"Failed to write to file %@, %@ - %@", self.mySong, exception.name, exception.description);
					
					if (cacheS.freeSpace <= BytesFromMiB(25))
					{
						/*[EX2Dispatch runInMainThread:^
						 {
							 // Space has run out, so show the message
							 [cacheS showNoFreeSpaceMessage:NSLocalizedString(@"Your device has run out of space and cannot stream any more music. Please free some space and try again", @"Stream manager, device out of space message")];
						 }];*/
					}
					
					[self cancel];
                }
				
				self.totalBytesTransferred += _bytesRead;
				self.bytesTransferred += _bytesRead;
                
                //DLog(@"downloading song, bytes transferred ")
				
				//if (isProgressLoggingEnabled)
				//	//DLog(@"downloadedLengthA:  %lu   bytesRead: %ld", [musicControlsRef downloadedLengthA], bytesRead);
				
				// Notify delegate if enough bytes received to start playback
				if (!self.isDelegateNotifiedToStartPlayback && self.totalBytesTransferred >= ISMSMinBytesToStartPlayback(self.bitrate))
				{
					DDLogCVerbose(@"telling player to start, min bytes: %u, total bytes: %llu, bitrate: %u", ISMSMinBytesToStartPlayback(self.bitrate), self.totalBytesTransferred, self.bitrate);
					self.isDelegateNotifiedToStartPlayback = YES;
					
					if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerStartPlayback:)])
						[self.delegate ISMSStreamHandlerStartPlayback:self];
				}
				
				// Check if we should throttle
				NSTimeInterval now = CFAbsoluteTimeGetCurrent();
				NSTimeInterval intervalSinceLastThrottle = now - _lastThrottle;
				if (intervalSinceLastThrottle > ISMSThrottleTimeInterval && self.totalBytesTransferred > ISMSMinBytesToStartLimiting(self.bitrate))
				{
					NSTimeInterval delay = 0.0;
					
					double maxBytesPerInterval = [self maxBytesPerIntervalForBitrate:(double)self.bitrate is3G:!appDelegateS.isWifi];
					double numberOfIntervals = intervalSinceLastThrottle / ISMSThrottleTimeInterval;
					double maxBytesPerTotalInterval = maxBytesPerInterval * numberOfIntervals;
					
					if (self.bytesTransferred > maxBytesPerTotalInterval)
					{
						double speedDifferenceFactor = (double)self.bytesTransferred / maxBytesPerTotalInterval;
						delay = (speedDifferenceFactor * intervalSinceLastThrottle) - intervalSinceLastThrottle;
						
						if (isThrottleLoggingEnabled)
							DDLogCInfo(@"Pausing for %f  interval: %f  bytesTransferred: %llu maxBytes: %f", delay, intervalSinceLastThrottle, self.bytesTransferred, maxBytesPerTotalInterval);
						
						self.bytesTransferred = 0;
					}
					
					// Pause by unscheduling from the runloop
					CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetMain(), kCFRunLoopCommonModes);
					
					// Continue after the delay
					[self performSelector:@selector(continueDownload) withObject:nil afterDelay:delay];
				}
                
                // Handle partial pre-cache next song
                if (!self.isCurrentSong && !self.isTempCache && settingsS.isPartialCacheNextSong && self.partialPrecacheSleep)
                {
                    NSUInteger partialPrecacheSize = ISMSNumBytesToPartialPreCache(self.mySong.estimatedBitrate);
                    if (self.totalBytesTransferred >= partialPrecacheSize)
                    {
                        // First verify that the stream can be opened
                        if (audioEngineS.player)
                        {
                            if ([audioEngineS.player prepareStreamForSong:self.mySong])
                            {
                                // The stream worked, so go ahead and pause the download
                                self.isPrecacheSleeping = YES;
                                CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetMain(), kCFRunLoopCommonModes);
                                if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerPartialPrecachePaused:)])
                                {
                                    [self.delegate ISMSStreamHandlerPartialPrecachePaused:self];
                                }
                            }
                            else
                            {
                                self.secondsToPartialPrecache += 10;
                            }
                        }
                    }
                }
			}
			else
			{
				DDLogCError(@"Stream handler: An error occured in the download");
				[self downloadFailed];
			}
		}
		else if (_bytesRead < 0)		// Less than zero is an error
		{
			DDLogCError(@"Stream handler: An occured in the download bytesRead < 0");
			[self downloadFailed];
		}
		else	//	0 assume we are done with the stream
		{
			DDLogCVerbose(@"Stream handler: bytesRead == 0 occured in the download, but we're continuing");
			//[self downloadDone];
		}
	}
	else if (type == kCFStreamEventEndEncountered)
	{
		DDLogCVerbose(@"Stream handler: An kCFStreamEventEndEncountered occured in the download, download is done");
		[self downloadDone];
	}
	else if (type == kCFStreamEventErrorOccurred)
	{
		DDLogCError(@"Stream handler: An kCFStreamEventErrorOccurred occured in the download");
		[self downloadFailed];
	}
}

- (void)downloadFailed
{
	[self terminateDownload];
	
	self.isDownloading = NO;
	
	// Close the file handle
	[self.fileHandle closeFile];
	self.fileHandle = nil;
		
	if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerConnectionFailed:withError:)])
		[self.delegate ISMSStreamHandlerConnectionFailed:self withError:nil];
	
	self.selfRef = nil;
}

- (void)downloadDone
{
	// Get the response header
	if (_readStreamRef != NULL)
	{
		CFHTTPMessageRef myResponse = (CFHTTPMessageRef)CFReadStreamCopyProperty(_readStreamRef, kCFStreamPropertyHTTPResponseHeader);
		CFStringRef myStatusLine = CFHTTPMessageCopyResponseStatusLine(myResponse);
		DDLogCInfo(@"http response status: %@", myStatusLine);
		
		CFStringRef contentLength = CFHTTPMessageCopyHeaderFieldValue(myResponse, (CFStringRef)@"Content-Length");
		DDLogCInfo(@"contentLength: %@", contentLength);
		
		self.contentLength = [((__bridge NSString *)contentLength) longLongValue];
	}
	
	[self terminateDownload];
    			  
	DDLogCInfo(@"Connection Finished for %@  file size: %llu   contentLength: %llu", self.mySong.title, self.mySong.localFileSize, self.contentLength);
	
	self.isDownloading = NO;
    
    // Close the file handle
	[self.fileHandle closeFile];
	self.fileHandle = nil;
    	
	if (self.contentLength != ULLONG_MAX && self.mySong.localFileSize < self.contentLength && self.numberOfContentLengthFailures < ISMSMaxContentLengthFailures)
	{
		DDLogCInfo(@"Connection Failed because not enough bytes were downloaed for %@", self.mySong.title);

		// This is a failed download, it didn't download enough
		self.numberOfContentLengthFailures++;
		
		if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerConnectionFailed:withError:)])
			[self.delegate ISMSStreamHandlerConnectionFailed:self withError:nil];
	}
	else
	{
		DDLogCInfo(@"Connection was successful because the file size matches the content length header for %@", self.mySong.title);

		if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerConnectionFinished:)])
			[self.delegate ISMSStreamHandlerConnectionFinished:self];
	}
    
    self.selfRef = nil;
}

- (void)setPartialPrecacheSleep:(BOOL)partialPrecacheSleep
{
    [super setPartialPrecacheSleep:partialPrecacheSleep];
    if (!partialPrecacheSleep && self.isPartialPrecacheSleeping)
    {
        self.isPartialPrecacheSleeping = NO;
        [self continueDownload];
        
        if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerPartialPrecacheUnpaused:)])
        {
            [self.delegate ISMSStreamHandlerPartialPrecacheUnpaused:self];
        }
    }
}

@end
