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

@class ISMSSong, ISMSStreamHandler, SUSLyricsDAO;
@interface ISMSStreamManager : NSObject <ISMSStreamHandlerDelegate>

@property (nullable, strong) NSMutableArray *handlerStack;
@property (nullable, strong) SUSLyricsDAO *lyricsDAO;

@property (nullable, copy) ISMSSong *lastCachedSong;
@property (nullable, copy) ISMSSong *lastTempCachedSong;

@property (readonly) BOOL isDownloading;

@property (nullable, readonly) ISMSSong *currentStreamingSong;

+ (nonnull instancetype)si;

- (void)delayedSetup;

- (nullable ISMSStreamHandler *)handlerForSong:(nonnull ISMSSong *)aSong;
- (BOOL)isSongInQueue:(nonnull ISMSSong *)aSong;
- (BOOL)isSongFirstInQueue:(nonnull ISMSSong *)aSong;
- (BOOL)isSongDownloading:(nonnull ISMSSong *)aSong;

- (void)cancelAllStreamsExcept:(nonnull NSArray *)handlersToSkip;
- (void)cancelAllStreamsExceptForSongs:(nonnull NSArray *)songsToSkip;
- (void)cancelAllStreamsExceptForSong:(nonnull ISMSSong *)aSong;
- (void)cancelAllStreams;
- (void)cancelStreamAtIndex:(NSInteger)index;
- (void)cancelStream:(nonnull ISMSStreamHandler *)handler;
- (void)cancelStreamForSong:(nonnull ISMSSong *)aSong;

- (void)removeAllStreamsExcept:(nonnull NSArray *)handlersToSkip;
- (void)removeAllStreamsExceptForSongs:(nonnull NSArray *)songsToSkip;
- (void)removeAllStreamsExceptForSong:(nonnull ISMSSong *)aSong;
- (void)removeAllStreams;
- (void)removeStreamAtIndex:(NSInteger)index;
- (void)removeStream:(nonnull ISMSStreamHandler *)handler;
- (void)removeStreamForSong:(nonnull ISMSSong *)aSong;

- (void)queueStreamForSong:(nonnull ISMSSong *)song byteOffset:(unsigned long long)byteOffset atIndex:(NSInteger)index isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload;
- (void)fillStreamQueue:(BOOL)isStartDownload;

- (void)resumeQueue;

- (void)resumeHandler:(nonnull ISMSStreamHandler *)handler;
- (void)startHandler:(nonnull ISMSStreamHandler *)handler resume:(BOOL)resume;
- (void)startHandler:(nonnull ISMSStreamHandler *)handler;

- (void)saveHandlerStack;
- (void)loadHandlerStack;

- (void)stealHandlerForCacheQueue:(nonnull ISMSStreamHandler *)handler;

@end
