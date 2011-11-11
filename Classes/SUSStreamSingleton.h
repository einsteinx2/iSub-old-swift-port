//
//  SUSStreamSingleton.h
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Song;
@interface SUSStreamSingleton : NSObject

@property (nonatomic, retain) NSDate *throttlingDate;
@property NSUInteger bytesTransferred;
@property BOOL isDownloadA;
@property BOOL isDownloadB;

+ (SUSStreamSingleton *)sharedInstance;

- (void) cancelCFNetA;
- (void) cancelCFNetB;

- (void) downloadCFNetA:(NSString *)songId;
- (void) downloadCFNetTemp:(NSString *)songId;
- (void) downloadCFNetB:(NSString *)songId;

- (void) resumeCFNetA:(NSString *)songId offset:(UInt32)byteOffset;
- (void) resumeCFNetB:(NSString *)songId offset:(UInt32)byteOffset;

- (BOOL) insertSong:(Song *)aSong intoGenreTable:(NSString *)table;

@end
