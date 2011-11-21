//
//  NSArray+FirstObject.m
//  iSub
//
//  Created by Ben Baron on 11/16/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NSArray+FirstObject.h"

@implementation NSArray (FirstObject)

- (id)firstObject
{
	if ([self count] > 0)
    {
		return [self objectAtIndex:0];
	}
	
	return nil;
}

@end
