//
//  Song+DAO.h
//  iSub
//
//  Created by Ben Baron on 11/14/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "Song.h"

@class FMDatabase, FMDatabaseQueue, FMResultSet;
@interface Song (DAO)

@property BOOL isPartiallyCached;
@property BOOL isFullyCached;
@property (readonly) CGFloat downloadProgress;
@property (readonly) BOOL fileExists;
@property (assign) NSDate *playedDate;

+ (Song *)songFromDbResult:(FMResultSet *)result;
+ (Song *)songFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabase:(FMDatabase *)db;
+ (Song *)songFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue;
+ (Song *)songFromDbForMD5:(NSString *)md5 inTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue;
+ (Song *)songFromGenreDb:(FMDatabase *)db md5:(NSString *)md5;
+ (Song *)songFromGenreDbQueue:(NSString *)md5;
+ (Song *)songFromCacheDb:(FMDatabase *)db md5:(NSString *)md5;
+ (Song *)songFromCacheDbQueue:(NSString *)md5;
+ (Song *)songFromServerPlaylistId:(NSString *)md5 row:(NSUInteger)row;

- (BOOL)insertIntoTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue;
- (BOOL)insertIntoServerPlaylistWithPlaylistId:(NSString *)md5;
- (BOOL)insertIntoFolderCacheForFolderId:(NSString *)folderId;
- (BOOL)insertIntoGenreTableDbQueue:(NSString *)table;
- (BOOL)insertIntoCachedSongsTableDbQueue;

- (BOOL)addToCacheQueueDbQueue;
- (BOOL)removeFromCacheQueueDbQueue;

- (BOOL)addToCurrentPlaylistDbQueue;
- (BOOL)addToShufflePlaylistDbQueue;

- (BOOL)removeFromCachedSongsTableDbQueue;
+ (BOOL)removeSongFromCacheDbQueueByMD5:(NSString *)md5;

- (BOOL)insertIntoCachedSongsLayoutDbQueue;

- (BOOL)isCurrentPlayingSong;

+ (NSString *)standardSongColumnSchema;
+ (NSString *)standardSongColumnNames;
+ (NSString *)standardSongColumnQMarks;

@end
