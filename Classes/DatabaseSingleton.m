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
#import "FMDatabaseAdditions.h"

#import "NSString+md5.h"
#import "Artist.h"
#import "Album.h"
#import "Song.h"
#import "QueueAlbumXMLParser.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "UIDevice+Hardware.h"
#import "SUSQueueAllLoader.h"
#import "SavedSettings.h"
#import "GTMNSString+HTML.h"
#import "PlaylistSingleton.h"
#import "SUSStreamSingleton.h"

static DatabaseSingleton *sharedInstance = nil;

@implementation DatabaseSingleton

// New SQL stuff
@synthesize databaseFolderPath, allAlbumsDb, allSongsDb, coverArtCacheDb540, coverArtCacheDb320, coverArtCacheDb60, albumListCacheDb, genresDb, currentPlaylistDb, localPlaylistsDb, serverPlaylistsDb, songCacheDb, cacheQueueDb, lyricsDb, bookmarksDb;

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
		DLog(@"allAlbumsDb: %@", allAlbumsDb);
		if ([allAlbumsDb open])
		{
			[allAlbumsDb synchronizedExecuteUpdate:@"PRAGMA cache_size = 1"];
		}
		else
		{
			DLog(@"Could not open allAlbumsDb."); 
		}
		
		// Setup the allSongs database
		allSongsDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@allSongs.db", databaseFolderPath, urlStringMd5]] retain];
		if ([allSongsDb open])
		{
			[allSongsDb synchronizedExecuteUpdate:@"PRAGMA cache_size = 1"];
		}
		else
		{
			DLog(@"Could not open allSongsDb.");
		}
		
		// Setup the Genres database
		genresDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@genres.db", databaseFolderPath, urlStringMd5]] retain];
		if ([genresDb open])
		{
			[genresDb synchronizedExecuteUpdate:@"PRAGMA cache_size = 1"];
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
		[albumListCacheDb synchronizedExecuteUpdate:@"PRAGMA cache_size = 1"];
		
		if (![albumListCacheDb tableExists:@"albumListCache"]) 
		{
			[albumListCacheDb synchronizedExecuteUpdate:@"CREATE TABLE albumListCache (id TEXT PRIMARY KEY, data BLOB)"];
		}
		if (![albumListCacheDb tableExists:@"albumsCache"]) 
		{
			[albumListCacheDb synchronizedExecuteUpdate:@"CREATE TABLE albumsCache (folderId TEXT, title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
			[albumListCacheDb synchronizedExecuteUpdate:@"CREATE INDEX albumsFolderId ON albumsCache (folderId)"];
		}
		if (![albumListCacheDb tableExists:@"songsCache"]) 
		{
			[albumListCacheDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE songsCache (folderId TEXT, %@)", [Song standardSongColumnSchema]]];
			[albumListCacheDb synchronizedExecuteUpdate:@"CREATE INDEX songsFolderId ON songsCache (folderId)"];
		}
        if (![albumListCacheDb tableExists:@"albumsCacheCount"])
        {
            [albumListCacheDb synchronizedExecuteUpdate:@"CREATE TABLE albumsCacheCount (folderId TEXT, count INTEGER)"];
            [albumListCacheDb synchronizedExecuteUpdate:@"CREATE INDEX albumsCacheCountFolderId ON albumsCacheCount (folderId)"];
        }
        if (![albumListCacheDb tableExists:@"songsCacheCount"])
        {
            [albumListCacheDb synchronizedExecuteUpdate:@"CREATE TABLE songsCacheCount (folderId TEXT, count INTEGER)"];
            [albumListCacheDb synchronizedExecuteUpdate:@"CREATE INDEX songsCacheCountFolderId ON songsCacheCount (folderId)"];
        }
        if (![albumListCacheDb tableExists:@"folderLength"])
        {
            [albumListCacheDb synchronizedExecuteUpdate:@"CREATE TABLE folderLength (folderId TEXT, length INTEGER)"];
            [albumListCacheDb synchronizedExecuteUpdate:@"CREATE INDEX folderLengthFolderId ON folderLength (folderId)"];
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
			[coverArtCacheDb540 synchronizedExecuteUpdate:@"PRAGMA cache_size = 1"];
			
			if (![coverArtCacheDb540 tableExists:@"coverArtCache"]) 
			{
				[coverArtCacheDb540 synchronizedExecuteUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
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
			[coverArtCacheDb320 synchronizedExecuteUpdate:@"PRAGMA cache_size = 1"];
			
			if (![coverArtCacheDb320 tableExists:@"coverArtCache"]) 
			{
				[coverArtCacheDb320 synchronizedExecuteUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
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
		[coverArtCacheDb60 synchronizedExecuteUpdate:@"PRAGMA cache_size = 1"];
		
		if (![coverArtCacheDb60 tableExists:@"coverArtCache"])
		{
			[coverArtCacheDb60 synchronizedExecuteUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
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
		[currentPlaylistDb synchronizedExecuteUpdate:@"PRAGMA cache_size = 1"];
		
		if (![currentPlaylistDb tableExists:@"currentPlaylist"]) 
		{
			[currentPlaylistDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentPlaylist (%@)", [Song standardSongColumnSchema]]];
		}
		if (![currentPlaylistDb tableExists:@"shufflePlaylist"]) 
		{
			[currentPlaylistDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shufflePlaylist (%@)", [Song standardSongColumnSchema]]];
		}
		if (![currentPlaylistDb tableExists:@"jukeboxCurrentPlaylist"])
		{
			[currentPlaylistDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", [Song standardSongColumnSchema]]];
		}
		if (![currentPlaylistDb tableExists:@"jukeboxShufflePlaylist"]) 
		{
			[currentPlaylistDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", [Song standardSongColumnSchema]]];
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
		[localPlaylistsDb synchronizedExecuteUpdate:@"PRAGMA cache_size = 1"];
		
		if (![localPlaylistsDb tableExists:@"localPlaylists"]) 
		{
			[localPlaylistsDb synchronizedExecuteUpdate:@"CREATE TABLE localPlaylists (playlist TEXT, md5 TEXT)"];
		}
	}
	else 
	{
		DLog(@"Could not open localPlaylistsDb."); 
	}
	
	// Setup the song cache database
	// Check if the songCache DB is in the documents directory
	SavedSettings *settings = [SavedSettings sharedInstance];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:[databaseFolderPath stringByAppendingPathComponent:@"songCache.db"]]) 
	{
		// The song cache Db is in the old place and needs to be moved
		[fileManager moveItemAtURL:[NSURL fileURLWithPath:[databaseFolderPath stringByAppendingPathComponent:@"songCache.db"]]
							 toURL:[NSURL fileURLWithPath:[settings.cachesPath stringByAppendingPathComponent:@"songCache.db"]] error:nil];
	}
	songCacheDb = [[FMDatabase databaseWithPath:[settings.cachesPath stringByAppendingPathComponent:@"songCache.db"]] retain];
	if ([songCacheDb open])
	{
		[songCacheDb synchronizedExecuteUpdate:@"PRAGMA cache_size = 1"];
		
		if (![songCacheDb tableExists:@"cachedSongs"])
		{
			[songCacheDb synchronizedExecuteUpdate:[NSString stringWithFormat:@"CREATE TABLE cachedSongs (md5 TEXT UNIQUE, finished TEXT, cachedDate INTEGER, playedDate INTEGER, %@)", [Song standardSongColumnSchema]]];
			[songCacheDb synchronizedExecuteUpdate:@"CREATE INDEX cachedDate ON cachedSongs (cachedDate DESC)"];
			[songCacheDb synchronizedExecuteUpdate:@"CREATE INDEX playedDate ON cachedSongs (playedDate DESC)"];
		}
		[songCacheDb synchronizedExecuteUpdate:@"CREATE INDEX md5 IF NOT EXISTS ON cachedSongs (md5)"];
		if (![songCacheDb tableExists:@"cachedSongsLayout"]) 
		{
			[songCacheDb synchronizedExecuteUpdate:@"CREATE TABLE cachedSongsLayout (md5 TEXT UNIQUE, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
			[songCacheDb synchronizedExecuteUpdate:@"CREATE INDEX genreLayout ON cachedSongsLayout (genre)"];
			[songCacheDb synchronizedExecuteUpdate:@"CREATE INDEX seg1 ON cachedSongsLayout (seg1)"];
			[songCacheDb synchronizedExecuteUpdate:@"CREATE INDEX seg2 ON cachedSongsLayout (seg2)"];
			[songCacheDb synchronizedExecuteUpdate:@"CREATE INDEX seg3 ON cachedSongsLayout (seg3)"];
			[songCacheDb synchronizedExecuteUpdate:@"CREATE INDEX seg4 ON cachedSongsLayout (seg4)"];
			[songCacheDb synchronizedExecuteUpdate:@"CREATE INDEX seg5 ON cachedSongsLayout (seg5)"];
			[songCacheDb synchronizedExecuteUpdate:@"CREATE INDEX seg6 ON cachedSongsLayout (seg6)"];
			[songCacheDb synchronizedExecuteUpdate:@"CREATE INDEX seg7 ON cachedSongsLayout (seg7)"];
			[songCacheDb synchronizedExecuteUpdate:@"CREATE INDEX seg8 ON cachedSongsLayout (seg8)"];
			[songCacheDb synchronizedExecuteUpdate:@"CREATE INDEX seg9 ON cachedSongsLayout (seg9)"];
		}
		if (![songCacheDb tableExists:@"genres"]) 
		{
			[songCacheDb synchronizedExecuteUpdate:@"CREATE TABLE genres(genre TEXT UNIQUE)"];
		}
		if (![songCacheDb tableExists:@"genresSongs"]) 
		{
			[songCacheDb synchronizedExecuteUpdate:[NSString stringWithFormat:@"CREATE TABLE genresSongs (md5 TEXT UNIQUE, %@)", [Song standardSongColumnSchema]]];
			[songCacheDb synchronizedExecuteUpdate:@"CREATE INDEX songGenre ON genresSongs (genre)"];
		}
	}
	else
	{ 
		DLog(@"Could not open songCacheDb."); 
	}
	
	if ([fileManager fileExistsAtPath:[NSString stringWithFormat:@"%@/%@cacheQueue.db", databaseFolderPath, [settings.urlString md5]]]) 
	{
		// The song cache queue Db is in the old place and needs to be moved
		[fileManager moveItemAtURL:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@cacheQueue.db", databaseFolderPath, [settings.urlString md5]]] 
							 toURL:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@cacheQueue.db", settings.cachesPath, [settings.urlString md5]]] error:nil];
	}
	cacheQueueDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@cacheQueue.db", settings.cachesPath, [settings.urlString md5]]] retain];
	if ([cacheQueueDb open])
	{
		[cacheQueueDb synchronizedExecuteUpdate:@"PRAGMA cache_size = 1"];
		
		if (![cacheQueueDb tableExists:@"cacheQueue"]) 
		{
			[cacheQueueDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE cacheQueue (md5 TEXT UNIQUE, finished TEXT, cachedDate INTEGER, playedDate INTEGER, %@)", [Song standardSongColumnSchema]]];
			[cacheQueueDb synchronizedExecuteUpdate:@"CREATE INDEX queueDate ON cacheQueue (cachedDate DESC)"];
		}
		
		[songCacheDb synchronizedExecuteUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:@"%@/%@cacheQueue.db", settings.cachesPath, urlStringMd5], @"cacheQueueDb"];
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
		[lyricsDb synchronizedExecuteUpdate:@"PRAGMA cache_size = 1"];

		if (![lyricsDb tableExists:@"lyrics"])
		{
			[lyricsDb synchronizedExecuteUpdate:@"CREATE TABLE lyrics (artist TEXT, title TEXT, lyrics TEXT)"];
			[lyricsDb synchronizedExecuteUpdate:@"CREATE INDEX artistTitle ON lyrics (artist, title)"];
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
		[bookmarksDb synchronizedExecuteUpdate:@"PRAGMA cache_size = 1"];
		
		if (![bookmarksDb tableExists:@"bookmarks"]) 
		{
			[bookmarksDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarks (name TEXT, position INTEGER, %@, bytes INTEGER)", [Song standardSongColumnSchema]]];
			[bookmarksDb synchronizedExecuteUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
		}
	}
	else
	{
		DLog(@"Could not open bookmarksDb."); 
	}
	
	[self updateTableDefinitions];
}

- (void)updateTableDefinitions
{
	// Add parentId column to tables if necessary
	NSArray *parentIdDatabases = [NSArray arrayWithObjects:albumListCacheDb, currentPlaylistDb, currentPlaylistDb, currentPlaylistDb, currentPlaylistDb, songCacheDb, songCacheDb, cacheQueueDb, bookmarksDb, songCacheDb, cacheQueueDb, nil];
	NSArray *parentIdTables = [NSArray arrayWithObjects:@"songsCache", @"currentPlaylist", @"shufflePlaylist", @"jukeboxCurrentPlaylist", @"jukeboxShufflePlaylist", @"cachedSongs", @"genresSongs", @"cacheQueue", @"bookmarks", @"cachedSongsList", @"queuedSongsList", nil];
	NSString *columnName = @"parentId";
	for (int i = 0; i < [parentIdDatabases count]; i++)
	{
		FMDatabase *db = [parentIdDatabases objectAtIndex:i];
		NSString *table = [parentIdTables objectAtIndex:i];
		
		if (![db columnExists:table columnName:columnName])
		{
			NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ TEXT", table, columnName];
			[db executeUpdate:query];
		}
	}
	
	// Add parentId to all playlist and splaylist tables
	NSMutableArray *playlistTableNames = [NSMutableArray arrayWithCapacity:0];
	NSString *query = @"SELECT name FROM sqlite_master WHERE type = 'table'";
	FMResultSet *result = [localPlaylistsDb executeQuery:query];
	while ([result next])
	{
		NSString *tableName = [result stringForColumnIndex:0];
		if ([tableName length] > 8)
		{
			NSString *tableNameSubstring = [tableName substringToIndex:8];
			if ([tableNameSubstring isEqualToString:@"playlist"] ||
				[tableNameSubstring isEqualToString:@"splaylis"])
			{
				[playlistTableNames addObject:tableName];
			}
		}
	}
	[result close];
	for (NSString *table in playlistTableNames)
	{
		if (![localPlaylistsDb columnExists:table columnName:columnName])
		{
			NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ TEXT", table, columnName];
			[localPlaylistsDb executeUpdate:query];
		}
	}
	
	// Add bytes column to bookmarks table if necessary
	if (![bookmarksDb columnExists:@"bookmarks" columnName:@"bytes"])
	{
		[bookmarksDb synchronizedExecuteUpdate:@"ALTER TABLE bookmarks ADD COLUMN bytes INTEGER"];
	}
}

- (void)closeAllDatabases
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

- (void)resetCoverArtCache
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Clear the table cell cover art
	[coverArtCacheDb60 close]; self.coverArtCacheDb60 = nil;
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/coverArtCache60.db", databaseFolderPath] error:NULL];
	
	coverArtCacheDb60 = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/coverArtCache60.db", databaseFolderPath]] retain];
	[coverArtCacheDb60 synchronizedExecuteUpdate:@"PRAGMA cache_size = 1"];
	if ([coverArtCacheDb60 open] == NO) { DLog(@"Could not open coverArtCacheDb60."); }
	if ([coverArtCacheDb60 tableExists:@"coverArtCache"] == NO) {
		[coverArtCacheDb60 synchronizedExecuteUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
	}
	
	// Clear the player cover art
	if (IS_IPAD())
	{
		[coverArtCacheDb540 close]; self.coverArtCacheDb540 = nil;
		[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/coverArtCache540.db", databaseFolderPath] error:NULL];

		coverArtCacheDb540 = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/coverArtCache540.db", databaseFolderPath]] retain];
		[coverArtCacheDb540 synchronizedExecuteUpdate:@"PRAGMA cache_size = 1"];
		if ([coverArtCacheDb540 open] == NO) { DLog(@"Could not open coverArtCacheDb540."); }
		if ([coverArtCacheDb540 tableExists:@"coverArtCache"] == NO) {
			[coverArtCacheDb540 synchronizedExecuteUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
		}
	}
	else
	{
		[coverArtCacheDb320 close]; self.coverArtCacheDb320 = nil;
		[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/coverArtCache320.db", databaseFolderPath] error:NULL];
		
		coverArtCacheDb320 = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/coverArtCache320.db", databaseFolderPath]] retain];
		[coverArtCacheDb320 synchronizedExecuteUpdate:@"PRAGMA cache_size = 1"];
		if ([coverArtCacheDb320 open] == NO) { DLog(@"Could not open coverArtCacheDb320."); }
		if ([coverArtCacheDb320 tableExists:@"coverArtCache"] == NO) {
			[coverArtCacheDb320 synchronizedExecuteUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
		}
	}
	
	[pool release];
}

- (void)resetFolderCache
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSString *urlStringMd5 = [[[SavedSettings sharedInstance] urlString] md5];
	
	[albumListCacheDb close]; self.albumListCacheDb = nil;
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@albumListCache.db", databaseFolderPath, urlStringMd5] error:NULL];
	
	// Setup the album list cache database
	albumListCacheDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@albumListCache.db", databaseFolderPath, urlStringMd5]] retain];
	if ([albumListCacheDb open]) 
	{ 
		[albumListCacheDb synchronizedExecuteUpdate:@"PRAGMA cache_size = 1"];
		
		if (![albumListCacheDb tableExists:@"albumListCache"]) 
		{
			[albumListCacheDb synchronizedExecuteUpdate:@"CREATE TABLE albumListCache (id TEXT PRIMARY KEY, data BLOB)"];
		}
		if (![albumListCacheDb tableExists:@"albumsCache"]) 
		{
			[albumListCacheDb synchronizedExecuteUpdate:@"CREATE TABLE albumsCache (folderId TEXT, title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
			[albumListCacheDb synchronizedExecuteUpdate:@"CREATE INDEX albumsFolderId ON albumsCache (folderId)"];
		}
		if (![albumListCacheDb tableExists:@"songsCache"]) 
		{
			[albumListCacheDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE songsCache (folderId TEXT, %@)", [Song standardSongColumnSchema]]];
			[albumListCacheDb synchronizedExecuteUpdate:@"CREATE INDEX songsFolderId ON songsCache (folderId)"];
		}
        if (![albumListCacheDb tableExists:@"albumsCacheCount"])
        {
            [albumListCacheDb synchronizedExecuteUpdate:@"CREATE TABLE albumsCacheCount (folderId TEXT, count INTEGER)"];
            [albumListCacheDb synchronizedExecuteUpdate:@"CREATE INDEX albumsCacheCountFolderId ON albumsCacheCount (folderId)"];
        }
        if (![albumListCacheDb tableExists:@"songsCacheCount"])
        {
            [albumListCacheDb synchronizedExecuteUpdate:@"CREATE TABLE songsCacheCount (folderId TEXT, count INTEGER)"];
            [albumListCacheDb synchronizedExecuteUpdate:@"CREATE INDEX songsCacheCountFolderId ON songsCacheCount (folderId)"];
        }
        if (![albumListCacheDb tableExists:@"folderLength"])
        {
            [albumListCacheDb synchronizedExecuteUpdate:@"CREATE TABLE folderLength (folderId TEXT, length INTEGER)"];
            [albumListCacheDb synchronizedExecuteUpdate:@"CREATE INDEX folderLengthFolderId ON folderLength (folderId)"];
        }
	}
	else
	{
		DLog(@"Could not open albumListCacheDb."); 
	}
	
	[pool release];
}

- (void)resetLocalPlaylistsDb
{
	NSString *urlStringMd5 = [[[SavedSettings sharedInstance] urlString] md5];
	
	[localPlaylistsDb close]; self.localPlaylistsDb = nil;
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@localPlaylists.db", databaseFolderPath, urlStringMd5] error:NULL];
	localPlaylistsDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@localPlaylists.db", databaseFolderPath, urlStringMd5]] retain];
	if ([localPlaylistsDb open] == NO) { DLog(@"Could not open localPlaylistsDb."); }
	if ([localPlaylistsDb tableExists:@"localPlaylists"] == NO) {
		[localPlaylistsDb synchronizedExecuteUpdate:@"CREATE TABLE localPlaylists (playlist TEXT, md5 TEXT)"];
	}
}

- (void)resetCurrentPlaylistDb
{
	NSString *urlStringMd5 = [[[SavedSettings sharedInstance] urlString] md5];
	
	[currentPlaylistDb close]; self.currentPlaylistDb = nil;
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseFolderPath, urlStringMd5] error:NULL];
	currentPlaylistDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseFolderPath, urlStringMd5]] retain];
	if ([currentPlaylistDb open] == NO) { DLog(@"Could not open currentPlaylistDb."); }
	[currentPlaylistDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentPlaylist (%@)", [Song standardSongColumnSchema]]];
	[currentPlaylistDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shufflePlaylist (%@)", [Song standardSongColumnSchema]]];	
	[currentPlaylistDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", [Song standardSongColumnSchema]]];	
	[currentPlaylistDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", [Song standardSongColumnSchema]]];	

	//if ([SavedSettings sharedInstance].isJukeboxEnabled)
	//	[musicControls jukeboxClearPlaylist];
}

- (void)resetCurrentPlaylist
{
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		[currentPlaylistDb synchronizedExecuteUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
		[currentPlaylistDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", [Song standardSongColumnSchema]]];	
	}
	else
	{	
		[currentPlaylistDb synchronizedExecuteUpdate:@"DROP TABLE currentPlaylist"];
		[currentPlaylistDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentPlaylist (%@)", [Song standardSongColumnSchema]]];	
	}
}

- (void)resetShufflePlaylist
{
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		[currentPlaylistDb synchronizedExecuteUpdate:@"DROP TABLE jukeboxShufflePlaylist"];
		[currentPlaylistDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", [Song standardSongColumnSchema]]];	
	}
	else
	{	
		[currentPlaylistDb synchronizedExecuteUpdate:@"DROP TABLE shufflePlaylist"];
		[currentPlaylistDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shufflePlaylist (%@)", [Song standardSongColumnSchema]]];	
	}
}

- (void)resetJukeboxPlaylist
{
	[currentPlaylistDb synchronizedExecuteUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
	[currentPlaylistDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", [Song standardSongColumnSchema]]];	

	[currentPlaylistDb synchronizedExecuteUpdate:@"DROP TABLE jukeboxShufflePlaylist"];
	[currentPlaylistDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", [Song standardSongColumnSchema]]];	
}

- (void)createServerPlaylistTable:(NSString *)md5
{
	[localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE splaylist%@ (%@)", md5, [Song standardSongColumnSchema]]];
}

- (void)removeServerPlaylistTable:(NSString *)md5
{
	[localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"DROP TABLE splaylist%@", md5]];
}

- (Album *)albumFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabase:(FMDatabase *)db
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

- (NSUInteger)serverPlaylistCount:(NSString *)md5
{
	NSString *query = [NSString stringWithFormat:@"SELECT count(*) FROM splaylist%@", md5];
	return [localPlaylistsDb intForQuery:query];
}

- (BOOL)insertAlbumIntoFolderCache:(Album *)anAlbum forId:(NSString *)folderId
{
	[albumListCacheDb synchronizedExecuteUpdate:@"INSERT INTO albumsCache (folderId, title, albumId, coverArtId, artistName, artistId) VALUES (?, ?, ?, ?, ?, ?)", [folderId md5], anAlbum.title, anAlbum.albumId, anAlbum.coverArtId, anAlbum.artistName, anAlbum.artistId];
	
	if ([albumListCacheDb hadError]) {
		DLog(@"Err %d: %@", [albumListCacheDb lastErrorCode], [albumListCacheDb lastErrorMessage]);
	}
	
	return ![albumListCacheDb hadError];
}

- (BOOL)insertAlbum:(Album *)anAlbum intoTable:(NSString *)table inDatabase:(FMDatabase *)db
{
	[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (title, albumId, coverArtId, artistName, artistId) VALUES (?, ?, ?, ?, ?)", table], anAlbum.title, anAlbum.albumId, anAlbum.coverArtId, anAlbum.artistName, anAlbum.artistId];
	
	if ([db hadError]) {
		DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
	
	return ![db hadError];
}

- (NSArray *)sectionInfoFromTable:(NSString *)table inDatabase:(FMDatabase *)database withColumn:(NSString *)column
{
	DLog(@"albumIndex count: %i", [database intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM %@", table]]);
	
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
	// Show loading screen
	//[viewObjects showLoadingScreenOnMainWindow];
	[viewObjects showAlbumLoadingScreen:appDelegate.window sender:queueAll];
	
	// Download all the songs
	if (queueAll == nil)
		queueAll = [[SUSQueueAllLoader alloc] init];
	//[queueAll loadData:folderId artist:theArtist isQueue:NO];
	[queueAll cacheData:folderId artist:theArtist];
}

- (void)queueAllSongs:(NSString *)folderId artist:(Artist *)theArtist
{
	// Show loading screen
	//[viewObjects showLoadingScreenOnMainWindow];
	[viewObjects showAlbumLoadingScreen:appDelegate.window sender:queueAll];
	
	// Queue all the songs
	if (queueAll == nil)
		queueAll = [[SUSQueueAllLoader alloc] init];
	//[queueAll loadData:folderId artist:theArtist isQueue:YES];
	[queueAll queueData:folderId artist:theArtist];
}

- (void)queueSong:(Song *)aSong
{
	SavedSettings *settings = [SavedSettings sharedInstance];
	PlaylistSingleton *currentPlaylist = [PlaylistSingleton sharedInstance];
	if (settings.isJukeboxEnabled)
	{
		[aSong insertIntoTable:@"jukeboxCurrentPlaylist" inDatabase:self.currentPlaylistDb];
		[musicControls jukeboxAddSong:aSong.songId];
	}
	else
	{
		[aSong insertIntoTable:@"currentPlaylist" inDatabase:self.currentPlaylistDb];
		if (currentPlaylist.isShuffle)
			[aSong insertIntoTable:@"shufflePlaylist" inDatabase:self.currentPlaylistDb];
	}
	
	[[SUSStreamSingleton sharedInstance] fillStreamQueue];
}

- (void)showLoadingScreen
{
	[viewObjects showLoadingScreenOnMainWindow];
}

- (void)playAllSongs:(NSString *)folderId artist:(Artist *)theArtist
{	
	PlaylistSingleton *currentPlaylist = [PlaylistSingleton sharedInstance];
	
	// Show loading screen
	//[viewObjects showLoadingScreenOnMainWindow];
	[viewObjects showAlbumLoadingScreen:appDelegate.window sender:queueAll];
	
	// Clear the current and shuffle playlists
	[self resetCurrentPlaylistDb];
	
	// Set shuffle off in case it's on
	currentPlaylist.isShuffle = NO;
	
	// Queue all the songs
	if (queueAll == nil)
		queueAll = [[SUSQueueAllLoader alloc] init];
	//[queueAll loadData:folderId artist:theArtist isQueue:YES];
	[queueAll playAllData:folderId artist:theArtist];
}

- (void)shuffleAllSongs:(NSString *)folderId artist:(Artist *)theArtist
{
	PlaylistSingleton *currentPlaylist = [PlaylistSingleton sharedInstance];
	
	// Show loading screen
	//[viewObjects showLoadingScreenOnMainWindow];
	[viewObjects showAlbumLoadingScreen:appDelegate.window sender:queueAll];
	
	// Clear the current and shuffle playlists
	[self resetCurrentPlaylistDb];

	// Set shuffle on
	currentPlaylist.isShuffle = YES;
	
	// Queue all the songs
	if (queueAll == nil)
		queueAll = [[SUSQueueAllLoader alloc] init];
	//[queueAll loadData:folderId artist:theArtist isQueue:YES];
	[queueAll shuffleData:folderId artist:theArtist];
}

- (void)shufflePlaylist
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	PlaylistSingleton *currentPlaylist = [PlaylistSingleton sharedInstance];
	
	currentPlaylist.currentIndex = 0;
	currentPlaylist.isShuffle = YES;
	
	[self resetShufflePlaylist];
	
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
		[self.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO jukeboxShufflePlaylist SELECT * FROM jukeboxCurrentPlaylist ORDER BY RANDOM()"];
	else
		[self.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO shufflePlaylist SELECT * FROM currentPlaylist ORDER BY RANDOM()"];
		
	[[NSNotificationCenter defaultCenter] postNotificationName:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	
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
