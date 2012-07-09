//
//  EX2RingBuffer.h
//  Anghami
//
//  Created by Ben Baron on 6/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EX2RingBuffer : NSObject
{
	void *bufferBackingStore;
}

@property (strong) NSData *buffer;
@property (nonatomic) NSUInteger readPosition;
@property (nonatomic) NSUInteger writePosition;
@property (nonatomic, readonly) NSUInteger totalLength;
@property (nonatomic, readonly) NSUInteger freeSpaceLength;
@property (nonatomic, readonly) NSUInteger filledSpaceLength;

- (id)initWithBufferLength:(NSUInteger)bytes;
+ (id)ringBufferWithLength:(NSUInteger)bytes;

- (BOOL)fillWithBytes:(const void *)byteBuffer length:(NSUInteger)bufferLength;
- (BOOL)fillWithData:(NSData *)data;

- (NSUInteger)drainBytes:(void *)byteBuffer length:(NSUInteger)bufferLength;
- (NSData *)drainData:(NSUInteger)length;

- (BOOL)hasSpace:(NSUInteger)length;

- (void)reset;

@end
