//
//  SUSLyricsLoader.h
//  iSub
//
//  Created by Benjamin Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLoader.h"

@class FMDatabase;
@interface SUSLyricsLoader : SUSLoader

@property (unsafe_unretained, readonly) FMDatabase *db;

@property (copy) NSString *artist;
@property (copy) NSString *title;

@property (copy) NSString *loadedLyrics;

@end
