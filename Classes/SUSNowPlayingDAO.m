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
		NSDictionary *songDict = [nowPlayingSongDicts objectAtIndex:index];
		Song *aSong = [songDict objectForKey:@"song"];
		return aSong;
	}
	return nil;
}

- (NSString *)playTimeForIndex:(NSUInteger)index
{
	if (index < self.count)
	{
		NSDictionary *songDict = [nowPlayingSongDicts objectAtIndex:index];
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
		NSDictionary *songDict = [nowPlayingSongDicts objectAtIndex:index];
		return [songDict objectForKey:@"username"];
	}
	return nil;
}

- (NSString *)playerNameForIndex:(NSUInteger)index
{
	if (index < self.count)
	{
		NSDictionary *songDict = [nowPlayingSongDicts objectAtIndex:index];
		return [songDict objectForKey:@"playerName"];
	}
	return nil;
}

- (void)playSongAtIndex:(NSUInteger)index
{
	PlaylistSingleton *currentPlaylist = [PlaylistSingleton sharedInstance];
	MusicSingleton *musicControls = [MusicSingleton sharedInstance];
	
	// Clear the current playlist
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
		[[DatabaseSingleton sharedInstance] resetJukeboxPlaylist];
	else
		[[DatabaseSingleton sharedInstance] resetCurrentPlaylistDb];
	
	// Add the song to the empty playlist
	Song *aSong = [self songForIndex:index];
	[aSong addToCurrentPlaylist];
	
	// If jukebox mode, send song ids to server
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		[musicControls jukeboxStop];
		[musicControls jukeboxClearPlaylist];
		[musicControls jukeboxAddSong:aSong.songId];
	}
	
	// Set player defaults
	currentPlaylist.isShuffle = NO;
	
	// Start the song
	[musicControls playSongAtPosition:0];
}

#pragma mark - Loader Manager Methods

- (void)restartLoad
{
    [self startLoad];
}

- (void)startLoad
{	
    self.loader = [[[SUSNowPlayingLoader alloc] initWithDelegate:self] autorelease];
    [loader startLoad];
}

- (void)cancelLoad
{
    [loader cancelLoad];
	loader.delegate = nil;
    self.loader = nil;
}

#pragma mark - Loader Delegate Methods

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error
{
	loader.delegate = nil;
	self.loader = nil;
	
	if ([delegate respondsToSelector:@selector(loadingFailed:withError:)])
	{
		[delegate loadingFailed:nil withError:error];
	}
}

- (void)loadingFinished:(SUSLoader*)theLoader
{
	self.nowPlayingSongDicts = [NSArray arrayWithArray:loader.nowPlayingSongDicts];
	
	loader.delegate = nil;
	self.loader = nil;
		
	if ([delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[delegate loadingFinished:nil];
	}
}

@end
