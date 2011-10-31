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

@property (readonly) FMDatabase *db;

@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *title;

@property (nonatomic, copy) NSString *loadedLyrics;

@end
