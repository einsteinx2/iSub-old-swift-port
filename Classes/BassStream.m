//
//  BassUserInfo.m
//  Anghami
//
//  Created by Ben Baron on 1/17/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "BassStream.h"
#import "Song.h"

@implementation BassStream
@synthesize song, fileHandle, shouldBreakWaitLoop, neededSize, isWaiting, writePath, isTempCached, shouldBreakWaitLoopForever, isSongStarted, isFileUnderrun, wasFileJustUnderrun, stream, isEnded, isEndedCalled, bufferSpaceTilSongEnd, player;

- (id)init
{
	if ((self = [super init]))
	{
		neededSize = ULLONG_MAX;
	}
	return self;
}

- (unsigned long long)localFileSize
{
	return [[[NSFileManager defaultManager] attributesOfItemAtPath:self.writePath error:NULL] fileSize];
}

- (NSUInteger)hash
{
	return stream;
}

- (BOOL)isEqualToStream:(BassStream *)otherStream 
{
    if (self == otherStream)
        return YES;
	
	if (!song || !otherStream.song)
		return NO;
	
	if ([song isEqualToSong:otherStream.song] && stream == otherStream.stream)
		return YES;
	
	return NO;
}

- (BOOL)isEqual:(id)other 
{
    if (other == self)
        return YES;
	
    if (!other || ![other isKindOfClass:[self class]])
        return NO;
	
    return [self isEqualToStream:other];
}

@end
