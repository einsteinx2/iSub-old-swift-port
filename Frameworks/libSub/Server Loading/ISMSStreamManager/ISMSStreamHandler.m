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

- (id)initWithSong:(ISMSSong *)song byteOffset:(unsigned long long)bOffset secondsOffset:(double)sOffset isTemp:(BOOL)isTemp delegate:(NSObject<ISMSStreamHandlerDelegate> *)theDelegate
{
	if ((self = [self init]))
	{
		[self setup];
		
		_song = [song copy];
		_delegate = theDelegate;
		_byteOffset = bOffset;
		_secondsOffset = sOffset;
		_isTempCache = isTemp;
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playlistIndexChanged) name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	}
	
	return self;
}

- (id)initWithSong:(ISMSSong *)song isTemp:(BOOL)isTemp delegate:(NSObject<ISMSStreamHandlerDelegate> *)theDelegate
{
	return [self initWithSong:song byteOffset:0 secondsOffset:0.0 isTemp:isTemp delegate:theDelegate];
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
	if ([self.song isEqualToSong:[PlayQueue sharedInstance].currentSong])
		self.isCurrentSong = YES;
}

+ (NSUInteger)minBytesToStartPlaybackForKiloBitrate:(double)rate speedInBytesPerSec:(NSUInteger)bytesPerSec
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
    NSUInteger minBytesToStartPlayback = minSecondsToStartPlayback * bytesForOneSecond;
    return minBytesToStartPlayback;
}

- (NSUInteger)totalDownloadSpeedInBytesPerSec
{
    return self.totalBytesTransferred / [[NSDate date] timeIntervalSinceDate:self.startDate];
}

#pragma mark - Overriding equality

- (NSUInteger)hash
{
	return [self.song.songId hash];
}

- (BOOL)isEqualToISMSStreamHandler:(ISMSStreamHandler *)otherHandler 
{
	if (self == otherHandler)
		return YES;
	
	return [self.song isEqualToSong:otherHandler.song];
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
	[encoder encodeObject:self.song forKey:@"song"];
	[encoder encodeInt64:self.byteOffset forKey:@"byteOffset"];
	[encoder encodeDouble:self.secondsOffset forKey:@"secondsOffset"];
	[encoder encodeBool:self.isDelegateNotifiedToStartPlayback forKey:@"isDelegateNotifiedToStartPlayback"];
	[encoder encodeBool:self.isTempCache forKey:@"isTempCache"];
	[encoder encodeBool:self.isDownloading forKey:@"isDownloading"];
	[encoder encodeInt64:self.contentLength forKey:@"contentLength"];
	[encoder encodeInt32:(int32_t)self.maxBitrateSetting forKey:@"maxBitrateSetting"];
    [encoder encodeBool:self.isEnableRateLimiting forKey:@"isEnableRateLimiting"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{		
		[self setup];
		
		_song = [[decoder decodeObjectForKey:@"song"] copy];
		_byteOffset = [decoder decodeInt64ForKey:@"byteOffset"];
		_secondsOffset = [decoder decodeDoubleForKey:@"secondsOffset"];
		_isDelegateNotifiedToStartPlayback = [decoder decodeBoolForKey:@"isDelegateNotifiedToStartPlayback"];
		_isTempCache = [decoder decodeBoolForKey:@"isTempCache"];
		_isDownloading = [decoder decodeBoolForKey:@"isDownloading"];
		_contentLength = [decoder decodeInt64ForKey:@"contentLength"];
		_maxBitrateSetting = [decoder decodeInt32ForKey:@"maxBitrateSetting"];
        _isEnableRateLimiting = [decoder decodeBoolForKey:@"isEnableRateLimiting"];
	}
	
	return self;
}

- (NSString *)description
{
	//return [NSString stringWithFormat:@"%@: title: %@, songId: %@", [super description], title, songId];
	return [NSString stringWithFormat:@"%@  title: %@", [super description], self.song.title];
}

@end
