//
//  DatabaseSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "DatabaseSingleton.h"
#import "iSub-Swift.h"
#import "ISMSStreamManager.h"

@implementation DatabaseSingleton

#pragma mark -
#pragma mark class instance methods

- (void)databasePool:(FMDatabasePool*)pool didAddDatabase:(FMDatabase*)database
{
    [database executeStatements:@"PRAGMA journal_mode=WAL"];
}

- (void)setupDatabases
{
    // Setup the new data model (WAL enabled)
    NSString *path = [self.databaseFolderPath stringByAppendingPathComponent:@"newSongModel.db"];
    NSLog(@"new model db: %@", path);
    self.songModelReadDbPool = [FMDatabasePool databasePoolWithPath:path];
    self.songModelReadDbPool.maximumNumberOfDatabasesToCreate = 20;
    self.songModelReadDbPool.delegate = self;
    self.songModelWritesDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
    [self.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
    {
        [db executeStatements:@"PRAGMA journal_mode=WAL"];
        
        if (![db tableExists:@"cachedSongsMetadata"])
        {
            [db executeUpdate:@"CREATE TABLE cachedSongsMetadata (songId INTEGER, serverId INTEGER, partiallyCached INTEGER, fullyCached INTEGER, pinned INTEGER, PRIMARY KEY (songId, serverId))"];
        }
        
        if (![db tableExists:@"contentTypes"])
        {
            [db executeUpdate:@"CREATE TABLE contentTypes (contentTypeId INTEGER PRIMARY KEY, mimeType TEXT, extension TEXT, basicType TEXT)"];
            [db executeUpdate:@"CREATE INDEX contentTypes_mimeTypeExtension ON contentTypes (mimeType, extension)"];
            
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/mpeg", @"mp3", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/ogg", @"ogg", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/ogg", @"oga", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/ogg", @"opus", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/ogg", @"ogx", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/mp4", @"aac", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/mp4", @"m4a", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/flac", @"flac", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/x-wav", @"wav", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/x-ms-wma", @"wma", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/x-monkeys-audio", @"ape", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/x-musepack", @"mpc", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/x-shn", @"shn", @1];
            
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/x-flv", @"flv", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/avi", @"avi", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/mpeg", @"mpg", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/mpeg", @"mpeg", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/mp4", @"mp4", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/x-m4v", @"m4v", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/x-matroska", @"mkv", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/quicktime", @"mov", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/x-ms-wmv", @"wmv", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/ogg", @"ogv", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/divx", @"divx", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/MP2T", @"m2ts", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/MP2T", @"ts", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/webm", @"webm", @2];
            
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"image/gif", @"gif", @3];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"image/jpeg", @"jpg", @3];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"image/jpeg", @"jpeg", @3];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"image/png", @"png", @3];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"image/bmp", @"bmp", @3];
        }
        
        if (![db tableExists:@"mediaFolders"])
        {
            [db executeUpdate:@"CREATE TABLE mediaFolders (mediaFolderId INTEGER, serverId INTEGER, name TEXT, PRIMARY KEY (mediaFolderId, serverId))"];
        }
        
        if (![db tableExists:@"ignoredArticles"])
        {
            [db executeUpdate:@"CREATE TABLE ignoredArticles (articleId INTEGER, serverId INTEGER, name TEXT, PRIMARY KEY (articleId, serverId))"];
        }
        
        if (![db tableExists:@"folders"])
        {
            [db executeUpdate:@"CREATE TABLE folders (folderId INTEGER, serverId INTEGER, parentFolderId INTEGER, mediaFolderId INTEGER, coverArtId TEXT, name TEXT, PRIMARY KEY (folderId, serverId))"];
            [db executeUpdate:@"CREATE INDEX folders_parentFolderId ON folders (parentFolderId)"];
            [db executeUpdate:@"CREATE INDEX folders_mediaFolderId ON folders (mediaFolderId)"];
        }
        
        if (![db tableExists:@"cachedFolders"])
        {
            [db executeUpdate:@"CREATE TABLE cachedFolders (folderId INTEGER, serverId INTEGER, parentFolderId INTEGER, mediaFolderId INTEGER, coverArtId TEXT, name TEXT, PRIMARY KEY (folderId, serverId))"];
            [db executeUpdate:@"CREATE INDEX cachedFolders_parentFolderId ON cachedFolders (parentFolderId)"];
            [db executeUpdate:@"CREATE INDEX cachedFolders_mediaFolderId ON cachedFolders (mediaFolderId)"];
        }
        
        if (![db tableExists:@"artists"])
        {
            [db executeUpdate:@"CREATE TABLE artists (artistId INTEGER, serverId INTEGER, name TEXT, coverArtid TEXT, albumCount INTEGER, PRIMARY KEY (artistId, serverId))"];
        }
        
        if (![db tableExists:@"cachedArtists"])
        {
            [db executeUpdate:@"CREATE TABLE cachedArtists (artistId INTEGER, serverId INTEGER, name TEXT, coverArtId TEXT, albumCount INTEGER, PRIMARY KEY (artistId, serverId))"];
        }
        
        if (![db tableExists:@"albums"])
        {
            [db executeUpdate:@"CREATE TABLE albums (albumId INTEGER, serverId INTEGER, artistId INTEGER, genreId INTEGER, coverArtId TEXT, name TEXT, songCount INTEGER, duration INTEGER, year INTEGER, created REAL, PRIMARY KEY (albumId, serverId))"];
        }
        
        if (![db tableExists:@"cachedAlbums"])
        {
            [db executeUpdate:@"CREATE TABLE cachedAlbums (albumId INTEGER, serverId INTEGER, artistId INTEGER, genreId INTEGER, coverArtId TEXT, name TEXT, songCount INTEGER, duration INTEGER, year INTEGER, created REAL, PRIMARY KEY (albumId, serverId))"];
        }
        
        if (![db tableExists:@"songs"])
        {
            [db executeUpdate:@"CREATE TABLE songs (songId INTEGER, serverId INTEGER, contentTypeId INTEGER, transcodedContentTypeId INTEGER, mediaFolderId INTEGER, folderId INTEGER, artistId INTEGER, albumId INTEGER, genreId TEXT, coverArtId TEXT, title TEXT, duration INTEGER, bitrate INTEGER, trackNumber INTEGER, discNumber INTEGER, year INTEGER, size INTEGER, path TEXT, lastPlayed REAL, artistName TEXT, albumName TEXT, PRIMARY KEY (songId, serverId))"];
            [db executeUpdate:@"CREATE INDEX songs_mediaFolderId ON songs (mediaFolderId)"];
            [db executeUpdate:@"CREATE INDEX songs_folderId ON songs (folderId)"];
            [db executeUpdate:@"CREATE INDEX songs_artistId ON songs (artistId)"];
            [db executeUpdate:@"CREATE INDEX songs_albumId ON songs (albumId)"];
        }
        
        if (![db tableExists:@"cachedSongs"])
        {
            [db executeUpdate:@"CREATE TABLE cachedSongs (songId INTEGER, serverId INTEGER, contentTypeId INTEGER, transcodedContentTypeId INTEGER, mediaFolderId INTEGER, folderId INTEGER, artistId INTEGER, albumId INTEGER, genreId TEXT, coverArtId TEXT, title TEXT, duration INTEGER, bitrate INTEGER, trackNumber INTEGER, discNumber INTEGER, year INTEGER, size INTEGER, path TEXT, lastPlayed REAL, artistName TEXT, albumName TEXT, PRIMARY KEY (songId, serverId))"];
            [db executeUpdate:@"CREATE INDEX cachedSongs_mediaFolderId ON cachedSongs (mediaFolderId)"];
            [db executeUpdate:@"CREATE INDEX cachedSongs_folderId ON cachedSongs (folderId)"];
            [db executeUpdate:@"CREATE INDEX cachedSongs_artistId ON cachedSongs (artistId)"];
            [db executeUpdate:@"CREATE INDEX cachedSongs_albumId ON cachedSongs (albumId)"];
        }
        
        if (![db tableExists:@"genres"])
        {
            [db executeUpdate:@"CREATE TABLE genres (genreId INTEGER PRIMARY KEY, name TEXT)"];
            [db executeUpdate:@"CREATE INDEX genres_name ON genres (name)"];
        }
        
        if (![db tableExists:@"playlists"])
        {
            [db executeUpdate:@"CREATE TABLE playlists (playlistId INTEGER, serverId INTEGER, name TEXT, PRIMARY KEY (playlistId, serverId))"];
            [db executeUpdate:@"CREATE INDEX playlists_name ON playlists (name)"];
        }
        
        // NOTE: Passwords stored in the keychain
        if (![db tableExists:@"servers"])
        {
            [db executeUpdate:@"CREATE TABLE servers (serverId INTEGER PRIMARY KEY AUTOINCREMENT, type INTEGER, url TEXT, username TEXT, lastQueryId TEXT, uuid TEXT)"];
        }
    }];
    
    // Create the playlist tables if necessary (does nothing if they exist)
    [ISMSPlaylist createPlaylist:@"Play Queue" playlistId:[ISMSPlaylist playQueuePlaylistId] serverId:SavedSettings.si.currentServerId];
    [ISMSPlaylist createPlaylist:@"Download Queue" playlistId:[ISMSPlaylist downloadQueuePlaylistId] serverId:SavedSettings.si.currentServerId];
    [ISMSPlaylist createPlaylist:@"Downloaded Songs" playlistId:[ISMSPlaylist downloadedSongsPlaylistId] serverId:SavedSettings.si.currentServerId];
	
	// Setup the bookmarks database
	path = [self.databaseFolderPath stringByAppendingPathComponent:@"bookmarks.db"];
	
    // TODO: Rewrite with new data model
    /*
	self.bookmarksDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.bookmarksDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if ([db tableExists:@"bookmarks"])
        {
            // Make sure the isVideo column is there
            if (![db columnExists:@"isVideo" inTableWithName:@"bookmarks"])
            {
                // Doesn't exist so fix the table definition
                [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarksTemp (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, %@, bytes INTEGER)", [ISMSSong standardSongColumnSchema]]];
                [db executeUpdate:@"INSERT INTO bookmarksTemp SELECT bookmarkId, playlistIndex, name, position, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size, parentId, 0, bytes FROM bookmarks"];
                [db executeUpdate:@"DROP TABLE bookmarks"];
                [db executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];
                [db executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
            }
            
            if(![db columnExists:@"discNumber" inTableWithName:@"bookmarks"])
            {
                [db executeUpdate:@"ALTER TABLE bookmarks ADD COLUMN discNumber INTEGER"];
            }
        }
        else
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarks (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, %@, bytes INTEGER)", [ISMSSong standardSongColumnSchema]]];
			[db executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
		}
	}];
     */
}

- (void)closeAllDatabases
{
    [self.songModelReadDbPool releaseAllDatabases];
    [self.songModelWritesDbQueue close];
	[self.bookmarksDbQueue close];
}

- (void)resetFolderCache
{	
	// TODO: Reimplement this joining the song and playlist tables to leave only records belonging to the downloaded songs
}

// New Model Stuff

- (NSArray *)ignoredArticles
{
    NSMutableArray *ignoredArticles = [[NSMutableArray alloc] init];
    
    [self.songModelReadDbPool inDatabase:^(FMDatabase *db) {
        FMResultSet *r = [db executeQuery:@"SELECT name FROM ignoredArticles"];
        while ([r next])
        {
            [ignoredArticles addObject:[r stringForColumnIndex:0]];
        }
        [r close];
    }];
    
    return ignoredArticles;
}

- (NSString *)name:(NSString *)name ignoringArticles:(NSArray *)articles
{
    if (articles.count > 0)
    {
        for (NSString *article in articles)
        {
            NSString *articlePlusSpace = [article stringByAppendingString:@" "];
            if ([name hasPrefix:articlePlusSpace])
            {
                return [name substringFromIndex:articlePlusSpace.length];
            }
        }
    }
    
    return [self stringWithoutIndefiniteArticle:name];
}

- (NSString *)stringWithoutIndefiniteArticle:(NSString *)string
{
    NSArray *indefiniteArticles = @[@"the", @"los", @"las", @"les", @"el", @"la", @"le"];
    
    for (NSString *article in indefiniteArticles)
    {
        // See if the string starts with this article, note the space after each article to reduce false positives
        if ([string.lowercaseString hasPrefix:[NSString stringWithFormat:@"%@ ", article]])
        {
            // Make sure we don't mess with it if there's nothing after the article
            if (string.length > (article.length + 1))
            {
                // Move the article to the end after a comma
                return [NSString stringWithFormat:@"%@, %@", [string substringFromIndex:(article.length + 1)], [string substringToIndex:article.length]];
            }
        }
    }
    
    // Does not contain an article
    return string;
}


#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
//DLog(@"received memory warning");
	
	
}

#pragma mark - Singleton methods

- (void)setup 
{	
    _databaseFolderPath = [[SavedSettings documentsPath] stringByAppendingPathComponent:@"database"];
	
	// Make sure database directory exists, if not create them
	BOOL isDir = YES;
	if (![[NSFileManager defaultManager] fileExistsAtPath:_databaseFolderPath isDirectory:&isDir])
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:_databaseFolderPath withIntermediateDirectories:YES attributes:nil error:NULL];
	}
    
#ifdef IOS
    // Create the caches folder database path if this is iOS 5.0
    if (SYSTEM_VERSION_LESS_THAN(@"5.0.1"))
    {
        NSString *path = [[SavedSettings currentCacheRoot] stringByAppendingPathComponent:@"database"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir])
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
        }
    }
#endif
	
	[self setupDatabases];
	
#ifdef IOS
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
}

+ (void) setAllSongsToBackup
{
    // Handle moving the song cache database if necessary
    NSString *path = [[[SavedSettings currentCacheRoot] stringByAppendingPathComponent:@"database"] stringByAppendingPathComponent:@"songCache.db"];
    NSFileManager *defaultManager = [NSFileManager defaultManager];
#ifdef IOS
    if ([defaultManager fileExistsAtPath:path] && SYSTEM_VERSION_GREATER_THAN(@"5.0.0"))
    {
        // Set the no backup flag since the file already exists
        [[NSURL fileURLWithPath:path] removeSkipBackupAttribute];
    }
#endif
}

+ (void) setAllSongsToNotBackup
{
    // Handle moving the song cache database if necessary
    NSString *path = [[[SavedSettings currentCacheRoot] stringByAppendingPathComponent:@"database"] stringByAppendingPathComponent:@"songCache.db"];
    NSFileManager *defaultManager = [NSFileManager defaultManager];
#ifdef IOS
    if ([defaultManager fileExistsAtPath:path] && SYSTEM_VERSION_GREATER_THAN(@"5.0.0"))
    {
        // Set the no backup flag since the file already exists
        [[NSURL fileURLWithPath:path] addSkipBackupAttribute];
    }
#endif
}

+ (instancetype)si
{
    static DatabaseSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    
    __block BOOL runSetup = NO;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
        runSetup = YES;
    });
    
    if (runSetup)
    {
        [sharedInstance setup];
    }
    
    return sharedInstance;
}

@end
