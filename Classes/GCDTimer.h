//
//  GCDTimer.h
//  iSub
//
//  Created by Ben Baron on 4/2/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface GCDTimer : NSObject
{
	dispatch_source_t timer;
}

+ (id)gcdTimerInQueue:(dispatch_queue_t)queue afterDelay:(NSTimeInterval)delay performBlock:(void (^)(void))block;
+ (id)gcdTimerInMainQueueAfterDelay:(NSTimeInterval)delay performBlock:(void (^)(void))block;
+ (id)gcdTimerInCurrentQueueAfterDelay:(NSTimeInterval)delay performBlock:(void (^)(void))block;
- (BOOL)createTimerInQueue:(dispatch_queue_t)queue afterDelay:(NSTimeInterval)delay performBlock:(void (^)(void))block;
- (BOOL)gcdCancelTimerBlock;

@end
