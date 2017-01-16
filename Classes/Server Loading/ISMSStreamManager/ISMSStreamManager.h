//
//  ISMSStreamManager.h
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

// TODO: Rewrite in swift using an operation queue

#import "ISMSStreamHandlerDelegate.h"
#import "ISMSStreamHandler.h"

#define ISMSNumberOfStreamsToQueue 2

@class Song, ISMSStreamHandler;
@interface ISMSStreamManager : NSObject <ISMSStreamHandlerDelegate>

@property (nullable, strong) Song *lastTempCachedSong;
@property (readonly) BOOL isDownloading;

+ (nonnull instancetype)si;

- (void)delayedSetup;

- (nullable ISMSStreamHandler *)handlerForSong:(nonnull Song *)aSong;
- (BOOL)isSongFirstInQueue:(nonnull Song *)aSong;
- (BOOL)isSongDownloading:(nonnull Song *)aSong;

- (void)cancelAllStreams;
- (void)removeAllStreamsExceptForSong:(nonnull Song *)aSong;
- (void)removeAllStreams;

- (void)queueStreamForSong:(nonnull Song *)song byteOffset:(unsigned long long)byteOffset atIndex:(NSInteger)index isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload;
- (void)fillStreamQueue:(BOOL)isStartDownload;

- (void)resumeQueue;

- (void)stealHandlerForCacheQueue:(nonnull ISMSStreamHandler *)handler;

@end
