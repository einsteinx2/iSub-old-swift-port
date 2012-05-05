//
//  SUSNowPlayingDAO.m
//  iSub
//
//  Created by Ben Baron on 1/24/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSNowPlayingDAO.h"
#import "SUSNowPlayingLoader.h"
#import "Song.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "NSArray+Additions.h"
#import "JukeboxSingleton.h"
#import "NSNotificationCenter+MainThread.h"

@implementation SUSNowPlayingDAO
@synthesize delegate, loader, nowPlayingSongDicts;

- (id)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate
{
    if ((self = [super init])) 
	{
		delegate = theDelegate;
		nowPlayingSongDicts = nil;
    }
    
    return self;
}

- (void)dealloc
{
	[loader cancelLoad];
	loader.delegate = nil;
    loader = nil;
}

#pragma mark - Public DAO Methods

- (NSUInteger)count
{
	if (nowPlayingSongDicts)
		return [nowPlayingSongDicts count];
	
	return 0;
}

- (Song *)songForIndex:(NSUInteger)index
{
	if (index < self.count)
	{
		NSDictionary *songDict = [nowPlayingSongDicts objectAtIndexSafe:index];
		Song *aSong = [songDict objectForKey:@"song"];
		return aSong;
	}
	return nil;
}

- (NSString *)playTimeForIndex:(NSUInteger)index
{
	if (index < self.count)
	{
		NSDictionary *songDict = [nowPlayingSongDicts objectAtIndexSafe:index];
		NSUInteger minutesAgo = [[songDict objectForKey:@"minutesAgo"] intValue];
		
		if (minutesAgo == 1)
			return [NSString stringWithFormat:@"%i min ago", minutesAgo];
		else
			return [NSString stringWithFormat:@"%i mins ago", minutesAgo];
	}
	return nil;
}

- (NSString *)usernameForIndex:(NSUInteger)index
{
	if (index < self.count)
	{
		NSDictionary *songDict = [nowPlayingSongDicts objectAtIndexSafe:index];
		return [songDict objectForKey:@"username"];
	}
	return nil;
}

- (NSString *)playerNameForIndex:(NSUInteger)index
{
	if (index < self.count)
	{
		NSDictionary *songDict = [nowPlayingSongDicts objectAtIndexSafe:index];
		return [songDict objectForKey:@"playerName"];
	}
	return nil;
}

- (void)playSongAtIndex:(NSUInteger)index
{
	
	// Clear the current playlist
	if (settingsS.isJukeboxEnabled)
		[databaseS resetJukeboxPlaylist];
	else
		[databaseS resetCurrentPlaylistDb];
	
	// Add the song to the empty playlist
	Song *aSong = [self songForIndex:index];
	[aSong addToCurrentPlaylistDbQueue];
	
	// If jukebox mode, send song ids to server
	if (settingsS.isJukeboxEnabled)
	{
		[jukeboxS jukeboxStop];
		[jukeboxS jukeboxClearPlaylist];
		[jukeboxS jukeboxAddSong:aSong.songId];
	}
	
	// Set player defaults
	playlistS.isShuffle = NO;
	
	// Start the song
	[musicS playSongAtPosition:0];
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
}

#pragma mark - Loader Manager Methods

- (void)restartLoad
{
    [self startLoad];
}

- (void)startLoad
{	
    self.loader = [[SUSNowPlayingLoader alloc] initWithDelegate:self];
    [self.loader startLoad];
}

- (void)cancelLoad
{
    [self.loader cancelLoad];
	self.loader.delegate = nil;
    self.loader = nil;
}

#pragma mark - Loader Delegate Methods

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error
{
	self.loader.delegate = nil;
	self.loader = nil;
	
	if ([self.delegate respondsToSelector:@selector(loadingFailed:withError:)])
	{
		[self.delegate loadingFailed:nil withError:error];
	}
}

- (void)loadingFinished:(SUSLoader*)theLoader
{
	self.nowPlayingSongDicts = [NSArray arrayWithArray:self.loader.nowPlayingSongDicts];
	
	self.loader.delegate = nil;
	self.loader = nil;
		
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[self.delegate loadingFinished:nil];
	}
}

@end
