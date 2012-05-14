//
//  ISMSCacheQueueManager.h
//  iSub
//
//  Created by Ben Baron on 2/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSLoaderDelegate.h"
#import "ISMSStreamHandlerDelegate.h"

#define cacheQueueManagerS ((ISMSCacheQueueManager *)[ISMSCacheQueueManager sharedInstance])

@class Song, ISMSStreamHandler;
@interface ISMSCacheQueueManager : NSObject <SUSLoaderDelegate, ISMSStreamHandlerDelegate>

@property BOOL isQueueDownloading;
@property (copy) Song *currentQueuedSong;
@property (strong) ISMSStreamHandler *currentStreamHandler;
- (Song *)currentQueuedSongInDb;


/*@property NSUInteger downloadLength;

@property (strong) NSFileHandle *fileHandle;
@property (strong) NSURLConnection *connection;

@property unsigned long long contentLength;
@property NSUInteger numberOfContentLengthFailures;*/

+ (id)sharedInstance;

- (void)startDownloadQueue;
- (void)stopDownloadQueue;
- (void)resumeDownloadQueue:(NSNumber *)byteOffset;

- (void)removeCurrentSong;

@end
