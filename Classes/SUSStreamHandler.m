//
//  SUSStreamConnectionDelegate.m
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSStreamHandler.h"
#import "MusicSingleton.h"
#import "AudioStreamer.h"
#import "Song.h"
#import "iSubAppDelegate.h"
#import "NSMutableURLRequest+SUS.h"

#define kThrottleTimeInterval 0.01

#define kMaxKilobitsPerSec3G 550
#define kMaxBytesPerSec3G ((kMaxKilobitsPerSec3G * 1024) / 8)
#define kMaxBytesPerInterval3G (kMaxBytesPerSec3G * kThrottleTimeInterval)

#define kMaxKilobitsPerSecWifi 8000
#define kMaxBytesPerSecWifi ((kMaxKilobitsPerSecWifi * 1024) / 8)
#define kMaxBytesPerIntervalWifi (kMaxBytesPerSecWifi * kThrottleTimeInterval)

#define kMinBytesToStartPlayback (1024 * 50)    // Number of bytes to wait before activating the player
#define kMinBytesToStartLimiting (1024 * 1024)   // Start throttling bandwidth after 1 MB downloaded for 192kbps files (adjusted accordingly by bitrate)

// Logging
#define isProgressLoggingEnabled NO
#define isThrottleLoggingEnabled NO

@implementation SUSStreamHandler
@synthesize bytesTransferred, throttlingDate, songId;

- (id)initWithSongId:(NSString *)theSongId
{
	if ((self = [super init]))
	{
		songId = [theSongId copy];
		
		[self performSelectorInBackground:@selector(createConnection) withObject:nil]; 
	}
	
	return self;
}

- (NSDictionary *)generateParameters
{	
    MusicSingleton *musicControls = [MusicSingleton sharedInstance];
    
    if ([musicControls maxBitrateSetting] != 0)
	{
		NSString *bitrate = [NSString stringWithFormat:@"%i", musicControls.maxBitrateSetting];
		return [NSDictionary dictionaryWithObjectsAndKeys:n2N(bitrate), @"maxBitRate", n2N(songId), @"id", nil];
	}
    else
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:n2N(songId), @"id", nil];
	}
}

- (void)createConnection
{
	@autoreleasepool 
	{
		NSDictionary *parameters = [self generateParameters];
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"stream" andParameters:parameters];
		NSURLConnection *connection = [NSURLConnection connectionWithRequest:request delegate:self];
		if (!connection)
		{
			[self autorelease];
		}
	}
}

- (NSUInteger)currentSongBitrate
{
	MusicSingleton *musicControls = [MusicSingleton sharedInstance];
	
	int bitRate = 128;
	
	if (musicControls.currentSongObject.bitRate == nil)
		bitRate = 128;
	else if ([musicControls.currentSongObject.bitRate intValue] < 1000)
		bitRate = [musicControls.currentSongObject.bitRate intValue];
	else
		bitRate = [musicControls.currentSongObject.bitRate intValue] / 1000;
	
	if (bitRate > musicControls.maxBitrateSetting && musicControls.maxBitrateSetting != 0)
		bitRate = musicControls.maxBitrateSetting;
	
	return bitRate;
}

- (NSUInteger)nextSongBitrate
{
	MusicSingleton *musicControls = [MusicSingleton sharedInstance];
	
	int bitRate = 128;
	
	if (musicControls.nextSongObject.bitRate == nil)
		bitRate = 128;
	else if ([musicControls.nextSongObject.bitRate intValue] < 1000)
		bitRate = [musicControls.nextSongObject.bitRate intValue];
	else
		bitRate = [musicControls.nextSongObject.bitRate intValue] / 1000;
	
	if (bitRate > musicControls.maxBitrateSetting && musicControls.maxBitrateSetting != 0)
		bitRate = musicControls.maxBitrateSetting;
	
	return bitRate;
}

- (BOOL)mSleep:(NSUInteger)milliseconds
{
	struct timespec tim;
	
	if (milliseconds > 1000)
	{
		tim.tv_sec = milliseconds / 1000
		tim.tv_nsec = (milliseconds % 1000) * 1000000;
	}
	else
	{	
		tim.tv_sec = 0;
		tim.tv_nsec = milliseconds * 1000000
	}
	
	if(nanosleep(&tim , NULL) < 0)   
	{
		return NO;
	}
	
	return YES;
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

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{	
	MusicSingleton *musicControls = [MusicSingleton sharedInstance];
	iSubAppDelegate *appDelegate = [iSubAppDelegate sharedInstance];
	
	long bytesRead = [incrementalData length];
	
	// Save the data to the file
	[musicControls.audioFileA writeData:incrementalData];
	musicControls.downloadedLengthA = musicControls.downloadedLengthA + bytesRead;
	
	if (isProgressLoggingEnabled)
		DLog(@"downloadedLengthA:  %lu   bytesRead: %ld", musicControls.downloadedLengthA, bytesRead);
	
	if ([musicControls streamer])
		musicControls.streamer.fileDownloadCurrentSize = musicControls.downloadedLengthA;
	
	// When we get enough of the file, then just start playing it.
	if (!musicControls.streamer && (musicControls.downloadedLengthA > kMinBytesToStartPlayback)) 
	{
		//DLog(@"start playback for %@", [musicControlsRef downloadFileNameA]);
		
		[musicControls createStreamer];
		musicControls.showNowPlayingIcon = NO;
	}
	
	// Handle bandwidth throttling
	bytesTransferred += bytesRead;
	
	if (musicControls.downloadedLengthA < (kMinBytesToStartLimiting * ((float)self.currentSongBitrate / 160.0f)))
	{
		self.throttlingDate = [NSDate date];
		bytesTransferred = 0;
	}
	
	if ([[NSDate date] timeIntervalSinceDate:self.throttlingDate] > kThrottleTimeInterval &&
		musicControls.downloadedLengthA > (kMinBytesToStartLimiting * ((float)self.currentSongBitrate / 160.0f)))
	{
		if (appDelegate.isWifi == NO && bytesTransferred > kMaxBytesPerInterval3G)
		{
			CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
			
			//Calculate how many intervals to pause
			NSTimeInterval delay = (kThrottleTimeInterval * ((double)bytesTransferred / (double)kMaxBytesPerInterval3G));
			
			if (isThrottleLoggingEnabled)
				DLog(@"Bandwidth used is more than kMaxBytesPerSec3G, Pausing for %f", delay);
			
			[NSTimer scheduledTimerWithTimeInterval:delay target:[SUSDownloadSingleton sharedInstance] selector:@selector(continueDownloadA) userInfo:nil repeats:NO];
			
			bytesTransferred = 0;
		}
		else if (appDelegate.isWifi && bytesTransferred > kMaxBytesPerIntervalWifi)
		{
			CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
			
			//Calculate how many intervals to pause
			NSTimeInterval delay = (kThrottleTimeInterval * ((double)bytesTransferred / (double)kMaxBytesPerIntervalWifi));
			
			if (isThrottleLoggingEnabled)
				DLog(@"Bandwidth used is more than kMaxBytesPerSec3G, Pausing for %f", delay);
			
			[NSTimer scheduledTimerWithTimeInterval:delay target:[SUSDownloadSingleton sharedInstance] selector:@selector(continueDownloadA) userInfo:nil repeats:NO];
			
			bytesTransferred = 0;
		}				
	}
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	theConnection = nil;
	
	[[MusicSingleton sharedInstance] resumeDownloadA:[[MusicSingleton sharedInstance] downloadedLengthA]];
	
	[self autorelease];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	theConnection = nil;
	
	[self autorelease];
}

@end
