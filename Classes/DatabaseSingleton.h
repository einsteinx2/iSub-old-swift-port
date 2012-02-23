//
//  DatabaseControlsSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#define databaseS [DatabaseSingleton sharedInstance]

@class FMDatabase, Artist, Album, Song, SUSQueueAllLoader;

@interface DatabaseSingleton : NSObject 
{
	
	SUSQueueAllLoader *queueAll;
}

@property (retain) NSString *databaseFolderPath;
@property (retain) FMDatabase *allAlbumsDb;
@property (retain) FMDatabase *allSongsDb;
@property (retain) FMDatabase *coverArtCacheDb540;
@property (retain) FMDatabase *coverArtCacheDb320;
@property (retain) FMDatabase *coverArtCacheDb60;
@property (retain) FMDatabase *albumListCacheDb;
@property (retain) FMDatabase *genresDb;
@property (retain) FMDatabase *currentPlaylistDb;
@property (retain) FMDatabase *localPlaylistsDb;
@property (retain) FMDatabase *serverPlaylistsDb;
@property (retain) FMDatabase *songCacheDb;
@property (retain) FMDatabase *cacheQueueDb;
@property (retain) FMDatabase *lyricsDb;
@property (retain) FMDatabase *bookmarksDb;

+ (DatabaseSingleton*)sharedInstance;

- (void) initDatabases;
- (void) closeAllDatabases;
- (void) resetCoverArtCache;
- (void) resetFolderCache;
- (void) resetLocalPlaylistsDb;
- (void) resetCurrentPlaylistDb;
- (void) resetCurrentPlaylist;
- (void) resetShufflePlaylist;
- (void) resetJukeboxPlaylist;

- (void) createServerPlaylistTable:(NSString *)md5;
- (void) removeServerPlaylistTable:(NSString *)md5;

- (Album *) albumFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabase:(FMDatabase *)db;
- (BOOL) insertAlbumIntoFolderCache:(Album *)anAlbum forId:(NSString *)folderId;
- (BOOL) insertAlbum:(Album *)anAlbum intoTable:(NSString *)table inDatabase:(FMDatabase *)db;

- (NSUInteger) serverPlaylistCount:(NSString *)md5;

- (NSArray *)sectionInfoFromTable:(NSString *)table inDatabase:(FMDatabase *)database withColumn:(NSString *)column;

- (void)queueSong:(Song *)aSong;
- (void)queueAllSongs:(NSString *)folderId artist:(Artist *)theArtist;
- (void)downloadAllSongs:(NSString *)folderId artist:(Artist *)theArtist;
- (void)playAllSongs:(NSString *)folderId artist:(Artist *)theArtist;
- (void)shuffleAllSongs:(NSString *)folderId artist:(Artist *)theArtist;
- (void)shufflePlaylist;

- (void)updateTableDefinitions;

@end
