//
//  ISMSStreamManager.h
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSStreamHandlerDelegate.h"
#import "SUSLoaderDelegate.h"

#define streamManagerS ((ISMSStreamManager *)[ISMSStreamManager sharedInstance])

#define ISMSNumberOfStreamsToQueue 2

@class Song, ISMSStreamHandler, SUSLyricsDAO;
@interface ISMSStreamManager : NSObject <ISMSStreamHandlerDelegate, SUSLoaderDelegate>

@property (strong) NSMutableArray *handlerStack;
@property (strong) SUSLyricsDAO *lyricsDAO;

@property (copy) Song *lastCachedSong;
@property (copy) Song *lastTempCachedSong;

@property (readonly) BOOL isQueueDownloading;

+ (id)sharedInstance;

- (ISMSStreamHandler *)handlerForSong:(Song *)aSong;
- (BOOL)isSongInQueue:(Song *)aSong;
- (BOOL)isSongFirstInQueue:(Song *)aSong;
- (BOOL)isSongDownloading:(Song *)aSong;

- (void)cancelAllStreamsExcept:(NSArray *)handlersToSkip;
- (void)cancelAllStreamsExceptForSongs:(NSArray *)songsToSkip;
- (void)cancelAllStreamsExceptForSong:(Song *)aSong;
- (void)cancelAllStreams;
- (void)cancelStreamAtIndex:(NSUInteger)index;
- (void)cancelStream:(ISMSStreamHandler *)handler;
- (void)cancelStreamForSong:(Song *)aSong;

- (void)removeAllStreamsExcept:(NSArray *)handlersToSkip;
- (void)removeAllStreamsExceptForSongs:(NSArray *)songsToSkip;
- (void)removeAllStreamsExceptForSong:(Song *)aSong;
- (void)removeAllStreams;
- (void)removeStreamAtIndex:(NSUInteger)index;
- (void)removeStream:(ISMSStreamHandler *)handler;
- (void)removeStreamForSong:(Song *)aSong;

- (void)queueStreamForSong:(Song *)song byteOffset:(unsigned long long)byteOffset secondsOffset:(double)secondsOffset atIndex:(NSUInteger)index isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload;
- (void)queueStreamForSong:(Song *)song byteOffset:(unsigned long long)byteOffset secondsOffset:(double)secondsOffset isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload;
- (void)queueStreamForSong:(Song *)song atIndex:(NSUInteger)index isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload;
- (void)queueStreamForSong:(Song *)song isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload;

- (void)fillStreamQueue:(BOOL)isStartDownload;

- (void)resumeQueue;

- (void)resumeHandler:(ISMSStreamHandler *)handler;
- (void)startHandler:(ISMSStreamHandler *)handler resume:(BOOL)resume;
- (void)startHandler:(ISMSStreamHandler *)handler;

- (void)saveHandlerStack;
- (void)loadHandlerStack;

@end
