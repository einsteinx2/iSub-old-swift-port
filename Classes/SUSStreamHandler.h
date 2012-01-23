//
//  SUSStreamConnectionDelegate.h
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSStreamHandlerDelegate.h"

@class Song;
@interface SUSStreamHandler : NSObject <NSURLConnectionDelegate>

- (id)initWithSong:(Song *)song offset:(NSUInteger)offset isTemp:(BOOL)isTemp delegate:(NSObject<SUSStreamHandlerDelegate> *)theDelegate;
- (id)initWithSong:(Song *)song isTemp:(BOOL)isTemp delegate:(NSObject<SUSStreamHandlerDelegate> *)theDelegate;

@property (nonatomic, assign) NSObject<SUSStreamHandlerDelegate> *delegate;
@property (nonatomic, copy) Song *mySong;
@property NSUInteger byteOffset;
@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSURLRequest *request;

@property (nonatomic, retain) NSFileHandle *fileHandle;

@property long totalBytesTransferred;
@property long bytesTransferred;

@property (readonly) NSUInteger bitrate;

@property BOOL isDelegateNotifiedToStartPlayback;

@property NSUInteger numOfReconnects;

@property (nonatomic, retain) NSThread *loadingThread;

@property BOOL isTempCache;
@property (readonly) NSString *filePath;

- (void)start:(BOOL)resume;
- (void)start;
- (void)cancel;

- (void)startConnection;

@end
