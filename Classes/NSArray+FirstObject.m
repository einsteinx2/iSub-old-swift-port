//
//  NSArray+FirstObject.m
//  iSub
//
//  Created by Ben Baron on 11/16/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NSArray+FirstObject.h"
#import "NSArray+Safe.h"

@implementation NSArray (FirstObject)

- (id)firstObject
{
	return [self objectAtIndex:0];
}

- (id)firstObjectSafe
{
	return [self objectAtIndexSafe:0];
}

@end
