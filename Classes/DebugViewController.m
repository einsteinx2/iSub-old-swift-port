//
//  DebugViewController.m
//  iSub
//
//  Created by Ben Baron on 4/9/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "DebugViewController.h"
#import "MusicSingleton.h"
#import "SavedSettings.h"
#import "CacheSingleton.h"
#import "Song.h"
#import "PlaylistSingleton.h"
#import "NSNotificationCenter+MainThread.h"

@implementation DebugViewController
@synthesize currentSong, nextSong, currentSongProgress, nextSongProgress;

#pragma mark - Lifecycle

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	
	currentSongProgress = 0.;
	nextSongProgress = 0.;
		
	if (settingsS.isCacheUnlocked)
	{
		// Cache the song objects
		[self cacheSongObjects];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cacheSongObjects) 
													 name:ISMSNotification_SongPlaybackStarted object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cacheSongObjects) 
													 name:ISMSNotification_SongPlaybackEnded object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cacheSongObjects) 
													 name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
		
		// Set the fields
		[self updateStats];
	}
	else
	{
		// Display the unlock cache feature screen
		
		for (UIView *subView in self.view.subviews)
		{
			subView.hidden = YES;
		}
		songInfoToggleButton.enabled = NO;
		
		UIImageView *noCacheScreen = [[UIImageView alloc] init];
		noCacheScreen.userInteractionEnabled = YES;
		noCacheScreen.frame = CGRectMake(40, 80, 240, 180);
		noCacheScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
		
		UILabel *textLabel = [[UILabel alloc] init];
		textLabel.backgroundColor = [UIColor clearColor];
		textLabel.textColor = [UIColor whiteColor];
		textLabel.font = [UIFont boldSystemFontOfSize:32];
		textLabel.textAlignment = UITextAlignmentCenter;
		textLabel.numberOfLines = 0;
		textLabel.text = @"Caching\nLocked";
		textLabel.frame = CGRectMake(20, 0, 200, 100);
		[noCacheScreen addSubview:textLabel];
		
		UILabel *textLabel2 = [[UILabel alloc] init];
		textLabel2.backgroundColor = [UIColor clearColor];
		textLabel2.textColor = [UIColor whiteColor];
		textLabel2.font = [UIFont boldSystemFontOfSize:14];
		textLabel2.textAlignment = UITextAlignmentCenter;
		textLabel2.numberOfLines = 0;
		textLabel2.text = @"Tap to purchase the ability to cache songs for better streaming performance and offline playback";
		textLabel2.frame = CGRectMake(20, 90, 200, 70);
		[noCacheScreen addSubview:textLabel2];
		
		UIButton *storeLauncher = [UIButton buttonWithType:UIButtonTypeCustom];
		storeLauncher.frame = CGRectMake(0, 0, noCacheScreen.frame.size.width, noCacheScreen.frame.size.height);
		[storeLauncher addTarget:self action:@selector(showStore) forControlEvents:UIControlEventTouchUpInside];
		[noCacheScreen addSubview:storeLauncher];
		
		[self.view addSubview:noCacheScreen];
		
	}
}

- (void)showStore
{
	[NSNotificationCenter postNotificationToMainThreadWithName:@"player show store"];
}


- (void)viewDidDisappear:(BOOL)animated
{	
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	 currentSongProgressView = nil;
	 nextSongLabel = nil;
	 nextSongProgressView = nil;
	
	 songsCachedLabel = nil;
	 cacheSizeLabel = nil;
	 cacheSettingLabel = nil;
	 cacheSettingSizeLabel = nil;
	 freeSpaceLabel = nil;
	
	 songInfoToggleButton = nil;
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];	
}

#pragma mark -

- (void)cacheSongObjects
{
	self.currentSong = playlistS.currentDisplaySong;
	self.nextSong = playlistS.nextSong;
}
		 
- (void)updateStats
{
	if (!settingsS.isJukeboxEnabled)
	{
		// Set the current song progress bar
		if (![self.currentSong isTempCached])
			currentSongProgress = self.currentSong.downloadProgress;
		
		nextSongProgress = self.nextSong.downloadProgress;
	}
	
	if (settingsS.isJukeboxEnabled)
	{
		currentSongProgressView.progress = 0.0;
		currentSongProgressView.alpha = 0.2;
		
		nextSongProgressView.progress = 0.0;
		nextSongProgressView.alpha = 0.2;
	}
	else
	{
		// Set the current song progress bar
		if ([self.currentSong isTempCached])
		{
			currentSongProgressView.progress = 0.0;
			currentSongProgressView.alpha = 0.2;
		}
		else
		{
			currentSongProgressView.progress = currentSongProgress;
			currentSongProgressView.alpha = 1.0;
		}
				
		// Set the next song progress bar
		if (self.nextSong.path != nil)
		{
			// Make sure label and progress view aren't greyed out
			nextSongLabel.alpha = 1.0;
			nextSongProgressView.alpha = 1.0;
		}
		else
		{
			// There is no next song, so return 0 and grey out the label and progress view
			nextSongLabel.alpha = 0.2;
			nextSongProgressView.alpha = 0.2;
		}
		nextSongProgressView.progress = nextSongProgress;
	}
	
	// Set the number of songs cached label
	NSUInteger cachedSongs = cacheS.numberOfCachedSongs;
	if (cachedSongs == 1)
		songsCachedLabel.text = @"1 song";
	else
		songsCachedLabel.text = [NSString stringWithFormat:@"%i songs", cachedSongs];
	
	// Set the cache setting labels
	if (settingsS.cachingType == ISMSCachingType_minSpace)
	{
		cacheSettingLabel.text = @"Min Free Space:";
		cacheSettingSizeLabel.text = [NSString formatFileSize:settingsS.minFreeSpace];
	}
	else
	{
		cacheSettingLabel.text = @"Max Cache Size:";
		cacheSettingSizeLabel.text = [NSString formatFileSize:settingsS.maxCacheSize];
	}
	
	// Set the free space label
	freeSpaceLabel.text = [NSString formatFileSize:cacheS.freeSpace];
	
	// Set the cache size label
	cacheSizeLabel.text = [NSString formatFileSize:cacheS.cacheSize];
	
	[self performSelector:@selector(updateStats) withObject:nil afterDelay:1.0];
}

- (IBAction)songInfoToggle
{
	[NSNotificationCenter postNotificationToMainThreadWithName:@"hideSongInfo"];
}

@end
