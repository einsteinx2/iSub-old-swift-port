//
//  SettingsTabViewController.m
//  iSub
//
//  Created by Ben Baron on 6/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SettingsTabViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicControlsSingleton.h"
#import "SocialControlsSingleton.h"
#import "DatabaseControlsSingleton.h"

#import "SA_OAuthTwitterEngine.h"
#import "SA_OAuthTwitterController.h"

#import "UIDevice-Hardware.h"
#import "iPadMainMenu.h"

#import "NSString+md5.h"
#import "FMDatabase.h"

@implementation SettingsTabViewController

@synthesize parentController, loadedTime;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if ([[[iSubAppDelegate sharedInstance].settingsDictionary objectForKey:@"lockRotationSetting"] isEqualToString:@"YES"])
		return NO;
	
    return YES;
}

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}
*/

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	// Fix for UISwitch/UISegment bug in iOS 4.3 beta 1 and 2
	//
	self.loadedTime = [NSDate date];
	
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicControlsSingleton sharedInstance];
	socialControls = [SocialControlsSingleton sharedInstance];
	databaseControls = [DatabaseControlsSingleton sharedInstance];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTwitterUIElements) name:@"twitterAuthenticated" object:nil];
	
	// Set version label
	NSString* version = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
	versionLabel.text = [NSString stringWithFormat:@"iSub version %@%@", version, BETA_VERSION];
	
	// Main Settings
	if ([[appDelegate.settingsDictionary objectForKey:@"enableScrobblingSetting"] isEqualToString:@"YES"])
		enableScrobblingSwitch.on = YES;
	else
		enableScrobblingSwitch.on = NO;
	
	scrobblePercentSlider.value = [[appDelegate.settingsDictionary objectForKey:@"scrobblePercentSetting"] floatValue];
	[self updateScrobblePercentLabel];
	
	if ([[appDelegate.settingsDictionary objectForKey:@"manualOfflineModeSetting"] isEqualToString:@"YES"])
		manualOfflineModeSwitch.on = YES;
	else
		manualOfflineModeSwitch.on = NO;
	
	if ([[appDelegate.settingsDictionary objectForKey:@"checkUpdatesSetting"] isEqualToString:@"YES"])
		checkUpdatesSwitch.on = YES;
	else
		checkUpdatesSwitch.on = NO;
	
	if ([[appDelegate.settingsDictionary objectForKey:@"autoReloadArtistsSetting"] isEqualToString:@"YES"])
		autoReloadArtistSwitch.on = YES;
	else
		autoReloadArtistSwitch.on = NO;
	
	if ([[appDelegate.settingsDictionary objectForKey:@"disablePopupsSetting"] isEqualToString:@"YES"])
		disablePopupsSwitch.on = YES;
	else
		disablePopupsSwitch.on = NO;
	
	/*if ([[UIDevice currentDevice] isOldDevice])
	{
		enableSongsTabSwitch.enabled = NO;
		enableSongsTabSwitch.hidden = YES;
		enableSongsTabLabel.hidden = YES;
		enableSongsTabDesc.hidden = YES;
	}*/
	
	if ([[appDelegate.settingsDictionary objectForKey:@"enableSongsTabSetting"] isEqualToString:@"YES"])
		enableSongsTabSwitch.on = YES;
	else
		enableSongsTabSwitch.on = NO;
	
	recoverSegmentedControl.selectedSegmentIndex = [[appDelegate.settingsDictionary objectForKey:@"recoverSetting"] intValue];
	
	//maxBitrateSegmentedControl.selectedSegmentIndex = [[appDelegate.settingsDictionary objectForKey:@"maxBitrateSetting"] intValue];
	maxBitrateWifiSegmentedControl.selectedSegmentIndex = [[appDelegate.settingsDictionary objectForKey:@"maxBitrateWifiSetting"] intValue];
	maxBitrate3GSegmentedControl.selectedSegmentIndex = [[appDelegate.settingsDictionary objectForKey:@"maxBitrate3GSetting"] intValue];
	
	if ([[appDelegate.settingsDictionary objectForKey:@"autoPlayerInfoSetting"] isEqualToString:@"YES"])
		autoPlayerInfoSwitch.on = YES;
	else
		autoPlayerInfoSwitch.on = NO;
	
	if ([[appDelegate.settingsDictionary objectForKey:@"lyricsEnabledSetting"] isEqualToString:@"YES"])
		enableLyricsSwitch.on = YES;
	else
		enableLyricsSwitch.on = NO;
	
	// Cache Settings
	if ([[appDelegate.settingsDictionary objectForKey:@"enableSongCachingSetting"] isEqualToString:@"YES"])
		enableSongCachingSwitch.on = YES;
	else
		enableSongCachingSwitch.on = NO;
	
	if ([[appDelegate.settingsDictionary objectForKey:@"enableNextSongCacheSetting"] isEqualToString:@"YES"])
		enableNextSongCacheSwitch.on = YES;
	else
		enableNextSongCacheSwitch.on = NO;
		
	totalSpace = [[[[NSFileManager defaultManager] attributesOfFileSystemForPath:musicControls.audioFolderPath error:NULL] objectForKey:NSFileSystemSize] unsignedLongLongValue];
	freeSpace = [[[[NSFileManager defaultManager] attributesOfFileSystemForPath:musicControls.audioFolderPath error:NULL] objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
	freeSpaceLabel.text = [NSString stringWithFormat:@"Free space: %@", [appDelegate formatFileSize:freeSpace]];
	totalSpaceLabel.text = [NSString stringWithFormat:@"Total space: %@", [appDelegate formatFileSize:totalSpace]];
	float percentFree = (float) freeSpace / (float) totalSpace;
	CGRect frame = freeSpaceBackground.frame;
	frame.size.width = frame.size.width * percentFree;
	freeSpaceBackground.frame = frame;
	//cacheSpaceSlider.value = [[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] floatValue] / totalSpace;
	cachingTypeSegmentedControl.selectedSegmentIndex = [[appDelegate.settingsDictionary objectForKey:@"cachingTypeSetting"] intValue];
	[self toggleCacheControlsVisibility];
	[self cachingTypeToggle];
	
	if ([[appDelegate.settingsDictionary objectForKey:@"autoDeleteCacheSetting"] isEqualToString:@"YES"])
		autoDeleteCacheSwitch.on = YES;
	else
		autoDeleteCacheSwitch.on = NO;
	
	autoDeleteCacheTypeSegmentedControl.selectedSegmentIndex = [[appDelegate.settingsDictionary objectForKey:@"autoDeleteCacheTypeSetting"] intValue];
	
	cacheSongCellColorSegmentedControl.selectedSegmentIndex = [[appDelegate.settingsDictionary objectForKey:@"cacheSongCellColorSetting"] intValue];
	
	// Twitter settings
	if (socialControls.twitterEngine)
	{
		twitterEnabledSwitch.enabled = YES;
		if ([[appDelegate.settingsDictionary objectForKey:@"twitterEnabledSetting"] isEqualToString:@"YES"])
			twitterEnabledSwitch.on = YES;
		else
			twitterEnabledSwitch.on = NO;
		
		twitterSigninButton.imageView.image = [UIImage imageNamed:@"twitter-signout.png"];
		
		twitterStatusLabel.text = [NSString stringWithFormat:@"%@ signed in", [socialControls.twitterEngine username]];
	}
	else
	{
		twitterEnabledSwitch.on = NO;
		twitterEnabledSwitch.enabled = NO;
		
		twitterSigninButton.imageView.image = [UIImage imageNamed:@"twitter-signin.png"];
		
		twitterStatusLabel.text = @"Signed out";
	}
	
	
	// Handle In App Purchase settings
	if (viewObjects.isCacheUnlocked == NO)
	{
		// Caching is disabled, so disable the controls
		enableSongCachingSwitch.enabled = NO; enableSongCachingSwitch.alpha = 0.5;
		enableNextSongCacheSwitch.enabled = NO; enableNextSongCacheSwitch.alpha = 0.5;
		cachingTypeSegmentedControl.enabled = NO; cachingTypeSegmentedControl.alpha = 0.5;
		cacheSpaceSlider.enabled = NO; cacheSpaceSlider.alpha = 0.5;
		autoDeleteCacheSwitch.enabled = NO; autoDeleteCacheSwitch.alpha = 0.5;
		autoDeleteCacheTypeSegmentedControl.enabled = NO; autoDeleteCacheTypeSegmentedControl.alpha = 0.5;
		cacheSongCellColorSegmentedControl.enabled = NO; cacheSongCellColorSegmentedControl.alpha = 0.5;
	}
	
	/*[manualOfflineModeSwitch addTarget:self action:@selector(switchAction:) forControlEvents:UIControlEventValueChanged];
	[checkUpdatesSwitch addTarget:self action:@selector(switchAction:) forControlEvents:UIControlEventValueChanged];
	[autoReloadArtistSwitch addTarget:self action:@selector(switchAction:) forControlEvents:UIControlEventValueChanged];
	[enableSongsTabSwitch addTarget:self action:@selector(switchAction:) forControlEvents:UIControlEventValueChanged];
	[enableLyricsSwitch addTarget:self action:@selector(switchAction:) forControlEvents:UIControlEventValueChanged];
	[autoPlayerInfoSwitch addTarget:self action:@selector(switchAction:) forControlEvents:UIControlEventValueChanged];
	[enableSongCachingSwitch addTarget:self action:@selector(switchAction:) forControlEvents:UIControlEventValueChanged];
	[enableNextSongCacheSwitch addTarget:self action:@selector(switchAction:) forControlEvents:UIControlEventValueChanged];
	[cacheSpaceSlider addTarget:self action:@selector(switchAction:) forControlEvents:UIControlEventValueChanged];
	[autoDeleteCacheSwitch addTarget:self action:@selector(switchAction:) forControlEvents:UIControlEventValueChanged];
	[twitterEnabledSwitch addTarget:self action:@selector(switchAction:) forControlEvents:UIControlEventValueChanged];*/
}

/*- (void)viewWillAppear:(BOOL)animated
{
	if ([[appDelegate.settingsDictionary objectForKey:@"manualOfflineModeSetting"] isEqualToString:@"YES"])
		manualOfflineModeSwitch.on = YES;
	else
		manualOfflineModeSwitch.on = NO;
}*/

- (void) reloadTwitterUIElements
{
	if (socialControls.twitterEngine)
	{
		twitterEnabledSwitch.enabled = YES;
		if ([[appDelegate.settingsDictionary objectForKey:@"twitterEnabledSetting"] isEqualToString:@"YES"])
			twitterEnabledSwitch.on = YES;
		else
			twitterEnabledSwitch.on = NO;
		
		twitterSigninButton.imageView.image = [UIImage imageNamed:@"twitter-signout.png"];
		
		twitterStatusLabel.text = [NSString stringWithFormat:@"%@ signed in", [socialControls.twitterEngine username]];
	}
	else
	{
		twitterEnabledSwitch.on = NO;
		twitterEnabledSwitch.enabled = NO;
		
		twitterSigninButton.imageView.image = [UIImage imageNamed:@"twitter-signin.png"];

		twitterStatusLabel.text = @"Signed out";
	}
}

- (void) cachingTypeToggle
{
	if (cachingTypeSegmentedControl.selectedSegmentIndex == 0)
	{
		cacheSpaceLabel1.text = @"Minimum free space:";
		cacheSpaceLabel2.text = [appDelegate formatFileSize:[[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] unsignedLongLongValue]];
		cacheSpaceSlider.value = [[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] floatValue] / totalSpace;
	}
	else if (cachingTypeSegmentedControl.selectedSegmentIndex == 1)
	{
		cacheSpaceLabel1.text = @"Maximum cache size:";
		cacheSpaceLabel2.text = [appDelegate formatFileSize:[[appDelegate.settingsDictionary objectForKey:@"maxCacheSize"] unsignedLongLongValue]];
		cacheSpaceSlider.value = [[appDelegate.settingsDictionary objectForKey:@"maxCacheSize"] floatValue] / totalSpace;
	}
}

- (IBAction) segmentAction:(id)sender
{
	if ([[NSDate date] timeIntervalSinceDate:loadedTime] > 0.5)
	{
		if (sender == recoverSegmentedControl)
		{
			[appDelegate.settingsDictionary setObject:[NSNumber numberWithInt:recoverSegmentedControl.selectedSegmentIndex] forKey:@"recoverSetting"];
		}
		//else if (sender == maxBitrateSegmentedControl)
		//{
		//	[appDelegate.settingsDictionary setObject:[NSNumber numberWithInt:maxBitrateSegmentedControl.selectedSegmentIndex] forKey:@"maxBitrateSetting"];
		//}
		else if (sender == maxBitrateWifiSegmentedControl)
		{
			[appDelegate.settingsDictionary setObject:[NSNumber numberWithInt:maxBitrateWifiSegmentedControl.selectedSegmentIndex] forKey:@"maxBitrateWifiSetting"];
		}
		else if (sender == maxBitrate3GSegmentedControl)
		{
			[appDelegate.settingsDictionary setObject:[NSNumber numberWithInt:maxBitrate3GSegmentedControl.selectedSegmentIndex] forKey:@"maxBitrate3GSetting"];
		}
		else if (sender == cachingTypeSegmentedControl)
		{
			[appDelegate.settingsDictionary setObject:[NSNumber numberWithInt:cachingTypeSegmentedControl.selectedSegmentIndex] forKey:@"cachingTypeSetting"];
			[self cachingTypeToggle];
		}
		else if (sender == autoDeleteCacheTypeSegmentedControl)
		{
			[appDelegate.settingsDictionary setObject:[NSNumber numberWithInt:autoDeleteCacheTypeSegmentedControl.selectedSegmentIndex] forKey:@"autoDeleteCacheTypeSetting"];
		}
		else if (sender == cacheSongCellColorSegmentedControl)
		{
			[appDelegate.settingsDictionary setObject:[NSNumber numberWithInt:cacheSongCellColorSegmentedControl.selectedSegmentIndex] forKey:@"cacheSongCellColorSetting"];
		}
		
		[[NSUserDefaults standardUserDefaults] setObject:appDelegate.settingsDictionary forKey:@"settingsDictionary"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}

- (void) toggleCacheControlsVisibility
{
	if (enableSongCachingSwitch.on)
	{
		enableNextSongCacheLabel.alpha = 1;
		enableNextSongCacheSwitch.enabled = YES;
		enableNextSongCacheSwitch.alpha = 1;
		cachingTypeSegmentedControl.enabled = YES;
		cachingTypeSegmentedControl.alpha = 1;
		cacheSpaceLabel1.alpha = 1;
		cacheSpaceLabel2.alpha = 1;
		freeSpaceLabel.alpha = 1;
		totalSpaceLabel.alpha = 1;
		totalSpaceBackground.alpha = .7;
		freeSpaceBackground.alpha = .7;
		cacheSpaceSlider.enabled = YES;
		cacheSpaceSlider.alpha = 1;
		cacheSpaceDescLabel.alpha = 1;
	}
	else
	{
		enableNextSongCacheLabel.alpha = .5;
		enableNextSongCacheSwitch.enabled = NO;
		enableNextSongCacheSwitch.alpha = .5;
		cachingTypeSegmentedControl.enabled = NO;
		cachingTypeSegmentedControl.alpha = .5;
		cacheSpaceLabel1.alpha = .5;
		cacheSpaceLabel2.alpha = .5;
		freeSpaceLabel.alpha = .5;
		totalSpaceLabel.alpha = .5;
		totalSpaceBackground.alpha = .3;
		freeSpaceBackground.alpha = .3;
		cacheSpaceSlider.enabled = NO;
		cacheSpaceSlider.alpha = .5;
		cacheSpaceDescLabel.alpha = .5;
	}
}

- (IBAction) switchAction:(id)sender
{
	if ([[NSDate date] timeIntervalSinceDate:loadedTime] > 0.5)
	{
		if (sender == manualOfflineModeSwitch)
		{
			if (manualOfflineModeSwitch.on)
			{
				[appDelegate.settingsDictionary setObject:@"YES" forKey:@"manualOfflineModeSetting"];
				[appDelegate enterOfflineModeForce];
			}
			else
			{
				[appDelegate.settingsDictionary setObject:@"NO" forKey:@"manualOfflineModeSetting"];
				[appDelegate enterOnlineModeForce];
			}
			
			// Handle the moreNavigationController stupidity
			if (appDelegate.currentTabBarController.selectedIndex == 4)
			{
				[appDelegate.currentTabBarController.moreNavigationController popToViewController:[appDelegate.currentTabBarController.moreNavigationController.viewControllers objectAtIndex:1] animated:YES];
			}
			else
			{
				[(UINavigationController*)appDelegate.currentTabBarController.selectedViewController popToRootViewControllerAnimated:YES];
			}
		}
		else if (sender == enableScrobblingSwitch)
		{
			if (enableScrobblingSwitch.on)
				[appDelegate.settingsDictionary setObject:@"YES" forKey:@"enableScrobblingSetting"];
			else
				[appDelegate.settingsDictionary setObject:@"NO" forKey:@"enableScrobblingSetting"];
		}
		else if (sender == enableSongCachingSwitch)
		{
			if (enableSongCachingSwitch.on)
			{
				[appDelegate.settingsDictionary setObject:@"YES" forKey:@"enableSongCachingSetting"];
				[self toggleCacheControlsVisibility];
			}
			else
			{
				[appDelegate.settingsDictionary setObject:@"NO" forKey:@"enableSongCachingSetting"];
				[self toggleCacheControlsVisibility];
			}
		}
		else if (sender == enableNextSongCacheSwitch)
		{
			if (enableNextSongCacheSwitch.on)
				[appDelegate.settingsDictionary setObject:@"YES" forKey:@"enableNextSongCacheSetting"];
			else
				[appDelegate.settingsDictionary setObject:@"NO" forKey:@"enableNextSongCacheSetting"];
		}
		else if (sender == autoDeleteCacheSwitch)
		{
			if (autoDeleteCacheSwitch.on)
				[appDelegate.settingsDictionary setObject:@"YES" forKey:@"autoDeleteCacheSetting"];
			else
				[appDelegate.settingsDictionary setObject:@"NO" forKey:@"autoDeleteCacheSetting"];
		}
		else if (sender == twitterEnabledSwitch)
		{
			if (twitterEnabledSwitch.on)
				[appDelegate.settingsDictionary setObject:@"YES" forKey:@"twitterEnabledSetting"];
			else
				[appDelegate.settingsDictionary setObject:@"NO" forKey:@"twitterEnabledSetting"];
		}
		else if (sender == checkUpdatesSwitch)
		{
			if (checkUpdatesSwitch.on)
				[appDelegate.settingsDictionary setObject:@"YES" forKey:@"checkUpdatesSetting"];
			else
				[appDelegate.settingsDictionary setObject:@"NO" forKey:@"checkUpdatesSetting"];
		}
		else if (sender == enableLyricsSwitch)
		{
			if (enableLyricsSwitch.on)
				[appDelegate.settingsDictionary setObject:@"YES" forKey:@"lyricsEnabledSetting"];
			else
				[appDelegate.settingsDictionary setObject:@"NO" forKey:@"lyricsEnabledSetting"];
		}
		else if (sender == autoPlayerInfoSwitch)
		{
			if (autoPlayerInfoSwitch.on)
				[appDelegate.settingsDictionary setObject:@"YES" forKey:@"autoPlayerInfoSetting"];
			else
				[appDelegate.settingsDictionary setObject:@"NO" forKey:@"autoPlayerInfoSetting"];
		}
		else if (sender == autoReloadArtistSwitch)
		{
			if (autoReloadArtistSwitch.on)
				[appDelegate.settingsDictionary setObject:@"YES" forKey:@"autoReloadArtistsSetting"];
			else
				[appDelegate.settingsDictionary setObject:@"NO" forKey:@"autoReloadArtistsSetting"];
		}
		else if (sender == disablePopupsSwitch)
		{
			if (disablePopupsSwitch.on)
				[appDelegate.settingsDictionary setObject:@"YES" forKey:@"disablePopupsSetting"];
			else
				[appDelegate.settingsDictionary setObject:@"NO" forKey:@"disablePopupsSetting"];
		}
		else if (sender == enableSongsTabSwitch)
		{
			if (enableSongsTabSwitch.on)
			{
				[appDelegate.settingsDictionary setObject:@"YES" forKey:@"enableSongsTabSetting"];
				
				if (IS_IPAD())
				{
					[appDelegate.mainMenu loadTable];
				}
				else
				{
					NSMutableArray *controllers = [NSMutableArray arrayWithArray:appDelegate.mainTabBarController.viewControllers];
					[controllers addObject:appDelegate.allAlbumsNavigationController];
					[controllers addObject:appDelegate.allSongsNavigationController];
					[controllers addObject:appDelegate.genresNavigationController];
					appDelegate.mainTabBarController.viewControllers = controllers;
				}
				
				// Setup the allAlbums database
				databaseControls.allAlbumsDb = [FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@allAlbums.db", databaseControls.databaseFolderPath, [NSString md5:appDelegate.defaultUrl]]];
				[databaseControls.allAlbumsDb executeUpdate:@"PRAGMA cache_size = 1"];
				if ([databaseControls.allAlbumsDb open] == NO) { NSLog(@"Could not open allAlbumsDb."); }
				
				// Setup the allSongs database
				databaseControls.allSongsDb = [FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@allSongs.db", databaseControls.databaseFolderPath, [NSString md5:appDelegate.defaultUrl]]];
				[databaseControls.allSongsDb executeUpdate:@"PRAGMA cache_size = 1"];
				if ([databaseControls.allSongsDb open] == NO) { NSLog(@"Could not open allSongsDb."); }
				
				// Setup the Genres database
				databaseControls.genresDb = [FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@genres.db", databaseControls.databaseFolderPath, [NSString md5:appDelegate.defaultUrl]]];
				[databaseControls.genresDb executeUpdate:@"PRAGMA cache_size = 1"];
				if ([databaseControls.genresDb open] == NO) { NSLog(@"Could not open genresDb."); }
			}
			else
			{
				[appDelegate.settingsDictionary setObject:@"NO" forKey:@"enableSongsTabSetting"];

				if (IS_IPAD())
					[appDelegate.mainMenu loadTable];
				else
					[viewObjects orderMainTabBarController];
				
				[databaseControls.allAlbumsDb close];
				[databaseControls.allSongsDb close];
				[databaseControls.genresDb close];
			}
		}
		
		[[NSUserDefaults standardUserDefaults] setObject:appDelegate.settingsDictionary forKey:@"settingsDictionary"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}

- (IBAction) updateMinFreeSpaceLabel
{
	//NSLog(@"cacheSpaceSlider.value: %f", cacheSpaceSlider.value);
	cacheSpaceLabel2.text = [appDelegate formatFileSize:(unsigned long long int) (cacheSpaceSlider.value * totalSpace)];
}

- (IBAction) updateMinFreeSpaceSetting
{
	//NSLog(@"cacheSpaceSlider.value: %f", cacheSpaceSlider.value);
	if (cachingTypeSegmentedControl.selectedSegmentIndex == 0)
	{
		// Check if the user is trying to assing a higher min free space than is available space - 50MB
		if (cacheSpaceSlider.value * totalSpace > freeSpace - 52428800)
		{
			[appDelegate.settingsDictionary setObject:[NSNumber numberWithLongLong:freeSpace] forKey:@"minFreeSpace"];
			cacheSpaceLabel2.text = [appDelegate formatFileSize:[[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] unsignedLongLongValue]];
			cacheSpaceSlider.value = ( (float)freeSpace / (float)totalSpace ) - 52428800.0; // Leave 50MB space
		}
		else 
		{
			[appDelegate.settingsDictionary setObject:[NSNumber numberWithLongLong:(unsigned long long int) (cacheSpaceSlider.value * totalSpace)] forKey:@"minFreeSpace"];
			cacheSpaceLabel2.text = [appDelegate formatFileSize:[[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] unsignedLongLongValue]];
		}
	}
	else if (cachingTypeSegmentedControl.selectedSegmentIndex == 1)
	{
		
		// Check if the user is trying to assign a larger max cache size than there is available space - 50MB
		if (cacheSpaceSlider.value * totalSpace > freeSpace - 52428800)
		{
			[appDelegate.settingsDictionary setObject:[NSNumber numberWithLongLong:(freeSpace - 52428800)] forKey:@"minFreeSpace"];
			cacheSpaceLabel2.text = [appDelegate formatFileSize:[[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] unsignedLongLongValue]];
			cacheSpaceSlider.value = ( (float)freeSpace / (float)totalSpace ) - 52428800.0; // Leave 50MB space
		}
		else
		{
			[appDelegate.settingsDictionary setObject:[NSNumber numberWithLongLong:(unsigned long long int) (cacheSpaceSlider.value * totalSpace)] forKey:@"maxCacheSize"];
			cacheSpaceLabel2.text = [appDelegate formatFileSize:[[appDelegate.settingsDictionary objectForKey:@"maxCacheSize"] unsignedLongLongValue]];
		}
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:appDelegate.settingsDictionary forKey:@"settingsDictionary"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (IBAction) revertMinFreeSpaceSlider
{
	//NSLog(@"revertMinFreeSpaceSlider");
	cacheSpaceLabel2.text = [appDelegate formatFileSize:[[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] unsignedLongLongValue]];
	cacheSpaceSlider.value = [[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] floatValue] / totalSpace;
}

- (IBAction) twitterButtonAction
{
	if (socialControls.twitterEngine)
	{
		//[appDelegate.twitterEngine endUserSession];
		socialControls.twitterEngine = nil;
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"twitterAuthData"];
		[self reloadTwitterUIElements];
	}
	else
	{
		[socialControls createTwitterEngine];
		
		UIViewController *controller = [SA_OAuthTwitterController controllerToEnterCredentialsWithTwitterEngine:socialControls.twitterEngine delegate:socialControls];
		if (controller) 
		{
			if (IS_IPAD())
				[appDelegate.splitView presentModalViewController:controller animated:YES];
			else
				[self.parentController presentModalViewController:controller animated:YES];
		}
	}
}

- (IBAction) updateScrobblePercentLabel
{
	NSUInteger percentInt = scrobblePercentSlider.value * 100;
	scrobblePercentLabel.text = [NSString stringWithFormat:@"%i", percentInt];
}

- (IBAction) updateScrobblePercentSetting;
{
	NSNumber *percent = [NSNumber numberWithFloat:scrobblePercentSlider.value];
	[appDelegate.settingsDictionary setObject:percent forKey:@"scrobblePercentSetting"];
	
	[[NSUserDefaults standardUserDefaults] setObject:appDelegate.settingsDictionary forKey:@"settingsDictionary"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
	//NSLog(@"settigns tab view did unload");
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"twitterAuthenticated" object:nil];
	[parentController release];
}


- (void)dealloc 
{
	[loadedTime release];
    [super dealloc];
}


@end
