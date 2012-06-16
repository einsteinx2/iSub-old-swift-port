//
//  SUSSubFolderLoader.h
//  iSub
//
//  Created by Benjamin Baron on 11/6/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoader.h"

@class Artist, Album, Song, FMDatabaseQueue;
@interface ISMSSubFolderLoader : ISMSLoader

@property (nonatomic) NSUInteger albumsCount;
@property (nonatomic) NSUInteger songsCount;
@property (nonatomic) NSUInteger folderLength;

@property (copy) NSString *myId;
@property (copy) Artist *myArtist;

// Database methods
- (FMDatabaseQueue *)dbQueue;
- (ISMSLoaderType)type;
- (BOOL)resetDb;
- (BOOL)insertAlbumIntoFolderCache:(Album *)anAlbum;
- (BOOL)insertSongIntoFolderCache:(Song *)aSong;
- (BOOL)insertAlbumsCount;
- (BOOL)insertSongsCount;
- (BOOL)insertFolderLength;


@end
