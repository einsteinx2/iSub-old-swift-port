//
//  EX2FileDecryptor.h
//  TestCode
//
//  Created by Ben Baron on 6/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EX2FileDecryptor : NSObject

@property (nonatomic, readonly) NSUInteger chunkSize;
@property (nonatomic, readonly) NSUInteger encryptedChunkSize;
@property (nonatomic, readonly) NSString *path;

- (id)initWithPath:(NSString *)path chunkSize:(NSUInteger)chunkSize key:(NSString *)key;

- (BOOL)seekToOffset:(NSUInteger)offset;

- (NSUInteger)readBytes:(void *)buffer length:(NSUInteger)length;
- (NSData *)readData:(NSUInteger)length;

- (void)closeFile;

@property (nonatomic, readonly) unsigned long long encryptedFileSizeOnDisk;
@property (nonatomic, readonly) unsigned long long decryptedFileSizeOnDisk;

@end
