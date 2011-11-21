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

static NSUInteger currentIndex = 0;

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
	return [self songForIndex:(currentIndex + 1)];
}

- (NSInteger)currentIndex
{
	return currentIndex;
}

- (void)setCurrentIndex:(NSInteger)index
{
	currentIndex = index;
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

@end
