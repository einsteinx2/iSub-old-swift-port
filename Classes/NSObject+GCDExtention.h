//
//  NSObject+GCDExtention.h
//  iSub
//
//  Created by Ben Baron on 3/17/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//



@interface NSObject (GCDExtention)

- (BOOL)gcdTimerPerformBlock:(void (^)(void))block inQueue:(dispatch_queue_t)queue afterDelay:(NSTimeInterval)delay withName:(NSString *)name;
- (BOOL)gcdTimerPerformBlockInMainQueue:(void (^)(void))block afterDelay:(NSTimeInterval)delay withName:(NSString *)name;
- (BOOL)gcdTimerPerformBlockInCurrentQueue:(void (^)(void))block afterDelay:(NSTimeInterval)delay withName:(NSString *)name;

+ (void)gcdCancelTimerBlockWithName:(NSString *)name;
+ (void)gcdCancelAllTimerBlocks;

@end
