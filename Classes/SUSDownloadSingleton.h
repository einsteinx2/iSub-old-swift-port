//
//  CFNetworkRequests.h
//  iSub
//
//  Created by Ben Baron on 7/14/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "Song.h"
#import "SUSLoaderDelegate.h"

@interface SUSDownloadSingleton : NSObject <SUSLoaderDelegate>

@property (nonatomic, retain) NSDate *throttlingDate;
@property BOOL isDownloadA;
@property BOOL isDownloadB;

+ (SUSDownloadSingleton *)sharedInstance;

- (void) cancelCFNetA;
- (void) cancelCFNetB;

- (void) downloadCFNetA:(NSString *)songId;
- (void) downloadCFNetTemp:(NSString *)songId;
- (void) downloadCFNetB:(NSString *)songId;

- (void) resumeCFNetA:(NSString *)songId offset:(UInt32)byteOffset;
- (void) resumeCFNetB:(NSString *)songId offset:(UInt32)byteOffset;

- (BOOL) insertSong:(Song *)aSong intoGenreTable:(NSString *)table;

@end
