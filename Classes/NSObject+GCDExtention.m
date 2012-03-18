//
//  NSObject+GCDExtention.m
//  iSub
//
//  Created by Ben Baron on 3/17/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "NSObject+GCDExtention.h"

@implementation NSObject (GCDExtention)

static NSMutableDictionary *gcdTimers;
static NSObject *syncObject;

__attribute__((constructor))
static void initialize_navigationBarImages() 
{
	gcdTimers = [[NSMutableDictionary alloc] init];
	syncObject = [[NSObject alloc] init];
}

- (BOOL)gcdTimerPerformBlock:(void (^)(void))block inQueue:(dispatch_queue_t)queue afterDelay:(NSTimeInterval)delay withName:(NSString *)name
{
	@synchronized(syncObject)
	{
		// If a timer already exists for this name, return
		if ([gcdTimers objectForKey:name])
			return NO;
		
		// As per: http://stackoverflow.com/questions/8906026/synchronizing-a-block-within-a-block
		// remember to call [block copy] otherwise it is not correctly retained because block are created on stack and destroyed when exit scope and unless you call copy it will not move to heap even retain is called.
		block = [[block copy] autorelease];
		
		//Create the timer
		dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
		dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 0);
		dispatch_source_set_event_handler(timer, ^{
			// Run the block
			block();
				
			// Make sure it only runs once
			[NSObject gcdCancelTimerBlockWithName:name];
		});
		
		// Add it to the dictionary
		NSValue *timerValue = [NSValue valueWithPointer:timer];
		[gcdTimers setObject:timerValue forKey:name];
		
		// Start the timer
		dispatch_resume(timer);
		
		return YES;
	}
}

- (BOOL)gcdTimerPerformBlockInMainQueue:(void (^)(void))block afterDelay:(NSTimeInterval)delay withName:(NSString *)name
{
	return [self gcdTimerPerformBlock:block inQueue:dispatch_get_main_queue() afterDelay:delay withName:name];
}

- (BOOL)gcdTimerPerformBlockInCurrentQueue:(void (^)(void))block afterDelay:(NSTimeInterval)delay withName:(NSString *)name
{
	return [self gcdTimerPerformBlock:block inQueue:dispatch_get_current_queue() afterDelay:delay withName:name];
}

+ (void)gcdCancelTimerBlockWithName:(NSString *)name
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
			[NSObject gcdCancelTimerBlockWithName:key];
		}
	}
}

@end
