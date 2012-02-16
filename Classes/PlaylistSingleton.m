//
//  SUSCurrentPlaylistDAO.m
//  iSub
//
//  Created by Ben Baron on 11/14/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "PlaylistSingleton.h"
#import "Song.h"
#import "DatabaseSingleton.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "FMDatabaseAdditions.h"

#import "NSNotificationCenter+MainThread.h"
#import "AudioEngine.h"

@implementation PlaylistSingleton
@synthesize shuffleIndex, normalIndex, isShuffle;

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
		[self.db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", [Song standardSongColumnSchema]]];	
	}
	else
	{	
		[self.db executeUpdate:@"DROP TABLE currentPlaylist"];
		[self.db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentPlaylist (%@)", [Song standardSongColumnSchema]]];	
	}
}

- (void)resetShufflePlaylist
{
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		[self.db executeUpdate:@"DROP TABLE jukeboxShufflePlaylist"];
		[self.db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", [Song standardSongColumnSchema]]];	
	}
	else
	{	
		[self.db executeUpdate:@"DROP TABLE shufflePlaylist"];
		[self.db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shufflePlaylist (%@)", [Song standardSongColumnSchema]]];	
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
				[self.db executeUpdate:@"DROP TABLE IF EXISTS jukeboxTemp"];
				[self.db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxTemp(%@)", [Song standardSongColumnSchema]]];
				
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
			if (self.isShuffle)
			{
				if ([indexesMut count] == self.count)
				{
					[[DatabaseSingleton sharedInstance] resetCurrentPlaylistDb];
					self.isShuffle = NO;
				}
				else
				{
					[self.db executeUpdate:@"DROP TABLE IF EXISTS shuffleTemp"];
					[self.db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shuffleTemp(%@)", [Song standardSongColumnSchema]]];
					
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
					[self.db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentTemp(%@)", [Song standardSongColumnSchema]]];
					
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
		if ([indexesMut containsObject:[NSNumber numberWithInt:self.currentIndex]] && [AudioEngine sharedInstance].isPlaying)
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
		if (self.currentIndex < 0)
			self.currentIndex = 0;
		
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
		{
			[musicControls jukeboxReplacePlaylistWithLocal];
		}
		
		if (goToNextSong)
		{
			[self incrementIndex];
			[musicControls performSelectorOnMainThread:@selector(startSong) withObject:nil waitUntilDone:NO];
		}
		else
		{
			if (![SavedSettings sharedInstance].isJukeboxEnabled)
				[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistOrderChanged];
		}
	}
}

- (Song *)songForIndex:(NSUInteger)index
{
	Song *aSong = nil;
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		aSong = [Song songFromDbRow:index inTable:@"jukeboxCurrentPlaylist" inDatabase:self.db];
	}
	else
	{
		if (self.isShuffle)
			aSong = [Song songFromDbRow:index inTable:@"shufflePlaylist" inDatabase:self.db];
		else
			aSong = [Song songFromDbRow:index inTable:@"currentPlaylist" inDatabase:self.db];
	}
	
	return aSong;
}

- (Song *)prevSong
{
	Song *aSong = nil;
	@synchronized(self.class)
	{
		if (self.currentIndex - 1 >= 0)
			aSong = [self songForIndex:self.currentIndex-1];
	}
	return aSong;
}

- (Song *)currentDisplaySong
{
	// Either the current song, or the previous song if we're past the end of the playlist
	Song *aSong = self.currentSong;
	if (!aSong)
		aSong = self.prevSong;
	return aSong;
}

- (Song *)currentSong
{
	return [self songForIndex:self.currentIndex];	
}

- (Song *)nextSong
{
	//DLog(@"current index: %i   nextIndex: %i   nextSong: %@", self.currentIndex, self.nextIndex, [self songForIndex:self.nextIndex]);
	return [self songForIndex:self.nextIndex];
}

- (NSInteger)normalIndex
{
	@synchronized(self.class)
	{
		return normalIndex;
	}
}

- (void)setNormalIndex:(NSInteger)index
{
	@synchronized(self.class)
	{
		normalIndex = index;
	}
}

- (NSInteger)shuffleIndex
{
	@synchronized(self.class)
	{
		return shuffleIndex;
	}
}

- (void)setShuffleIndex:(NSInteger)index
{
	@synchronized(self.class)
	{
		shuffleIndex = index;
	}
}

- (NSInteger)currentIndex
{
	if (self.isShuffle)
		return self.shuffleIndex;
	
	return self.normalIndex;
}

- (void)setCurrentIndex:(NSInteger)index
{
	if (self.isShuffle)
		self.shuffleIndex = index;
	else
		self.normalIndex = index;
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistIndexChanged];
}

- (NSInteger)nextIndex
{
	@synchronized(self.class)
	{
		switch (self.repeatMode) 
		{
			case ISMSRepeatMode_RepeatOne:
				return self.currentIndex;
				break;
			case ISMSRepeatMode_RepeatAll:	
				if ([self songForIndex:self.currentIndex + 1])
					return self.currentIndex + 1;
				else
					return 0;
				break;
			case ISMSRepeatMode_Normal:
				return self.currentIndex + 1;
			default:
				break;
		}
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
		if (self.isShuffle)
			count = [self.db intForQuery:@"SELECT COUNT(*) FROM shufflePlaylist"];
		else
			count = [self.db intForQuery:@"SELECT COUNT(*) FROM currentPlaylist"];
	}
	return count;
}

- (NSInteger)incrementIndex
{
	@synchronized(self.class)
	{
		self.currentIndex = self.nextIndex;
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistIndexChanged];
		return self.currentIndex;
	}
}

- (ISMSRepeatMode)repeatMode
{
	@synchronized(self.class)
	{
		return repeatMode;
	}
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
		
		if (self.isShuffle)
		{
			self.isShuffle = NO;
			
			if (settings.isJukeboxEnabled)
			{
				[musicControls jukeboxReplacePlaylistWithLocal];
				//[musicControls playSongAtPosition:];
			}
			
			// Send a notification to update the playlist view
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistShuffleToggled];
		}
		else
		{
			Song *currentSong = self.currentSong;
			
			NSNumber *oldPlaylistPosition = [NSNumber numberWithInt:(self.currentIndex + 1)];
			self.shuffleIndex = 0;
			self.isShuffle = YES;
			
			[self resetShufflePlaylist];
			[currentSong addToShufflePlaylist];
			
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
				[musicControls performSelectorOnMainThread:@selector(jukeboxReplacePlaylistWithLocal) 
												withObject:nil 
											 waitUntilDone:YES];
				
				[musicControls performSelectorOnMainThread:@selector(jukeboxPlaySongAtPosition:)
												withObject:[NSNumber numberWithInt:1] 
											 waitUntilDone:YES];
				
				self.isShuffle = NO;
			}
			
			// Send a notification to update the playlist view 
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistShuffleToggled];
		}
	}
}

#pragma mark - Singleton methods

static PlaylistSingleton *sharedInstance = nil;

- (void)setup
{
	shuffleIndex = 0;
	normalIndex = 0;
	repeatMode = ISMSRepeatMode_Normal;
}

+ (PlaylistSingleton *)sharedInstance
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
	if ((self = [super init]))
	{
		[self setup];
		sharedInstance = self;
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
