//
//  SUSStreamSingleton.h
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSStreamHandlerDelegate.h"
#import "SUSLoaderDelegate.h"

#define ISMSNumberOfStreamsToQueue 2

@class Song, SUSStreamHandler, SUSLyricsDAO, PlaylistSingleton;
@interface SUSStreamSingleton : NSObject <SUSStreamHandlerDelegate, SUSLoaderDelegate>

@property (retain) NSMutableArray *handlerStack;
@property (retain) SUSLyricsDAO *lyricsDAO;
@property (assign) PlaylistSingleton *currentPlaylistDAO;

@property (copy) Song *lastCachedSong;
@property (copy) Song *lastTempCachedSong;

@property (readonly) BOOL isQueueDownloading;

+ (SUSStreamSingleton *)sharedInstance;

- (SUSStreamHandler *)handlerForSong:(Song *)aSong;
- (BOOL)isSongInQueue:(Song *)aSong;
- (BOOL)isSongFirstInQueue:(Song *)aSong;
- (BOOL)isSongDownloading:(Song *)aSong;

- (void)cancelAllStreamsExcept:(NSArray *)handlersToSkip;
- (void)cancelAllStreamsExceptForSongs:(NSArray *)songsToSkip;
- (void)cancelAllStreamsExceptForSong:(Song *)aSong;
- (void)cancelAllStreams;
- (void)cancelStreamAtIndex:(NSUInteger)index;
- (void)cancelStream:(SUSStreamHandler *)handler;
- (void)cancelStreamForSong:(Song *)aSong;

- (void)removeAllStreamsExcept:(NSArray *)handlersToSkip;
- (void)removeAllStreamsExceptForSongs:(NSArray *)songsToSkip;
- (void)removeAllStreamsExceptForSong:(Song *)aSong;
- (void)removeAllStreams;
- (void)removeStreamAtIndex:(NSUInteger)index;
- (void)removeStream:(SUSStreamHandler *)handler;
- (void)removeStreamForSong:(Song *)aSong;

- (void)queueStreamForSong:(Song *)song byteOffset:(unsigned long long)byteOffset secondsOffset:(double)secondsOffset atIndex:(NSUInteger)index isTempCache:(BOOL)isTemp;
- (void)queueStreamForSong:(Song *)song byteOffset:(unsigned long long)byteOffset secondsOffset:(double)secondsOffset isTempCache:(BOOL)isTemp;
- (void)queueStreamForSong:(Song *)song atIndex:(NSUInteger)index isTempCache:(BOOL)isTemp;
- (void)queueStreamForSong:(Song *)song isTempCache:(BOOL)isTemp;

- (void)fillStreamQueue;

- (void)resumeQueue;

- (void)resumeHandler:(SUSStreamHandler *)handler;
- (void)startHandler:(SUSStreamHandler *)handler resume:(BOOL)resume;
- (void)startHandler:(SUSStreamHandler *)handler;

- (void)saveHandlerStack;
- (void)loadHandlerStack;

@end
