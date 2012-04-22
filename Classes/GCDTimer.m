//
//  GCDTimer.m
//  iSub
//
//  Created by Ben Baron on 4/2/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "GCDTimer.h"

@implementation GCDTimer

- (id)init
{
	if ((self = [super init]))
	{
		timer = nil;
	}
	return self;
}

- (void)dealloc
{
	[self gcdCancelTimerBlock];
}

+ (id)gcdTimerInQueue:(dispatch_queue_t)queue afterDelay:(NSTimeInterval)delay performBlock:(void (^)(void))block
{
	GCDTimer *aTimer = [[GCDTimer alloc] init];
	
	[aTimer createTimerInQueue:queue afterDelay:delay performBlock:block];
	
	return aTimer;
}

+ (id)gcdTimerInMainQueueAfterDelay:(NSTimeInterval)delay performBlock:(void (^)(void))block
{
	return [GCDTimer gcdTimerInQueue:dispatch_get_main_queue() afterDelay:delay performBlock:block];
}

+ (id)gcdTimerInCurrentQueueAfterDelay:(NSTimeInterval)delay performBlock:(void (^)(void))block
{
	return [GCDTimer gcdTimerInQueue:dispatch_get_current_queue() afterDelay:delay performBlock:block];
}

- (BOOL)createTimerInQueue:(dispatch_queue_t)queue afterDelay:(NSTimeInterval)delay performBlock:(void (^)(void))block
{
	if (timer)
		return NO;
	
	// As per: http://stackoverflow.com/questions/8906026/synchronizing-a-block-within-a-block
	// remember to call [block copy] otherwise it is not correctly retained because block are created on stack and destroyed when exit scope and unless you call copy it will not move to heap even retain is called.
	block = [block copy];
	
	//Create the timer
	timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
	dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 0);
	dispatch_source_set_event_handler(timer, ^{
		// Run the block
		block();
		
		// Make sure it only runs once
		[self gcdCancelTimerBlock];
	});
	
	// Start the timer
	dispatch_resume(timer);
	
	return YES;
}

- (BOOL)gcdCancelTimerBlock
{
	if (!timer)
		return NO;
	
	// Cancel and release the timer
	DLog(@"canceling timer block");
	dispatch_source_cancel(timer); 
	dispatch_release(timer);
	timer = nil;
		
	return YES;
}

@end
