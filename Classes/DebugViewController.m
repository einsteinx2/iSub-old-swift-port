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

@implementation DebugViewController

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	musicControls = [MusicSingleton sharedInstance];
	cacheControls = [CacheSingleton sharedInstance];
	settings = [SavedSettings sharedInstance];
		
	if (settings.isCacheUnlocked)
	{
		// Set the fields
		[self updateStats];
		
		// Setup the update timer
		updateTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateStats) userInfo:nil repeats:YES];
	}
	else
	{
		// Display the unlock cache feature screen
		
		UIImageView *noCacheScreen = [[UIImageView alloc] init];
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
		[textLabel release];
		
		UILabel *textLabel2 = [[UILabel alloc] init];
		textLabel2.backgroundColor = [UIColor clearColor];
		textLabel2.textColor = [UIColor whiteColor];
		textLabel2.font = [UIFont boldSystemFontOfSize:14];
		textLabel2.textAlignment = UITextAlignmentCenter;
		textLabel2.numberOfLines = 0;
		textLabel2.text = @"Tap to purchase the ability to cache songs for better streaming performance and offline playback";
		textLabel2.frame = CGRectMake(20, 90, 200, 70);
		[noCacheScreen addSubview:textLabel2];
		[textLabel2 release];
		
		[self.view addSubview:noCacheScreen];
		
		[noCacheScreen release];
	}
}

- (void) updateStats
{
	if (settings.isJukeboxEnabled)
	{
		currentSongProgressView.progress = 0.0;
		currentSongProgressView.alpha = 0.2;
		
		nextSongProgressView.progress = 0.0;
		nextSongProgressView.alpha = 0.2;
	}
	else
	{
		// Set the current song progress bar
		if (musicControls.isTempDownload)
		{
			currentSongProgressView.progress = 0.0;
			currentSongProgressView.alpha = 0.2;
		}
		else
		{
			currentSongProgressView.progress = [musicControls findCurrentSongProgress];
			currentSongProgressView.alpha = 1.0;
		}
		
		// Set the next song progress bar
		if (musicControls.nextSongObject.path != nil)
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
		nextSongProgressView.progress = [musicControls findNextSongProgress];
	}
	
	// Set the number of songs cached label
	NSUInteger cachedSongs = cacheControls.numberOfCachedSongs;
	if (cachedSongs == 1)
		songsCachedLabel.text = @"1 song";
	else
		songsCachedLabel.text = [NSString stringWithFormat:@"%i songs", cachedSongs];
	
	// Set the cache setting labels
	if (settings.cachingType == 0)
	{
		cacheSettingLabel.text = @"Min Free Space:";
		cacheSettingSizeLabel.text = [settings formatFileSize:settings.minFreeSpace];
	}
	else
	{
		cacheSettingLabel.text = @"Max Cache Size:";
		cacheSettingSizeLabel.text = [settings formatFileSize:settings.maxCacheSize];
	}
	
	// Set the free space label
	freeSpaceLabel.text = [settings formatFileSize:cacheControls.freeSpace];
	
	// Set the cache size label
	cacheSizeLabel.text = [settings formatFileSize:cacheControls.cacheSize];
}

- (IBAction) songInfoToggle
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"hideSongInfo" object:nil];
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)viewDidDisappear:(BOOL)animated
{
	NSLog(@"DebugViewController viewDidDisappear called");
	
	[updateTimer invalidate]; updateTimer = nil;
	
	[currentSongProgressView release]; currentSongProgressView = nil;
	[nextSongLabel release]; nextSongLabel = nil;
	[nextSongProgressView release]; nextSongProgressView = nil;
	
	[songsCachedLabel release]; songsCachedLabel = nil;
	[cacheSizeLabel release]; cacheSizeLabel = nil;
	[cacheSettingLabel release]; cacheSettingLabel = nil;
	[cacheSettingSizeLabel release]; cacheSettingSizeLabel = nil;
	[freeSpaceLabel release]; freeSpaceLabel = nil;
	
	[songInfoToggleButton release]; songInfoToggleButton = nil;
}


- (void)dealloc
{
	
	[super dealloc];
}


@end
