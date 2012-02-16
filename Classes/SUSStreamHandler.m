//
//  SUSStreamConnectionDelegate.m
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSStreamHandler.h"
#import "MusicSingleton.h"
#import "Song.h"
#import "iSubAppDelegate.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSError+ISMSError.h"
#import "NSString+md5.h"
#import "DatabaseSingleton.h"
#import "FMDatabaseAdditions.h"
#import "SUSCoverArtLargeDAO.h"
#import "SavedSettings.h"
#import "CacheSingleton.h"
#import "PlaylistSingleton.h"

#define ISMSNumSecondsToPartialPreCache 30
#define ISMSNumBytesToPartialPreCache(bitrate) (BytesForSecondsAtBitrate(ISMSNumSecondsToPartialPreCache, bitrate))

#define ISMSMinSecondsToStartPlayback 5
#define ISMSMinBytesToStartPlayback(bitrate) (BytesForSecondsAtBitrate(ISMSMinSecondsToStartPlayback, bitrate))

#define ISMSThrottleTimeInterval 0.1

#define ISMSMaxKilobitsPerSec3G 500
#define ISMSMaxBytesPerInterval3G BytesForSecondsAtBitrate(ISMSThrottleTimeInterval, ISMSMaxKilobitsPerSec3G)

#define ISMSMaxKilobitsPerSecWifi 8000
#define ISMSMaxBytesPerIntervalWifi BytesForSecondsAtBitrate(ISMSThrottleTimeInterval, ISMSMaxKilobitsPerSecWifi)

#define ISMSMinBytesToStartLimiting(bitrate) (BytesForSecondsAtBitrate(60, bitrate))

//#define kMinKiloBytesToStartPlayback 250
//#define kMinBytesToStartPlayback ((unsigned long long)(1024 * kMinKiloBytesToStartPlayback)) // Number of bytes to wait before activating the player
//#define kMinBytesToStartLimiting ((unsigned long long)(1024 * 1024))	// Start throttling bandwidth after 1 MB downloaded for 160kbps files (adjusted accordingly by bitrate)

// Logging
#define isProgressLoggingEnabled NO
#define isThrottleLoggingEnabled NO

@implementation SUSStreamHandler
@synthesize totalBytesTransferred, bytesTransferred, mySong, connection, byteOffset, delegate, fileHandle, isDelegateNotifiedToStartPlayback, numOfReconnects, request, loadingThread, isTempCache, secondsOffset, partialPrecacheSleep, isDownloading;

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
	partialPrecacheSleep = YES;
	isDownloading = NO;
	
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

- (id)initWithSong:(Song *)song byteOffset:(unsigned long long)bOffset secondsOffset:(double)sOffset isTemp:(BOOL)isTemp delegate:(NSObject<SUSStreamHandlerDelegate> *)theDelegate
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

- (id)initWithSong:(Song *)song isTemp:(BOOL)isTemp delegate:(NSObject<SUSStreamHandlerDelegate> *)theDelegate
{
	return [self initWithSong:song byteOffset:0 secondsOffset:0.0 isTemp:isTemp delegate:theDelegate];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	
	[loadingThread release]; loadingThread = nil;
	[fileHandle release]; fileHandle = nil;
	[mySong release]; mySong = nil;
	[request release]; request = nil;
	[connection release]; connection = nil;
	[super dealloc];
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
		// Remove temp file for this song if exists
		[[NSFileManager defaultManager] removeItemAtPath:self.mySong.localTempPath error:NULL];
		
		// Clear cache if this is a temp file
		if (self.isTempCache)
			[[CacheSingleton sharedInstance] clearTempCache];
	}
	
	SavedSettings *settings = [SavedSettings sharedInstance];

	// Create the file handle
	self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.filePath];
	
	if (self.fileHandle)
	{
		if (resume)
		{
			// File exists so seek to end
			self.totalBytesTransferred = [self.fileHandle seekToEndOfFile];
			self.byteOffset = self.totalBytesTransferred;
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
	if (settings.currentMaxBitrate != 0)
	{
		NSString *bitrate = [[NSString alloc] initWithFormat:@"%i", settings.currentMaxBitrate];
		[parameters setObject:n2N(bitrate) forKey:@"maxBitRate"];
		[bitrate release];
	}
	self.request = [NSMutableURLRequest requestWithSUSAction:@"stream" andParameters:parameters byteOffset:byteOffset];

	self.loadingThread = [[[NSThread alloc] initWithTarget:self selector:@selector(startConnection) object:nil] autorelease];
	
	NSNumber *bitrate = [[NSNumber alloc] initWithInt:mySong.estimatedBitrate];
	[self.loadingThread.threadDictionary setObject:bitrate forKey:@"bitrate"];
	[bitrate release];
	
	NSDate *now = [[NSDate alloc] init];
	[self.loadingThread.threadDictionary setObject:now forKey:@"throttlingDate"];
	[now release];
	
	//[self.loadingThread.threadDictionary setObject:[[mySong copy] autorelease] forKey:@"mySong"];
	[self.loadingThread.threadDictionary setObject:[NSNumber numberWithBool:isTempCache] forKey:@"isTempCache"];
	DLog(@"mySong: %@   nextSong: %@", mySong, [[PlaylistSingleton sharedInstance] nextSong]);
	if ([self.mySong isEqualToSong:[[PlaylistSingleton sharedInstance] nextSong]])
	{
		[self.loadingThread.threadDictionary setObject:[NSNumber numberWithBool:YES] forKey:@"isNextSong"];
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
			[self performSelectorOnMainThread:@selector(startConnectionInternalSuccess) withObject:nil waitUntilDone:YES];
			DLog(@"Stream handler download starting for %@", mySong);
			CFRunLoopRun();
			DLog(@"Stream handler runloop finished for %@", mySong);
		}
		else
		{
			[self performSelectorOnMainThread:@selector(startConnectionInternalFailure) withObject:nil waitUntilDone:YES];
		}
	}
}

- (void)startConnectionInternalSuccess
{
	if (!self.isTempCache)
		self.mySong.isPartiallyCached = YES;
}

- (void)startConnectionInternalFailure
{
	NSError *error = [[NSError alloc] initWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
	[self.delegate SUSStreamHandlerConnectionFailed:self withError:error];
	[error release];
}

// Cancel the download and stop the run loop in loadingThread
- (void)cancel
{
	self.isDownloading = NO;
	
	// Pop out of infinite loop if partially pre-cached
	self.partialPrecacheSleep = NO;
	
	DLog(@"Stream handler request canceled for %@", mySong);
	[self.connection cancel]; 
	self.connection = nil;
	
	[self.fileHandle closeFile];
	self.fileHandle = nil;
	
	[self performSelector:@selector(cancelRunLoop) onThread:loadingThread withObject:nil waitUntilDone:NO];
}

// Stop the current run loop
- (void)cancelRunLoop
{
	CFRunLoopStop(CFRunLoopGetCurrent());
}

- (void)playlistIndexChanged
{
	// If this song is partially precached and sleeping, stop sleeping
	self.partialPrecacheSleep = NO;
}

#pragma mark - Connection Delegate

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	self.bytesTransferred = 0;
}

- (double)maxBytesPerIntervalForBitrate:(double)bitrate is3G:(BOOL)is3G
{
	double maxBytesDefault = is3G ? (double)ISMSMaxBytesPerInterval3G : (double)ISMSMaxBytesPerIntervalWifi;
	double maxBytesPerInterval = maxBytesDefault * (bitrate / 160.0);
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

BOOL isBeginning = YES;

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{		
	NSMutableDictionary *threadDict = [[NSThread currentThread] threadDictionary];
	CGFloat bitrate = [[threadDict objectForKey:@"bitrate"] floatValue];
	NSDate *throttlingDate = [[threadDict objectForKey:@"throttlingDate"] retain];
	NSUInteger dataLength = [incrementalData length];
	
	self.totalBytesTransferred += dataLength;
	self.bytesTransferred += dataLength;
		
	// Save the data to the file
	@try
	{
		[fileHandle writeData:incrementalData];
	}
	@catch (NSException *exception) 
	{
		DLog(@"Failed to write to file %@, %@ - %@", self.mySong, exception.name, exception.description);
		[self performSelectorOnMainThread:@selector(cancel) withObject:nil waitUntilDone:NO];
	}
	
	// Notify delegate if enough bytes received to start playback
	if (!isDelegateNotifiedToStartPlayback && totalBytesTransferred >= ISMSMinBytesToStartPlayback(bitrate))
	{
		isDelegateNotifiedToStartPlayback = YES;
		//DLog(@"player told to start playback");
		[self performSelectorOnMainThread:@selector(startPlaybackInternal) withObject:nil waitUntilDone:NO];
	}
	
	// Log progress
	if (isProgressLoggingEnabled)
		DLog(@"downloadedLengthA:  %llu   bytesRead: %i", totalBytesTransferred, dataLength);
	
	// If near beginning of file, don't throttle
	if (totalBytesTransferred < ISMSMinBytesToStartLimiting(bitrate))
	{
		NSDate *now = [[NSDate alloc] init];
		[threadDict setObject:now forKey:@"throttlingDate"];
		[now release];
		bytesTransferred = 0;		
	}
	
	// Check if we should throttle
	NSDate *now = [[NSDate alloc] init];
	NSTimeInterval intervalSinceLastThrottle = [now timeIntervalSinceDate:throttlingDate];
	[throttlingDate release];
	[now release];
	if (intervalSinceLastThrottle > ISMSThrottleTimeInterval && totalBytesTransferred > (unsigned long long)(ISMSMinBytesToStartLimiting(bitrate)))
	{
		//if (isThrottleLoggingEnabled)
		//	DLog(@"entering throttling if statement, interval: %f  bytes transferred: %llu  maxBytes: %f", intervalSinceLastThrottle, bytesTransferred, ISMSMaxBytesPerInterval3G(bitrate));
		
		NSTimeInterval delay = 0.0;
		if (![iSubAppDelegate sharedInstance].isWifi && bytesTransferred > ISMSMaxBytesPerInterval3G)
		{
			double maxBytesPerInterval = [self maxBytesPerIntervalForBitrate:(double)bitrate is3G:YES];
			delay = (ISMSThrottleTimeInterval * ((double)bytesTransferred / maxBytesPerInterval));
			bytesTransferred = 0;
			
			if (isThrottleLoggingEnabled)
				DLog(@"Bandwidth used is more than kMaxBytesPerInterval3G, Pausing for %f", delay);
		}
		else if ([iSubAppDelegate sharedInstance].isWifi && bytesTransferred > ISMSMaxBytesPerIntervalWifi)
		{
			double maxBytesPerInterval = [self maxBytesPerIntervalForBitrate:(double)bitrate is3G:NO];
			delay = (ISMSThrottleTimeInterval * ((double)bytesTransferred / maxBytesPerInterval));
			bytesTransferred = 0;
			
			if (isThrottleLoggingEnabled)
				DLog(@"Bandwidth used is more than kMaxBytesPerIntervalWifi, Pausing for %f", delay);
		}
		
		[NSThread sleepForTimeInterval:delay];
		
		NSDate *newThrottlingDate = [[NSDate alloc] init];
		[threadDict setObject:newThrottlingDate forKey:@"throttlingDate"];
		[newThrottlingDate release];
	}
	
	// Handle partial pre-cache next song
	SavedSettings *settings = [SavedSettings sharedInstance];
	BOOL isNextSong = [[threadDict objectForKey:@"isNextSong"] boolValue];
	BOOL tempCache = [[threadDict objectForKey:@"isTempCache"] boolValue];
	if (isNextSong && !tempCache && settings.isPartialCacheNextSong && self.partialPrecacheSleep)
	{
		NSUInteger partialPrecacheSize = BytesForSecondsAtBitrate(ISMSNumSecondsToPartialPreCache, self.mySong.estimatedBitrate);
		if (totalBytesTransferred >= partialPrecacheSize)
		{
			while (self.partialPrecacheSleep)
			{
				[NSThread sleepForTimeInterval:0.1];
			}
		}
	}
}

// Main Thread
- (void)startPlaybackInternal
{
	[self.delegate SUSStreamHandlerStartPlayback:self byteOffset:byteOffset secondsOffset:secondsOffset];
}

// loadingThread
- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	// Perform these operations on the main thread
	[self performSelectorOnMainThread:@selector(didFailInternal:) withObject:error waitUntilDone:YES];
	
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
	
	[self.delegate SUSStreamHandlerConnectionFailed:self withError:error];
}

// loadingThread
- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{		
	// Perform these operations on the main thread
	[self performSelectorOnMainThread:@selector(didFinishLoadingInternal) withObject:nil waitUntilDone:YES];
	
	// Stop the run loop so the thread can die
	[self cancelRunLoop];
}

// Main Thread
- (void)didFinishLoadingInternal
{
	self.isDownloading = NO;
	
	self.connection = nil;
	
	// Close the file handle
	[fileHandle closeFile];
	self.fileHandle = nil;
	
	if (totalBytesTransferred < 500)
	{
		// Show an alert and delete the file, this was not a song but an XML error
		// TODO: Parse with TBXML and display proper error
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"No song data returned. This could be because your Subsonic API trial has expired, this song is not an mp3 and the Subsonic transcoding plugins failed, or another reason." delegate:[iSubAppDelegate sharedInstance] cancelButtonTitle:@"OK" otherButtonTitles: nil];
		[alert show];
		[alert release];
		[[NSFileManager defaultManager] removeItemAtPath:self.filePath error:NULL];
	}
	else
	{		
		// Mark song as cached
		DLog(@"Stream handler connection did finish for %@", mySong);
		if (!isTempCache)
			mySong.isFullyCached = YES;
	}
	
	[self.delegate SUSStreamHandlerConnectionFinished:self];
}

#pragma mark - Overriding equality

- (NSUInteger)hash
{
	return [mySong.songId hash];
}

- (BOOL)isEqualToSUSStreamHandler:(SUSStreamHandler	*)otherHandler 
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
	
	return [self isEqualToSUSStreamHandler:other];
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:mySong forKey:@"mySong"];
	[encoder encodeInt64:byteOffset forKey:@"byteOffset"];
	[encoder encodeDouble:secondsOffset forKey:@"secondsOffset"];
	[encoder encodeInt32:totalBytesTransferred forKey:@"totalBytesTransferred"];
	[encoder encodeBool:isDelegateNotifiedToStartPlayback forKey:@"isDelegateNotifiedToStartPlayback"];
	[encoder encodeBool:isTempCache forKey:@"isTempCache"];
	[encoder encodeBool:isDownloading forKey:@"isDownloading"];
}


- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{		
		[self setup];
		
		mySong = [[decoder decodeObjectForKey:@"mySong"] copy];
		byteOffset = [decoder decodeInt64ForKey:@"byteOffset"];
		secondsOffset = [decoder decodeDoubleForKey:@"secondsOffset"];
		totalBytesTransferred = [decoder decodeInt32ForKey:@"totalBytesTransferred"];
		isDelegateNotifiedToStartPlayback = [decoder decodeBoolForKey:@"isDelegateNotifiedToStartPlayback"];
		isTempCache = [decoder decodeBoolForKey:@"isTempCache"];
		isDownloading = [decoder decodeBoolForKey:@"isDownloading"];
	}
	
	return self;
}

@end
