//
//  Video.m
//  iSub
//
//  Created by Ben Baron on 9/9/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "Video.h"

@implementation Video
@synthesize itemId, title;

- (NSString *)description
{
	//return [NSString stringWithFormat:@"%@: title: %@, songId: %@", [super description], title, songId];
	return [NSString stringWithFormat:@"%@  title: %@", [super description], title];
}

- (NSUInteger)hash
{
	return [itemId hash];
}

- (BOOL)isEqualToVideo:(Video *)otherVideo
{
    if (self == otherVideo)
        return YES;
	
	if (!itemId || !otherVideo.itemId)
		return NO;
	
	return [itemId isEqualToString:otherVideo.itemId];
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
	
    if (!other || ![other isKindOfClass:[self class]])
        return NO;
	
    return [self isEqualToVideo:other];
}

@end
