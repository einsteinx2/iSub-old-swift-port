//
//  ISMSCacheQueueManager.h
//  iSub
//
//  Created by Ben Baron on 2/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSLoaderDelegate.h"

#define cacheQueueManagerS [ISMSCacheQueueManager sharedInstance]

@class Song;
@interface ISMSCacheQueueManager : NSObject <SUSLoaderDelegate>

@property BOOL isQueueDownloading;
@property (copy) Song *currentQueuedSong;
@property (readonly) Song *currentQueuedSongInDb;
@property NSUInteger downloadLength;

@property (retain) NSFileHandle *fileHandle;
@property (retain) NSURLConnection *connection;

@property unsigned long long contentLength;
@property NSUInteger numberOfContentLengthFailures;

+ (ISMSCacheQueueManager *)sharedInstance;

- (void)startDownloadQueue;
- (void)stopDownloadQueue;
- (void)resumeDownloadQueue:(NSNumber *)byteOffset;

- (void)removeCurrentSong;

@end
