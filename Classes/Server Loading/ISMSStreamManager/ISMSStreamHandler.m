//
//  ISMSStreamHandler.m
//  Anghami
//
//  Created by Ben Baron on 7/4/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "ISMSStreamHandler.h"
#import "iSub-Swift.h"


@implementation ISMSStreamHandler

- (void)setup
{
	_contentLength = -1;
	_maxBitrateSetting = -1;
	
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

- (id)initWithSong:(Song *)song byteOffset:(unsigned long long)bOffset isTemp:(BOOL)isTemp delegate:(NSObject<ISMSStreamHandlerDelegate> *)theDelegate
{
	if ((self = [self init]))
	{
		[self setup];
		
        _song = song;
		_delegate = theDelegate;
		_byteOffset = bOffset;
		_isTempCache = isTemp;
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playlistIndexChanged) name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	}
	
	return self;
}

- (id)initWithSong:(Song *)song isTemp:(BOOL)isTemp delegate:(NSObject<ISMSStreamHandlerDelegate> *)theDelegate
{
	return [self initWithSong:song byteOffset:0 isTemp:isTemp delegate:theDelegate];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)filePath
{
	return self.isTempCache ? self.song.localTempPath : self.song.localPath;
}

- (void)start
{
	[self start:NO];
}

- (void)start:(BOOL)resume
{
	// Override this
}

- (void)cancel
{
	// Override this
}

- (void)playlistIndexChanged
{
	if ([self.song isEqual:PlayQueue.si.currentSong])
		self.isCurrentSong = YES;
}

+ (long long)minBytesToStartPlaybackForKiloBitrate:(double)rate speedInBytesPerSec:(NSInteger)bytesPerSec
{
    // If start date is nil somehow, or total bytes transferred is 0 somehow,
    if (rate == 0. || bytesPerSec == 0)
    {
        return ISMSMinBytesToStartPlayback(rate);
    }
    
    // Get the download speed so far
    double kiloBytesPerSec = (double)bytesPerSec / 1024.;
    
    // Find out out many bytes equals 1 second of audio
    double bytesForOneSecond = BytesForSecondsAtBitrate(1, rate);
    double kiloBytesForOneSecond = bytesForOneSecond / 1024.;
    
    // Calculate the amount of seconds to start as a factor of how many seconds of audio are being downloaded per second
    double secondsPerSecondFactor = (double)kiloBytesPerSec / (double)kiloBytesForOneSecond;
        
    double minSecondsToStartPlayback;
    if (secondsPerSecondFactor < 1.0)
    {
        // Downloading slower than needed for playback, allow for a long buffer
        minSecondsToStartPlayback = 16;
    }
    else if (secondsPerSecondFactor >= 1.0 && secondsPerSecondFactor < 1.5)
    {
        // Downloading faster, but not much faster, allow for a long buffer period
        minSecondsToStartPlayback = 8;
    }
    else if (secondsPerSecondFactor >= 1.5 && secondsPerSecondFactor < 1.8)
    {
        minSecondsToStartPlayback = 6;
    }
    else if (secondsPerSecondFactor >= 1.8 && secondsPerSecondFactor < 2.0)
    {
        // Downloading fast enough for a smaller buffer
        minSecondsToStartPlayback = 4;
    }
    else
    {
        // Downloading multiple times playback speed, start quickly
        minSecondsToStartPlayback = 2;
    }
    
    // Convert from seconds to bytes
    long long minBytesToStartPlayback = minSecondsToStartPlayback * bytesForOneSecond;
    return minBytesToStartPlayback;
}

- (NSInteger)totalDownloadSpeedInBytesPerSec
{
    return self.totalBytesTransferred / [[NSDate date] timeIntervalSinceDate:self.startDate];
}

#pragma mark - Overriding equality

- (NSUInteger)hash
{
	return [self.song hash];
}

- (BOOL)isEqualToISMSStreamHandler:(ISMSStreamHandler *)otherHandler 
{
	if (self == otherHandler)
		return YES;
	
	return [self.song isEqual:otherHandler.song];
}

- (BOOL)isEqual:(id)other 
{
	if (other == self)
		return YES;
	
	if (!other || ![other isKindOfClass:[self class]])
		return NO;
	
	return [self isEqualToISMSStreamHandler:other];
}

- (NSString *)description
{
	//return [NSString stringWithFormat:@"%@: title: %@, songId: %@", [super description], title, songId];
	return [NSString stringWithFormat:@"%@  title: %@", [super description], self.song.title];
}

@end
