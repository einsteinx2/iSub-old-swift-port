//
//  DatabaseControlsSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "DatabaseSingleton.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "iSubAppDelegate.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString-md5.h"
#import "Artist.h"
#import "Album.h"
#import "Song.h"
#import "QueueAlbumXMLParser.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "UIDevice-Hardware.h"
#import "SUSQueueAllDAO.h"
#import "SavedSettings.h"
#import "GTMNSString+HTML.h"
#import "SUSCurrentPlaylistDAO.h"

static DatabaseSingleton *sharedInstance = nil;

@implementation DatabaseSingleton

// New SQL stuff
@synthesize databaseFolderPath, allAlbumsDb, allSongsDb, coverArtCacheDb540, coverArtCacheDb320, coverArtCacheDb60, albumListCacheDb, genresDb, currentPlaylistDb, localPlaylistsDb, serverPlaylistsDb, songCacheDb, cacheQueueDb, lyricsDb, bookmarksDb, inMemoryDb;

#pragma mark -
#pragma mark class instance methods

- (void)initDatabases
{
	NSString *urlStringMd5 = [[[SavedSettings sharedInstance] urlString] md5];
		
	// Only load Albums, Songs, and Genre databases if this is a newer device
	if ([SavedSettings sharedInstance].isSongsTabEnabled)
	{
		// Setup the allAlbums database
		allAlbumsDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@allAlbums.db", databaseFolderPath, urlStringMd5]] retain];
		if ([allAlbumsDb open])
		{
			[allAlbumsDb executeUpdate:@"PRAGMA cache_size = 1"];
		}
		else
		{
			DLog(@"Could not open allAlbumsDb."); 
		}
		
		// Setup the allSongs database
		allSongsDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@allSongs.db", databaseFolderPath, urlStringMd5]] retain];
		if ([allSongsDb open])
		{
			[allSongsDb executeUpdate:@"PRAGMA cache_size = 1"];
		}
		else
		{
			DLog(@"Could not open allSongsDb.");
		}
		
		// Setup the Genres database
		genresDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@genres.db", databaseFolderPath, urlStringMd5]] retain];
		if ([genresDb open])
		{
			[genresDb executeUpdate:@"PRAGMA cache_size = 1"];
		}
		else
		{
			DLog(@"Could not open genresDb."); 
		}
	}
	else
	{
		allAlbumsDb = nil;
		allSongsDb = nil;
		genresDb = nil;
	}
	
	// Setup the album list cache database
	albumListCacheDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@albumListCache.db", databaseFolderPath, urlStringMd5]] retain];
	if ([albumListCacheDb open]) 
	{ 
		[albumListCacheDb executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![albumListCacheDb tableExists:@"albumListCache"]) 
		{
			[albumListCacheDb executeUpdate:@"CREATE TABLE albumListCache (id TEXT PRIMARY KEY, data BLOB)"];
		}
		if (![albumListCacheDb tableExists:@"albumsCache"]) 
		{
			[albumListCacheDb executeUpdate:@"CREATE TABLE albumsCache (folderId TEXT, title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
			[albumListCacheDb executeUpdate:@"CREATE INDEX albumsFolderId ON albumsCache (folderId)"];
		}
		if (![albumListCacheDb tableExists:@"songsCache"]) 
		{
			[albumListCacheDb executeUpdate:@"CREATE TABLE songsCache (folderId TEXT, title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
			[albumListCacheDb executeUpdate:@"CREATE INDEX songsFolderId ON songsCache (folderId)"];
		}
        if (![albumListCacheDb tableExists:@"albumsCacheCount"])
        {
            [albumListCacheDb executeUpdate:@"CREATE TABLE albumsCacheCount (folderId TEXT, count INTEGER)"];
            [albumListCacheDb executeUpdate:@"CREATE INDEX albumsCacheCountFolderId ON albumsCacheCount (folderId)"];
        }
        if (![albumListCacheDb tableExists:@"songsCacheCount"])
        {
            [albumListCacheDb executeUpdate:@"CREATE TABLE songsCacheCount (folderId TEXT, count INTEGER)"];
            [albumListCacheDb executeUpdate:@"CREATE INDEX songsCacheCountFolderId ON songsCacheCount (folderId)"];
        }
        if (![albumListCacheDb tableExists:@"folderLength"])
        {
            [albumListCacheDb executeUpdate:@"CREATE TABLE folderLength (folderId TEXT, length INTEGER)"];
            [albumListCacheDb executeUpdate:@"CREATE INDEX folderLengthFolderId ON folderLength (folderId)"];
        }
	}
	else
	{
		DLog(@"Could not open albumListCacheDb."); 
	}
	
	// Setup music player cover art cache database
	if (IS_IPAD())
	{
		// Only load large album art DB if this is an iPad
		coverArtCacheDb540 = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/coverArtCache540.db", databaseFolderPath]] retain];
		
		if ([coverArtCacheDb540 open])
		{
			[coverArtCacheDb540 executeUpdate:@"PRAGMA cache_size = 1"];
			
			if (![coverArtCacheDb540 tableExists:@"coverArtCache"]) 
			{
				[coverArtCacheDb540 executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
			}
		}
		else
		{ 
			DLog(@"Could not open coverArtCacheDb540."); 
		}
	}
	else
	{
		// Only load small album art DB if this is not an iPad
		coverArtCacheDb320 = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/coverArtCache320.db", databaseFolderPath]] retain];
		if ([coverArtCacheDb320 open])
		{
			[coverArtCacheDb320 executeUpdate:@"PRAGMA cache_size = 1"];
			
			if (![coverArtCacheDb320 tableExists:@"coverArtCache"]) 
			{
				[coverArtCacheDb320 executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
			}
		}
		else
		{ 
			DLog(@"Could not open coverArtCacheDb320."); 
		}
	}
	
	// Setup album cell cover art cache database
	coverArtCacheDb60 = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/coverArtCache60.db", databaseFolderPath]] retain];
	if ([coverArtCacheDb60 open])
	{
		[coverArtCacheDb60 executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![coverArtCacheDb60 tableExists:@"coverArtCache"])
		{
			[coverArtCacheDb60 executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
		}
	}
	else
	{ 
		DLog(@"Could not open coverArtCacheDb60."); 
	}
	
	// Setup the current playlist database
	if (viewObjects.isOfflineMode) 
	{
		currentPlaylistDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/offlineCurrentPlaylist.db", databaseFolderPath]] retain];
	}
	else 
	{
		currentPlaylistDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseFolderPath, urlStringMd5]] retain];
	}
	if ([currentPlaylistDb open])
	{
		[currentPlaylistDb executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![currentPlaylistDb tableExists:@"currentPlaylist"]) 
		{
			[currentPlaylistDb executeUpdate:@"CREATE TABLE currentPlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
		}
		if (![currentPlaylistDb tableExists:@"shufflePlaylist"]) 
		{
			[currentPlaylistDb executeUpdate:@"CREATE TABLE shufflePlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
		}
		if (![currentPlaylistDb tableExists:@"jukeboxCurrentPlaylist"])
		{
			[currentPlaylistDb executeUpdate:@"CREATE TABLE jukeboxCurrentPlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
		}
		if (![currentPlaylistDb tableExists:@"jukeboxShufflePlaylist"]) 
		{
			[currentPlaylistDb executeUpdate:@"CREATE TABLE jukeboxShufflePlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
		}
	}
	else
	{ 
		DLog(@"Could not open currentPlaylistDb."); 
	}
	
	// Setup the local playlists database
	if (viewObjects.isOfflineMode) 
	{
		localPlaylistsDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/offlineLocalPlaylists.db", databaseFolderPath]] retain];
	}
	else 
	{
		localPlaylistsDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@localPlaylists.db", databaseFolderPath, urlStringMd5]] retain];
	}
	if ([localPlaylistsDb open])
	{
		[localPlaylistsDb executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![localPlaylistsDb tableExists:@"localPlaylists"]) 
		{
			[localPlaylistsDb executeUpdate:@"CREATE TABLE localPlaylists (playlist TEXT, md5 TEXT)"];
		}
	}
	else 
	{
		DLog(@"Could not open localPlaylistsDb."); 
	}
	
	// Setup the song cache database
	songCacheDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/songCache.db", databaseFolderPath]] retain];
	if ([songCacheDb open])
	{
		[songCacheDb executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![songCacheDb tableExists:@"cachedSongs"])
		{
			[songCacheDb executeUpdate:@"CREATE TABLE cachedSongs (md5 TEXT UNIQUE, finished TEXT, cachedDate INTEGER, playedDate INTEGER, title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
			[songCacheDb executeUpdate:@"CREATE INDEX cachedDate ON cachedSongs (cachedDate DESC)"];
			[songCacheDb executeUpdate:@"CREATE INDEX playedDate ON cachedSongs (playedDate DESC)"];
		}
		[songCacheDb executeUpdate:@"CREATE INDEX md5 IF NOT EXISTS ON cachedSongs (md5)"];
		if (![songCacheDb tableExists:@"cachedSongsLayout"]) 
		{
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
		if (![songCacheDb tableExists:@"genres"]) 
		{
			[songCacheDb executeUpdate:@"CREATE TABLE genres(genre TEXT UNIQUE)"];
		}
		if (![songCacheDb tableExists:@"genresSongs"]) 
		{
			[songCacheDb executeUpdate:@"CREATE TABLE genresSongs (md5 TEXT UNIQUE, title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
			[songCacheDb executeUpdate:@"CREATE INDEX songGenre ON genresSongs (genre)"];
		}
	}
	else
	{ 
		DLog(@"Could not open songCacheDb."); 
	}
	
	cacheQueueDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@cacheQueue.db", databaseFolderPath, urlStringMd5]] retain];
	if ([cacheQueueDb open])
	{
		[cacheQueueDb executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![cacheQueueDb tableExists:@"cacheQueue"]) 
		{
			[cacheQueueDb executeUpdate:@"CREATE TABLE cacheQueue (md5 TEXT UNIQUE, finished TEXT, cachedDate INTEGER, playedDate INTEGER, title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
			[cacheQueueDb executeUpdate:@"CREATE INDEX queueDate ON cacheQueue (cachedDate DESC)"];
		}
		
		[songCacheDb executeUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:@"%@/%@cacheQueue.db", databaseFolderPath, urlStringMd5], @"cacheQueueDb"];
		if ([songCacheDb hadError]) 
		{
			DLog(@"Err attaching the cacheQueueDb %d: %@", [songCacheDb lastErrorCode], [songCacheDb lastErrorMessage]);
		}

	}
	else
	{ 
		DLog(@"Could not open cacheQueueDb."); 
	}
		
	// Setup the lyrics database
	lyricsDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/lyrics.db", databaseFolderPath]] retain];
	if ([lyricsDb open])
	{
		[lyricsDb executeUpdate:@"PRAGMA cache_size = 1"];

		if (![lyricsDb tableExists:@"lyrics"])
		{
			[lyricsDb executeUpdate:@"CREATE TABLE lyrics (artist TEXT, title TEXT, lyrics TEXT)"];
			[lyricsDb executeUpdate:@"CREATE INDEX artistTitle ON lyrics (artist, title)"];
		}
	}
	else
	{ 
		DLog(@"Could not open lyricsDb."); 
	}
	
	// Setup the bookmarks database
	bookmarksDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@bookmarks.db", databaseFolderPath, urlStringMd5]] retain];
	if ([bookmarksDb open])
	{
		[bookmarksDb executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![bookmarksDb tableExists:@"bookmarks"]) 
		{
			[bookmarksDb executeUpdate:@"CREATE TABLE bookmarks (name TEXT, position INTEGER, title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
			[bookmarksDb executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
		}
	}
	else
	{
		DLog(@"Could not open bookmarksDb."); 
	}
	
	// Setup in memory database
	inMemoryDb = [[FMDatabase databaseWithPath:@":memory:"] retain];
	if (![inMemoryDb open]) 
	{ 
		DLog(@"Could not open inMemoryDb.");
	}
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
	
	NSString *urlStringMd5 = [[[SavedSettings sharedInstance] urlString] md5];
	
	[albumListCacheDb close]; self.albumListCacheDb = nil;
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@albumListCache.db", databaseFolderPath, urlStringMd5] error:NULL];
	
	albumListCacheDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@albumListCache.db", databaseFolderPath, urlStringMd5]] retain];
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
	NSString *urlStringMd5 = [[[SavedSettings sharedInstance] urlString] md5];
	
	[localPlaylistsDb close]; self.localPlaylistsDb = nil;
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@localPlaylists.db", databaseFolderPath, urlStringMd5] error:NULL];
	localPlaylistsDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@localPlaylists.db", databaseFolderPath, urlStringMd5]] retain];
	if ([localPlaylistsDb open] == NO) { DLog(@"Could not open localPlaylistsDb."); }
	if ([localPlaylistsDb tableExists:@"localPlaylists"] == NO) {
		[localPlaylistsDb executeUpdate:@"CREATE TABLE localPlaylists (playlist TEXT, md5 TEXT)"];
	}
}

- (void) resetCurrentPlaylistDb
{
	NSString *urlStringMd5 = [[[SavedSettings sharedInstance] urlString] md5];
	
	[currentPlaylistDb close]; self.currentPlaylistDb = nil;
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseFolderPath, urlStringMd5] error:NULL];
	currentPlaylistDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseFolderPath, urlStringMd5]] retain];
	if ([currentPlaylistDb open] == NO) { DLog(@"Could not open currentPlaylistDb."); }
	[currentPlaylistDb executeUpdate:@"CREATE TABLE currentPlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
	[currentPlaylistDb executeUpdate:@"CREATE TABLE shufflePlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];	
	[currentPlaylistDb executeUpdate:@"CREATE TABLE jukeboxCurrentPlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];	
	[currentPlaylistDb executeUpdate:@"CREATE TABLE jukeboxShufflePlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];	

	//if ([SavedSettings sharedInstance].isJukeboxEnabled)
	//	[musicControls jukeboxClearPlaylist];
}

- (void) resetCurrentPlaylist
{
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
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
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
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
	Album *anAlbum = nil;
	FMResultSet *result = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE ROWID = %i", table, row]];
	if ([db hadError]) 
	{
		DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
	else
	{
		if ([result next])
		{
			anAlbum = [[Album alloc] init];

			if ([result stringForColumn:@"title"] != nil)
				anAlbum.title = [NSString stringWithString:[result stringForColumn:@"title"]];
			if ([result stringForColumn:@"albumId"] != nil)
				anAlbum.albumId = [NSString stringWithString:[result stringForColumn:@"albumId"]];
			if ([result stringForColumn:@"coverArtId"] != nil)
				anAlbum.coverArtId = [NSString stringWithString:[result stringForColumn:@"coverArtId"]];
			if ([result stringForColumn:@"artistName"] != nil)
				anAlbum.artistName = [NSString stringWithString:[result stringForColumn:@"artistName"]];
			if ([result stringForColumn:@"artistId"] != nil)
				anAlbum.artistId = [NSString stringWithString:[result stringForColumn:@"artistId"]];
		}
	}
	[result close];
	
	return [anAlbum autorelease];
}

- (NSUInteger) serverPlaylistCount:(NSString *)md5
{
	NSString *query = [NSString stringWithFormat:@"SELECT count(*) FROM splaylist%@", md5];
	return [localPlaylistsDb intForQuery:query];
}

- (BOOL) insertAlbumIntoFolderCache:(Album *)anAlbum forId:(NSString *)folderId
{
	[albumListCacheDb executeUpdate:@"INSERT INTO albumsCache (folderId, title, albumId, coverArtId, artistName, artistId) VALUES (?, ?, ?, ?, ?, ?)", [NSString md5:folderId], anAlbum.title, anAlbum.albumId, anAlbum.coverArtId, anAlbum.artistName, anAlbum.artistId];
	
	if ([albumListCacheDb hadError]) {
		DLog(@"Err %d: %@", [albumListCacheDb lastErrorCode], [albumListCacheDb lastErrorMessage]);
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
		queueAll = [[SUSQueueAllDAO alloc] init];
	//[queueAll loadData:folderId artist:theArtist isQueue:NO];
	[queueAll cacheData:folderId artist:theArtist];
}

- (void)queueAllSongs:(NSString *)folderId artist:(Artist *)theArtist
{
	// Show loading screen
	[viewObjects showLoadingScreenOnMainWindow];
	
	// Queue all the songs
	if (queueAll == nil)
		queueAll = [[SUSQueueAllDAO alloc] init];
	//[queueAll loadData:folderId artist:theArtist isQueue:YES];
	[queueAll queueData:folderId artist:theArtist];
}

- (void)queueSong:(Song *)aSong
{
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		[aSong insertIntoTable:@"jukeboxCurrentPlaylist" inDatabase:self.currentPlaylistDb];
		[musicControls jukeboxAddSong:aSong.songId];
	}
	else
	{
		[aSong insertIntoTable:@"currentPlaylist" inDatabase:self.currentPlaylistDb];
		if (musicControls.isShuffle)
			[aSong insertIntoTable:@"shufflePlaylist" inDatabase:self.currentPlaylistDb];
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
		queueAll = [[SUSQueueAllDAO alloc] init];
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
		queueAll = [[SUSQueueAllDAO alloc] init];
	//[queueAll loadData:folderId artist:theArtist isQueue:YES];
	[queueAll shuffleData:folderId artist:theArtist];
}

- (void)shufflePlaylist
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[SUSCurrentPlaylistDAO dataModel].currentIndex = 0;
	musicControls.isShuffle = YES;
	
	[self resetShufflePlaylist];
	
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
		[self.currentPlaylistDb executeUpdate:@"INSERT INTO jukeboxShufflePlaylist SELECT * FROM jukeboxCurrentPlaylist ORDER BY RANDOM()"];
	else
		[self.currentPlaylistDb executeUpdate:@"INSERT INTO shufflePlaylist SELECT * FROM currentPlaylist ORDER BY RANDOM()"];
		
	[[NSNotificationCenter defaultCenter] postNotificationName:@"reloadPlaylist" object:nil];
	
	[pool release];
}

// New Model Stuff




#pragma mark - Singleton methods

+ (DatabaseSingleton*)sharedInstance
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
	musicControls = [MusicSingleton sharedInstance];
	
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

- (oneway void)release {
    //do nothing
}

- (id)autorelease {
    return self;
}

@end
