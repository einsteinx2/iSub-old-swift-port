//
//  EX2Dispatch.h
//  EX2Kit
//
//  Created by Ben Baron on 4/26/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//


#import <Foundation/Foundation.h>

@interface EX2Dispatch : NSObject

// Run after delay
+ (void)runInQueue:(dispatch_queue_t)queue delay:(NSTimeInterval)delay block:(void (^)(void))block;
+ (void)runInCurrentQueueAfterDelay:(NSTimeInterval)delay block:(void (^)(void))block;
+ (void)runInMainThreadAfterDelay:(NSTimeInterval)delay block:(void (^)(void))block;
+ (void)runInBackgroundAfterDelay:(NSTimeInterval)delay block:(void (^)(void))block;

// Run async
+ (void)runAsync:(dispatch_queue_t)queue block:(void (^)(void))block;
+ (void)runInBackground:(void (^)(void))block;
+ (void)runInMainThread:(void (^)(void))block;

// Run now
+ (void)runInQueue:(dispatch_queue_t)queue waitUntilDone:(BOOL)shouldWait block:(void (^)(void))block;
+ (void)runInMainThreadAndWaitUntilDone:(BOOL)shouldWait block:(void (^)(void))block;

// Timers
+ (BOOL)timerInQueue:(dispatch_queue_t)queue afterDelay:(NSTimeInterval)delay withName:(NSString *)name repeats:(BOOL)repeats performBlock:(void (^)(void))block;
+ (BOOL)timerInMainQueueAfterDelay:(NSTimeInterval)delay withName:(NSString *)name repeats:(BOOL)repeats performBlock:(void (^)(void))block;
+ (BOOL)timerInCurrentQueueAfterDelay:(NSTimeInterval)delay withName:(NSString *)name repeats:(BOOL)repeats performBlock:(void (^)(void))block;
+ (void)cancelTimerBlockWithName:(NSString *)name;
+ (void)gcdCancelAllTimerBlocks;

@end
