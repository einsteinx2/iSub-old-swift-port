//
//  GCDWrapper.h
//  iSub
//
//  Created by Ben Baron on 4/26/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GCDWrapper : NSObject

// Run after delay
+ (void)runInQueue:(dispatch_queue_t)queue delay:(NSTimeInterval)delay block:(void (^)(void))block;
+ (void)runInCurrentQueueAfterDelay:(NSTimeInterval)delay block:(void (^)(void))block;
+ (void)runInMainThreadAfterDelay:(NSTimeInterval)delay block:(void (^)(void))block;
+ (void)runInBackgroundAfterDelay:(NSTimeInterval)delay block:(void (^)(void))block;

// Run now
+ (void)runInQueue:(dispatch_queue_t)queue waitUntilDone:(BOOL)shouldWait block:(void (^)(void))block;
+ (void)runInMainThreadAndWaitUntilDone:(BOOL)shouldWait block:(void (^)(void))block;
+ (void)runInBackground:(void (^)(void))block;

// Timers
+ (BOOL)timerInQueue:(dispatch_queue_t)queue afterDelay:(NSTimeInterval)delay withName:(NSString *)name performBlock:(void (^)(void))block;
+ (BOOL)timerInMainQueueAfterDelay:(NSTimeInterval)delay withName:(NSString *)name performBlock:(void (^)(void))block;
+ (BOOL)timerInCurrentQueueAfterDelay:(NSTimeInterval)delay withName:(NSString *)name performBlock:(void (^)(void))block;
+ (void)cancelTimerBlockWithName:(NSString *)name;
+ (void)gcdCancelAllTimerBlocks;

@end
