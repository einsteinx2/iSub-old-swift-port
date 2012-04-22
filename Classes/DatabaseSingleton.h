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

@property (strong) NSString *databaseFolderPath;
@property (strong) FMDatabase *allAlbumsDb;
@property (strong) FMDatabase *allSongsDb;
@property (strong) FMDatabase *coverArtCacheDb540;
@property (strong) FMDatabase *coverArtCacheDb320;
@property (strong) FMDatabase *coverArtCacheDb60;
@property (strong) FMDatabase *albumListCacheDb;
@property (strong) FMDatabase *genresDb;
@property (strong) FMDatabase *currentPlaylistDb;
@property (strong) FMDatabase *localPlaylistsDb;
@property (strong) FMDatabase *serverPlaylistsDb;
@property (strong) FMDatabase *songCacheDb;
@property (strong) FMDatabase *cacheQueueDb;
@property (strong) FMDatabase *lyricsDb;
@property (strong) FMDatabase *bookmarksDb;

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
