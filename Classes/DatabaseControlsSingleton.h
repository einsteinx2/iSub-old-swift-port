//
//  DatabaseControlsSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@class iSubAppDelegate, ViewObjectsSingleton, MusicControlsSingleton, FMDatabase, Artist, Album, Song, QueueAll;

@interface DatabaseControlsSingleton : NSObject 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicControlsSingleton *musicControls;
	
	NSString *databaseFolderPath;
	FMDatabase *allAlbumsDb;
	FMDatabase *allSongsDb;
	FMDatabase *coverArtCacheDb540;
	FMDatabase *coverArtCacheDb320;
	FMDatabase *coverArtCacheDb60;
	FMDatabase *albumListCacheDb;
	FMDatabase *genresDb;
	FMDatabase *currentPlaylistDb;
	FMDatabase *localPlaylistsDb;
	FMDatabase *serverPlaylistsDb;
	FMDatabase *songCacheDb;
	FMDatabase *cacheQueueDb;
	FMDatabase *lyricsDb;
	FMDatabase *bookmarksDb;
	FMDatabase *inMemoryDb;
	
	QueueAll *queueAll;
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
@property (nonatomic, retain) FMDatabase *inMemoryDb;

+ (DatabaseControlsSingleton*)sharedInstance;

- (void) initDatabases;

- (void) createServerPlaylistTable:(NSString *)md5;
- (void) removeServerPlaylistTable:(NSString *)md5;

- (Album *) albumFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabase:(FMDatabase *)db;
- (Song *) songFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabase:(FMDatabase *)db;
- (Song *) songFromGenreDb:(NSString *)md5;
- (Song *) songFromCacheDb:(NSString *)md5;
- (Song *) songFromServerPlaylistId:(NSString *)md5 row:(NSUInteger)row;

- (NSUInteger) serverPlaylistCount:(NSString *)md5;

- (BOOL) insertSongIntoServerPlaylist:(Song *)aSong playlistId:(NSString *)md5;
- (BOOL) insertAlbumIntoFolderCache:(Album *)anAlbum forId:(NSString *)folderId;
- (BOOL) insertSongIntoFolderCache:(Song *)aSong forId:(NSString *)folderId;

- (BOOL) insertAlbum:(Album *)anAlbum intoTable:(NSString *)table inDatabase:(FMDatabase *)db;
- (BOOL) insertSong:(Song *)aSong intoTable:(NSString *)table inDatabase:(FMDatabase *)db;
- (BOOL) addSongToCacheQueue:(Song *)aSong;
- (BOOL) addSongToPlaylistQueue:(Song *)aSong;
- (BOOL) addSongToShuffleQueue:(Song *)aSong;

- (BOOL) removeSongFromCacheDb:(NSString *)md5;

- (void) closeAllDatabases;
- (void) resetCoverArtCache;
- (void) resetFolderCache;
- (void) resetLocalPlaylistsDb;
- (void) resetCurrentPlaylistDb;
- (void) resetCurrentPlaylist;
- (void) resetShufflePlaylist;
- (void) resetJukeboxPlaylist;

- (NSArray *)sectionInfoFromTable:(NSString *)table inDatabase:(FMDatabase *)database withColumn:(NSString *)column;

- (void)queueSong:(Song *)aSong;

- (void)queueAllSongs:(NSString *)folderId artist:(Artist *)theArtist;
- (void)downloadAllSongs:(NSString *)folderId artist:(Artist *)theArtist;
- (void)playAllSongs:(NSString *)folderId artist:(Artist *)theArtist;
- (void)shuffleAllSongs:(NSString *)folderId artist:(Artist *)theArtist;
- (void)shufflePlaylist;

// New Model Stuff


@end
