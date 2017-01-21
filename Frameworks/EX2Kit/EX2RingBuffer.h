//
//  EX2RingBuffer.h
//  EX2Kit
//
//  Created by Ben Baron on 6/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EX2RingBuffer : NSObject

@property NSInteger maximumLength;
@property (nonatomic) NSInteger readPosition;
@property (nonatomic) NSInteger writePosition;
@property (nonatomic, readonly) NSInteger totalLength;
@property (nonatomic, readonly) NSInteger freeSpaceLength;
@property (nonatomic, readonly) NSInteger filledSpaceLength;
@property long long totalBytesDrained;

- (nonnull instancetype)initWithBufferLength:(NSInteger)bytes;

- (BOOL)fillWithBytes:(const void * _Nonnull)byteBuffer length:(NSInteger)bufferLength;
- (BOOL)fillWithData:(NSData * _Nonnull)data;

- (NSInteger)drainBytes:(void * _Nonnull)byteBuffer length:(NSInteger)bufferLength;
- (nonnull NSData *)drainData:(NSInteger)length;

- (BOOL)hasSpace:(NSInteger)length;

- (void)reset;

@end
