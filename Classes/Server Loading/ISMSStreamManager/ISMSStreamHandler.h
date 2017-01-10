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

- (nonnull instancetype)initWithSong:(nonnull ISMSSong *)song byteOffset:(unsigned long long)bOffset isTemp:(BOOL)isTemp delegate:(nullable NSObject<ISMSStreamHandlerDelegate> *)theDelegate;
- (nonnull instancetype)initWithSong:(nonnull ISMSSong *)song isTemp:(BOOL)isTemp delegate:(nullable NSObject<ISMSStreamHandlerDelegate> *)theDelegate;

@property (nullable, weak) NSObject<ISMSStreamHandlerDelegate> *delegate;
@property BOOL isDelegateNotifiedToStartPlayback;

@property (nonnull, copy) ISMSSong *song;

@property NSInteger byteOffset;
@property NSInteger totalBytesTransferred;
@property NSInteger bytesTransferred;
@property (nullable, strong) NSDate *speedLoggingDate;
@property NSInteger speedLoggingLastSize;
@property NSInteger recentDownloadSpeedInBytesPerSec;
@property NSInteger numOfReconnects;
@property BOOL isTempCache;
@property NSInteger bitrate;
@property (nonnull, readonly) NSString *filePath;
@property BOOL isDownloading;
@property BOOL isCurrentSong;
@property BOOL shouldResume;
@property BOOL isCanceled;


@property long long contentLength;
@property NSInteger maxBitrateSetting;

@property NSInteger numberOfContentLengthFailures;
@property (nullable, strong) NSFileHandle *fileHandle;
@property (nullable, strong) NSDate *startDate;

@property (readonly) NSInteger totalDownloadSpeedInBytesPerSec;

- (void)start:(BOOL)resume;
- (void)start;
- (void)cancel;

+ (NSInteger)minBytesToStartPlaybackForKiloBitrate:(double)rate speedInBytesPerSec:(NSInteger)bytesPerSec;

@end
