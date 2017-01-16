//
//  ISMSStreamManager.h
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSStreamHandlerDelegate.h"
#import "ISMSStreamHandler.h"

#define ISMSNumberOfStreamsToQueue 2

@class Song, ISMSStreamHandler, SUSLyricsDAO;
@interface ISMSStreamManager : NSObject <ISMSStreamHandlerDelegate>

@property (nullable, strong) NSMutableArray *handlerStack;
@property (nullable, strong) SUSLyricsDAO *lyricsDAO;

@property (nullable, strong) Song *lastCachedSong;
@property (nullable, strong) Song *lastTempCachedSong;

@property (readonly) BOOL isDownloading;

@property (nullable, readonly) Song *currentStreamingSong;

+ (nonnull instancetype)si;

- (void)delayedSetup;

- (nullable ISMSStreamHandler *)handlerForSong:(nonnull Song *)aSong;
- (BOOL)isSongInQueue:(nonnull Song *)aSong;
- (BOOL)isSongFirstInQueue:(nonnull Song *)aSong;
- (BOOL)isSongDownloading:(nonnull Song *)aSong;

- (void)cancelAllStreamsExcept:(nonnull NSArray *)handlersToSkip;
- (void)cancelAllStreamsExceptForSongs:(nonnull NSArray *)songsToSkip;
- (void)cancelAllStreamsExceptForSong:(nonnull Song *)aSong;
- (void)cancelAllStreams;
- (void)cancelStreamAtIndex:(NSInteger)index;
- (void)cancelStream:(nonnull ISMSStreamHandler *)handler;
- (void)cancelStreamForSong:(nonnull Song *)aSong;

- (void)removeAllStreamsExcept:(nonnull NSArray *)handlersToSkip;
- (void)removeAllStreamsExceptForSongs:(nonnull NSArray *)songsToSkip;
- (void)removeAllStreamsExceptForSong:(nonnull Song *)aSong;
- (void)removeAllStreams;
- (void)removeStreamAtIndex:(NSInteger)index;
- (void)removeStream:(nonnull ISMSStreamHandler *)handler;
- (void)removeStreamForSong:(nonnull Song *)aSong;

- (void)queueStreamForSong:(nonnull Song *)song byteOffset:(unsigned long long)byteOffset atIndex:(NSInteger)index isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload;
- (void)fillStreamQueue:(BOOL)isStartDownload;

- (void)resumeQueue;

- (void)resumeHandler:(nonnull ISMSStreamHandler *)handler;
- (void)startHandler:(nonnull ISMSStreamHandler *)handler resume:(BOOL)resume;
- (void)startHandler:(nonnull ISMSStreamHandler *)handler;

- (void)saveHandlerStack;
- (void)loadHandlerStack;

- (void)stealHandlerForCacheQueue:(nonnull ISMSStreamHandler *)handler;

@end
