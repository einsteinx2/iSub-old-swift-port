//
//  CacheSingleton.h
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

//#import <Foundation/Foundation.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

@interface CacheSingleton : NSObject
{
	NSTimeInterval cacheCheckInterval;
	NSTimer *cacheCheckTimer;
	
	unsigned long long cacheSize;
}

@property NSTimeInterval cacheCheckInterval;
@property (readonly) unsigned long long cacheSize;
@property (readonly) unsigned long long freeSpace;
@property (readonly) NSUInteger numberOfCachedSongs;

+ (CacheSingleton *)sharedInstance;

- (void)startCacheCheckTimer;
- (void)startCacheCheckTimerWithInterval:(NSTimeInterval)interval;
- (void)stopCacheCheckTimer;

@end
