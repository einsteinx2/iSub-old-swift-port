//
//  ISMSStreamHandler.h
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSStreamHandlerDelegate.h"

@class Song;
@interface ISMSStreamHandler : NSObject <NSURLConnectionDelegate, NSCoding>

- (id)initWithSong:(Song *)song byteOffset:(unsigned long long)bOffset secondsOffset:(double)sOffset isTemp:(BOOL)isTemp delegate:(NSObject<ISMSStreamHandlerDelegate> *)theDelegate;
- (id)initWithSong:(Song *)song isTemp:(BOOL)isTemp delegate:(NSObject<ISMSStreamHandlerDelegate> *)theDelegate;

@property (unsafe_unretained) NSObject<ISMSStreamHandlerDelegate> *delegate;
@property (copy) Song *mySong;
@property unsigned long long byteOffset;
@property double secondsOffset;
@property (strong) NSURLConnection *connection;
@property (strong) NSURLRequest *request;
@property (strong) NSFileHandle *fileHandle;
@property unsigned long long totalBytesTransferred;
@property unsigned long long bytesTransferred;
@property BOOL isDelegateNotifiedToStartPlayback;
@property NSUInteger numOfReconnects;
@property (strong) NSThread *loadingThread;
@property BOOL isTempCache;
@property NSUInteger bitrate;
- (NSString *)filePath;
@property BOOL partialPrecacheSleep;
@property BOOL isDownloading;
@property BOOL isCurrentSong;
@property BOOL shouldResume;
@property unsigned long long contentLength;
@property NSInteger maxBitrateSetting;
@property (strong) NSDate *speedLoggingDate;
@property unsigned long long speedLoggingLastSize;
@property BOOL isCanceled;
@property NSUInteger numberOfContentLengthFailures;
@property BOOL isPartialPrecacheSleeping;
@property NSUInteger secondsToPartialPrecache;
@property BOOL tempBreakPartialPrecache;

- (void)start:(BOOL)resume;
- (void)start;
- (void)cancel;

- (void)startConnection;

@end
