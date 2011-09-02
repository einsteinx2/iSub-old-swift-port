//
//  DebugViewController.m
//  iSub
//
//  Created by Ben Baron on 4/9/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "DebugViewController.h"
#import "iSubAppDelegate.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "ViewObjectsSingleton.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString-md5.h"
#import "Song.h"
#import "SavedSettings.h"
#import "CacheSingleton.h"

@implementation DebugViewController

//@synthesize currentSongProgressView, nextSongProgressView;
//@synthesize songsCachedLabel, cacheSizeLabel, freeSpaceLabel;
//@synthesize songInfoToggleButton;

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	musicControls = [MusicSingleton sharedInstance];
	databaseControls = [DatabaseSingleton sharedInstance];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	
	// Set the fields
	[self updateStats];
	[self updateStats2];
	
	// Setup the update timer
	updateTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateStats) userInfo:nil repeats:YES];
	updateTimer2 = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(updateStats2) userInfo:nil repeats:YES];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidUnload) name:@"hideSongInfoFast" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidUnload) name:@"hideSongInfo" object:nil];
	
	if ([SavedSettings sharedInstance].isCacheUnlocked == NO)
	{
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
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
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
	NSInteger cachedSongs = [databaseControls.songCacheDb intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE finished = 'YES'"];
	if (cachedSongs == 1)
		songsCachedLabel.text = @"1 song";
	else
		songsCachedLabel.text = [NSString stringWithFormat:@"%i songs", cachedSongs];
	
	// Set the cache setting labels
	//if ([[appDelegate.settingsDictionary objectForKey:@"cachingTypeSetting"] intValue] == 0)
	if ([SavedSettings sharedInstance].cachingType == 0)
	{
		cacheSettingLabel.text = @"Min Free Space:";
		//cacheSettingSizeLabel.text = [appDelegate formatFileSize:[[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] unsignedLongLongValue]];
		cacheSettingSizeLabel.text = [appDelegate formatFileSize:[SavedSettings sharedInstance].minFreeSpace];
	}
	else
	{
		cacheSettingLabel.text = @"Max Cache Size:";
		//cacheSettingSizeLabel.text = [appDelegate formatFileSize:[[appDelegate.settingsDictionary objectForKey:@"maxCacheSize"] unsignedLongLongValue]];
		cacheSettingSizeLabel.text = [appDelegate formatFileSize:[SavedSettings sharedInstance].maxCacheSize];
	}
	
	// Set the free space label
	freeSpaceLabel.text = [appDelegate formatFileSize:[CacheSingleton sharedInstance].freeSpace];
}

- (void) updateStats2
{
	[self performSelectorInBackground:@selector(updateCacheSizeLabel) withObject:nil];
}

- (void) updateCacheSizeLabel
{
	// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	NSString *size = [appDelegate formatFileSize:[CacheSingleton sharedInstance].cacheSize];
	[self performSelectorOnMainThread:@selector(updateCacheSizeLabel2:) withObject:size waitUntilDone:NO];
	
	[autoreleasePool release];
}

- (void) updateCacheSizeLabel2:(NSString *)size
{
	cacheSizeLabel.text = size;
}


/*- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
}


- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}*/


- (IBAction) songInfoToggle
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"hideSongInfo" object:nil];
}



- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload 
{
    [super viewDidUnload];
	
	//[[NSNotificationCenter defaultCenter] removeObserver:self name:@"queuedBuffers" object:nil];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewDidDisappear:(BOOL)animated
{
	NSLog(@"DebugViewController viewDidDisappear called");
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideSongInfoFast" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideSongInfo" object:nil];
	
	[updateTimer invalidate]; updateTimer = nil;
	[updateTimer2 invalidate]; updateTimer2 = nil;
	
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


- (void)dealloc {
	
	[super dealloc];
}


@end
