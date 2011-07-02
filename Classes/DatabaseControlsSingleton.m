//
//  DatabaseControlsSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "DatabaseControlsSingleton.h"
#import "ViewObjectsSingleton.h"
#import "MusicControlsSingleton.h"
#import "iSubAppDelegate.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString-md5.h"
#import "Artist.h"
#import "Album.h"
#import "Song.h"
#import "LyricsXMLParser.h"
#import "QueueAlbumXMLParser.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "UIDevice-Hardware.h"
#import "QueueAll.h"

static DatabaseControlsSingleton *sharedInstance = nil;

@implementation DatabaseControlsSingleton

// New SQL stuff
@synthesize databaseFolderPath, allAlbumsDb, allSongsDb, coverArtCacheDb540, coverArtCacheDb320, coverArtCacheDb60, albumListCacheDb, genresDb, currentPlaylistDb, localPlaylistsDb, serverPlaylistsDb, songCacheDb, cacheQueueDb, lyricsDb, bookmarksDb, inMemoryDb;

#pragma mark -
#pragma mark class instance methods

- (void)initDatabases
{
	//DLog(@"%@", [NSString stringWithFormat:@"%@/%@allAlbums.db", databaseFolderPath, [NSString md5:appDelegate.defaultUrl]]);
	
	// Only load Albums, Songs, and Genre databases if this is a newer device
	//if (![[UIDevice currentDevice] isOldDevice])
	if ([[appDelegate.settingsDictionary objectForKey:@"enableSongsTabSetting"] isEqualToString:@"YES"])
	{
		// Setup the allAlbums database
		allAlbumsDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@allAlbums.db", databaseFolderPath, [NSString md5:appDelegate.defaultUrl]]] retain];
		[allAlbumsDb executeUpdate:@"PRAGMA cache_size = 1"];
		if ([allAlbumsDb open] == NO) { DLog(@"Could not open allAlbumsDb."); }
		
		/*DLog(@"allAlbumsDb: cache_size: %@   default_cache_size: %@", [allAlbumsDb stringForQuery:@"PRAGMA cache_size"], [allAlbumsDb stringForQuery:@"PRAGMA default_cache_size"]);
		 
		 FMResultSet *rs = [allAlbumsDb executeQuery:@"PRAGMA database_list"];
		 while ([rs next]) {
		 NSString *file = [rs stringForColumn:@"file"];
		 DLog(@"1");
		 DLog(@"database_list: %@", file);
		 DLog(@"2");
		 }
		 
		 FMResultSet *result = [allAlbumsDb executeQuery:@"PRAGMA cache_size"];
		 [result next];
		 DLog(@"cache_size: %@", [result stringForColumn:@"cach"]);
		 [result close];
		 [allAlbumsDb executeUpdate:@"PRAGMA default_cache_size = 10"];
		 DLog(@"allAlbumsDb: cache_size: %i   default_cache_size: %i", [allAlbumsDb intForQuery:@"PRAGMA cache_size"], [allAlbumsDb intForQuery:@"PRAGMA default_cache_size"]);
		 if ([allAlbumsDb open] == NO) { DLog(@"Could not open allAlbumsDb."); }*/
		
		// Setup the allSongs database
		allSongsDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@allSongs.db", databaseFolderPath, [NSString md5:appDelegate.defaultUrl]]] retain];
		[allSongsDb executeUpdate:@"PRAGMA cache_size = 1"];
		if ([allSongsDb open] == NO) { DLog(@"Could not open allSongsDb."); }
		
		// Setup the Genres database
		genresDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@genres.db", databaseFolderPath, [NSString md5:appDelegate.defaultUrl]]] retain];
		[genresDb executeUpdate:@"PRAGMA cache_size = 1"];
		if ([genresDb open] == NO) { DLog(@"Could not open genresDb."); }
	}
	else
	{
		allAlbumsDb = nil;
		allSongsDb = nil;
		genresDb = nil;
	}
	
	// Setup the album list cache database
	albumListCacheDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@albumListCache.db", databaseFolderPath, [NSString md5:appDelegate.defaultUrl]]] retain];
	[albumListCacheDb executeUpdate:@"PRAGMA cache_size = 1"];
	if ([albumListCacheDb open] == NO) { DLog(@"Could not open albumListCacheDb."); }
	if ([albumListCacheDb tableExists:@"albumListCache"] == NO) {
		[albumListCacheDb executeUpdate:@"CREATE TABLE albumListCache (id TEXT PRIMARY KEY, data BLOB)"];
	}
	if ([albumListCacheDb tableExists:@"albumsCache"] == NO) {
		[albumListCacheDb executeUpdate:@"CREATE TABLE albumsCache (folderId TEXT, title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
		[albumListCacheDb executeUpdate:@"CREATE INDEX albumsFolderId ON albumsCache (folderId)"];
	}
	if ([albumListCacheDb tableExists:@"songsCache"] == NO) {
		[albumListCacheDb executeUpdate:@"CREATE TABLE songsCache (folderId TEXT, title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
		[albumListCacheDb executeUpdate:@"CREATE INDEX songsFolderId ON songsCache (folderId)"];
	}
	
	// Only load large album art DB if this is an iPad
	if (IS_IPAD())
	{
		// Setup music player cover art cache database
		coverArtCacheDb540 = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/coverArtCache540.db", databaseFolderPath]] retain];
		[coverArtCacheDb540 executeUpdate:@"PRAGMA cache_size = 1"];
		if ([coverArtCacheDb540 open] == NO) { DLog(@"Could not open coverArtCacheDb540."); }
		if ([coverArtCacheDb540 tableExists:@"coverArtCache"] == NO) {
			[coverArtCacheDb540 executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
		}
	}

	// Only load small album art DB if this is not an iPad
	if (!IS_IPAD())
	{
		// Setup music player cover art cache database
		coverArtCacheDb320 = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/coverArtCache320.db", databaseFolderPath]] retain];
		[coverArtCacheDb320 executeUpdate:@"PRAGMA cache_size = 1"];
		if ([coverArtCacheDb320 open] == NO) { DLog(@"Could not open coverArtCacheDb320."); }
		if ([coverArtCacheDb320 tableExists:@"coverArtCache"] == NO) {
			[coverArtCacheDb320 executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
		}
	}
	
	// Setup album cell cover art cache database
	coverArtCacheDb60 = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/coverArtCache60.db", databaseFolderPath]] retain];
	[coverArtCacheDb60 executeUpdate:@"PRAGMA cache_size = 1"];
	if ([coverArtCacheDb60 open] == NO) { DLog(@"Could not open coverArtCacheDb60."); }
	if ([coverArtCacheDb60 tableExists:@"coverArtCache"] == NO) {
		[coverArtCacheDb60 executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
	}
	
	// Setup the current playlist database
	if (viewObjects.isOfflineMode) {
		currentPlaylistDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/offlineCurrentPlaylist.db", databaseFolderPath]] retain];
	}
	else {
		currentPlaylistDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseFolderPath, [NSString md5:appDelegate.defaultUrl]]] retain];
	}
	[currentPlaylistDb executeUpdate:@"PRAGMA cache_size = 1"];
	if ([currentPlaylistDb open] == NO) { DLog(@"Could not open currentPlaylistDb."); }
	if ([currentPlaylistDb tableExists:@"currentPlaylist"] == NO) {
		[currentPlaylistDb executeUpdate:@"CREATE TABLE currentPlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
	}
	if ([currentPlaylistDb tableExists:@"shufflePlaylist"] == NO) {
		[currentPlaylistDb executeUpdate:@"CREATE TABLE shufflePlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
	}
	if ([currentPlaylistDb tableExists:@"jukeboxCurrentPlaylist"] == NO) {
		[currentPlaylistDb executeUpdate:@"CREATE TABLE jukeboxCurrentPlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
	}
	if ([currentPlaylistDb tableExists:@"jukeboxShufflePlaylist"] == NO) {
		[currentPlaylistDb executeUpdate:@"CREATE TABLE jukeboxShufflePlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
	}
	
	// Setup the local playlists database
	if (viewObjects.isOfflineMode) {
		localPlaylistsDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/offlineLocalPlaylists.db", databaseFolderPath, [NSString md5:appDelegate.defaultUrl]]] retain];
	}
	else {
		localPlaylistsDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@localPlaylists.db", databaseFolderPath, [NSString md5:appDelegate.defaultUrl]]] retain];
	}
	[localPlaylistsDb executeUpdate:@"PRAGMA cache_size = 1"];
	if ([localPlaylistsDb open] == NO) { DLog(@"Could not open localPlaylistsDb."); }
	if ([localPlaylistsDb tableExists:@"localPlaylists"] == NO) {
		[localPlaylistsDb executeUpdate:@"CREATE TABLE localPlaylists (playlist TEXT, md5 TEXT)"];
	}
	
	// Setup the server playlists database
	//serverPlaylistsDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@serverPlaylists.db", databaseFolderPath, [NSString md5:appDelegate.defaultUrl]]] retain];
	//if ([serverPlaylistsDb open] == NO) { DLog(@"Could not open serverPlaylistsDb."); }
	
	// Setup the song cache database
	songCacheDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/songCache.db", databaseFolderPath]] retain];
	[songCacheDb executeUpdate:@"PRAGMA cache_size = 1"];
	if ([songCacheDb open] == NO) { DLog(@"Could not open songCacheDb."); }
	if ([songCacheDb tableExists:@"cachedSongs"] == NO) {
		[songCacheDb executeUpdate:@"CREATE TABLE cachedSongs (md5 TEXT UNIQUE, finished TEXT, cachedDate INTEGER, playedDate INTEGER, title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
		[songCacheDb executeUpdate:@"CREATE INDEX cachedDate ON cachedSongs (cachedDate DESC)"];
		[songCacheDb executeUpdate:@"CREATE INDEX playedDate ON cachedSongs (playedDate DESC)"];
	}
	[songCacheDb executeUpdate:@"CREATE INDEX md5 IF NOT EXISTS ON cachedSongs (md5)"];
	if ([songCacheDb tableExists:@"cachedSongsLayout"] == NO) {
		[songCacheDb executeUpdate:@"CREATE TABLE cachedSongsLayout (md5 TEXT UNIQUE, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
		[songCacheDb executeUpdate:@"CREATE INDEX genreLayout ON cachedSongsLayout (genre)"];
		[songCacheDb executeUpdate:@"CREATE INDEX seg1 ON cachedSongsLayout (seg1)"];
		[songCacheDb executeUpdate:@"CREATE INDEX seg2 ON cachedSongsLayout (seg2)"];
		[songCacheDb executeUpdate:@"CREATE INDEX seg3 ON cachedSongsLayout (seg3)"];
		[songCacheDb executeUpdate:@"CREATE INDEX seg4 ON cachedSongsLayout (seg4)"];
		[songCacheDb executeUpdate:@"CREATE INDEX seg5 ON cachedSongsLayout (seg5)"];
		[songCacheDb executeUpdate:@"CREATE INDEX seg6 ON cachedSongsLayout (seg6)"];
		[songCacheDb executeUpdate:@"CREATE INDEX seg7 ON cachedSongsLayout (seg7)"];
		[songCacheDb executeUpdate:@"CREATE INDEX seg8 ON cachedSongsLayout (seg8)"];
		[songCacheDb executeUpdate:@"CREATE INDEX seg9 ON cachedSongsLayout (seg9)"];
	}
	if ([songCacheDb tableExists:@"genres"] == NO) {
		[songCacheDb executeUpdate:@"CREATE TABLE genres(genre TEXT UNIQUE)"];
	}
	if ([songCacheDb tableExists:@"genresSongs"] == NO) {
		[songCacheDb executeUpdate:@"CREATE TABLE genresSongs (md5 TEXT UNIQUE, title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
		[songCacheDb executeUpdate:@"CREATE INDEX songGenre ON genresSongs (genre)"];
	}
	
	cacheQueueDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@cacheQueue.db", databaseFolderPath, [NSString md5:appDelegate.defaultUrl]]] retain];
	[cacheQueueDb executeUpdate:@"PRAGMA cache_size = 1"];
	if ([cacheQueueDb open] == NO) { DLog(@"Could not open cacheQueueDb."); }
	if ([cacheQueueDb tableExists:@"cacheQueue"] == NO) {
		[cacheQueueDb executeUpdate:@"CREATE TABLE cacheQueue (md5 TEXT UNIQUE, finished TEXT, cachedDate INTEGER, playedDate INTEGER, title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
		[cacheQueueDb executeUpdate:@"CREATE INDEX queueDate ON cacheQueue (cachedDate DESC)"];
	}
	[songCacheDb executeUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:@"%@/%@cacheQueue.db", databaseFolderPath, [NSString md5:appDelegate.defaultUrl]], @"cacheQueueDb"];
	if ([songCacheDb hadError]) { DLog(@"Err attaching the cacheQueueDb %d: %@", [songCacheDb lastErrorCode], [songCacheDb lastErrorMessage]); }
	
	// Setup the lyrics database
	lyricsDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/lyrics.db", databaseFolderPath]] retain];
	[lyricsDb executeUpdate:@"PRAGMA cache_size = 1"];
	if ([lyricsDb open] == NO) { DLog(@"Could not open lyricsDb."); }
	if ([lyricsDb tableExists:@"lyrics"] == NO) {
		[lyricsDb executeUpdate:@"CREATE TABLE lyrics (artist TEXT, title TEXT, lyrics TEXT)"];
		[lyricsDb executeUpdate:@"CREATE INDEX artistTitle ON lyrics (artist, title)"];
	}
	
	// Setup the bookmarks database
	bookmarksDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@bookmarks.db", databaseFolderPath, [NSString md5:appDelegate.defaultUrl]]] retain];
	[bookmarksDb executeUpdate:@"PRAGMA cache_size = 1"];
	if ([bookmarksDb open] == NO) { DLog(@"Could not open bookmarksDb."); }
	if ([bookmarksDb tableExists:@"bookmarks"] == NO) {
		[bookmarksDb executeUpdate:@"CREATE TABLE bookmarks (name TEXT, position INTEGER, title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
		[bookmarksDb executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
	}
	
	// Setup in memory database
	inMemoryDb = [[FMDatabase databaseWithPath:@":memory:"] retain];
	if ([inMemoryDb open] == NO) { DLog(@"Could not open inMemoryDb."); }
}

- (void) closeAllDatabases
{
	[allAlbumsDb close]; self.allAlbumsDb = nil;
	[allSongsDb close]; self.allSongsDb = nil;
	[genresDb close]; self.genresDb = nil;
	[albumListCacheDb close]; self.albumListCacheDb = nil;
	[coverArtCacheDb320 close]; self.coverArtCacheDb320 = nil;
	[coverArtCacheDb60 close]; self.coverArtCacheDb60 = nil;
	[currentPlaylistDb close]; self.currentPlaylistDb = nil;
	[localPlaylistsDb close]; self.localPlaylistsDb = nil;
	//[serverPlaylistsDb close]; self.serverPlaylistsDb = nil;
	[songCacheDb close]; self.songCacheDb = nil;
	[cacheQueueDb close]; self.cacheQueueDb = nil;
	[bookmarksDb close]; self.bookmarksDb = nil;
}

- (void) resetCoverArtCache
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Clear the table cell cover art
	[coverArtCacheDb60 close]; self.coverArtCacheDb60 = nil;
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/coverArtCache60.db", databaseFolderPath] error:NULL];
	
	coverArtCacheDb60 = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/coverArtCache60.db", databaseFolderPath]] retain];
	[coverArtCacheDb60 executeUpdate:@"PRAGMA cache_size = 1"];
	if ([coverArtCacheDb60 open] == NO) { DLog(@"Could not open coverArtCacheDb60."); }
	if ([coverArtCacheDb60 tableExists:@"coverArtCache"] == NO) {
		[coverArtCacheDb60 executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
	}
	
	// Clear the player cover art
	if (IS_IPAD())
	{
		[coverArtCacheDb540 close]; self.coverArtCacheDb540 = nil;
		[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/coverArtCache540.db", databaseFolderPath] error:NULL];

		coverArtCacheDb540 = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/coverArtCache540.db", databaseFolderPath]] retain];
		[coverArtCacheDb540 executeUpdate:@"PRAGMA cache_size = 1"];
		if ([coverArtCacheDb540 open] == NO) { DLog(@"Could not open coverArtCacheDb540."); }
		if ([coverArtCacheDb540 tableExists:@"coverArtCache"] == NO) {
			[coverArtCacheDb540 executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
		}
	}
	else
	{
		[coverArtCacheDb320 close]; self.coverArtCacheDb320 = nil;
		[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/coverArtCache320.db", databaseFolderPath] error:NULL];
		
		coverArtCacheDb320 = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/coverArtCache320.db", databaseFolderPath]] retain];
		[coverArtCacheDb320 executeUpdate:@"PRAGMA cache_size = 1"];
		if ([coverArtCacheDb320 open] == NO) { DLog(@"Could not open coverArtCacheDb320."); }
		if ([coverArtCacheDb320 tableExists:@"coverArtCache"] == NO) {
			[coverArtCacheDb320 executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
		}
	}
	
	[pool release];
}

- (void) resetFolderCache
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[albumListCacheDb close]; self.albumListCacheDb = nil;
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@albumListCache.db", databaseFolderPath, [NSString md5:appDelegate.defaultUrl]] error:NULL];
	
	albumListCacheDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@albumListCache.db", databaseFolderPath, [NSString md5:appDelegate.defaultUrl]]] retain];
	[albumListCacheDb executeUpdate:@"PRAGMA cache_size = 1"];
	if ([albumListCacheDb open] == NO) { DLog(@"Could not open albumListCacheDb."); }
	if ([albumListCacheDb tableExists:@"albumListCache"] == NO) {
		[albumListCacheDb executeUpdate:@"CREATE TABLE albumListCache (id TEXT PRIMARY KEY, data BLOB)"];
	}
	if ([albumListCacheDb tableExists:@"albumsCache"] == NO) {
		[albumListCacheDb executeUpdate:@"CREATE TABLE albumsCache (folderId TEXT, title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
		[albumListCacheDb executeUpdate:@"CREATE INDEX albumsFolderId ON albumsCache (folderId)"];
	}
	if ([albumListCacheDb tableExists:@"songsCache"] == NO) {
		[albumListCacheDb executeUpdate:@"CREATE TABLE songsCache (folderId TEXT, title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
		[albumListCacheDb executeUpdate:@"CREATE INDEX songsFolderId ON songsCache (folderId)"];
	}
	
	[pool release];
}

- (void) resetLocalPlaylistsDb
{
	[localPlaylistsDb close]; self.localPlaylistsDb = nil;
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@localPlaylists.db", databaseFolderPath, [NSString md5:appDelegate.defaultUrl]] error:NULL];
	localPlaylistsDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@localPlaylists.db", databaseFolderPath, [NSString md5:appDelegate.defaultUrl]]] retain];
	if ([localPlaylistsDb open] == NO) { DLog(@"Could not open localPlaylistsDb."); }
	if ([localPlaylistsDb tableExists:@"localPlaylists"] == NO) {
		[localPlaylistsDb executeUpdate:@"CREATE TABLE localPlaylists (playlist TEXT, md5 TEXT)"];
	}
}

- (void) resetCurrentPlaylistDb
{
	[currentPlaylistDb close]; self.currentPlaylistDb = nil;
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseFolderPath, [NSString md5:appDelegate.defaultUrl]] error:NULL];
	currentPlaylistDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseFolderPath, [NSString md5:appDelegate.defaultUrl]]] retain];
	if ([currentPlaylistDb open] == NO) { DLog(@"Could not open currentPlaylistDb."); }
	[currentPlaylistDb executeUpdate:@"CREATE TABLE currentPlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
	[currentPlaylistDb executeUpdate:@"CREATE TABLE shufflePlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];	
	[currentPlaylistDb executeUpdate:@"CREATE TABLE jukeboxCurrentPlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];	
	[currentPlaylistDb executeUpdate:@"CREATE TABLE jukeboxShufflePlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];	

	//if (viewObjects.isJukebox)
	//	[musicControls jukeboxClearPlaylist];
}

- (void) resetCurrentPlaylist
{
	if (viewObjects.isJukebox)
	{
		[currentPlaylistDb executeUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
		[currentPlaylistDb executeUpdate:@"CREATE TABLE jukeboxCurrentPlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];	
	}
	else
	{	
		[currentPlaylistDb executeUpdate:@"DROP TABLE currentPlaylist"];
		[currentPlaylistDb executeUpdate:@"CREATE TABLE currentPlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];	
	}
}

- (void) resetShufflePlaylist
{
	if (viewObjects.isJukebox)
	{
		[currentPlaylistDb executeUpdate:@"DROP TABLE jukeboxShufflePlaylist"];
		[currentPlaylistDb executeUpdate:@"CREATE TABLE jukeboxShufflePlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];	
	}
	else
	{	
		[currentPlaylistDb executeUpdate:@"DROP TABLE shufflePlaylist"];
		[currentPlaylistDb executeUpdate:@"CREATE TABLE shufflePlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];	
	}
}

- (void) resetJukeboxPlaylist
{
	[currentPlaylistDb executeUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
	[currentPlaylistDb executeUpdate:@"CREATE TABLE jukeboxCurrentPlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];	

	[currentPlaylistDb executeUpdate:@"DROP TABLE jukeboxShufflePlaylist"];
	[currentPlaylistDb executeUpdate:@"CREATE TABLE jukeboxShufflePlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];	
}

- (void) createServerPlaylistTable:(NSString *)md5
{
	//[serverPlaylistsDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)", md5]];
	[localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE splaylist%@ (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)", md5]];
}

- (void) removeServerPlaylistTable:(NSString *)md5
{
	//[serverPlaylistsDb executeUpdate:[NSString stringWithFormat:@"DROP TABLE playlist%@", md5]];
	[localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"DROP TABLE splaylist%@", md5]];
}

- (Album *) albumFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabase:(FMDatabase *)db
{
	row++;
	Album *anAlbum = [[Album alloc] init];
	FMResultSet *result = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE ROWID = %i", table, row]];
	[result next];
	if ([db hadError]) {
		DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
	anAlbum.title = [result stringForColumn:@"title"];
	anAlbum.albumId = [result stringForColumn:@"albumId"];
	anAlbum.coverArtId = [result stringForColumn:@"coverArtId"];
	anAlbum.artistName = [result stringForColumn:@"artistName"];
	anAlbum.artistId = [result stringForColumn:@"artistId"];
	[result close];
	return [anAlbum autorelease];
}

- (Song *) songFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabase:(FMDatabase *)db
{
	row++;
	Song *aSong = [[Song alloc] init];
	FMResultSet *result = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE ROWID = %i", table, row]];
	[result next];
	if ([db hadError]) {
		DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
	
	aSong.title = [result stringForColumn:@"title"];
	aSong.songId = [result stringForColumn:@"songId"];
	aSong.artist = [result stringForColumn:@"artist"];
	aSong.album = [result stringForColumn:@"album"];
	aSong.genre = [result stringForColumn:@"genre"];
	aSong.coverArtId = [result stringForColumn:@"coverArtId"];
	aSong.path = [result stringForColumn:@"path"];
	aSong.suffix = [result stringForColumn:@"suffix"];
	aSong.transcodedSuffix = [result stringForColumn:@"transcodedSuffix"];
	aSong.duration = [NSNumber numberWithInt:[result intForColumn:@"duration"]];
	aSong.bitRate = [NSNumber numberWithInt:[result intForColumn:@"bitRate"]];
	aSong.track = [NSNumber numberWithInt:[result intForColumn:@"track"]];
	aSong.year = [NSNumber numberWithInt:[result intForColumn:@"year"]];
	aSong.size = [NSNumber numberWithInt:[result intForColumn:@"size"]];
	
	[result close];
	
	if (aSong.path == nil)
	{
		[aSong release];
		return nil;
	}
	else
	{
		return [aSong autorelease];
	}
}

- (Song *) songFromAllSongsDb:(NSUInteger)row inTable:(NSString *)table
{
	row++;
	Song *aSong = [[Song alloc] init];
	FMResultSet *result = [allSongsDb executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE ROWID = %i", table, row]];
	[result next];
	if ([allSongsDb hadError]) {
		DLog(@"Err %d: %@", [allSongsDb lastErrorCode], [allSongsDb lastErrorMessage]);
	}
	
	aSong.title = [[result stringForColumn:@"title"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	aSong.songId = [result stringForColumn:@"songId"];
	aSong.artist = [[result stringForColumn:@"artist"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	aSong.album = [[result stringForColumn:@"album"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	aSong.genre = [[result stringForColumn:@"genre"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	aSong.coverArtId = [result stringForColumn:@"coverArtId"];
	aSong.path = [result stringForColumn:@"path"];
	aSong.suffix = [result stringForColumn:@"suffix"];
	aSong.transcodedSuffix = [result stringForColumn:@"transcodedSuffix"];
	aSong.duration = [NSNumber numberWithInt:[result intForColumn:@"duration"]];
	aSong.bitRate = [NSNumber numberWithInt:[result intForColumn:@"bitRate"]];
	aSong.track = [NSNumber numberWithInt:[result intForColumn:@"track"]];
	aSong.year = [NSNumber numberWithInt:[result intForColumn:@"year"]];
	aSong.size = [NSNumber numberWithInt:[result intForColumn:@"size"]];
	
	[result close];
	
	if (aSong.path == nil)
	{
		[aSong release];
		return nil;
	}
	else
	{
		return [aSong autorelease];
	}
}

- (Song *) songFromGenreDb:(NSString *)md5
{
	Song *aSong = [[Song alloc] init];
	FMResultSet *result;
	if (viewObjects.isOfflineMode)
	{
		result = [songCacheDb executeQuery:@"SELECT * FROM genresSongs WHERE md5 = ?", md5];
		if ([songCacheDb hadError]) {
			DLog(@"Err %d: %@", [songCacheDb lastErrorCode], [songCacheDb lastErrorMessage]);
		}
	}
	else
	{
		result = [genresDb executeQuery:@"SELECT * FROM genresSongs WHERE md5 = ?", md5];
		if ([genresDb hadError]) {
			DLog(@"Err %d: %@", [genresDb lastErrorCode], [genresDb lastErrorMessage]);
		}
	}
	
	[result next];
	aSong.title = [[result stringForColumnIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	aSong.songId = [result stringForColumnIndex:2];
	aSong.artist = [[result stringForColumnIndex:3] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	aSong.album = [[result stringForColumnIndex:4] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	aSong.genre = [[result stringForColumnIndex:5] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	aSong.coverArtId = [result stringForColumnIndex:6];
	aSong.path = [result stringForColumnIndex:7];
	aSong.suffix = [result stringForColumnIndex:8];
	aSong.transcodedSuffix = [result stringForColumnIndex:9];
	aSong.duration = [NSNumber numberWithInt:[result intForColumnIndex:10]];
	aSong.bitRate = [NSNumber numberWithInt:[result intForColumnIndex:11]];
	aSong.track = [NSNumber numberWithInt:[result intForColumnIndex:12]];
	aSong.year = [NSNumber numberWithInt:[result intForColumnIndex:13]];
	aSong.size = [NSNumber numberWithInt:[result intForColumnIndex:14]];
	
	[result close];
	return [aSong autorelease];
}

- (Song *) songFromCacheDb:(NSString *)md5
{
	Song *aSong = [[Song alloc] init];
	FMResultSet *result;
	result = [songCacheDb executeQuery:@"SELECT * FROM cachedSongs WHERE md5 = ?", md5];
	if ([songCacheDb hadError]) {
		DLog(@"Err %d: %@", [songCacheDb lastErrorCode], [songCacheDb lastErrorMessage]);
	}
	
	[result next];
	aSong.title = [result stringForColumnIndex:4];
	aSong.songId = [result stringForColumnIndex:5];
	aSong.artist = [result stringForColumnIndex:6];
	aSong.album = [result stringForColumnIndex:7];
	aSong.genre = [result stringForColumnIndex:8];
	aSong.coverArtId = [result stringForColumnIndex:9];
	aSong.path = [result stringForColumnIndex:10];
	aSong.suffix = [result stringForColumnIndex:11];
	aSong.transcodedSuffix = [result stringForColumnIndex:12];
	aSong.duration = [NSNumber numberWithInt:[result intForColumnIndex:13]];
	aSong.bitRate = [NSNumber numberWithInt:[result intForColumnIndex:14]];
	aSong.track = [NSNumber numberWithInt:[result intForColumnIndex:15]];
	aSong.year = [NSNumber numberWithInt:[result intForColumnIndex:16]];
	aSong.size = [NSNumber numberWithInt:[result intForColumnIndex:17]];
	
	[result close];
	return [aSong autorelease];
}

- (Song *) songFromServerPlaylistId:(NSString *)md5 row:(NSUInteger)row
{
	NSUInteger rowId = row + 1;
	
	Song *aSong = [[Song alloc] init];
	//NSString *query = [NSString stringWithFormat:@"SELECT * FROM playlist%@ WHERE rowid = %i", md5, rowId];
	//FMResultSet *result = [serverPlaylistsDb executeQuery:query];
	//if ([serverPlaylistsDb hadError]) {
	//	DLog(@"Err %d: %@", [serverPlaylistsDb lastErrorCode], [serverPlaylistsDb lastErrorMessage]);
	//}
	
	NSString *query = [NSString stringWithFormat:@"SELECT * FROM splaylist%@ WHERE rowid = %i", md5, rowId];
	FMResultSet *result = [localPlaylistsDb executeQuery:query];
	if ([localPlaylistsDb hadError]) {
		DLog(@"Err %d: %@", [localPlaylistsDb lastErrorCode], [localPlaylistsDb lastErrorMessage]);
	}
	
	[result next];
	aSong.title = [result stringForColumnIndex:0];
	aSong.songId = [result stringForColumnIndex:1];
	aSong.artist = [result stringForColumnIndex:2];
	aSong.album = [result stringForColumnIndex:3];
	aSong.genre = [result stringForColumnIndex:4];
	aSong.coverArtId = [result stringForColumnIndex:5];
	aSong.path = [result stringForColumnIndex:6];
	aSong.suffix = [result stringForColumnIndex:7];
	aSong.transcodedSuffix = [result stringForColumnIndex:8];
	aSong.duration = [NSNumber numberWithInt:[result intForColumnIndex:9]];
	aSong.bitRate = [NSNumber numberWithInt:[result intForColumnIndex:10]];
	aSong.track = [NSNumber numberWithInt:[result intForColumnIndex:11]];
	aSong.year = [NSNumber numberWithInt:[result intForColumnIndex:12]];
	aSong.size = [NSNumber numberWithInt:[result intForColumnIndex:13]];
	
	[result close];
	return [aSong autorelease];
}

- (NSUInteger) serverPlaylistCount:(NSString *)md5
{
	NSString *query = [NSString stringWithFormat:@"SELECT count(*) FROM splaylist%@", md5];
	return [localPlaylistsDb intForQuery:query];
}

- (BOOL) insertSongIntoServerPlaylist:(Song *)aSong playlistId:(NSString *)md5
{
	//[serverPlaylistsDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ (title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", md5], aSong.title, aSong.songId, aSong.artist, aSong.album, aSong.genre, aSong.coverArtId, aSong.path, aSong.suffix, aSong.transcodedSuffix, aSong.duration, aSong.bitRate, aSong.track, aSong.year, aSong.size];
	[localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO splaylist%@ (title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", md5], aSong.title, aSong.songId, aSong.artist, aSong.album, aSong.genre, aSong.coverArtId, aSong.path, aSong.suffix, aSong.transcodedSuffix, aSong.duration, aSong.bitRate, aSong.track, aSong.year, aSong.size];
	
	/*if ([serverPlaylistsDb hadError]) {
		DLog(@"Err inserting song %d: %@", [serverPlaylistsDb lastErrorCode], [serverPlaylistsDb lastErrorMessage]);
	}
	
	return ![serverPlaylistsDb hadError];*/
	
	if ([localPlaylistsDb hadError]) {
		DLog(@"Err inserting song %d: %@", [localPlaylistsDb lastErrorCode], [localPlaylistsDb lastErrorMessage]);
	}
	
	return ![localPlaylistsDb hadError];
}

- (BOOL) insertAlbumIntoFolderCache:(Album *)anAlbum forId:(NSString *)folderId
{
	[albumListCacheDb executeUpdate:@"INSERT INTO albumsCache (folderId, title, albumId, coverArtId, artistName, artistId) VALUES (?, ?, ?, ?, ?, ?)", [NSString md5:folderId], anAlbum.title, anAlbum.albumId, anAlbum.coverArtId, anAlbum.artistName, anAlbum.artistId];
	
	if ([albumListCacheDb hadError]) {
		DLog(@"Err %d: %@", [albumListCacheDb lastErrorCode], [albumListCacheDb lastErrorMessage]);
	}
	
	return ![albumListCacheDb hadError];
}

- (BOOL) insertSongIntoFolderCache:(Song *)aSong forId:(NSString *)folderId
{
	[albumListCacheDb executeUpdate:@"INSERT INTO songsCache (folderId, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [NSString md5:folderId], aSong.title, aSong.songId, aSong.artist, aSong.album, aSong.genre, aSong.coverArtId, aSong.path, aSong.suffix, aSong.transcodedSuffix, aSong.duration, aSong.bitRate, aSong.track, aSong.year, aSong.size];
	
	if ([albumListCacheDb hadError]) {
		DLog(@"Err inserting song %d: %@", [albumListCacheDb lastErrorCode], [albumListCacheDb lastErrorMessage]);
	}
	
	return ![albumListCacheDb hadError];
}


- (BOOL) insertAlbum:(Album *)anAlbum intoTable:(NSString *)table inDatabase:(FMDatabase *)db
{
	[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (title, albumId, coverArtId, artistName, artistId) VALUES (?, ?, ?, ?, ?)", table], anAlbum.title, anAlbum.albumId, anAlbum.coverArtId, anAlbum.artistName, anAlbum.artistId];
	
	if ([db hadError]) {
		DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
	
	return ![db hadError];
}

- (BOOL) insertSong:(Song *)aSong intoTable:(NSString *)table inDatabase:(FMDatabase *)db
{
	[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", table], aSong.title, aSong.songId, aSong.artist, aSong.album, aSong.genre, aSong.coverArtId, aSong.path, aSong.suffix, aSong.transcodedSuffix, aSong.duration, aSong.bitRate, aSong.track, aSong.year, aSong.size];
	
	if ([db hadError]) {
		DLog(@"Err inserting song %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
	
	return ![db hadError];
}

- (BOOL) addSongToCacheQueue:(Song *)aSong
{
	if ([songCacheDb intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE md5 = ? AND finished = 'YES'", [NSString md5:aSong.path]] == 0) 
	{
		[songCacheDb executeUpdate:@"INSERT INTO cacheQueue (md5, finished, cachedDate, playedDate, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [NSString md5:aSong.path], @"NO", [NSNumber numberWithInt:(NSUInteger)[[NSDate date] timeIntervalSince1970]], [NSNumber numberWithInt:0], aSong.title, aSong.songId, aSong.artist, aSong.album, aSong.genre, aSong.coverArtId, aSong.path, aSong.suffix, aSong.transcodedSuffix, aSong.duration, aSong.bitRate, aSong.track, aSong.year, aSong.size];
	}
	
	if ([songCacheDb hadError]) 
	{
		DLog(@"Err adding song to cache queue %d: %@", [songCacheDb lastErrorCode], [songCacheDb lastErrorMessage]);
	}
	
	return ![songCacheDb hadError];
}


- (BOOL) addSongToPlaylistQueue:(Song *)aSong
{
	BOOL hadError = NO;
	
	if (viewObjects.isJukebox)
	{
		//DLog(@"inserting %@", aSong.title);
		[self insertSong:aSong intoTable:@"jukeboxCurrentPlaylist" inDatabase:currentPlaylistDb];
		if ([songCacheDb hadError])
			hadError = YES;
		
		if (musicControls.isShuffle)
		{
			[self insertSong:aSong intoTable:@"jukeboxShufflePlaylist" inDatabase:currentPlaylistDb];
			if ([songCacheDb hadError])
				hadError = YES;
		}
	}
	else
	{
		[self insertSong:aSong intoTable:@"currentPlaylist" inDatabase:currentPlaylistDb];
		if ([songCacheDb hadError])
			hadError = YES;
		
		if (musicControls.isShuffle)
		{
			[self insertSong:aSong intoTable:@"shufflePlaylist" inDatabase:currentPlaylistDb];
			if ([songCacheDb hadError])
				hadError = YES;
		}
	}
	
	return !hadError;
}

- (BOOL) addSongToShuffleQueue:(Song *)aSong
{
	BOOL hadError = NO;
	
	if (viewObjects.isJukebox)
	{
		[self insertSong:aSong intoTable:@"jukeboxShufflePlaylist" inDatabase:currentPlaylistDb];
		if ([songCacheDb hadError])
			hadError = YES;
	}
	else
	{
		[self insertSong:aSong intoTable:@"shufflePlaylist" inDatabase:currentPlaylistDb];
		if ([songCacheDb hadError])
			hadError = YES;
	}
	
	return !hadError;
}


- (BOOL) removeSongFromCacheDb:(NSString *)md5
{
	BOOL hadError = NO;
	
	// Get the song info
	FMResultSet *result = [songCacheDb executeQuery:@"SELECT genre, transcodedSuffix, suffix FROM cachedSongs WHERE md5 = ?", md5];
	[result next];
	NSString *genre = [result stringForColumnIndex:0];
	NSString *transcodedSuffix = [result stringForColumnIndex:1];
	NSString *suffix = [result stringForColumnIndex:2];
	[result close];
	if ([songCacheDb hadError])
		hadError = YES;
	
	// Delete the row from the cachedSongs and genresSongs
	[songCacheDb executeUpdate:@"DELETE FROM cachedSongs WHERE md5 = ?", md5];
	if ([songCacheDb hadError])
		hadError = YES;
	[songCacheDb executeUpdate:@"DELETE FROM cachedSongsLayout WHERE md5 = ?", md5];
	if ([songCacheDb hadError])
		hadError = YES;
	[songCacheDb executeUpdate:@"DELETE FROM genresSongs WHERE md5 = ?", md5];
	if ([songCacheDb hadError])
		hadError = YES;
	
	// Delete the song from disk
	NSString *fileName;
	if (transcodedSuffix)
		fileName = [musicControls.audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", md5, transcodedSuffix]];
	else
		fileName = [musicControls.audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", md5, suffix]];
	///////// REWRITE TO CATCH THIS NSFILEMANAGER ERROR ///////////
	[[NSFileManager defaultManager] removeItemAtPath:fileName error:NULL];
	
	// Check if we're deleting the song that's currently playing. If so, stop the player.
	if (musicControls.currentSongObject && !viewObjects.isJukebox &&
		[[NSString md5:musicControls.currentSongObject.path] isEqualToString:md5])
	{
		[musicControls destroyStreamer];
	}
	
	// Clean up genres table
	if ([songCacheDb intForQuery:@"SELECT COUNT(*) FROM genresSongs WHERE genre = ?", genre] == 0)
	{
		[songCacheDb executeUpdate:@"DELETE FROM genres WHERE genre = ?", genre];
		if ([songCacheDb hadError])
			hadError = YES;
	}
	
	return !hadError;
}

- (NSArray *)sectionInfoFromTable:(NSString *)table inDatabase:(FMDatabase *)database withColumn:(NSString *)column
{
	//NSArray *sectionTitles = [[NSArray alloc] initWithObjects:@"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H", @"I", @"J", @"K", @"L", @"M", @"N", @"O", @"P", @"Q", @"R", @"S", @"T", @"U", @"V", @"W", nil];
	NSArray *sectionTitles = [[NSArray alloc] initWithObjects:@"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H", @"I", @"J", @"K", @"L", @"M", @"N", @"O", @"P", @"Q", @"R", @"S", @"T", @"U", @"V", @"W", @"X", @"Y", @"Z", nil];
	NSMutableArray *sections = [[NSMutableArray alloc] init];
	
	int i = 0;
	for (NSString *title in sectionTitles)
	{
		NSString *row;
		row = [database stringForQuery:[NSString stringWithFormat:@"SELECT ROWID FROM %@ WHERE %@ LIKE '%@%%' LIMIT 1", table, column, [sectionTitles objectAtIndex:i]]];
		//DLog(@"%@", [NSString stringWithFormat:@"SELECT ROWID FROM %@ WHERE %@ LIKE '%@%%' LIMIT 1", table, column, [sectionTitles objectAtIndex:i]]);
		if (row != nil)
		{
			[sections addObject:[NSArray arrayWithObjects:[sectionTitles objectAtIndex:i], [NSNumber numberWithInt:([row intValue] - 1)], nil]];
		}
		
		i++;
	}
	
	if ([sections count] > 0)
	{
		if ([[[sections objectAtIndex:0] objectAtIndex:1] intValue] > 0)
		{
			[sections insertObject:[NSArray arrayWithObjects:@"#", [NSNumber numberWithInt:0], nil] atIndex:0];
		}
	}
	else
	{
		[sections insertObject:[NSArray arrayWithObjects:@"#", [NSNumber numberWithInt:0], nil] atIndex:0];
	}
	
	NSArray *returnArray = [NSArray arrayWithArray:sections];
	[sectionTitles release];
	[sections release];
	
	return returnArray;
}


- (void)downloadAllSongs:(NSString *)folderId artist:(Artist *)theArtist
{
	/*// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	NSURL *url = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"getMusicDirectory.view"], folderId]];
	
	NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithContentsOfURL:url];
	[url release];
	QueueAlbumXMLParser *parser = (QueueAlbumXMLParser *)[[QueueAlbumXMLParser alloc] initXMLParser];
	parser.myArtist = theArtist;
	[xmlParser setDelegate:parser];
	[xmlParser parse];
	
	// Add each song to playlist
	for (Song *aSong in parser.listOfSongs)
	{
		[self addSongToCacheQueue:aSong];
	}
	
	// First level of recursion
	for (Album *anAlbum in parser.listOfAlbums)
	{
		// Do an XML parse for each item.
		url = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"getMusicDirectory.view"], anAlbum.albumId]];
		NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithContentsOfURL:url];
		[url release];
		QueueAlbumXMLParser *parser1 = (QueueAlbumXMLParser *)[[QueueAlbumXMLParser alloc] initXMLParser];
		parser1.myArtist = theArtist;
		[xmlParser setDelegate:parser1];
		[xmlParser parse];
		
		// Add each song to playlist
		for (Song *aSong in parser1.listOfSongs)
		{
			[self addSongToCacheQueue:aSong];
		}
		
		// Second level of recursion
		for (Album *anAlbum in parser1.listOfAlbums)
		{
			// Do an XML parse for each item.
			url = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"getMusicDirectory.view"], anAlbum.albumId]];
			NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithContentsOfURL:url];
			[url release];
			QueueAlbumXMLParser *parser2 = (QueueAlbumXMLParser *)[[QueueAlbumXMLParser alloc] initXMLParser];
			parser2.myArtist = theArtist;
			[xmlParser setDelegate:parser2];
			[xmlParser parse];
			
			// Add each song to playlist
			for (Song *aSong in parser2.listOfSongs)
			{
				[self addSongToCacheQueue:aSong];
			}
			
			// Third level of recursion
			for (Album *anAlbum in parser2.listOfAlbums)
			{
				// Do an XML parse for each item.
				url = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"getMusicDirectory.view"], anAlbum.albumId]];
				NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithContentsOfURL:url];
				[url release];
				QueueAlbumXMLParser *parser3 = (QueueAlbumXMLParser *)[[QueueAlbumXMLParser alloc] initXMLParser];
				parser3.myArtist = theArtist;
				[xmlParser setDelegate:parser3];
				[xmlParser parse];
				
				// Add each song to playlist
				for (Song *aSong in parser3.listOfSongs)
				{
					[self addSongToCacheQueue:aSong];
				}
				
				[xmlParser release];
				[parser3 release];
			}
			
			[xmlParser release];
			[parser2 release];
		}		
		
		[xmlParser release];
		[parser1 release];
	}
	
	[xmlParser release];
	[parser release];
	
	if (musicControls.isQueueListDownloading == NO)
	{
		[musicControls performSelectorOnMainThread:@selector(downloadNextQueuedSong) withObject:nil waitUntilDone:NO];
	}
	
	//[viewObjects performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:NO];
	
	[autoreleasePool release];
	*/
	
	
	// Show loading screen
	[viewObjects showLoadingScreenOnMainWindow];
	
	// Download all the songs
	if (queueAll == nil)
		queueAll = [[QueueAll alloc] init];
	//[queueAll loadData:folderId artist:theArtist isQueue:NO];
	[queueAll cacheData:folderId artist:theArtist];
}

- (void)queueAllSongs:(NSString *)folderId artist:(Artist *)theArtist
{
	// Show loading screen
	[viewObjects showLoadingScreenOnMainWindow];
	
	// Queue all the songs
	if (queueAll == nil)
		queueAll = [[QueueAll alloc] init];
	//[queueAll loadData:folderId artist:theArtist isQueue:YES];
	[queueAll queueData:folderId artist:theArtist];
}

- (void)queueSong:(Song *)aSong
{
	if (viewObjects.isJukebox)
	{
		[self insertSong:aSong intoTable:@"jukeboxCurrentPlaylist" inDatabase:self.currentPlaylistDb];
		[musicControls jukeboxAddSong:aSong.songId];
	}
	else
	{
		[self insertSong:aSong intoTable:@"currentPlaylist" inDatabase:self.currentPlaylistDb];
		if (musicControls.isShuffle)
			[self insertSong:aSong intoTable:@"shufflePlaylist" inDatabase:self.currentPlaylistDb];
	}
}

- (void)showLoadingScreen
{
	[viewObjects showLoadingScreenOnMainWindow];
}

- (void)playAllSongs:(NSString *)folderId artist:(Artist *)theArtist
{	
	// Show loading screen
	[viewObjects showLoadingScreenOnMainWindow];
	
	// Clear the current and shuffle playlists
	[self resetCurrentPlaylistDb];
	
	// Set shuffle off in case it's on
	musicControls.isShuffle = NO;
	
	// Queue all the songs
	if (queueAll == nil)
		queueAll = [[QueueAll alloc] init];
	//[queueAll loadData:folderId artist:theArtist isQueue:YES];
	[queueAll playAllData:folderId artist:theArtist];
}

- (void)shuffleAllSongs:(NSString *)folderId artist:(Artist *)theArtist
{
	// Show loading screen
	[viewObjects showLoadingScreenOnMainWindow];
	
	// Clear the current and shuffle playlists
	[self resetCurrentPlaylistDb];

	// Set shuffle on
	musicControls.isShuffle = YES;
	
	// Queue all the songs
	if (queueAll == nil)
		queueAll = [[QueueAll alloc] init];
	//[queueAll loadData:folderId artist:theArtist isQueue:YES];
	[queueAll shuffleData:folderId artist:theArtist];
}

- (void)shufflePlaylist
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	musicControls.currentPlaylistPosition = 0;
	musicControls.isShuffle = YES;
	
	[self resetShufflePlaylist];
	
	if (viewObjects.isJukebox)
		[self.currentPlaylistDb executeUpdate:@"INSERT INTO jukeboxShufflePlaylist SELECT * FROM jukeboxCurrentPlaylist ORDER BY RANDOM()"];
	else
		[self.currentPlaylistDb executeUpdate:@"INSERT INTO shufflePlaylist SELECT * FROM currentPlaylist ORDER BY RANDOM()"];
		
	[[NSNotificationCenter defaultCenter] postNotificationName:@"reloadPlaylist" object:nil];
	
	[pool release];
}


#pragma mark -
#pragma mark Singleton methods

+ (DatabaseControlsSingleton*)sharedInstance
{
    @synchronized(self)
    {
        if (sharedInstance == nil)
			[[self alloc] init];
    }
    return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone 
{
    @synchronized(self) 
	{
        if (sharedInstance == nil) 
		{
            sharedInstance = [super allocWithZone:zone];
            return sharedInstance;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}
	
-(id)init 
{
	self = [super init];
	sharedInstance = self;
	
	//initialize here
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicControlsSingleton sharedInstance];
	
	queueAll = nil;
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	self.databaseFolderPath = [[paths objectAtIndex: 0] stringByAppendingPathComponent:@"database"];
	
	// Make sure database directory exists, if not create them
	BOOL isDir = YES;
	if (![[NSFileManager defaultManager] fileExistsAtPath:databaseFolderPath isDirectory:&isDir]) 
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:databaseFolderPath withIntermediateDirectories:YES attributes:nil error:NULL];
	}	
		
	return self;
}
	

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain {
    return self;
}

- (unsigned)retainCount {
    return UINT_MAX;  // denotes an object that cannot be released
}

- (void)release {
    //do nothing
}

- (id)autorelease {
    return self;
}

@end
