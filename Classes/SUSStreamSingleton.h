//
//  SUSStreamSingleton.h
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSStreamHandlerDelegate.h"
#import "SUSLoaderDelegate.h"

@class Song, SUSStreamHandler, SUSLyricsDAO;
@interface SUSStreamSingleton : NSObject <SUSStreamHandlerDelegate, SUSLoaderDelegate>

@property (nonatomic, retain) NSMutableArray *handlerStack;
@property (nonatomic, retain) SUSLyricsDAO *lyricsDataModel;

+ (SUSStreamSingleton *)sharedInstance;

- (void)cancelAllStreams;
- (void)cancelStreamAtIndex:(NSUInteger)index;
- (void)cancelStream:(SUSStreamHandler *)handler;

- (void)removeAllStreams;
- (void)removeStreamAtIndex:(NSUInteger)index;
- (void)removeStream:(SUSStreamHandler *)handler;

- (void)queueStreamForSong:(Song *)song offset:(NSUInteger)byteOffset atIndex:(NSUInteger)index;

// Convenience methods
- (void)queueStreamForSong:(Song *)song offset:(NSUInteger)byteOffset;
- (void)queueStreamForSong:(Song *)song atIndex:(NSUInteger)index;
- (void)queueStreamForSong:(Song *)song;

- (BOOL)insertSong:(Song *)aSong intoGenreTable:(NSString *)table;

@end
