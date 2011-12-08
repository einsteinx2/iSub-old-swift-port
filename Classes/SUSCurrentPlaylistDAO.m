//
//  SUSCurrentPlaylistDAO.m
//  iSub
//
//  Created by Ben Baron on 11/14/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSCurrentPlaylistDAO.h"
#import "Song.h"
#import "DatabaseSingleton.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSNotificationCenter+MainThread.h"
#import "BassWrapperSingleton.h"

static NSUInteger currentIndex = 0;
static ISMSRepeatMode repeatMode = ISMSRepeatMode_Normal;

@implementation SUSCurrentPlaylistDAO

+ (SUSCurrentPlaylistDAO *)dataModel
{
	return [[[SUSCurrentPlaylistDAO alloc] init] autorelease];
}

#pragma mark - Private DB Methods

- (FMDatabase *)db
{
    return [DatabaseSingleton sharedInstance].currentPlaylistDb;
}

#pragma mark - Public DAO Methods

- (void)resetCurrentPlaylist
{
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		[self.db executeUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
		[self.db executeUpdate:@"CREATE TABLE jukeboxCurrentPlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];	
	}
	else
	{	
		[self.db executeUpdate:@"DROP TABLE currentPlaylist"];
		[self.db executeUpdate:@"CREATE TABLE currentPlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];	
	}
}

- (void)resetShufflePlaylist
{
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		[self.db executeUpdate:@"DROP TABLE jukeboxShufflePlaylist"];
		[self.db executeUpdate:@"CREATE TABLE jukeboxShufflePlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];	
	}
	else
	{	
		[self.db executeUpdate:@"DROP TABLE shufflePlaylist"];
		[self.db executeUpdate:@"CREATE TABLE shufflePlaylist (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];	
	}
}

- (void)deleteSongs:(NSArray *)indexes
{	
	@autoreleasepool
	{
		MusicSingleton *musicControls = [MusicSingleton sharedInstance];
		
		BOOL goToNextSong = NO;
		
		NSMutableArray *indexesMut = [NSMutableArray arrayWithArray:indexes];
		
		// Sort the multiDeleteList to make sure it's accending
		[indexesMut sortUsingSelector:@selector(compare:)];
		
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
		{
			if ([indexesMut count] == self.count)
			{
				[self resetCurrentPlaylist];
			}
			else
			{
				[self.db executeUpdate:@"DROP TABLE jukeboxTemp"];
				[self.db executeUpdate:@"CREATE TABLE jukeboxTemp(title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
				
				for (NSNumber *index in [indexesMut reverseObjectEnumerator])
				{
					@autoreleasepool
					{
						NSInteger rowId = [index integerValue] + 1;
						[self.db executeUpdate:[NSString stringWithFormat:@"DELETE FROM jukeboxCurrentPlaylist WHERE ROWID = %i", rowId]];
					}
				}
				
				[self.db executeUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist"];
				[self.db executeUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
				[self.db executeUpdate:@"ALTER TABLE jukeboxTemp RENAME TO jukeboxCurrentPlaylist"];
			}
		}
		else
		{
			if (musicControls.isShuffle)
			{
				if ([indexesMut count] == self.count)
				{
					[[DatabaseSingleton sharedInstance] resetCurrentPlaylistDb];
					musicControls.isShuffle = NO;
				}
				else
				{
					[self.db executeUpdate:@"DROP TABLE shuffleTemp"];
					[self.db executeUpdate:@"CREATE TABLE shuffleTemp(title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
					
					for (NSNumber *index in [indexesMut reverseObjectEnumerator])
					{
						@autoreleasepool 
						{
							NSInteger rowId = [index integerValue] + 1;
							[self.db executeUpdate:[NSString stringWithFormat:@"DELETE FROM shufflePlaylist WHERE ROWID = %i", rowId]];
						}
					}
					
					[self.db executeUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist"];
					[self.db executeUpdate:@"DROP TABLE shufflePlaylist"];
					[self.db executeUpdate:@"ALTER TABLE shuffleTemp RENAME TO shufflePlaylist"];
				}
			}
			else
			{
				if ([indexesMut count] == self.count)
				{
					[[DatabaseSingleton sharedInstance] resetCurrentPlaylistDb];
				}
				else
				{
					[self.db executeUpdate:@"DROP TABLE currentTemp"];
					[self.db executeUpdate:@"CREATE TABLE currentTemp(title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
					
					for (NSNumber *index in [indexesMut reverseObjectEnumerator])
					{
						@autoreleasepool 
						{
							NSInteger rowId = [index integerValue] + 1;
							[self.db executeUpdate:[NSString stringWithFormat:@"DELETE FROM currentPlaylist WHERE ROWID = %i", rowId]];
						}
					}
					
					[self.db executeUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist"];
					[self.db executeUpdate:@"DROP TABLE currentPlaylist"];
					[self.db executeUpdate:@"ALTER TABLE currentTemp RENAME TO currentPlaylist"];
				}
			}
		}
		
		// Correct the value of currentPlaylistPosition
		// If the current song was deleted make sure to set goToNextSong so the next song will play
		if ([indexesMut containsObject:[NSNumber numberWithInt:self.currentIndex]] && [BassWrapperSingleton sharedInstance].isPlaying)
		{
			goToNextSong = YES;
		}
		
		// Find out how many songs were deleted before the current position to determine the new position
		NSInteger numberBefore = 0;
		for (NSNumber *index in indexesMut)
		{
			@autoreleasepool
			{
				if ([index integerValue] <= self.currentIndex)
				{
					numberBefore = numberBefore + 1;
				}
			}
		}
		self.currentIndex = self.currentIndex - numberBefore;
		
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
		{
			[musicControls jukeboxReplacePlaylistWithLocal];
		}
		
		if (goToNextSong)
		{
			[self incrementIndex];
			[musicControls performSelectorOnMainThread:@selector(startSong) withObject:nil waitUntilDone:NO];
		}
	}
}

- (Song *)songForIndex:(NSUInteger)index
{
	//DLog(@"%@", [NSThread callStackSymbols]);
	MusicSingleton *musicControls = [MusicSingleton sharedInstance];
	
	Song *aSong = nil;
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		aSong = [Song songFromDbRow:index inTable:@"jukeboxCurrentPlaylist" inDatabase:self.db];
	}
	else
	{
		if (musicControls.isShuffle)
			aSong = [Song songFromDbRow:index inTable:@"shufflePlaylist" inDatabase:self.db];
		else
			aSong = [Song songFromDbRow:index inTable:@"currentPlaylist" inDatabase:self.db];
	}
	
	//DLog(@"aSong: %@", aSong);
	return aSong;
}

- (Song *)currentSong
{
	return [self songForIndex:currentIndex];
}

- (Song *)nextSong
{
	switch (self.repeatMode) 
	{
		case ISMSRepeatMode_RepeatOne:
			return self.currentSong;
			break;
		case ISMSRepeatMode_RepeatAll:			
			if (self.currentIndex + 1 >= self.count)
				return [self songForIndex:0];
			else
				return [self songForIndex:(currentIndex + 1)];
			break;
		case ISMSRepeatMode_Normal:
		default:
			return [self songForIndex:(currentIndex + 1)];
			break;
	}
}

- (NSInteger)currentIndex
{
	NSInteger index;
	@synchronized(self.class)
	{
		index = currentIndex;
	}
	return index;
}

- (void)setCurrentIndex:(NSInteger)index
{
	@synchronized(self.class)
	{
		currentIndex = index;
	}
}

- (NSUInteger)count
{
	int count = 0;
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		count = [self.db intForQuery:@"SELECT COUNT(*) FROM jukeboxCurrentPlaylist"];
	}
	else
	{
		if ([MusicSingleton sharedInstance].isShuffle)
			count = [self.db intForQuery:@"SELECT COUNT(*) FROM shufflePlaylist"];
		else
			count = [self.db intForQuery:@"SELECT COUNT(*) FROM currentPlaylist"];
	}
	return count;
}

- (NSInteger)incrementIndex
{
	NSInteger index;
	@synchronized(self.class)
	{
		switch (self.repeatMode) 
		{
			case ISMSRepeatMode_RepeatOne:
				break;
			case ISMSRepeatMode_RepeatAll:			
				if (self.currentIndex + 1 >= self.count)
				{
					currentIndex = 0;
					break;
				}
			case ISMSRepeatMode_Normal:
			default:
				currentIndex++;
				break;
		}
		index = currentIndex;
	}
	return index;
}

- (ISMSRepeatMode)repeatMode
{
	ISMSRepeatMode aMode;
	@synchronized(self.class)
	{
		aMode = repeatMode;
	}
	return aMode;
}

- (void)setRepeatMode:(ISMSRepeatMode)mode
{
	@synchronized(self.class)
	{
		if (repeatMode != mode)
		{
			repeatMode = mode;
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_RepeatModeChanged];
		}
	}
}

- (void)shuffleToggle
{	
	@autoreleasepool
	{		
		MusicSingleton *musicControls = [MusicSingleton sharedInstance];
		SavedSettings *settings = [SavedSettings sharedInstance];
		
		if (musicControls.isShuffle)
		{
			MusicSingleton *musicControls = [MusicSingleton sharedInstance];
			musicControls.isShuffle = NO;
			
			if ([SavedSettings sharedInstance].isJukeboxEnabled)
			{
				[musicControls jukeboxReplacePlaylistWithLocal];
				//[musicControls playSongAtPosition:1];
			}
			else
			{
				[SUSCurrentPlaylistDAO dataModel].currentIndex = -1;
			}
			
			// Send a notification to update the playlist view
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistShuffleToggled];
		}
		else
		{
			Song *currentSong = self.currentSong;
			
			NSNumber *oldPlaylistPosition = [NSNumber numberWithInt:(self.currentIndex + 1)];
			self.currentIndex = 0;
			musicControls.isShuffle = YES;
			
			[self resetShufflePlaylist];
			[currentSong addToShuffleQueue];
			
			if (settings.isJukeboxEnabled)
			{
				[self.db executeUpdate:@"INSERT INTO jukeboxShufflePlaylist SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID != ? ORDER BY RANDOM()", oldPlaylistPosition];
			}
			else
			{
				[self.db executeUpdate:@"INSERT INTO shufflePlaylist SELECT * FROM currentPlaylist WHERE ROWID != ? ORDER BY RANDOM()", oldPlaylistPosition];
			}
			
			if (settings.isJukeboxEnabled)
			{
				[musicControls performSelectorOnMainThread:@selector(jukeboxReplacePlaylistWithLocal) withObject:nil waitUntilDone:YES];
				[musicControls performSelectorOnMainThread:@selector(jukeboxPlaySongAtPosition:) withObject:[NSNumber numberWithInt:1] waitUntilDone:YES];
				
				musicControls.isShuffle = NO;
			}
			
			// Send a notification to update the playlist view 
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistShuffleToggled];
		}
	}
}

@end
