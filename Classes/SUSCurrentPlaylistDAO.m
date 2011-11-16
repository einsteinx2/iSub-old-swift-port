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
	DatabaseSingleton *databaseControls = [DatabaseSingleton sharedInstance];
	MusicSingleton *musicControls = [MusicSingleton sharedInstance];
	
	Song *aSong = nil;
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		aSong = [databaseControls songFromDbRow:index inTable:@"jukeboxCurrentPlaylist" inDatabase:self.db];
	}
	else
	{
		if (musicControls.isShuffle)
			aSong = [databaseControls songFromDbRow:index inTable:@"shufflePlaylist" inDatabase:self.db];
		else
			aSong = [databaseControls songFromDbRow:index inTable:@"currentPlaylist" inDatabase:self.db];
	}
	
	DLog(@"aSong: %@", aSong);
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

@end
