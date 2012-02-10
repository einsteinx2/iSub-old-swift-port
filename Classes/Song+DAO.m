//
//  Song+DAO.m
//  iSub
//
//  Created by Ben Baron on 11/14/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "Song+DAO.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabase+Synchronized.h"
#import "DatabaseSingleton.h"
#import "NSString+md5.h"
#import "ViewObjectsSingleton.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "PlaylistSingleton.h"
#import "AudioEngine.h"

@implementation Song (DAO)

- (FMDatabase *)db
{
	return [DatabaseSingleton sharedInstance].songCacheDb;
}

- (BOOL)fileExists
{
	// Filesystem check
	return [[NSFileManager defaultManager] fileExistsAtPath:self.currentPath]; 

	// Database check
	//return [self.db synchronizedBoolForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE md5 = ?", [self.path md5]];
}

- (BOOL)isPartiallyCached
{
	return [self.db synchronizedIntForQuery:@"SELECT count(*) FROM cachedSongs WHERE md5 = ? AND finished = 'NO'", [self.path md5]];
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
	return [[self.db synchronizedStringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", [self.path md5]] boolValue];
}

- (void)setIsFullyCached:(BOOL)isFullyCached
{
	assert(isFullyCached && "Can not set isFullyCached to to NO");
	if (isFullyCached)
	{
		[self.db synchronizedUpdate:@"UPDATE cachedSongs SET finished = 'YES' WHERE md5 = ?", [self.path md5]];
		
		[self insertIntoCachedSongsLayout];
		
		// Setup the genre table entries
		if (self.genre)
		{		
			// Check if the genre has a table in the database yet, if not create it and add the new genre to the genres table
			if ([self.db synchronizedIntForQuery:@"SELECT COUNT(*) FROM genres WHERE genre = ?", self.genre] == 0)
			{							
				[self.db synchronizedUpdate:@"INSERT INTO genres (genre) VALUES (?)", self.genre];
				if ([self.db hadError])
				{
					DLog(@"Err adding the genre %d: %@", [self.db lastErrorCode], [self.db lastErrorMessage]); 
				}
			}
			
			// Insert the song object into the genresSongs
			[self insertIntoGenreTable:@"genresSongs"];
		}
	}
}

+ (Song *)songFromDbResult:(FMResultSet *)result
{
	Song *aSong = nil;
	if ([result next])
	{
		aSong = [[Song alloc] init];
		if ([result stringForColumn:@"title"] != nil)
			aSong.title = [[result stringForColumn:@"title"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		if ([result stringForColumn:@"songId"] != nil)
			aSong.songId = [[result stringForColumn:@"songId"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		if ([result stringForColumn:@"parentId"] != nil)
			aSong.parentId = [[result stringForColumn:@"parentId"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		if ([result stringForColumn:@"artist"] != nil)
			aSong.artist = [[result stringForColumn:@"artist"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		if ([result stringForColumn:@"album"] != nil)
			aSong.album = [[result stringForColumn:@"album"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		if ([result stringForColumn:@"genre"] != nil)
			aSong.genre = [[result stringForColumn:@"genre"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		if ([result stringForColumn:@"coverArtId"] != nil)
			aSong.coverArtId = [[result stringForColumn:@"coverArtId"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		if ([result stringForColumn:@"path"] != nil)
			aSong.path = [[result stringForColumn:@"path"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		if ([result stringForColumn:@"suffix"] != nil)
			aSong.suffix = [[result stringForColumn:@"suffix"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		if ([result stringForColumn:@"transcodedSuffix"] != nil)
			aSong.transcodedSuffix = [[result stringForColumn:@"transcodedSuffix"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
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
	FMResultSet *result = [db synchronizedQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE ROWID = %i", table, row]];
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
	return [self songFromDbRow:row inTable:table inDatabase:[DatabaseSingleton sharedInstance].allSongsDb];
}

+ (Song *)songFromServerPlaylistId:(NSString *)md5 row:(NSUInteger)row
{
	NSString *table = [NSString stringWithFormat:@"splaylist%@", md5];
	return [self songFromDbRow:row inTable:table inDatabase:[DatabaseSingleton sharedInstance].localPlaylistsDb];
}

+ (Song *)songFromDbForMD5:(NSString *)md5 inTable:(NSString *)table inDatabase:(FMDatabase *)db
{
	Song *aSong = nil;
	FMResultSet *result = [db synchronizedQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE md5 = ?", table], md5];
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
	if ([ViewObjectsSingleton sharedInstance].isOfflineMode)
	{
		return [self songFromDbForMD5:md5 inTable:@"genresSongs" inDatabase:[DatabaseSingleton sharedInstance].songCacheDb];
	}
	else
	{
		return [self songFromDbForMD5:md5 inTable:@"genresSongs" inDatabase:[DatabaseSingleton sharedInstance].songCacheDb];
	}
}

+ (Song *)songFromCacheDb:(NSString *)md5
{
	return [self songFromDbForMD5:md5 inTable:@"cachedSongs" inDatabase:[DatabaseSingleton sharedInstance].songCacheDb];
}

- (BOOL)insertIntoTable:(NSString *)table inDatabase:(FMDatabase *)db
{
	[db synchronizedUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)", table, [Song standardSongColumnNames], [Song standardSongColumnQMarks]], self.title, self.songId, self.artist, self.album, self.genre, self.coverArtId, self.path, self.suffix, self.transcodedSuffix, self.duration, self.bitRate, self.track, self.year, self.size, self.parentId];
	
	if ([db hadError]) 
	{
		DLog(@"Err inserting song %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
	
	return ![db hadError];
}

- (BOOL)insertIntoServerPlaylistWithPlaylistId:(NSString *)md5
{
	NSString *table = [NSString stringWithFormat:@"splaylist%@", md5];
	return [self insertIntoTable:table inDatabase:[DatabaseSingleton sharedInstance].localPlaylistsDb];
}

- (BOOL)insertIntoFolderCacheForFolderId:(NSString *)folderId
{
	FMDatabase *db = [DatabaseSingleton sharedInstance].albumListCacheDb;
	
	[db synchronizedUpdate:[NSString stringWithFormat:@"INSERT INTO songsCache (folderId, %@) VALUES (?, %@)", [Song standardSongColumnNames], [Song standardSongColumnQMarks]], [folderId md5], self.title, self.songId, self.artist, self.album, self.genre, self.coverArtId, self.path, self.suffix, self.transcodedSuffix, self.duration, self.bitRate, self.track, self.year, self.size, self.parentId];
	
	if ([db hadError])
	{
		DLog(@"Err inserting song %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
	
	return ![db hadError];
}

- (BOOL)insertIntoGenreTable:(NSString *)table
{	
	[self.db synchronizedUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (md5, %@) VALUES (?, %@)", table, [Song standardSongColumnNames], [Song standardSongColumnQMarks]], [self.path md5], self.title, self.songId, self.artist, self.album, self.genre, self.coverArtId, self.path, self.suffix, self.transcodedSuffix, self.duration, self.bitRate, self.track, self.year, self.size, self.parentId];
	
	if ([self.db hadError]) 
	{
		DLog(@"Err inserting song into genre table %d: %@", [self.db lastErrorCode], [self.db lastErrorMessage]);
	}
	
	return ![self.db hadError];
}

- (BOOL)insertIntoCachedSongsTable
{
	[self.db synchronizedUpdate:[NSString stringWithFormat:@"REPLACE INTO cachedSongs (md5, finished, cachedDate, playedDate, %@) VALUES (?, 'NO', ?, 0, %@)",  [Song standardSongColumnNames], [Song standardSongColumnQMarks]], [self.path md5], [NSNumber numberWithInt:(NSUInteger)[[NSDate date] timeIntervalSince1970]], self.title, self.songId, self.artist, self.album, self.genre, self.coverArtId, self.path, self.suffix, self.transcodedSuffix, self.duration, self.bitRate, self.track, self.year, self.size, self.parentId];
	
	if ([self.db hadError]) 
	{
		DLog(@"Err inserting song into genre table %d: %@", [self.db lastErrorCode], [self.db lastErrorMessage]);
	}
	
	return ![self.db hadError];
}

- (BOOL)addToCacheQueue
{	
	if ([self.db synchronizedIntForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE md5 = ? AND finished = 'YES'", [self.path md5]] == 0) 
	{
		[self.db synchronizedUpdate:[NSString stringWithFormat:@"INSERT INTO cacheQueue (md5, finished, cachedDate, playedDate, %@) VALUES (?, ?, ?, ?, %@)", [Song standardSongColumnNames], [Song standardSongColumnQMarks]], [self.path md5], @"NO", [NSNumber numberWithInt:(NSUInteger)[[NSDate date] timeIntervalSince1970]], [NSNumber numberWithInt:0], self.title, self.songId, self.artist, self.album, self.genre, self.coverArtId, self.path, self.suffix, self.transcodedSuffix, self.duration, self.bitRate, self.track, self.year, self.size, self.parentId];
	}
	
	if ([self.db hadError]) 
	{
		DLog(@"Err adding song to cache queue %d: %@", [self.db lastErrorCode], [self.db lastErrorMessage]);
	}
	
	if (![MusicSingleton sharedInstance].isQueueListDownloading)
	{
		[[MusicSingleton sharedInstance] performSelectorOnMainThread:@selector(downloadNextQueuedSong) withObject:nil waitUntilDone:NO];
	}
	
	return ![self.db hadError];
}

- (BOOL)addToCurrentPlaylist
{
	DatabaseSingleton *dbControls = [DatabaseSingleton sharedInstance];
	PlaylistSingleton *currentPlaylist = [PlaylistSingleton sharedInstance];

	BOOL hadError = NO;
	
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		//DLog(@"inserting %@", aSong.title);
		[self insertIntoTable:@"jukeboxCurrentPlaylist" inDatabase:dbControls.currentPlaylistDb];
		if ([dbControls.currentPlaylistDb hadError])
			hadError = YES;
		
		if (currentPlaylist.isShuffle)
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
		
		if (currentPlaylist.isShuffle)
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
	DatabaseSingleton *dbControls = [DatabaseSingleton sharedInstance];

	BOOL hadError = NO;
	
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
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
		[self.db synchronizedUpdate:query, [segments objectAtIndex:0], [segments objectAtIndex:1], [segments objectAtIndex:2], [segments objectAtIndex:3], [segments objectAtIndex:4], [segments objectAtIndex:5], [segments objectAtIndex:6], [segments objectAtIndex:7], [segments objectAtIndex:8]];
		
		hadError = [self.db hadError];
		
		[segments release];
	}
	
	return !hadError;
}

+ (BOOL)removeSongFromCacheDbByMD5:(NSString *)md5
{
	DatabaseSingleton *dbControls = [DatabaseSingleton sharedInstance];
	SavedSettings *settings = [SavedSettings sharedInstance];
	
	BOOL hadError = NO;	
	
	// Get the song info
	FMResultSet *result = [dbControls.songCacheDb synchronizedQuery:@"SELECT genre, transcodedSuffix, suffix FROM cachedSongs WHERE md5 = ?", md5];
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
	[dbControls.songCacheDb synchronizedUpdate:@"DELETE FROM cachedSongs WHERE md5 = ?", md5];
	if ([dbControls.songCacheDb hadError])
		hadError = YES;
	[dbControls.songCacheDb synchronizedUpdate:@"DELETE FROM cachedSongsLayout WHERE md5 = ?", md5];
	if ([dbControls.songCacheDb hadError])
		hadError = YES;
	[dbControls.songCacheDb synchronizedUpdate:@"DELETE FROM genresSongs WHERE md5 = ?", md5];
	if ([dbControls.songCacheDb hadError])
		hadError = YES;
	
	// Delete the song from disk
	NSString *fileName;
	if (transcodedSuffix)
		fileName = [settings.songCachePath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", md5, transcodedSuffix]];
	else
		fileName = [settings.songCachePath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", md5, suffix]];
	///////// REWRITE TO CATCH THIS NSFILEMANAGER ERROR ///////////
	[[NSFileManager defaultManager] removeItemAtPath:fileName error:NULL];
	
	PlaylistSingleton *dataModel = [PlaylistSingleton sharedInstance];
	
	// Check if we're deleting the song that's currently playing. If so, stop the player.
	if (dataModel.currentSong && ![SavedSettings sharedInstance].isJukeboxEnabled &&
		[[dataModel.currentSong.path md5] isEqualToString:md5])
	{
        [[AudioEngine sharedInstance] stop];
	}
	
	// Clean up genres table
	if ([dbControls.songCacheDb synchronizedIntForQuery:@"SELECT COUNT(*) FROM genresSongs WHERE genre = ?", genre] == 0)
	{
		[dbControls.songCacheDb synchronizedUpdate:@"DELETE FROM genres WHERE genre = ?", genre];
		if ([dbControls.songCacheDb hadError])
			hadError = YES;
	}
	
	return !hadError;
}

- (CGFloat)downloadProgress
{
	if (self.isFullyCached)
		return 1.0;
	
	if (self.isPartiallyCached)
	{
		CGFloat totalSize = [self.size floatValue];
		if (self.transcodedSuffix)
		{
			// This is a transcode, so we'll want to use the actual bitrate if possible
			if ([[PlaylistSingleton sharedInstance].currentSong isEqualToSong:self])
			{
				// This is the current playing song, so see if BASS has an actual bitrate for it
				if ([AudioEngine sharedInstance].bitRate > 0)
				{
					// Bass has a non-zero bitrate, so use that for the calculation
					// convert to bytes per second, multiply by number of seconds
					CGFloat byteRate = (CGFloat)[AudioEngine sharedInstance].bitRate * 1024. / 8.;
					totalSize = byteRate * [self.duration floatValue];
				}
				else
				{
					// Current playing song, but BASS has no bitrate
					CGFloat byteRate = (CGFloat)self.estimatedBitrate * 1024. / 8.;
					totalSize = byteRate * [self.duration floatValue];
				}
			}
			else
			{
				// Not the current playing song, so use estimated bitrate
				CGFloat byteRate = (CGFloat)self.estimatedBitrate * 1024. / 8.;
				totalSize = byteRate * [self.duration floatValue];
			}
		}
		return (CGFloat)self.localFileSize / totalSize;
	}
	
	// The song hasn't started downloading yet
	return 0.0;
}

- (NSDate *)playedDate
{
	NSString *query = [NSString stringWithFormat:@"SELECT playedDate FROM cachedSongs WHERE md5 = '%@'",
					   [self.songId md5]];
	NSUInteger playedTime = [self.db synchronizedIntForQuery:query];
	return [NSDate dateWithTimeIntervalSince1970:playedTime];
}

- (void)setPlayedDate:(NSDate *)playedDate
{
	NSString *query = [NSString stringWithFormat:@"UPDATE cachedSongs SET playedDate = %i WHERE md5 = '%@'", 
					   (NSUInteger)[playedDate timeIntervalSince1970], 
					   [self.songId md5]];
	[self.db synchronizedUpdate:query];
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
