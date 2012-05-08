//
//  ISMSStreamHandler.m
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSStreamHandler.h"
#import "MusicSingleton.h"
#import "Song.h"
#import "iSubAppDelegate.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSError+ISMSError.h"
#import "NSString+md5.h"
#import "DatabaseSingleton.h"
#import "FMDatabaseAdditions.h"
#import "SUSCoverArtLoader.h"
#import "SavedSettings.h"
#import "CacheSingleton.h"
#import "PlaylistSingleton.h"
#import "ISMSNetworkIndicator.h"
#import "GCDWrapper.h"

#define ISMSNumSecondsToPartialPreCacheDefault 20
#define ISMSNumBytesToPartialPreCache(bitrate) (BytesForSecondsAtBitrate(self.secondsToPartialPrecache, bitrate))

#define ISMSMinBytesToStartPlayback(bitrate) (BytesForSecondsAtBitrate(settingsS.audioEngineStartNumberOfSeconds, bitrate))

#define ISMSThrottleTimeInterval 0.1

#define ISMSMaxKilobitsPerSec3G 500
#define ISMSMaxBytesPerInterval3G BytesForSecondsAtBitrate(ISMSThrottleTimeInterval, ISMSMaxKilobitsPerSec3G)

#define ISMSMaxKilobitsPerSecWifi 8000
#define ISMSMaxBytesPerIntervalWifi BytesForSecondsAtBitrate(ISMSThrottleTimeInterval, ISMSMaxKilobitsPerSecWifi)

#define ISMSMinBytesToStartLimiting(bitrate) (BytesForSecondsAtBitrate(60, bitrate))

#define ISMSMaxContentLengthFailures 1

//#define kMinKiloBytesToStartPlayback 250
//#define kMinBytesToStartPlayback ((unsigned long long)(1024 * kMinKiloBytesToStartPlayback)) // Number of bytes to wait before activating the player
//#define kMinBytesToStartLimiting ((unsigned long long)(1024 * 1024))	// Start throttling bandwidth after 1 MB downloaded for 160kbps files (adjusted accordingly by bitrate)

// Logging
#define isProgressLoggingEnabled 0
#define isThrottleLoggingEnabled 0
#define isSpeedLoggingEnabled 0

@implementation ISMSStreamHandler
@synthesize totalBytesTransferred, bytesTransferred, mySong, connection, byteOffset, delegate, fileHandle, isDelegateNotifiedToStartPlayback, numOfReconnects, request, loadingThread, isTempCache, bitrate, secondsOffset, partialPrecacheSleep, isDownloading, isCurrentSong, shouldResume, contentLength, maxBitrateSetting, speedLoggingDate, speedLoggingLastSize, isCanceled, numberOfContentLengthFailures, isPartialPrecacheSleeping, secondsToPartialPrecache, tempBreakPartialPrecache;

- (void)setup
{
	mySong = nil;
	delegate = nil;
	byteOffset = 0;
	secondsOffset = 0;
	isDelegateNotifiedToStartPlayback = NO;
	numOfReconnects = 0;
	loadingThread = nil;
	request = nil;
	connection = nil;
	isTempCache = NO;
	bitrate = 0;
	partialPrecacheSleep = YES;
	isPartialPrecacheSleeping = NO;
	isDownloading = NO;
	contentLength = ULLONG_MAX;
	maxBitrateSetting = NSIntegerMax;
	numberOfContentLengthFailures = 0;
	secondsToPartialPrecache = ISMSNumSecondsToPartialPreCacheDefault;
	tempBreakPartialPrecache = NO;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playlistIndexChanged) name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
}

- (id)init
{
	if ((self = [super init]))
	{
		[self setup];
	}
	return self;
}

- (id)initWithSong:(Song *)song byteOffset:(unsigned long long)bOffset secondsOffset:(double)sOffset isTemp:(BOOL)isTemp delegate:(NSObject<ISMSStreamHandlerDelegate> *)theDelegate
{
	if ((self = [super init]))
	{
		[self setup];
		
		mySong = [song copy];
		delegate = theDelegate;
		byteOffset = bOffset;
		secondsOffset = sOffset;
		isTempCache = isTemp;
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playlistIndexChanged) name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	}
	
	return self;
}

- (id)initWithSong:(Song *)song isTemp:(BOOL)isTemp delegate:(NSObject<ISMSStreamHandlerDelegate> *)theDelegate
{
	return [self initWithSong:song byteOffset:0 secondsOffset:0.0 isTemp:isTemp delegate:theDelegate];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)filePath
{
	return self.isTempCache ? mySong.localTempPath : mySong.localPath;
}

// Create the request and start the connection in loadingThread
- (void)start:(BOOL)resume
{
	if (!resume)
	{
		// Clear temp cache if this is a temp file
		if (self.isTempCache)
		{
			[cacheS clearTempCache];
		}
	}

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
	
	NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(mySong.songId), @"id", nil];
	[parameters setObject:@"true" forKey:@"estimateContentLength"];
	
	if (self.maxBitrateSetting == NSIntegerMax)
	{
		self.maxBitrateSetting = settingsS.currentMaxBitrate;
	}
	
	if (self.maxBitrateSetting != 0)
	{
		NSString *maxBitRate = [[NSString alloc] initWithFormat:@"%i", self.maxBitrateSetting];
		[parameters setObject:n2N(maxBitRate) forKey:@"maxBitRate"];
	}
	self.request = [NSMutableURLRequest requestWithSUSAction:@"stream" andParameters:parameters byteOffset:byteOffset];

	self.loadingThread = [[NSThread alloc] initWithTarget:self selector:@selector(startConnection) object:nil];
	
	self.bitrate = mySong.estimatedBitrate;

	NSDate *now = [[NSDate alloc] init];
	[self.loadingThread.threadDictionary setObject:now forKey:@"throttlingDate"];
		
	if ([self.mySong isEqualToSong:[playlistS currentSong]])
	{
		self.isCurrentSong = YES;
	}
		
	[self.loadingThread start];
}

- (void)start
{
	[self start:NO];
}

// loadingThread entry point
- (void)startConnection
{
	@autoreleasepool 
	{
		self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
		if (self.connection)
		{
			self.isDownloading = YES;
			[GCDWrapper runInMainThreadAndWaitUntilDone:NO block:^{ [self startConnectionInternalSuccess]; }];
			//DLog(@"Stream handler download starting for %@", mySong);
			CFRunLoopRun();
			//DLog(@"Stream handler runloop finished for %@", mySong);
		}
		else
		{
			[GCDWrapper runInMainThreadAndWaitUntilDone:NO block:^{ [self startConnectionInternalFailure]; }];
		}
	}
}

- (void)startConnectionInternalSuccess
{
	if (!self.isTempCache)
		self.mySong.isPartiallyCached = YES;
	
	[ISMSNetworkIndicator usingNetwork];
	
	if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerStarted:)])
		[self.delegate ISMSStreamHandlerStarted:self];
}

- (void)startConnectionInternalFailure
{	
	NSError *error = [[NSError alloc] initWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
	if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerConnectionFailed:withError:)])
		[self.delegate ISMSStreamHandlerConnectionFailed:self withError:error];
}

// Cancel the download and stop the run loop in loadingThread
- (void)cancel
{
	self.isDownloading = NO;
	self.isCanceled = YES;
	
	// Pop out of infinite loop if partially pre-cached
	self.partialPrecacheSleep = NO;
	
	//DLog(@"Stream handler request canceled for %@", mySong);
	[self.connection cancel]; 
	self.connection = nil;
	
	[self.fileHandle closeFile];
	self.fileHandle = nil;
		
	[self performSelector:@selector(cancelRunLoop) onThread:loadingThread withObject:nil waitUntilDone:NO];
	
	[ISMSNetworkIndicator doneUsingNetwork];
}

// Stop the current run loop
- (void)cancelRunLoop
{
	CFRunLoopStop(CFRunLoopGetCurrent());
}

- (void)playlistIndexChanged
{
	// If this song is partially precached and sleeping, stop sleeping
	if (self.isPartialPrecacheSleeping)
		self.partialPrecacheSleep = NO;
	
	if ([self.mySong isEqualToSong:playlistS.currentSong])
		self.isCurrentSong = YES;
}

#pragma mark - Connection Delegate

- (BOOL)connection:(NSURLConnection *)theConnection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)theConnection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveResponse:(NSURLResponse *)response
{
	if ([response isKindOfClass:[NSHTTPURLResponse class]])
	{
		NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
		DLog(@"allHeaderFields: %@", [httpResponse allHeaderFields]);
		DLog(@"statusCode: %i - %@", [httpResponse statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[httpResponse statusCode]]);
		
		if ([httpResponse statusCode] >= 500)
		{
			// This is a failure, cancel the connection and call the didFail delegate method
			[self.connection cancel];
			[self connection:self.connection didFailWithError:nil];
		}
		else
		{
			if (self.contentLength == ULLONG_MAX)
			{
				// Set the content length if it isn't set already, only set the first connection, not on retries
				NSString *contentLengthString = [[httpResponse allHeaderFields] objectForKey:@"Content-Length"];
				if (contentLengthString)
				{
					NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
					self.contentLength = [[formatter numberFromString:contentLengthString] unsignedLongLongValue];
				}
			}
		}
	}
	
	self.bytesTransferred = 0;
}

- (double)maxBytesPerIntervalForBitrate:(double)rate is3G:(BOOL)is3G
{
	double maxBytesDefault = is3G ? (double)ISMSMaxBytesPerInterval3G : (double)ISMSMaxBytesPerIntervalWifi;
	double maxBytesPerInterval = maxBytesDefault * (rate / 160.0);
	if (maxBytesPerInterval < maxBytesDefault)
	{
		// Don't go lower than the default
		maxBytesPerInterval = maxBytesDefault;
	}
	else if (maxBytesPerInterval > (double)ISMSMaxBytesPerIntervalWifi * 2.0)
	{
		// Don't go higher than twice the Wifi limit to prevent disk bandwidth issues
		maxBytesPerInterval = (double)ISMSMaxBytesPerIntervalWifi * 2.0;
	}
	
	return maxBytesPerInterval;
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{	
	if (self.isCanceled)
		return;
	
	if (isSpeedLoggingEnabled)
	{
		if (!self.speedLoggingDate)
		{
			self.speedLoggingDate = [NSDate date];
			self.speedLoggingLastSize = self.totalBytesTransferred;
		}
	}
	
	NSMutableDictionary *threadDict = [[NSThread currentThread] threadDictionary];
	NSDate *throttlingDate = [threadDict objectForKey:@"throttlingDate"];
	NSUInteger dataLength = [incrementalData length];
	
	self.totalBytesTransferred += dataLength;
	self.bytesTransferred += dataLength;
	
	if (self.fileHandle)
	{
		// Save the data to the file
		@try
		{
			[self.fileHandle writeData:incrementalData];
		}
		@catch (NSException *exception) 
		{
			DLog(@"Failed to write to file %@, %@ - %@", self.mySong, exception.name, exception.description);
			[GCDWrapper runInMainThreadAndWaitUntilDone:NO block:^{ [self cancel]; }];
		}
		
		// Notify delegate if enough bytes received to start playback
		if (!self.isDelegateNotifiedToStartPlayback && self.totalBytesTransferred >= ISMSMinBytesToStartPlayback(self.bitrate))
		{
			DLog(@"telling player to start, min bytes: %u, total bytes: %llu, bitrate: %u", ISMSMinBytesToStartPlayback(self.bitrate), self.totalBytesTransferred, self.bitrate);
			self.isDelegateNotifiedToStartPlayback = YES;
			//DLog(@"player told to start playback");
			[GCDWrapper runInMainThreadAndWaitUntilDone:NO block:^{ [self startPlaybackInternal]; }];
		}
		
		// Log progress
		if (isProgressLoggingEnabled)
			DLog(@"downloadedLengthA:  %llu   bytesRead: %i", self.totalBytesTransferred, dataLength);
		
		// If near beginning of file, don't throttle
		if (self.totalBytesTransferred < ISMSMinBytesToStartLimiting(self.bitrate))
		{
			NSDate *now = [[NSDate alloc] init];
			[threadDict setObject:now forKey:@"throttlingDate"];
			self.bytesTransferred = 0;		
		}
		
		// Check if we should throttle
		NSDate *now = [[NSDate alloc] init];
		NSTimeInterval intervalSinceLastThrottle = [now timeIntervalSinceDate:throttlingDate];
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
					DLog(@"Pausing for %f  interval: %f  bytesTransferred: %llu maxBytes: %f", delay, intervalSinceLastThrottle, self.bytesTransferred, maxBytesPerTotalInterval);
				
				self.bytesTransferred = 0;
			}
			
			[NSThread sleepForTimeInterval:delay];
			
			if (self.isCanceled)
				return;
			
			NSDate *newThrottlingDate = [[NSDate alloc] init];
			[threadDict setObject:newThrottlingDate forKey:@"throttlingDate"];
		}
		
		// Handle partial pre-cache next song
		if (!self.isCurrentSong && !self.isTempCache && settingsS.isPartialCacheNextSong && self.partialPrecacheSleep)
		{
			NSUInteger partialPrecacheSize = ISMSNumBytesToPartialPreCache(self.mySong.estimatedBitrate);
			if (self.totalBytesTransferred >= partialPrecacheSize)
			{
				[GCDWrapper runInMainThreadAndWaitUntilDone:NO block:^{ [self partialPrecachePausedInternal]; }];
				while (self.partialPrecacheSleep && !self.tempBreakPartialPrecache)
				{
					[NSThread sleepForTimeInterval:0.1];
				}
				self.tempBreakPartialPrecache = NO;
				[GCDWrapper runInMainThreadAndWaitUntilDone:NO block:^{ [self partialPrecacheUnpausedInternal]; }];
			}
		}
	}
	else
	{
		if (!self.isCanceled)
		{
			// There is no file handle for some reason, cancel the connection
			[self.connection cancel];
			[self connection:self.connection didFailWithError:nil];
		}
	}
	
#if isSpeedLoggingEnabled
	if (isSpeedLoggingEnabled)
	{
		NSTimeInterval speedInteval = [[NSDate date] timeIntervalSinceDate:self.speedLoggingDate];
		
		// Check every 10 seconds
		if (speedInteval >= 10.0)
		{
			unsigned long long transferredSinceLastCheck = self.totalBytesTransferred - self.speedLoggingLastSize;
			
			double speedInBytes = (double)transferredSinceLastCheck / speedInteval;
			double speedInKbytes = speedInBytes / 1024.;
			DLog(@"rate: %f  speedInterval: %f  transferredSinceLastCheck: %llu", speedInKbytes, speedInteval, transferredSinceLastCheck);
			
			self.speedLoggingLastSize = self.totalBytesTransferred;
			self.speedLoggingDate = [NSDate date];
		}
	}
#endif
}

// Main Thread
- (void)partialPrecachePausedInternal
{
	self.isPartialPrecacheSleeping = YES;
	
	[ISMSNetworkIndicator doneUsingNetwork];
	
	if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerPartialPrecachePaused:)])
		[self.delegate ISMSStreamHandlerPartialPrecachePaused:self];
}

// Main Thread
- (void)partialPrecacheUnpausedInternal
{
	self.isPartialPrecacheSleeping = NO;
	
	[ISMSNetworkIndicator usingNetwork];
	
	if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerPartialPrecacheUnpaused:)])
		[self.delegate ISMSStreamHandlerPartialPrecacheUnpaused:self];
}

// Main Thread
- (void)startPlaybackInternal
{
	if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerStartPlayback:)])
		[self.delegate ISMSStreamHandlerStartPlayback:self];
}

// loadingThread
- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	DLog(@"Connection Failed for %@", mySong.title);
	DLog(@"error domain: %@  code: %i description: %@", error.domain, error.code, error.description);
	
	// Perform these operations on the main thread
	[GCDWrapper runInMainThreadAndWaitUntilDone:YES block:^{ [self didFailInternal:error]; }];
	
	// Stop the run loop so the thread can die
	[self cancelRunLoop];
}	

// Main Thread
- (void)didFailInternal:(NSError *)error
{
	self.isDownloading = NO;
	
	self.connection = nil;
	
	// Close the file handle
	[self.fileHandle closeFile];
	self.fileHandle = nil;
	
	[ISMSNetworkIndicator doneUsingNetwork];
	
	if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerConnectionFailed:withError:)])
		[self.delegate ISMSStreamHandlerConnectionFailed:self withError:error];
}

// loadingThread
- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{		
	DLog(@"Connection Finished Successfully for %@", mySong.title);
	DLog(@"localSize: %llu   contentLength: %llu", mySong.localFileSize, self.contentLength);
		
	// Check to see if we're within 100K of the contentLength (to allow some leeway for contentLength estimation of transcoded songs
	if (self.contentLength != ULLONG_MAX && mySong.localFileSize < self.contentLength - BytesToKB(100) && self.numberOfContentLengthFailures < ISMSMaxContentLengthFailures)
	{
		self.numberOfContentLengthFailures++;
		// This is a failed connection that didn't call didFailInternal for some reason, so call didFailWithError
		[self connection:theConnection didFailWithError:nil];
	}
	else 
	{
		// Make sure the player is told to start
		if (!self.isDelegateNotifiedToStartPlayback)
		{
			self.isDelegateNotifiedToStartPlayback = YES;
			[GCDWrapper runInMainThreadAndWaitUntilDone:YES block:^{ [self startPlaybackInternal]; }];
		}
		
		// Perform these operations on the main thread
		[GCDWrapper runInMainThreadAndWaitUntilDone:YES block:^{ [self didFinishLoadingInternal]; }];
		
		// Stop the run loop so the thread can die
		[self cancelRunLoop];
	}
}

// Main Thread
- (void)didFinishLoadingInternal
{
	self.isDownloading = NO;
	
	self.connection = nil;
	
	// Close the file handle
	[self.fileHandle closeFile];
	self.fileHandle = nil;
	
	[ISMSNetworkIndicator doneUsingNetwork];
	
	if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerConnectionFinished:)])
		[self.delegate ISMSStreamHandlerConnectionFinished:self];
}

#pragma mark - Overriding equality

- (NSUInteger)hash
{
	return [mySong.songId hash];
}

- (BOOL)isEqualToISMSStreamHandler:(ISMSStreamHandler *)otherHandler 
{
	if (self == otherHandler)
		return YES;
	
	return [mySong isEqualToSong:otherHandler.mySong];
}

- (BOOL)isEqual:(id)other 
{
	if (other == self)
		return YES;
	
	if (!other || ![other isKindOfClass:[self class]])
		return NO;
	
	return [self isEqualToISMSStreamHandler:other];
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:self.mySong forKey:@"mySong"];
	[encoder encodeInt64:self.byteOffset forKey:@"byteOffset"];
	[encoder encodeDouble:self.secondsOffset forKey:@"secondsOffset"];
	[encoder encodeBool:self.isDelegateNotifiedToStartPlayback forKey:@"isDelegateNotifiedToStartPlayback"];
	[encoder encodeBool:self.isTempCache forKey:@"isTempCache"];
	[encoder encodeBool:self.isDownloading forKey:@"isDownloading"];
	[encoder encodeInt64:self.contentLength forKey:@"contentLength"];
	[encoder encodeInt32:self.maxBitrateSetting forKey:@"maxBitrateSetting"];
}


- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{		
		[self setup];
		
		mySong = [[decoder decodeObjectForKey:@"mySong"] copy];
		byteOffset = [decoder decodeInt64ForKey:@"byteOffset"];
		secondsOffset = [decoder decodeDoubleForKey:@"secondsOffset"];
		isDelegateNotifiedToStartPlayback = [decoder decodeBoolForKey:@"isDelegateNotifiedToStartPlayback"];
		isTempCache = [decoder decodeBoolForKey:@"isTempCache"];
		isDownloading = [decoder decodeBoolForKey:@"isDownloading"];
		contentLength = [decoder decodeInt64ForKey:@"contentLength"];
		maxBitrateSetting = [decoder decodeInt32ForKey:@"maxBitrateSetting"];
	}
	
	return self;
}

@end
