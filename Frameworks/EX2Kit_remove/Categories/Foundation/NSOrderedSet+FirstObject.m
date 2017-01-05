//
//  NSOrderedSet+FirstObject.m
//  EX2Kit
//
//  Created by Benjamin Baron on 8/7/13.
//
//

#import "NSOrderedSet+FirstObject.h"
#import "NSOrderedSet+Safe.h"

@implementation NSOrderedSet (FirstObject)

- (id)firstObject
{
	return [self objectAtIndex:0];
}

- (id)firstObjectSafe
{
	return [self objectAtIndexSafe:0];
}

@end
