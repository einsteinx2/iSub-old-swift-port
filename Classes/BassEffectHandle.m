//
//  BassEffectHandle.m
//  iSub
//
//  Created by Ben Baron on 11/19/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "BassEffectHandle.h"

@implementation BassEffectHandle
@synthesize effectHandle;

- (id)initWithEffectHandle:(HFX)handle
{
	if ((self = [super init]))
	{
		effectHandle = handle;
	}
	
	return self;
}

+ (BassEffectHandle *)handleWithEffectHandle:(HFX)handle
{
	return [[BassEffectHandle alloc] initWithEffectHandle:handle];
}

- (NSUInteger)hash
{
	return effectHandle;
}

- (BOOL)isEqualToBassEffectHandle:(BassEffectHandle *)otherHandle
{
	if (self == otherHandle)
        return YES;
	
	if (effectHandle == otherHandle.effectHandle)
		return YES;
	
	return NO;
}

- (BOOL)isEqual:(id)other
{
	if (other == self)
        return YES;
	
    if (!other || ![other isKindOfClass:[self class]])
        return NO;
	
    return [self isEqualToBassEffectHandle:other];

}

@end
