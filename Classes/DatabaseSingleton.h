//
//  DatabaseControlsSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, FMDatabase, Artist, Album, Song, SUSQueueAllLoader;

@interface DatabaseSingleton : NSObject 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	
	SUSQueueAllLoader *queueAll;
}

@property (nonatomic, retain) NSString *databaseFolderPath;
@property (nonatomic, retain) FMDatabase *allAlbumsDb;
@property (nonatomic, retain) FMDatabase *allSongsDb;
@property (nonatomic, retain) FMDatabase *coverArtCacheDb540;
@property (nonatomic, retain) FMDatabase *coverArtCacheDb320;
@property (nonatomic, retain) FMDatabase *coverArtCacheDb60;
@property (nonatomic, retain) FMDatabase *albumListCacheDb;
@property (nonatomic, retain) FMDatabase *genresDb;
@property (nonatomic, retain) FMDatabase *currentPlaylistDb;
@property (nonatomic, retain) FMDatabase *localPlaylistsDb;
@property (nonatomic, retain) FMDatabase *serverPlaylistsDb;
@property (nonatomic, retain) FMDatabase *songCacheDb;
@property (nonatomic, retain) FMDatabase *cacheQueueDb;
@property (nonatomic, retain) FMDatabase *lyricsDb;
@property (nonatomic, retain) FMDatabase *bookmarksDb;

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
