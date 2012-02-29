//
//  Song+DAO.m
//  iSub
//
//  Created by Ben Baron on 11/14/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "Song+DAO.h"
#import "FMDatabaseAdditions.h"

#import "DatabaseSingleton.h"
#import "ViewObjectsSingleton.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "PlaylistSingleton.h"
#import "AudioEngine.h"
#import "NSArray+Additions.h"
#import "ISMSCacheQueueManager.h"
#import "NSString+Additions.h"

@implementation Song (DAO)

- (FMDatabase *)db
{
	return databaseS.songCacheDb;
}

- (BOOL)fileExists
{
	// Filesystem check
	BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:self.currentPath]; 
	DLog(@"fileExists: %@  at path: %@", NSStringFromBOOL(fileExists), self.currentPath);
	return fileExists;
	
	// Database check
	//return [self.db stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ?", [self.path md5]] ? YES : NO;
}

- (BOOL)isPartiallyCached
{
	return [self.db stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ? AND finished = 'NO'", [self.path md5]] ? YES : NO;
}

- (void)setIsPartiallyCached:(BOOL)isPartiallyCached
{
	assert(isPartiallyCached && "Can not set isPartiallyCached to to NO");
	if (isPartiallyCached)
	{
		[self insertIntoCachedSongsTable];
	}
}

- (BOOL)isFullyCached
{
	//DLog(@"%@: SELECT finished FROM cachedSongs WHERE md5 = '%@'", self.title, [self.path md5]);
	return [[self.db stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", [self.path md5]] boolValue];
}

- (void)setIsFullyCached:(BOOL)isFullyCached
{
	assert(isFullyCached && "Can not set isFullyCached to NO");
	if (isFullyCached)
	{
		DLog(@"%@: UPDATE cachedSongs SET finished = 'YES', cachedDate = %llu WHERE md5 = '%@'", self.title, (unsigned long long)[[NSDate date] timeIntervalSince1970], [self.path md5]);
		[self.db executeUpdate:@"UPDATE cachedSongs SET finished = 'YES', cachedDate = ? WHERE md5 = ?", [NSNumber numberWithUnsignedLongLong:(unsigned long long)[[NSDate date] timeIntervalSince1970]], [self.path md5]];
		
		[self insertIntoCachedSongsLayout];
		
		// Setup the genre table entries
		if (self.genre)
		{
			// Check if the genre has a table in the database yet, if not create it and add the new genre to the genres table
			NSString *genre = [self.db stringForQuery:@"SELECT genre FROM genres WHERE genre = ?", self.genre];
			if (!genre)
			{							
				[self.db executeUpdate:@"INSERT INTO genres (genre) VALUES (?)", self.genre];
				if ([self.db hadError])
					DLog(@"Err adding the genre %d: %@", [self.db lastErrorCode], [self.db lastErrorMessage]); 
			}
			
			// Insert the song object into the appropriate genresSongs table
			[self insertIntoGenreTable:@"genresSongs"];
		}
		
		[self removeFromCacheQueue];
	}
}

+ (Song *)songFromDbResult:(FMResultSet *)result
{
	Song *aSong = nil;
	if ([result next])
	{
		aSong = [[Song alloc] init];
		if ([result stringForColumn:@"title"] != nil)
			aSong.title = [[result stringForColumn:@"title"] cleanString];
		if ([result stringForColumn:@"songId"] != nil)
			aSong.songId = [[result stringForColumn:@"songId"] cleanString];
		if ([result stringForColumn:@"parentId"] != nil)
			aSong.parentId = [[result stringForColumn:@"parentId"] cleanString];
		if ([result stringForColumn:@"artist"] != nil)
			aSong.artist = [[result stringForColumn:@"artist"] cleanString];
		if ([result stringForColumn:@"album"] != nil)
			aSong.album = [[result stringForColumn:@"album"] cleanString];
		if ([result stringForColumn:@"genre"] != nil)
			aSong.genre = [[result stringForColumn:@"genre"] cleanString];
		if ([result stringForColumn:@"coverArtId"] != nil)
			aSong.coverArtId = [[result stringForColumn:@"coverArtId"] cleanString];
		if ([result stringForColumn:@"path"] != nil)
			aSong.path = [[result stringForColumn:@"path"] cleanString];
		if ([result stringForColumn:@"suffix"] != nil)
			aSong.suffix = [[result stringForColumn:@"suffix"] cleanString];
		if ([result stringForColumn:@"transcodedSuffix"] != nil)
			aSong.transcodedSuffix = [[result stringForColumn:@"transcodedSuffix"] cleanString];
		aSong.duration = [NSNumber numberWithInt:[result intForColumn:@"duration"]];
		aSong.bitRate = [NSNumber numberWithInt:[result intForColumn:@"bitRate"]];
		aSong.track = [NSNumber numberWithInt:[result intForColumn:@"track"]];
		aSong.year = [NSNumber numberWithInt:[result intForColumn:@"year"]];
		aSong.size = [NSNumber numberWithInt:[result intForColumn:@"size"]];
	}
	
	if ([aSong path] == nil)
	{
		[aSong release]; aSong = nil;
	}
	
	return [aSong autorelease];
}

+ (Song *)songFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabase:(FMDatabase *)db
{
	row++;
	Song *aSong = nil;
	FMResultSet *result = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE ROWID = %i", table, row]];
	if ([db hadError]) 
	{
		DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
	else
	{
		aSong = [Song songFromDbResult:result];
	}
	[result close];
	
	return aSong;
}

+ (Song *)songFromAllSongsDb:(NSUInteger)row inTable:(NSString *)table
{
	return [self songFromDbRow:row inTable:table inDatabase:databaseS.allSongsDb];
}

+ (Song *)songFromServerPlaylistId:(NSString *)md5 row:(NSUInteger)row
{
	NSString *table = [NSString stringWithFormat:@"splaylist%@", md5];
	return [self songFromDbRow:row inTable:table inDatabase:databaseS.localPlaylistsDb];
}

+ (Song *)songFromDbForMD5:(NSString *)md5 inTable:(NSString *)table inDatabase:(FMDatabase *)db
{
	Song *aSong = nil;
	FMResultSet *result = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE md5 = ?", table], md5];
	if ([db hadError]) 
	{
		DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
	else
	{
		aSong = [Song songFromDbResult:result];
	}
	[result close];
	
	return aSong;
}

+ (Song *)songFromGenreDb:(NSString *)md5
{
	if (viewObjectsS.isOfflineMode)
	{
		return [self songFromDbForMD5:md5 inTable:@"genresSongs" inDatabase:databaseS.songCacheDb];
	}
	else
	{
		return [self songFromDbForMD5:md5 inTable:@"genresSongs" inDatabase:databaseS.songCacheDb];
	}
}

+ (Song *)songFromCacheDb:(NSString *)md5
{
	return [self songFromDbForMD5:md5 inTable:@"cachedSongs" inDatabase:databaseS.songCacheDb];
}

- (BOOL)insertIntoTable:(NSString *)table inDatabase:(FMDatabase *)db
{
	[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)", table, [Song standardSongColumnNames], [Song standardSongColumnQMarks]], self.title, self.songId, self.artist, self.album, self.genre, self.coverArtId, self.path, self.suffix, self.transcodedSuffix, self.duration, self.bitRate, self.track, self.year, self.size, self.parentId];
	
	if ([db hadError]) 
	{
		DLog(@"Err inserting song %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
	
	return ![db hadError];
}

- (BOOL)insertIntoServerPlaylistWithPlaylistId:(NSString *)md5
{
	NSString *table = [NSString stringWithFormat:@"splaylist%@", md5];
	return [self insertIntoTable:table inDatabase:databaseS.localPlaylistsDb];
}

- (BOOL)insertIntoFolderCacheForFolderId:(NSString *)folderId
{
	FMDatabase *db = databaseS.albumListCacheDb;
	
	[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO songsCache (folderId, %@) VALUES (?, %@)", [Song standardSongColumnNames], [Song standardSongColumnQMarks]], [folderId md5], self.title, self.songId, self.artist, self.album, self.genre, self.coverArtId, self.path, self.suffix, self.transcodedSuffix, self.duration, self.bitRate, self.track, self.year, self.size, self.parentId];
	
	if ([db hadError])
	{
		DLog(@"Err inserting song %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
	
	return ![db hadError];
}

- (BOOL)insertIntoGenreTable:(NSString *)table
{	
	[self.db executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (md5, %@) VALUES (?, %@)", table, [Song standardSongColumnNames], [Song standardSongColumnQMarks]], [self.path md5], self.title, self.songId, self.artist, self.album, self.genre, self.coverArtId, self.path, self.suffix, self.transcodedSuffix, self.duration, self.bitRate, self.track, self.year, self.size, self.parentId];
	
	if ([self.db hadError]) 
	{
		DLog(@"Err inserting song into genre table %d: %@", [self.db lastErrorCode], [self.db lastErrorMessage]);
	}
	
	return ![self.db hadError];
}

- (BOOL)insertIntoCachedSongsTable
{
	[self.db executeUpdate:[NSString stringWithFormat:@"REPLACE INTO cachedSongs (md5, finished, cachedDate, playedDate, %@) VALUES (?, 'NO', ?, 0, %@)",  [Song standardSongColumnNames], [Song standardSongColumnQMarks]], [self.path md5], [NSNumber numberWithUnsignedLongLong:(unsigned long long)[[NSDate date] timeIntervalSince1970]], self.title, self.songId, self.artist, self.album, self.genre, self.coverArtId, self.path, self.suffix, self.transcodedSuffix, self.duration, self.bitRate, self.track, self.year, self.size, self.parentId];
	
	if ([self.db hadError]) 
	{
		DLog(@"Err inserting song into cached songs table %d: %@", [self.db lastErrorCode], [self.db lastErrorMessage]);
	}
	
	return ![self.db hadError];
}

- (BOOL)removeFromCachedSongsTable
{
	//return [Song removeSongFromCacheDbByMD5:[self.path md5]];
	
	DLog(@"removing %@ from cachedSongs", self.title);
	[self.db executeUpdate:@"DELETE FROM cachedSongs WHERE md5 = ?", [self.path md5]];
	
	if ([self.db hadError]) 
	{
		DLog(@"Err removing song from cached songs table %d: %@", [self.db lastErrorCode], [self.db lastErrorMessage]);
	}
	
	return ![self.db hadError];
}

- (BOOL)removeFromCacheQueue
{
	[self.db executeUpdate:@"DELETE FROM cacheQueue WHERE md5 = ?", [self.path md5]];
	
	if ([self.db hadError]) 
	{
		DLog(@"Err removing song from cache queue table %d: %@", [self.db lastErrorCode], [self.db lastErrorMessage]);
	}
	
	return ![self.db hadError];
}

- (BOOL)addToCacheQueue
{	
	NSString *md5 = [self.db stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ? AND finished = 'YES'", [self.path md5]];
	if (!md5) 
	{
		[self.db executeUpdate:[NSString stringWithFormat:@"INSERT INTO cacheQueue (md5, finished, cachedDate, playedDate, %@) VALUES (?, ?, ?, ?, %@)", [Song standardSongColumnNames], [Song standardSongColumnQMarks]], [self.path md5], @"NO", [NSNumber numberWithUnsignedLongLong:(unsigned long long)[[NSDate date] timeIntervalSince1970]], [NSNumber numberWithInt:0], self.title, self.songId, self.artist, self.album, self.genre, self.coverArtId, self.path, self.suffix, self.transcodedSuffix, self.duration, self.bitRate, self.track, self.year, self.size, self.parentId];
	}
	
	if ([self.db hadError]) 
	{
		DLog(@"Err adding song to cache queue %d: %@", [self.db lastErrorCode], [self.db lastErrorMessage]);
	}
	
	if (!cacheQueueManagerS.isQueueDownloading)
	{
		// Make sure this is called from the main thread
		if ([NSThread isMainThread])
			[cacheQueueManagerS startDownloadQueue];
		else
			[cacheQueueManagerS performSelectorOnMainThread:@selector(startDownloadQueue) withObject:nil waitUntilDone:NO];
	}
	
	return ![self.db hadError];
}

- (BOOL)addToCurrentPlaylist
{
	DatabaseSingleton *dbControls = databaseS;

	BOOL hadError = NO;
	
	if (settingsS.isJukeboxEnabled)
	{
		//DLog(@"inserting %@", aSong.title);
		[self insertIntoTable:@"jukeboxCurrentPlaylist" inDatabase:dbControls.currentPlaylistDb];
		if ([dbControls.currentPlaylistDb hadError])
			hadError = YES;
		
		if (playlistS.isShuffle)
		{
			[self insertIntoTable:@"jukeboxShufflePlaylist" inDatabase:dbControls.currentPlaylistDb];
			if ([dbControls.currentPlaylistDb hadError])
				hadError = YES;
		}
	}
	else
	{
		[self insertIntoTable:@"currentPlaylist" inDatabase:dbControls.currentPlaylistDb];
		if ([dbControls.currentPlaylistDb hadError])
			hadError = YES;
		
		if (playlistS.isShuffle)
		{
			[self insertIntoTable:@"shufflePlaylist" inDatabase:dbControls.currentPlaylistDb];
			if ([dbControls.currentPlaylistDb hadError])
				hadError = YES;
		}
	}
	
	return !hadError;
}

- (BOOL)addToShufflePlaylist
{
	DatabaseSingleton *dbControls = databaseS;

	BOOL hadError = NO;
	
	if (settingsS.isJukeboxEnabled)
	{
		[self insertIntoTable:@"jukeboxShufflePlaylist" inDatabase:dbControls.currentPlaylistDb];
		if ([dbControls.currentPlaylistDb hadError])
			hadError = YES;
	}
	else
	{
		[self insertIntoTable:@"shufflePlaylist" inDatabase:dbControls.currentPlaylistDb];
		if ([dbControls.currentPlaylistDb hadError])
			hadError = YES;
	}
	
	return !hadError;
}

- (BOOL)insertIntoCachedSongsLayout
{
	// Save the offline view layout info
	NSArray *splitPath = [self.path componentsSeparatedByString:@"/"];
	
	BOOL hadError = YES;	

	if ([splitPath count] <= 9)
	{
		NSMutableArray *segments = [[NSMutableArray alloc] initWithArray:splitPath];
		while ([segments count] < 9)
		{
			[segments addObject:@""];
		}
		
		NSString *query = [NSString stringWithFormat:@"INSERT INTO cachedSongsLayout (md5, genre, segs, seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8, seg9) VALUES ('%@', '%@', %i, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [self.path md5], self.genre, [splitPath count]];
		[self.db executeUpdate:query, [segments objectAtIndexSafe:0], [segments objectAtIndexSafe:1], [segments objectAtIndexSafe:2], [segments objectAtIndexSafe:3], [segments objectAtIndexSafe:4], [segments objectAtIndexSafe:5], [segments objectAtIndexSafe:6], [segments objectAtIndexSafe:7], [segments objectAtIndexSafe:8]];
		
		hadError = [self.db hadError];
		
		[segments release];
	}
	
	return !hadError;
}

+ (BOOL)removeSongFromCacheDbByMD5:(NSString *)md5
{
	// Check if we're deleting the song that's currently playing. If so, stop the player.
	if (playlistS.currentSong && !settingsS.isJukeboxEnabled &&
		[[playlistS.currentSong.path md5] isEqualToString:md5])
	{
		DLog(@"stopping the player before deleting the file");
        [audioEngineS stop];
	}
	
	DatabaseSingleton *dbControls = databaseS;
	
	BOOL hadError = NO;	
	
	// Get the song info
	FMResultSet *result = [dbControls.songCacheDb executeQuery:@"SELECT genre, transcodedSuffix, suffix FROM cachedSongs WHERE md5 = ?", md5];
	[result next];
	NSString *genre = nil;
	NSString *transcodedSuffix = nil;
	NSString *suffix = nil;
	if ([result stringForColumnIndex:0] != nil)
		genre = [NSString stringWithString:[result stringForColumnIndex:0]];
	if ([result stringForColumnIndex:1] != nil)
		transcodedSuffix = [NSString stringWithString:[result stringForColumnIndex:1]];
	if ([result stringForColumnIndex:2] != nil)
		suffix = [NSString stringWithString:[result stringForColumnIndex:2]];
	[result close];
	if ([dbControls.songCacheDb hadError])
		hadError = YES;
	
	// Delete the row from the cachedSongs and genresSongs
	[dbControls.songCacheDb executeUpdate:@"DELETE FROM cachedSongs WHERE md5 = ?", md5];
	if ([dbControls.songCacheDb hadError])
		hadError = YES;
	[dbControls.songCacheDb executeUpdate:@"DELETE FROM cachedSongsLayout WHERE md5 = ?", md5];
	if ([dbControls.songCacheDb hadError])
		hadError = YES;
	[dbControls.songCacheDb executeUpdate:@"DELETE FROM genresSongs WHERE md5 = ?", md5];
	if ([dbControls.songCacheDb hadError])
		hadError = YES;
	
	// Delete the song from disk
	NSString *fileName;
	if (transcodedSuffix)
		fileName = [settingsS.songCachePath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", md5, transcodedSuffix]];
	else
		fileName = [settingsS.songCachePath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", md5, suffix]];
	///////// REWRITE TO CATCH THIS NSFILEMANAGER ERROR ///////////
	[[NSFileManager defaultManager] removeItemAtPath:fileName error:NULL];
	
	// Clean up genres table
	NSString *genreTest = [dbControls.songCacheDb stringForQuery:@"SELECT genre FROM genresSongs WHERE genre = ? LIMIT 1", genre];
	if (!genreTest)
	{
		[dbControls.songCacheDb executeUpdate:@"DELETE FROM genres WHERE genre = ?", genre];
		if ([dbControls.songCacheDb hadError])
			hadError = YES;
	}
	
	return !hadError;
}

- (CGFloat)downloadProgress
{
	CGFloat downloadProgress = 0.;
	
	if (self.isFullyCached)
		downloadProgress = 1.;
	
	if (self.isPartiallyCached)
	{
		double totalSize = [self.size doubleValue];
		CGFloat bitrate = (CGFloat)self.estimatedBitrate;
		CGFloat seconds = [self.duration floatValue];
		if (self.transcodedSuffix)
		{
			// This is a transcode, so we'll want to use the actual bitrate if possible
			if ([playlistS.currentSong isEqualToSong:self])
			{
				// This is the current playing song, so see if BASS has an actual bitrate for it
				if (audioEngineS.bitRate > 0)
				{
					// Bass has a non-zero bitrate, so use that for the calculation
					// convert to bytes per second, multiply by number of seconds
					bitrate = (CGFloat)audioEngineS.bitRate;
					seconds = [self.duration floatValue];
					
				}
			}
		}
		totalSize = BytesForSecondsAtBitrate(bitrate, seconds);
		downloadProgress = (double)self.localFileSize / totalSize;		
	}
	
	// Keep within bounds
	downloadProgress = downloadProgress < 0. ? 0. : downloadProgress;
	downloadProgress = downloadProgress > 1. ? 1. : downloadProgress;
	
	// The song hasn't started downloading yet
	return downloadProgress;
}

- (NSDate *)playedDate
{
	NSString *query = [NSString stringWithFormat:@"SELECT playedDate FROM cachedSongs WHERE md5 = '%@'",
					   [self.songId md5]];
	NSUInteger playedTime = [self.db intForQuery:query];
	return [NSDate dateWithTimeIntervalSince1970:playedTime];
}

- (void)setPlayedDate:(NSDate *)playedDate
{
	NSString *query = @"UPDATE cachedSongs SET playedDate = ? WHERE md5 = ?";
	[self.db executeUpdate:query, [NSNumber numberWithUnsignedLongLong:(unsigned long long)[playedDate timeIntervalSince1970]], [self.songId md5]];
}

+ (NSString *)standardSongColumnSchema
{
	return @"title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER, parentId TEXT";
}

+ (NSString *)standardSongColumnNames
{
	return @"title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size, parentId";
}

+ (NSString *)standardSongColumnQMarks
{
	return @"?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?";
}

@end
