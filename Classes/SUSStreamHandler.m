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
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "SUSCoverArtLargeDAO.h"
#import "SavedSettings.h"
#import "CacheSingleton.h"
#import "PlaylistSingleton.h"

#define ISMSNumSecondsToPartialPreCache 30

#define kThrottleTimeInterval 0.1

#define kMaxKilobitsPerSec3G 500
#define kMaxBytesPerSec3G ((kMaxKilobitsPerSec3G * 1024) / 8)
#define kMaxBytesPerInterval3G (kMaxBytesPerSec3G * kThrottleTimeInterval)

#define kMaxKilobitsPerSecWifi 8000
#define kMaxBytesPerSecWifi ((kMaxKilobitsPerSecWifi * 1024) / 8)
#define kMaxBytesPerIntervalWifi (kMaxBytesPerSecWifi * kThrottleTimeInterval)

#define kMinKiloBytesToStartPlayback 250
#define kMinBytesToStartPlayback (1024 * kMinKiloBytesToStartPlayback) // Number of bytes to wait before activating the player
#define kMinBytesToStartLimiting (1024 * 1024)	// Start throttling bandwidth after 1 MB downloaded for 160kbps files (adjusted accordingly by bitrate)

// Logging
#define isProgressLoggingEnabled NO
#define isThrottleLoggingEnabled NO

@implementation SUSStreamHandler
@synthesize totalBytesTransferred, bytesTransferred, mySong, connection, byteOffset, delegate, fileHandle, isDelegateNotifiedToStartPlayback, numOfReconnects, request, loadingThread, isTempCache, secondsOffset, partialPrecacheSleep;

- (id)initWithSong:(Song *)song byteOffset:(unsigned long long)bOffset secondsOffset:(double)sOffset isTemp:(BOOL)isTemp delegate:(NSObject<SUSStreamHandlerDelegate> *)theDelegate
{
	if ((self = [super init]))
	{
		mySong = [song copy];
		delegate = theDelegate;
		byteOffset = bOffset;
		secondsOffset = sOffset;
		isDelegateNotifiedToStartPlayback = NO;
		numOfReconnects = 0;
		loadingThread = nil;
		request = nil;
		connection = nil;
		isTempCache = isTemp;
		partialPrecacheSleep = YES;
		
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
			totalBytesTransferred = [self.fileHandle seekToEndOfFile];
		}
		else
		{
			// File exists so remove it
			[self.fileHandle closeFile];
			[[NSFileManager defaultManager] removeItemAtPath:self.filePath error:NULL];
		}
	}
	
	if (resume)
	{
		byteOffset = totalBytesTransferred;
	}
	else
	{
		// Create the file
		totalBytesTransferred = 0;
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

	loadingThread = [[NSThread alloc] initWithTarget:self selector:@selector(startConnection) object:nil];
	
	NSNumber *bitrate = [[NSNumber alloc] initWithInt:mySong.estimatedBitrate];
	[loadingThread.threadDictionary setObject:bitrate forKey:@"bitrate"];
	[bitrate release];
	
	NSDate *now = [[NSDate alloc] init];
	[loadingThread.threadDictionary setObject:now forKey:@"throttlingDate"];
	[now release];
	
	NSNumber *isWifi = [[NSNumber alloc] initWithBool:[iSubAppDelegate sharedInstance].isWifi];
	[loadingThread.threadDictionary setObject:isWifi forKey:@"isWifi"];
	[isWifi release];
	
	[loadingThread.threadDictionary setObject:[[mySong copy] autorelease] forKey:@"mySong"];
	
	[loadingThread.threadDictionary setObject:[NSNumber numberWithBool:isTempCache] forKey:@"isTempCache"];
	
	if ([mySong isEqualToSong:[[PlaylistSingleton sharedInstance] nextSong]])
	{
		[loadingThread.threadDictionary setObject:[NSNumber numberWithBool:YES] forKey:@"isNextSong"];
	}
		
	[loadingThread start];
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
		connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
		if (connection)
		{
			[self performSelectorOnMainThread:@selector(startConnectionInternalSuccess) withObject:nil waitUntilDone:YES];
			DLog(@"connection starting, starting runloop");
			CFRunLoopRun();
			DLog(@"run loop finished");
		}
		else
		{
			[self performSelectorOnMainThread:@selector(startConnectionInternalFailure) withObject:nil waitUntilDone:YES];
		}
	}
}

- (void)startConnectionInternalSuccess
{
	if (!isTempCache)
		mySong.isPartiallyCached = YES;
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
	// Pop out of infinite loop if partially pre-cached
	self.partialPrecacheSleep = NO;
	
	DLog(@"request canceled");
	[connection cancel]; 
	[connection release]; connection = nil;
	
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
	bytesTransferred = 0;
}

- (double)maxBytesPerIntervalForBitrate:(double)bitrate is3G:(BOOL)is3G
{
	/*double maxBytesDefault = is3G ? (double)kMaxBytesPerInterval3G : (double)kMaxBytesPerIntervalWifi;
	double bitrateForCalc = bitrate;
	NSString *suffix = [transcodedSuffix lowercaseString];
	if ([suffix isEqualToString:@"mp3"] || [suffix isEqualToString:@"ogg"] || [suffix isEqualToString:@"m4a"] || [suffix isEqualToString:@"aac"])
	{
		// This song is a lossy transcode, don't rely on the original reported bitrate, assume 320
		bitrateForCalc = 320.0f;
	}
	double maxBytesPerInterval = maxBytesDefault * (bitrateForCalc / 160.0);
	if (maxBytesPerInterval < maxBytesDefault)
	{
		// Don't go lower than the default
		maxBytesPerInterval = maxBytesDefault;
	}
	else if (maxBytesPerInterval > (double)kMaxBytesPerIntervalWifi * 2.0)
	{
		// Don't go higher than twice the Wifi limit to prevent disk bandwidth issues
		maxBytesPerInterval = (double)kMaxBytesPerIntervalWifi * 2.0;
	}
	
	return maxBytesPerInterval;*/
	
	double maxBytesDefault = is3G ? (double)kMaxBytesPerInterval3G : (double)kMaxBytesPerIntervalWifi;
	double maxBytesPerInterval = maxBytesDefault * (bitrate / 160.0);
	if (maxBytesPerInterval < maxBytesDefault)
	{
		// Don't go lower than the default
		maxBytesPerInterval = maxBytesDefault;
	}
	else if (maxBytesPerInterval > (double)kMaxBytesPerIntervalWifi * 2.0)
	{
		// Don't go higher than twice the Wifi limit to prevent disk bandwidth issues
		maxBytesPerInterval = (double)kMaxBytesPerIntervalWifi * 2.0;
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
	BOOL isWifi = [[threadDict objectForKey:@"isWifi"] boolValue];
	
	totalBytesTransferred += dataLength;
	bytesTransferred += dataLength;
		
	// Save the data to the file
	[fileHandle writeData:incrementalData];
	
	// Notify delegate if enough bytes received to start playback
	if (!isDelegateNotifiedToStartPlayback && totalBytesTransferred >= kMinBytesToStartPlayback)
	{
		isDelegateNotifiedToStartPlayback = YES;
		//DLog(@"player told to start playback");
		[self performSelectorOnMainThread:@selector(startPlaybackInternal) withObject:nil waitUntilDone:NO];
	}
	
	// Log progress
	if (isProgressLoggingEnabled)
	{
		DLog(@"downloadedLengthA:  %lu   bytesRead: %i", totalBytesTransferred, dataLength);
	}
	
	// If near beginning of file, don't throttle
	if (totalBytesTransferred < (kMinBytesToStartLimiting * (bitrate / 160.0f)))
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
	if (intervalSinceLastThrottle > kThrottleTimeInterval && totalBytesTransferred > (kMinBytesToStartLimiting * (bitrate / 160.0f)))
	{
		if (isThrottleLoggingEnabled)
			DLog(@"entering throttling if statement, interval: %f  bytes transferred: %lu  maxBytes: %f", intervalSinceLastThrottle, bytesTransferred, kMaxBytesPerInterval3G);
		
		NSTimeInterval delay = 0.0;
		if (!isWifi && bytesTransferred > kMaxBytesPerInterval3G)
		{
			double maxBytesPerInterval = [self maxBytesPerIntervalForBitrate:(double)bitrate is3G:YES];
			delay = (kThrottleTimeInterval * ((double)bytesTransferred / maxBytesPerInterval));
			bytesTransferred = 0;
			
			if (isThrottleLoggingEnabled)
				DLog(@"Bandwidth used is more than kMaxBytesPerInterval3G, Pausing for %f", delay);
		}
		else if (isWifi && bytesTransferred > kMaxBytesPerIntervalWifi)
		{
			double maxBytesPerInterval = [self maxBytesPerIntervalForBitrate:(double)bitrate is3G:NO];
			delay = (kThrottleTimeInterval * ((double)bytesTransferred / maxBytesPerInterval));
			bytesTransferred = 0;
			
			if (isThrottleLoggingEnabled)
				DLog(@"Bandwidth used is more than kMaxBytesPerIntervalWifi, Pausing for %f", delay);
		}
		
		[NSThread sleepForTimeInterval:delay];
		
		// Handle partial pre-cache next song
		SavedSettings *settings = [SavedSettings sharedInstance];
		BOOL isNextSong = [[threadDict objectForKey:@"isNextSong"] boolValue];
		BOOL tempCache = [[threadDict objectForKey:@"isTempCache"] boolValue];
		if (isNextSong && !tempCache && settings.isPartialCacheNextSong && self.partialPrecacheSleep)
		{
			Song *song = [threadDict objectForKey:@"mySong"];
			NSUInteger partialPrecacheSize = (song.estimatedBitrate / 8) * ISMSNumSecondsToPartialPreCache;
			if (totalBytesTransferred >= partialPrecacheSize)
			{
				while (self.partialPrecacheSleep)
				{
					[NSThread sleepForTimeInterval:0.1];
				}
			}
		}
		
		NSDate *newThrottlingDate = [[NSDate alloc] init];
		[threadDict setObject:newThrottlingDate forKey:@"throttlingDate"];
		[newThrottlingDate release];
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
	self.connection = nil;
	
	// Close the file handle
	[self.fileHandle closeFile];
	
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
	self.connection = nil;
	
	// Close the file handle
	[fileHandle closeFile];
	
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
		DLog(@"connection did finish");
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

@end