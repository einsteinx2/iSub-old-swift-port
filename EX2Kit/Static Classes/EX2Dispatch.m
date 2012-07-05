//
//  EX2Dispatch.m
//  iSub
//
//  Created by Ben Baron on 4/26/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "EX2Dispatch.h"

@implementation EX2Dispatch

#pragma mark - Blocks after delay

+ (void)runInQueue:(dispatch_queue_t)queue delay:(NSTimeInterval)delay block:(void (^)(void))block
{
	block = [block copy];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), queue, block);
}

+ (void)runInCurrentQueueAfterDelay:(NSTimeInterval)delay block:(void (^)(void))block
{
	[self runInQueue:dispatch_get_current_queue() delay:delay block:block];
}

+ (void)runInMainThreadAfterDelay:(NSTimeInterval)delay block:(void (^)(void))block
{
	[self runInQueue:dispatch_get_main_queue() delay:delay block:block];
}

+ (void)runInBackgroundAfterDelay:(NSTimeInterval)delay block:(void (^)(void))block
{
	[self runInQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) delay:delay block:block];
}

#pragma mark - Blocks now

+ (void)runInQueue:(dispatch_queue_t)queue waitUntilDone:(BOOL)shouldWait block:(void (^)(void))block
{
	block = [block copy];
	if (shouldWait)
		dispatch_sync(queue, block);
	else
		dispatch_async(queue, block);
}

+ (void)runInMainThreadAndWaitUntilDone:(BOOL)shouldWait block:(void (^)(void))block
{
	// Calling dispatch_sync to the main queue from the main thread can cause a deadlock,
	// so just run the block
	if ([NSThread isMainThread])
	{
		block();
		return;
	}
	
	[self runInQueue:dispatch_get_main_queue() waitUntilDone:shouldWait block:block];
}

+ (void)runInBackground:(void (^)(void))block
{
	[self runInQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) waitUntilDone:NO block:block];
}

#pragma mark - Timers

static __strong NSMutableDictionary *gcdTimers;
static __strong NSObject *syncObject;

__attribute__((constructor))
static void initialize_navigationBarImages() 
{
	gcdTimers = [[NSMutableDictionary alloc] init];
	syncObject = [[NSObject alloc] init];
}

+ (BOOL)timerInQueue:(dispatch_queue_t)queue afterDelay:(NSTimeInterval)delay withName:(NSString *)name repeats:(BOOL)repeats performBlock:(void (^)(void))block
{
	@synchronized(syncObject)
	{
		// If a timer already exists for this name, return
		if ([gcdTimers objectForKey:name])
			return NO;
		
		// As per: http://stackoverflow.com/questions/8906026/synchronizing-a-block-within-a-block
		// remember to call [block copy] otherwise it is not correctly retained because block are created on stack and destroyed when exit scope and unless you call copy it will not move to heap even retain is called.
		block = [block copy];
		
		//Create the timer
		dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
		dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 0);
		dispatch_source_set_event_handler(timer, ^{
			// Run the block
			block();
			
			if (!repeats)
			{
				// Make sure it only runs once
				[self cancelTimerBlockWithName:name];
			}
		});
		
		// Add it to the dictionary
		NSValue *timerValue = [NSValue valueWithPointer:timer];
		[gcdTimers setObject:timerValue forKey:name];
		
		// Start the timer
		dispatch_resume(timer);
		
		return YES;
	}
}

+ (BOOL)timerInMainQueueAfterDelay:(NSTimeInterval)delay withName:(NSString *)name repeats:(BOOL)repeats performBlock:(void (^)(void))block
{
	return [self timerInQueue:dispatch_get_main_queue() afterDelay:delay withName:name repeats:repeats performBlock:block];
}

+ (BOOL)timerInCurrentQueueAfterDelay:(NSTimeInterval)delay withName:(NSString *)name repeats:(BOOL)repeats performBlock:(void (^)(void))block
{
	return [self timerInQueue:dispatch_get_current_queue() afterDelay:delay withName:name repeats:repeats performBlock:block];
}

+ (void)cancelTimerBlockWithName:(NSString *)name
{
	@synchronized(syncObject)
	{
		// Get the value
		NSValue *value = [gcdTimers objectForKey:name];
		if (value)
		{
			// Get the timer pointer
			dispatch_source_t timer = [value pointerValue];
			if (timer)
			{
				// Cancel and release the timer
				dispatch_source_cancel(timer); 
				dispatch_release(timer);
			}
			
			// Remove the timer pointer from the dictionary
			[gcdTimers removeObjectForKey:name];
		}
	}
}

+ (void)gcdCancelAllTimerBlocks
{
	@synchronized(syncObject)
	{
		// Get all the keys
		NSArray *keys = [NSArray arrayWithArray:[gcdTimers allKeys]];
		
		// Cancel each timer
		for (NSString *key in keys)
		{
			[self cancelTimerBlockWithName:key];
		}
	}
}

@end
