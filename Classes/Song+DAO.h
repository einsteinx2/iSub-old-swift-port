//
//  Song+DAO.h
//  iSub
//
//  Created by Ben Baron on 11/14/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "Song.h"

@class FMDatabase, FMResultSet;
@interface Song (DAO)

@property BOOL isPartiallyCached;
@property BOOL isFullyCached;
@property (readonly) CGFloat downloadProgress;
@property (readonly) BOOL fileExists;
@property (assign) NSDate *playedDate;

+ (Song *)songFromDbResult:(FMResultSet *)result;
+ (Song *)songFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabase:(FMDatabase *)db;
+ (Song *)songFromDbForMD5:(NSString *)md5 inTable:(NSString *)table inDatabase:(FMDatabase *)db;
+ (Song *)songFromGenreDb:(NSString *)md5;
+ (Song *)songFromCacheDb:(NSString *)md5;
+ (Song *)songFromServerPlaylistId:(NSString *)md5 row:(NSUInteger)row;

- (BOOL)insertIntoTable:(NSString *)table inDatabase:(FMDatabase *)db;
- (BOOL)insertIntoServerPlaylistWithPlaylistId:(NSString *)md5;
- (BOOL)insertIntoFolderCacheForFolderId:(NSString *)folderId;
- (BOOL)insertIntoGenreTable:(NSString *)table;
- (BOOL)insertIntoCachedSongsTable;

- (BOOL)addToCacheQueue;
- (BOOL)removeFromCacheQueue;

- (BOOL)addToCurrentPlaylist;
- (BOOL)addToShufflePlaylist;

- (BOOL)removeFromCachedSongsTable;
+ (BOOL)removeSongFromCacheDbByMD5:(NSString *)md5;

- (BOOL)insertIntoCachedSongsLayout;

+ (NSString *)standardSongColumnSchema;
+ (NSString *)standardSongColumnNames;
+ (NSString *)standardSongColumnQMarks;

@end
