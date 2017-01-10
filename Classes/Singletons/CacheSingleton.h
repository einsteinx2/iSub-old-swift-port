
//
//  CacheSingleton.h
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#ifndef iSub_CacheSingleton_h
#define iSub_CacheSingleton_h

@interface CacheSingleton : NSObject

//@property (retain) NSTimer *cacheCheckTimer;
@property NSTimeInterval cacheCheckInterval;
@property (readonly) unsigned long long totalSpace;
@property (readonly) unsigned long long cacheSize;
@property (readonly) unsigned long long freeSpace;
@property (readonly) NSInteger numberOfCachedSongs;

+ (nonnull instancetype)si;
- (void)setup;

+ (nonnull NSString *)songCachePath;
+ (nonnull NSString *)tempCachePath;

//- (void)startCacheCheckTimer;
- (void)startCacheCheckTimerWithInterval:(NSTimeInterval)interval;
- (void)stopCacheCheckTimer;
- (void)clearTempCache;
- (void)findCacheSize;

- (void)setAllCachedSongsToBackup;
- (void)setAllCachedSongsToNotBackup;

@end

#endif
