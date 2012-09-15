//
//  ISMSStreamHandler.m
//  Anghami
//
//  Created by Ben Baron on 7/4/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "ISMSStreamHandler.h"
#import "Song.h"


@implementation ISMSStreamHandler

- (void)setup
{
	_partialPrecacheSleep = YES;
	_contentLength = ULLONG_MAX;
	_maxBitrateSetting = NSIntegerMax;
	_secondsToPartialPrecache = ISMSNumSecondsToPartialPreCacheDefault;
	
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
	if ((self = [self init]))
	{
		[self setup];
		
		_mySong = [song copy];
		_delegate = theDelegate;
		_byteOffset = bOffset;
		_secondsOffset = sOffset;
		_isTempCache = isTemp;
		
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
	return self.isTempCache ? self.mySong.localTempPath : self.mySong.localPath;
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

- (void)connectionTimedOut
{
	// Override this
}

- (void)startTimeOutTimer
{
    [self stopTimeOutTimer];
	[self performSelector:@selector(connectionTimedOut) withObject:nil afterDelay:30.];
}

- (void)stopTimeOutTimer
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(connectionTimedOut) object:nil];
}

- (void)playlistIndexChanged
{
	// If this song is partially precached and sleeping, stop sleeping
	if (self.isPartialPrecacheSleeping)
		self.partialPrecacheSleep = NO;
	
	if ([self.mySong isEqualToSong:playlistS.currentSong])
		self.isCurrentSong = YES;
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

#pragma mark - Overriding equality

- (NSUInteger)hash
{
	return [self.mySong.songId hash];
}

- (BOOL)isEqualToISMSStreamHandler:(ISMSStreamHandler *)otherHandler 
{
	if (self == otherHandler)
		return YES;
	
	return [self.mySong isEqualToSong:otherHandler.mySong];
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
		
		_mySong = [[decoder decodeObjectForKey:@"mySong"] copy];
		_byteOffset = [decoder decodeInt64ForKey:@"byteOffset"];
		_secondsOffset = [decoder decodeDoubleForKey:@"secondsOffset"];
		_isDelegateNotifiedToStartPlayback = [decoder decodeBoolForKey:@"isDelegateNotifiedToStartPlayback"];
		_isTempCache = [decoder decodeBoolForKey:@"isTempCache"];
		_isDownloading = [decoder decodeBoolForKey:@"isDownloading"];
		_contentLength = [decoder decodeInt64ForKey:@"contentLength"];
		_maxBitrateSetting = [decoder decodeInt32ForKey:@"maxBitrateSetting"];
	}
	
	return self;
}

- (NSString *)description
{
	//return [NSString stringWithFormat:@"%@: title: %@, songId: %@", [super description], title, songId];
	return [NSString stringWithFormat:@"%@  title: %@", [super description], self.mySong.title];
}

@end
