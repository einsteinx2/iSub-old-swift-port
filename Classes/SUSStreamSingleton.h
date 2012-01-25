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

@class Song, SUSStreamHandler, SUSLyricsDAO, SUSCurrentPlaylistDAO;
@interface SUSStreamSingleton : NSObject <SUSStreamHandlerDelegate, SUSLoaderDelegate>

@property (retain) NSMutableArray *handlerStack;
@property (retain) SUSLyricsDAO *lyricsDAO;
@property (retain) SUSCurrentPlaylistDAO *currentPlaylistDAO;

@property (copy) Song *lastCachedSong;

+ (SUSStreamSingleton *)sharedInstance;

- (BOOL)insertSong:(Song *)aSong intoGenreTable:(NSString *)table;
- (SUSStreamHandler *)handlerForSong:(Song *)aSong;
- (BOOL)isSongInQueue:(Song *)aSong;

- (void)cancelAllStreamsExcept:(SUSStreamHandler *)handlerToSkip;
- (void)cancelAllStreamsExceptForSong:(Song *)aSong;
- (void)cancelAllStreams;
- (void)cancelStreamAtIndex:(NSUInteger)index;
- (void)cancelStream:(SUSStreamHandler *)handler;
- (void)cancelStreamForSong:(Song *)aSong;

- (void)removeAllStreamsExcept:(SUSStreamHandler *)handlerToSkip;
- (void)removeAllStreamsExceptForSong:(Song *)aSong;
- (void)removeAllStreams;
- (void)removeStreamAtIndex:(NSUInteger)index;
- (void)removeStream:(SUSStreamHandler *)handler;
- (void)removeStreamForSong:(Song *)aSong;

- (void)queueStreamForSong:(Song *)song offset:(NSUInteger)byteOffset atIndex:(NSUInteger)index isTempCache:(BOOL)isTemp;
- (void)queueStreamForSong:(Song *)song offset:(NSUInteger)byteOffset isTempCache:(BOOL)isTemp;
- (void)queueStreamForSong:(Song *)song atIndex:(NSUInteger)index isTempCache:(BOOL)isTemp;
- (void)queueStreamForSong:(Song *)song isTempCache:(BOOL)isTemp;

- (void)fillStreamQueue;

- (void)resumeHandler:(SUSStreamHandler *)handler;
- (void)startHandler:(SUSStreamHandler *)handler resume:(BOOL)resume;
- (void)startHandler:(SUSStreamHandler *)handler;

@end
