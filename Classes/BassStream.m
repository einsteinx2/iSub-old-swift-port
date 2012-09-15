//
//  BassUserInfo.m
//  Anghami
//
//  Created by Ben Baron on 1/17/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "BassStream.h"
#import "ISMSSong.h"

@implementation BassStream

- (id)init
{
	if ((self = [super init]))
	{
		_neededSize = ULLONG_MAX;
	}
	return self;
}

- (unsigned long long)localFileSize
{
	return [[[NSFileManager defaultManager] attributesOfItemAtPath:self.writePath error:NULL] fileSize];
}

- (NSUInteger)hash
{
	return _stream;
}

- (BOOL)isEqualToStream:(BassStream *)otherStream 
{
    if (self == otherStream)
        return YES;
	
	if (!self.song || !otherStream.song)
		return NO;
	
	if ([self.song isEqualToSong:otherStream.song] && self.stream == otherStream.stream)
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
