//
//  ISMSStreamHandler.h
//  Anghami
//
//  Created by Ben Baron on 7/4/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "ISMSStreamHandlerDelegate.h"

#define ISMSMinBytesToStartPlayback(bitrate) (BytesForSecondsAtBitrate(10, bitrate))
#define ISMSMaxContentLengthFailures 25

@class ISMSSong;
@interface ISMSStreamHandler : NSObject <NSCoding>

- (nonnull instancetype)initWithSong:(nonnull ISMSSong *)song byteOffset:(unsigned long long)bOffset secondsOffset:(double)sOffset isTemp:(BOOL)isTemp delegate:(nullable NSObject<ISMSStreamHandlerDelegate> *)theDelegate;
- (nonnull instancetype)initWithSong:(nonnull ISMSSong *)song isTemp:(BOOL)isTemp delegate:(nullable NSObject<ISMSStreamHandlerDelegate> *)theDelegate;

@property (nullable, weak) NSObject<ISMSStreamHandlerDelegate> *delegate;
@property BOOL isDelegateNotifiedToStartPlayback;

@property (nonnull, copy) ISMSSong *song;

@property NSUInteger byteOffset;
@property double secondsOffset;
@property NSUInteger totalBytesTransferred;
@property NSUInteger bytesTransferred;
@property (nullable, strong) NSDate *speedLoggingDate;
@property NSUInteger speedLoggingLastSize;
@property NSUInteger recentDownloadSpeedInBytesPerSec;
@property NSInteger numOfReconnects;
@property BOOL isTempCache;
@property NSUInteger bitrate;
@property (nonnull, readonly) NSString *filePath;
@property BOOL isDownloading;
@property BOOL isCurrentSong;
@property BOOL shouldResume;
@property BOOL isCanceled;


@property long long contentLength;
@property NSInteger maxBitrateSetting;

@property NSUInteger numberOfContentLengthFailures;
@property (nullable, strong) NSFileHandle *fileHandle;
@property (nullable, strong) NSDate *startDate;

@property BOOL isEnableRateLimiting;

@property (readonly) NSUInteger totalDownloadSpeedInBytesPerSec;

- (void)start:(BOOL)resume;
- (void)start;
- (void)cancel;

+ (NSUInteger)minBytesToStartPlaybackForKiloBitrate:(double)rate speedInBytesPerSec:(NSUInteger)bytesPerSec;

@end
