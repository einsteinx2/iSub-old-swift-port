//
//  BassUserInfo.h
//  iSub
//
//  Created by Ben Baron on 1/17/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

@class Song;
@interface BassUserInfo : NSObject

@property (copy) Song *mySong;
@property FILE *myFileHandle;
@property BOOL shouldBreakWaitLoop;
@property unsigned long long neededSize;
@property BOOL isWaiting;
@property (copy) NSString *writePath;
@property (readonly) unsigned long long localFileSize;
@property BOOL isTempCached;

@end
