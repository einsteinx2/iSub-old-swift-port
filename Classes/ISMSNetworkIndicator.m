//
//  ISMSNetworkIndicator.m
//  iSub
//
//  Created by Benjamin Baron on 4/23/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "ISMSNetworkIndicator.h"

static NSUInteger networkUseCount = 0;

@implementation ISMSNetworkIndicator

+ (void)usingNetwork
{
	@synchronized(self)
	{
		networkUseCount++;
		[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	}
}

+ (void)doneUsingNetwork
{
	@synchronized(self)
	{
		if (networkUseCount > 0)
		{
			networkUseCount--;
			
			if (networkUseCount == 0)
				[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
		}
	}
}

@end
