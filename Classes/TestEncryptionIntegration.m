//
//  EncryptionIntegrationTest.m
//  TestCode
//
//  Created by Benjamin Baron on 6/30/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <GHUnitIOS/GHUnit.h> 

#import "EX2FileDecryptor.h"
#import "EX2FileEncryptor.h"
#import "RNCryptor.h"

@interface TestEncryptionIntegration : GHTestCase
@property (nonatomic, strong) NSString *path;
@property (nonatomic, strong) NSData *originalData;
@end

#define CHUNK_SIZE 4096

@implementation TestEncryptionIntegration
@synthesize path, originalData;

- (void)test_EncryptTestFile
{
	// Create the test file
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	self.path = [paths objectAtIndex:0];
	self.path = [self.path stringByAppendingPathComponent:@"testfile"];
	[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
	[[NSFileManager defaultManager] createFileAtPath:path contents:[NSData data] attributes:nil];
		
	// Create some random data to encrypt
	NSUInteger length = 1024 * 1024;
	self.originalData = [RNCryptor randomDataOfLength:length];
	GHAssertNotNil(self.originalData, @"originalData must not be nil");
	GHAssertEquals(length, self.originalData.length, @"originalData.length must match length");
	
	// Encrypt the data as if it were downloaded
	EX2FileEncryptor *encryptor = [[EX2FileEncryptor alloc] initWithPath:self.path chunkSize:CHUNK_SIZE];
	NSUInteger totalBytesWritten = 0;
	while (totalBytesWritten < length)
	{
		@autoreleasepool
		{
			NSUInteger writeChunkSize = (arc4random() % 10000) + 4000;
			NSUInteger writeLength = originalData.length - totalBytesWritten >= writeChunkSize ? writeChunkSize : originalData.length - totalBytesWritten;
			[encryptor writeData:[originalData subdataWithRange:NSMakeRange(totalBytesWritten, writeLength)]];
			totalBytesWritten += writeLength;
		}
	}
	[encryptor closeFile];
	//NSError *attribError;
	//unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:self.path error:&attribError] fileSize];
	//GHAssertNil(attribError, @"There should be no error getting the file attributes");
	//GHAssertGreaterThan(fileSize, length, nil, @"The file size should be greater than the original length");
}

- (void)test_RandomDecryption
{
	// Create the decryptor
	EX2FileDecryptor *decryptor = [[EX2FileDecryptor alloc] initWithPath:path chunkSize:CHUNK_SIZE];
	
	// Read data at random positions and chunk sizes and check that it matches
	NSUInteger numberOfChunkSizes = 10;
	NSUInteger numberOfOffsets = 50;
	NSUInteger numberOfConsecutiveReads = 10;
	for (int j = 0; j < numberOfChunkSizes; j++)
	{
		@autoreleasepool 
		{
			//NSUInteger readChunkSize = (arc4random() % 9999) + 1; // Small sizes: 1 - 10,000
			NSUInteger readChunkSize = (arc4random() % 90000) + 10000; // Medium sizes: 10,000 - 100,000
			//NSUInteger readChunkSize = arc4random() % 200000) + 100000; // Large sizes 100,000 - 300,000
			//NSUInteger readChunkSize = arc4random() % (originalData.length / 4); // Random sizes
			GHTestLog(@"Chunk size %u", readChunkSize);
			for (int i = 0; i < numberOfOffsets; i++)
			{
				@autoreleasepool 
				{
					// Generate a random offset
					NSUInteger offset = arc4random() % (originalData.length - (readChunkSize * numberOfConsecutiveReads));
					//GHTestLog(@"Checking data range (%i, %i)", offset, readChunkSize);
					[decryptor seekToOffset:offset];
					
					for (int i = 0; i < numberOfConsecutiveReads; i++)
					{
						NSData *decryptedDataChunk = [decryptor readData:readChunkSize];
						
						NSRange range = NSMakeRange(offset + (readChunkSize * i), readChunkSize);
						NSData *originalDataChunk = [originalData subdataWithRange:range];
						GHAssertEqualObjects(decryptedDataChunk, originalDataChunk, @"Data range at (%i, %i) should be equal", range.location, readChunkSize);
					}
				}
			}
		}
	}
}

@end
