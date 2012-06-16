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
#import "FMDatabaseQueueAdditions.h"
#import "NSString+md5.h"
#import "Artist.h"
#import "Album.h"
#import "Song.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "UIDevice+Hardware.h"
#import "ISMSQueueAllLoader.h"
#import "SavedSettings.h"
#import "GTMNSString+HTML.h"
#import "PlaylistSingleton.h"
#import "ISMSStreamManager.h"
#import "NSNotificationCenter+MainThread.h"
#import "JukeboxSingleton.h"
#import "AudioEngine.h"

@implementation DatabaseSingleton

@synthesize databaseFolderPath, queueAll;
@synthesize allAlbumsDbQueue, allSongsDbQueue, coverArtCacheDb540Queue, coverArtCacheDb320Queue, coverArtCacheDb60Queue, albumListCacheDbQueue, genresDbQueue, currentPlaylistDbQueue, localPlaylistsDbQueue, songCacheDbQueue, cacheQueueDbQueue, lyricsDbQueue, bookmarksDbQueue;

#pragma mark -
#pragma mark class instance methods

- (void)setupAllSongsDb
{
	NSString *urlStringMd5 = [[settingsS urlString] md5];
	
	// Setup the allAlbums database
	NSString *path = [NSString stringWithFormat:@"%@/%@allAlbums.db", databaseFolderPath, urlStringMd5];
	self.allAlbumsDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.allAlbumsDbQueue inDatabase:^(FMDatabase *db) 
	{
		[db  executeUpdate:@"PRAGMA cache_size = 1"];
	}];
	
	// Setup the allSongs database
	path = [NSString stringWithFormat:@"%@/%@allSongs.db", databaseFolderPath, urlStringMd5];
	self.allSongsDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.allSongsDbQueue inDatabase:^(FMDatabase *db) 
	{
		[db  executeUpdate:@"PRAGMA cache_size = 1"];
	}];
	
	// Setup the Genres database
	path = [NSString stringWithFormat:@"%@/%@genres.db", databaseFolderPath, urlStringMd5];
	self.genresDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.genresDbQueue inDatabase:^(FMDatabase *db) 
	{
		[db  executeUpdate:@"PRAGMA cache_size = 1"];
	}];
}

- (void)setupDatabases
{
	NSString *urlStringMd5 = [[settingsS urlString] md5];
		
	// Only load Albums, Songs, and Genre databases if this is a newer device
	if (settingsS.isSongsTabEnabled)
	{
		[self setupAllSongsDb];
	}
	
	// Setup the album list cache database
	NSString *path = [NSString stringWithFormat:@"%@/%@albumListCache.db", databaseFolderPath, urlStringMd5];
	self.albumListCacheDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.albumListCacheDbQueue inDatabase:^(FMDatabase *db) 
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"albumListCache"]) 
		{
			[db executeUpdate:@"CREATE TABLE albumListCache (id TEXT PRIMARY KEY, data BLOB)"];
		}
		if (![db tableExists:@"albumsCache"]) 
		{
			[db executeUpdate:@"CREATE TABLE albumsCache (folderId TEXT, title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
			[db executeUpdate:@"CREATE INDEX albumsFolderId ON albumsCache (folderId)"];
		}
		if (![db tableExists:@"songsCache"]) 
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE songsCache (folderId TEXT, %@)", [Song standardSongColumnSchema]]];
			[db executeUpdate:@"CREATE INDEX songsFolderId ON songsCache (folderId)"];
		}
        if (![db tableExists:@"albumsCacheCount"])
        {
            [db executeUpdate:@"CREATE TABLE albumsCacheCount (folderId TEXT, count INTEGER)"];
            [db executeUpdate:@"CREATE INDEX albumsCacheCountFolderId ON albumsCacheCount (folderId)"];
        }
        if (![db tableExists:@"songsCacheCount"])
        {
            [db executeUpdate:@"CREATE TABLE songsCacheCount (folderId TEXT, count INTEGER)"];
            [db executeUpdate:@"CREATE INDEX songsCacheCountFolderId ON songsCacheCount (folderId)"];
        }
        if (![db tableExists:@"folderLength"])
        {
            [db executeUpdate:@"CREATE TABLE folderLength (folderId TEXT, length INTEGER)"];
            [db executeUpdate:@"CREATE INDEX folderLengthFolderId ON folderLength (folderId)"];
        }
	}];
	
	// Setup music player cover art cache database
	if (IS_IPAD())
	{
		// Only load large album art DB if this is an iPad
		path = [NSString stringWithFormat:@"%@/coverArtCache540.db", databaseFolderPath];
		self.coverArtCacheDb540Queue = [FMDatabaseQueue databaseQueueWithPath:path];
		[self.coverArtCacheDb540Queue inDatabase:^(FMDatabase *db) 
		{
			[db executeUpdate:@"PRAGMA cache_size = 1"];
			
			if (![db tableExists:@"coverArtCache"]) 
			{
				[db executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
			}
		}];
	}
	else
	{
		// Only load small album art DB if this is not an iPad
		path = [NSString stringWithFormat:@"%@/coverArtCache320.db", databaseFolderPath];
		self.coverArtCacheDb320Queue = [FMDatabaseQueue databaseQueueWithPath:path];
		[self.coverArtCacheDb320Queue inDatabase:^(FMDatabase *db) 
		{
			[db executeUpdate:@"PRAGMA cache_size = 1"];
			
			if (![db tableExists:@"coverArtCache"]) 
			{
				[db executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
			}
		}];
	}
	
	// Setup album cell cover art cache database
	path = [NSString stringWithFormat:@"%@/coverArtCache60.db", databaseFolderPath];
	self.coverArtCacheDb60Queue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.coverArtCacheDb60Queue inDatabase:^(FMDatabase *db) 
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"coverArtCache"])
		{
			[db executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
		}
	}];
	
	// Setup the current playlist database
	if (viewObjectsS.isOfflineMode) 
	{
		path = [NSString stringWithFormat:@"%@/offlineCurrentPlaylist.db", databaseFolderPath];
	}
	else 
	{
		path = [NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseFolderPath, urlStringMd5];		
	}
	
	self.currentPlaylistDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db) 
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"currentPlaylist"]) 
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentPlaylist (%@)", [Song standardSongColumnSchema]]];
		}
		if (![db tableExists:@"shufflePlaylist"]) 
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shufflePlaylist (%@)", [Song standardSongColumnSchema]]];
		}
		if (![db tableExists:@"jukeboxCurrentPlaylist"])
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", [Song standardSongColumnSchema]]];
		}
		if (![db tableExists:@"jukeboxShufflePlaylist"]) 
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", [Song standardSongColumnSchema]]];
		}
	}];	
	
	// Setup the local playlists database
	if (viewObjectsS.isOfflineMode) 
	{
		path = [NSString stringWithFormat:@"%@/offlineLocalPlaylists.db", databaseFolderPath];
	}
	else 
	{
		path = [NSString stringWithFormat:@"%@/%@localPlaylists.db", databaseFolderPath, urlStringMd5];
	}
	
	self.localPlaylistsDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"localPlaylists"]) 
		{
			[db executeUpdate:@"CREATE TABLE localPlaylists (playlist TEXT, md5 TEXT)"];
		}
	}];
	
	// Setup the song cache database
	// Check if the songCache DB is in the documents directory
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:[databaseFolderPath stringByAppendingPathComponent:@"songCache.db"]]) 
	{
		// The song cache Db is in the old place and needs to be moved
		[fileManager moveItemAtURL:[NSURL fileURLWithPath:[databaseFolderPath stringByAppendingPathComponent:@"songCache.db"]]
							 toURL:[NSURL fileURLWithPath:[ settingsS.cachesPath stringByAppendingPathComponent:@"songCache.db"]] error:nil];
	}
	
	path = [settingsS.cachesPath stringByAppendingPathComponent:@"songCache.db"];
	self.songCacheDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.songCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"cachedSongs"])
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE cachedSongs (md5 TEXT UNIQUE, finished TEXT, cachedDate INTEGER, playedDate INTEGER, %@)", [Song standardSongColumnSchema]]];
			[db executeUpdate:@"CREATE INDEX cachedDate ON cachedSongs (cachedDate DESC)"];
			[db executeUpdate:@"CREATE INDEX playedDate ON cachedSongs (playedDate DESC)"];
		}
		[db executeUpdate:@"CREATE INDEX md5 IF NOT EXISTS ON cachedSongs (md5)"];
		if (![db tableExists:@"cachedSongsLayout"]) 
		{
			[db executeUpdate:@"CREATE TABLE cachedSongsLayout (md5 TEXT UNIQUE, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
			[db executeUpdate:@"CREATE INDEX genreLayout ON cachedSongsLayout (genre)"];
			[db executeUpdate:@"CREATE INDEX seg1 ON cachedSongsLayout (seg1)"];
			[db executeUpdate:@"CREATE INDEX seg2 ON cachedSongsLayout (seg2)"];
			[db executeUpdate:@"CREATE INDEX seg3 ON cachedSongsLayout (seg3)"];
			[db executeUpdate:@"CREATE INDEX seg4 ON cachedSongsLayout (seg4)"];
			[db executeUpdate:@"CREATE INDEX seg5 ON cachedSongsLayout (seg5)"];
			[db executeUpdate:@"CREATE INDEX seg6 ON cachedSongsLayout (seg6)"];
			[db executeUpdate:@"CREATE INDEX seg7 ON cachedSongsLayout (seg7)"];
			[db executeUpdate:@"CREATE INDEX seg8 ON cachedSongsLayout (seg8)"];
			[db executeUpdate:@"CREATE INDEX seg9 ON cachedSongsLayout (seg9)"];
		}
		if (![db tableExists:@"genres"]) 
		{
			[db executeUpdate:@"CREATE TABLE genres(genre TEXT UNIQUE)"];
		}
		if (![db tableExists:@"genresSongs"]) 
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE genresSongs (md5 TEXT UNIQUE, %@)", [Song standardSongColumnSchema]]];
			[db executeUpdate:@"CREATE INDEX songGenre ON genresSongs (genre)"];
		}
	}];
	
	if ([fileManager fileExistsAtPath:[NSString stringWithFormat:@"%@/%@cacheQueue.db", databaseFolderPath, [ settingsS.urlString md5]]]) 
	{
		// The song cache queue Db is in the old place and needs to be moved
		[fileManager moveItemAtURL:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@cacheQueue.db", databaseFolderPath, [ settingsS.urlString md5]]] 
							 toURL:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@cacheQueue.db", settingsS.cachesPath, [ settingsS.urlString md5]]] error:nil];
	}
	
	path = [NSString stringWithFormat:@"%@/%@cacheQueue.db", settingsS.cachesPath, [settingsS.urlString md5]];
	self.cacheQueueDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.cacheQueueDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"cacheQueue"]) 
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE cacheQueue (md5 TEXT UNIQUE, finished TEXT, cachedDate INTEGER, playedDate INTEGER, %@)", [Song standardSongColumnSchema]]];
			//[cacheQueueDb executeUpdate:@"CREATE INDEX queueDate ON cacheQueue (cachedDate DESC)"];
		}
	}];
		
	// Setup the lyrics database
	path = [NSString stringWithFormat:@"%@/lyrics.db", databaseFolderPath];
	self.lyricsDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.lyricsDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"lyrics"])
		{
			[db executeUpdate:@"CREATE TABLE lyrics (artist TEXT, title TEXT, lyrics TEXT)"];
			[db executeUpdate:@"CREATE INDEX artistTitle ON lyrics (artist, title)"];
		}
	}];
	
	// Setup the bookmarks database
	if (viewObjectsS.isOfflineMode) 
	{
		path = [NSString stringWithFormat:@"%@/bookmarks.db", databaseFolderPath];
	}
	else
	{
		path = [NSString stringWithFormat:@"%@/%@bookmarks.db", databaseFolderPath, urlStringMd5];
	}
	
	self.bookmarksDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.bookmarksDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"bookmarks"]) 
		{
			//[bookmarksDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarks (name TEXT, position INTEGER, %@, bytes INTEGER)", [Song standardSongColumnSchema]]];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarks (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, %@, bytes INTEGER)", [Song standardSongColumnSchema]]];
			[db executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
		}
	}];
	
	[self updateTableDefinitions];
}

- (void)updateTableDefinitions
{
	// Add parentId column to tables if necessary
	NSArray *parentIdDatabaseQueues = [NSArray arrayWithObjects:albumListCacheDbQueue, currentPlaylistDbQueue, currentPlaylistDbQueue, currentPlaylistDbQueue, currentPlaylistDbQueue, songCacheDbQueue, songCacheDbQueue, cacheQueueDbQueue, songCacheDbQueue, cacheQueueDbQueue, nil];
	NSArray *parentIdTables = [NSArray arrayWithObjects:@"songsCache", @"currentPlaylist", @"shufflePlaylist", @"jukeboxCurrentPlaylist", @"jukeboxShufflePlaylist", @"cachedSongs", @"genresSongs", @"cacheQueue", @"cachedSongsList", @"queuedSongsList", nil];
	NSString *columnName = @"parentId";
	for (int i = 0; i < [parentIdDatabaseQueues count]; i++)
	{
		FMDatabaseQueue *dbQueue = [parentIdDatabaseQueues objectAtIndexSafe:i];
		NSString *table = [parentIdTables objectAtIndexSafe:i];
		
		[dbQueue inDatabase:^(FMDatabase *db)
		{
			if (![db columnExists:table columnName:columnName])
			{
				NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ TEXT", table, columnName];
				[db executeUpdate:query];
			}
		}];
	}
	
	// Add parentId to all playlist and splaylist tables
	[self.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
	{
		NSMutableArray *playlistTableNames = [NSMutableArray arrayWithCapacity:0];
		NSString *query = @"SELECT name FROM sqlite_master WHERE type = 'table'";
		FMResultSet *result = [db executeQuery:query];
		while ([result next])
		{
			@autoreleasepool 
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
		}
		[result close];
		
		for (NSString *table in playlistTableNames)
		{
			if (![db columnExists:table columnName:columnName])
			{
				NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ TEXT", table, columnName];
				[db executeUpdate:query];
			}
		}
	}];
	
	// Update the bookmarks table to new format
	[self.bookmarksDbQueue inDatabase:^(FMDatabase *db)
	{
		if (![db columnExists:@"bookmarks" columnName:@"bookmarkId"])
		{
			// Create the new table
			[db executeUpdate:@"DROP TABLE IF EXISTS bookmarksTemp"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarksTemp (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, %@, bytes INTEGER)", [Song standardSongColumnSchema]]];
			
			// Move the records
			[db executeUpdate:@"INSERT INTO bookmarksTemp (playlistIndex, name, position, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) SELECT 0, name, position, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size FROM bookmarks"];
			
			// Swap the tables
			[db executeUpdate:@"DROP TABLE IF EXISTS bookmarks"];
			[db executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];	
			[db executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
		}
	}];
	
	[self.songCacheDbQueue inDatabase:^(FMDatabase *db)
	 {
		 if (![db tableExists:@"genresTableFixed"])
		 {
			 [db executeUpdate:@"DROP TABLE IF EXISTS genresTemp"];
			 [db executeUpdate:@"CREATE TABLE genresTemp (genre TEXT)"];
			 [db executeUpdate:@"INSERT INTO genresTemp SELECT * FROM genres"];
			 [db executeUpdate:@"DROP TABLE genres"];
			 [db executeUpdate:@"ALTER TABLE genresTemp RENAME TO genres"];
			 [db executeUpdate:@"CREATE UNIQUE INDEX genreNames ON genres (genre)"];
			 [db executeUpdate:@"CREATE TABLE genresTableFixed (a INTEGER)"];
		 }
	 }];
}

- (void)closeAllDatabases
{
	[allAlbumsDbQueue close]; self.allAlbumsDbQueue = nil;
	[allSongsDbQueue close]; self.allSongsDbQueue = nil;
	[genresDbQueue close]; self.genresDbQueue = nil;
	[albumListCacheDbQueue close]; self.albumListCacheDbQueue = nil;
	[coverArtCacheDb540Queue close]; self.coverArtCacheDb540Queue = nil;
	[coverArtCacheDb320Queue close]; self.coverArtCacheDb320Queue = nil;
	[coverArtCacheDb60Queue close]; self.coverArtCacheDb60Queue = nil;
	[currentPlaylistDbQueue close]; self.currentPlaylistDbQueue = nil;
	[localPlaylistsDbQueue close]; self.localPlaylistsDbQueue = nil;
	[songCacheDbQueue close]; self.songCacheDbQueue = nil;
	[cacheQueueDbQueue close]; self.cacheQueueDbQueue = nil;
	[bookmarksDbQueue close]; self.bookmarksDbQueue = nil;	
}

- (void)resetCoverArtCache
{	
	// Clear the table cell cover art	
	[self.coverArtCacheDb60Queue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"DROP TABLE IF EXISTS coverArtCache"];
		[db executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
	}];
	
	
	// Clear the player cover art
	FMDatabaseQueue *dbQueue = IS_IPAD() ? self.coverArtCacheDb540Queue : self.coverArtCacheDb320Queue;
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"DROP TABLE IF EXISTS coverArtCache"];
		[db executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
	}];
}

- (void)resetFolderCache
{	
	[self.albumListCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		// Drop the tables
		[db executeUpdate:@"DROP TABLE albumListCache"];
		[db executeUpdate:@"DROP TABLE albumsCache"];
		[db executeUpdate:@"DROP TABLE albumsCacheCount"];
		[db executeUpdate:@"DROP TABLE songsCacheCount"];
		[db executeUpdate:@"DROP TABLE folderLength"];
		
		// Create the tables and indexes
		[db executeUpdate:@"CREATE TABLE albumListCache (id TEXT PRIMARY KEY, data BLOB)"];
		[db executeUpdate:@"CREATE TABLE albumsCache (folderId TEXT, title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
		[db executeUpdate:@"CREATE INDEX albumsFolderId ON albumsCache (folderId)"];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE songsCache (folderId TEXT, %@)", [Song standardSongColumnSchema]]];
		[db executeUpdate:@"CREATE INDEX songsFolderId ON songsCache (folderId)"];
		[db executeUpdate:@"CREATE TABLE albumsCacheCount (folderId TEXT, count INTEGER)"];
		[db executeUpdate:@"CREATE INDEX albumsCacheCountFolderId ON albumsCacheCount (folderId)"];
		[db executeUpdate:@"CREATE TABLE songsCacheCount (folderId TEXT, count INTEGER)"];
		[db executeUpdate:@"CREATE INDEX songsCacheCountFolderId ON songsCacheCount (folderId)"];
		[db executeUpdate:@"CREATE TABLE folderLength (folderId TEXT, length INTEGER)"];
		[db executeUpdate:@"CREATE INDEX folderLengthFolderId ON folderLength (folderId)"];
	}];
}

- (void)resetLocalPlaylistsDb
{
	[self.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
	{
		// Get the table names
		NSMutableArray *playlistTableNames = [NSMutableArray arrayWithCapacity:0];
		NSString *query = @"SELECT name FROM sqlite_master WHERE type = 'table'";
		FMResultSet *result = [db executeQuery:query];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSString *tableName = [result stringForColumnIndex:0];
				[playlistTableNames addObject:tableName];
			}
		}
		[result close];
		
		// Drop the tables
		for (NSString *table in playlistTableNames)
		{
			NSString *query = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", table];
			[db executeUpdate:query];
		} 
		
		// Create the localPlaylists table
		[db executeUpdate:@"CREATE TABLE localPlaylists (playlist TEXT, md5 TEXT)"];
	}];
}

- (void)resetCurrentPlaylistDb
{
	[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
	{
		// Drop the tables
		[db executeUpdate:@"DROP TABLE IF EXISTS currentPlaylist"];
		[db executeUpdate:@"DROP TABLE IF EXISTS shufflePlaylist"];
		[db executeUpdate:@"DROP TABLE IF EXISTS jukeboxCurrentPlaylist"];
		[db executeUpdate:@"DROP TABLE IF EXISTS jukeboxShufflePlaylist"];
		
		// Create the tables
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentPlaylist (%@)", [Song standardSongColumnSchema]]];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shufflePlaylist (%@)", [Song standardSongColumnSchema]]];	
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", [Song standardSongColumnSchema]]];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", [Song standardSongColumnSchema]]];
	}];	
}

- (void)resetCurrentPlaylist
{
	[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
	{
		if (settingsS.isJukeboxEnabled)
		{
			[db executeUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", [Song standardSongColumnSchema]]];	
		}
		else
		{	
			[db executeUpdate:@"DROP TABLE currentPlaylist"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentPlaylist (%@)", [Song standardSongColumnSchema]]];	
		}
	}];
}

- (void)resetShufflePlaylist
{
	[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
	{
		if (settingsS.isJukeboxEnabled)
		{
			[db executeUpdate:@"DROP TABLE jukeboxShufflePlaylist"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", [Song standardSongColumnSchema]]];	
		}
		else
		{	
			[db executeUpdate:@"DROP TABLE shufflePlaylist"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shufflePlaylist (%@)", [Song standardSongColumnSchema]]];	
		}
	}];
}

- (void)resetJukeboxPlaylist
{
	[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", [Song standardSongColumnSchema]]];
		
		[db executeUpdate:@"DROP TABLE jukeboxShufflePlaylist"];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", [Song standardSongColumnSchema]]];	
	}];
}

- (void)createServerPlaylistTable:(NSString *)md5
{
	[self.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE splaylist%@ (%@)", md5, [Song standardSongColumnSchema]]];
	}];	
}

- (void)removeServerPlaylistTable:(NSString *)md5
{
	[self.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE splaylist%@", md5]];
	}];
}

- (Album *)albumFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue
{
	__block Album *anAlbum = nil;
	
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		anAlbum = [self albumFromDbRow:row inTable:table inDatabase:db];
	}];
	
	return anAlbum;
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
	
	return anAlbum;
}

- (NSUInteger)serverPlaylistCount:(NSString *)md5
{
	NSString *query = [NSString stringWithFormat:@"SELECT count(*) FROM splaylist%@", md5];
	return [self.localPlaylistsDbQueue intForQuery:query];
}

- (BOOL)insertAlbumIntoFolderCache:(Album *)anAlbum forId:(NSString *)folderId
{
	__block BOOL hadError;
	
	[self.albumListCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"INSERT INTO albumsCache (folderId, title, albumId, coverArtId, artistName, artistId) VALUES (?, ?, ?, ?, ?, ?)", [folderId md5], anAlbum.title, anAlbum.albumId, anAlbum.coverArtId, anAlbum.artistName, anAlbum.artistId];
		
		hadError = [db hadError];
		
		if (hadError)
			DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
	
	return !hadError;
}

- (BOOL)insertAlbum:(Album *)anAlbum intoTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue
{
	__block BOOL success;
	
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		success = [self insertAlbum:anAlbum intoTable:table inDatabase:db];
	}];
	
	return success;
}

- (BOOL)insertAlbum:(Album *)anAlbum intoTable:(NSString *)table inDatabase:(FMDatabase *)db
{
	[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (title, albumId, coverArtId, artistName, artistId) VALUES (?, ?, ?, ?, ?)", table], anAlbum.title, anAlbum.albumId, anAlbum.coverArtId, anAlbum.artistName, anAlbum.artistId];
	
	if ([db hadError]) {
		DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
	
	return ![db hadError];
}

- (NSArray *)sectionInfoFromTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue withColumn:(NSString *)column
{
	__block NSArray *sectionInfo;
	
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		sectionInfo = [self sectionInfoFromTable:table inDatabase:db withColumn:column];
	}];
	
	return sectionInfo;
}

- (NSArray *)sectionInfoFromTable:(NSString *)table inDatabase:(FMDatabase *)database withColumn:(NSString *)column
{	
	NSArray *sectionTitles = [[NSArray alloc] initWithObjects:@"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H", @"I", @"J", @"K", @"L", @"M", @"N", @"O", @"P", @"Q", @"R", @"S", @"T", @"U", @"V", @"W", @"X", @"Y", @"Z", nil];
	NSMutableArray *sections = [[NSMutableArray alloc] init];
	
	int i = 0;
	for (NSString *title in sectionTitles)
	{
		NSString *row;
		row = [database stringForQuery:[NSString stringWithFormat:@"SELECT ROWID FROM %@ WHERE %@ LIKE '%@%%' LIMIT 1", table, column, [sectionTitles objectAtIndexSafe:i]]];
		if (row != nil)
		{
			[sections addObject:[NSArray arrayWithObjects:[sectionTitles objectAtIndexSafe:i], [NSNumber numberWithInt:([row intValue] - 1)], nil]];
		}
		
		i++;
	}
	
	if ([sections count] > 0)
	{
		if ([[[sections objectAtIndexSafe:0] objectAtIndexSafe:1] intValue] > 0)
		{
			[sections insertObject:[NSArray arrayWithObjects:@"#", [NSNumber numberWithInt:0], nil] atIndex:0];
		}
	}
	else
	{
		// Looks like there are only number rows, make sure the table is not empty
		NSString *row = [database stringForQuery:[NSString stringWithFormat:@"SELECT ROWID FROM %@ LIMIT 1", table]];
		if (row)
		{
			[sections insertObject:[NSArray arrayWithObjects:@"#", [NSNumber numberWithInt:0], nil] atIndex:0];
		}
	}
	
	NSArray *returnArray = [NSArray arrayWithArray:sections];
	
	return returnArray;
}


- (void)downloadAllSongs:(NSString *)folderId artist:(Artist *)theArtist
{
	// Show loading screen
	[viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:queueAll];
	
	// Download all the songs
	[queueAll cacheData:folderId artist:theArtist];
}

- (void)queueAllSongs:(NSString *)folderId artist:(Artist *)theArtist
{
	// Show loading screen
	[viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:queueAll];
	
	// Queue all the songs
	[queueAll queueData:folderId artist:theArtist];
}

/*- (void)queueSong:(Song *)aSong
{
	if (settingsS.isJukeboxEnabled)
	{
		[aSong insertIntoTable:@"jukeboxCurrentPlaylist" inDatabaseQueue:self.currentPlaylistDbQueue];
		[jukeboxS jukeboxAddSong:aSong.songId];
	}
	else
	{
		[aSong insertIntoTable:@"currentPlaylist" inDatabaseQueue:self.currentPlaylistDbQueue];
		if (playlistS.isShuffle)
			[aSong insertIntoTable:@"shufflePlaylist" inDatabaseQueue:self.currentPlaylistDbQueue];
	}
	
	[streamManagerS fillStreamQueue:audioEngineS.isStarted];
}*/

- (void)playAllSongs:(NSString *)folderId artist:(Artist *)theArtist
{
	// Show loading screen
	[viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:queueAll];
	
	// Clear the current and shuffle playlists
	if (settingsS.isJukeboxEnabled)
	{
		[databaseS resetJukeboxPlaylist];
		[jukeboxS jukeboxClearRemotePlaylist];
	}
	else
	{
		[databaseS resetCurrentPlaylistDb];
	}
	
	// Set shuffle off in case it's on
	playlistS.isShuffle = NO;
	
	// Queue all the songs
	[queueAll playAllData:folderId artist:theArtist];
}

- (void)shuffleAllSongs:(NSString *)folderId artist:(Artist *)theArtist
{
	// Show loading screen
	[viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:queueAll];
	
	// Clear the current and shuffle playlists
	if (settingsS.isJukeboxEnabled)
	{
		[databaseS resetJukeboxPlaylist];
		[jukeboxS jukeboxClearRemotePlaylist];
	}
	else
	{
		[databaseS resetCurrentPlaylistDb];
	}

	// Set shuffle on
	playlistS.isShuffle = YES;
	
	// Queue all the songs
	[queueAll shuffleData:folderId artist:theArtist];
}

- (void)shufflePlaylist
{
	@autoreleasepool 
	{
		playlistS.currentIndex = 0;
		playlistS.isShuffle = YES;
		
		[self resetShufflePlaylist];
		
		[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
		{
			if (settingsS.isJukeboxEnabled)
				[db executeUpdate:@"INSERT INTO jukeboxShufflePlaylist SELECT * FROM jukeboxCurrentPlaylist ORDER BY RANDOM()"];
			else
				[db executeUpdate:@"INSERT INTO shufflePlaylist SELECT * FROM currentPlaylist ORDER BY RANDOM()"];
		}];
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistShuffleToggled];
	}
}

// New Model Stuff


#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
	DLog(@"received memory warning");
	
	
}

#pragma mark - Singleton methods

- (void)setup 
{
	queueAll = [ISMSQueueAllLoader loader];
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	databaseFolderPath = [[paths objectAtIndexSafe: 0] stringByAppendingPathComponent:@"database"];
	
	// Make sure database directory exists, if not create them
	BOOL isDir = YES;
	if (![[NSFileManager defaultManager] fileExistsAtPath:databaseFolderPath isDirectory:&isDir]) 
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:databaseFolderPath withIntermediateDirectories:YES attributes:nil error:NULL];
	}	
	
	[self setupDatabases];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(didReceiveMemoryWarning) 
												 name:UIApplicationDidReceiveMemoryWarningNotification 
											   object:nil];
}

+ (id)sharedInstance
{
    static DatabaseSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
