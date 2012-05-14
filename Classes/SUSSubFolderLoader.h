//
//  SUSSubFolderLoader.h
//  iSub
//
//  Created by Benjamin Baron on 11/6/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLoader.h"

@class Artist, Album, Song;
@interface SUSSubFolderLoader : SUSLoader

@property (nonatomic) NSUInteger albumsCount;
@property (nonatomic) NSUInteger songsCount;
@property (nonatomic) NSUInteger folderLength;

@property (copy) NSString *myId;
@property (copy) Artist *myArtist;

@end
