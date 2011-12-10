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
#import "MusicSingleton.h"
#import "SocialSingleton.h"
#import "DatabaseSingleton.h"
#import "RootViewController.h"
#import "CacheSingleton.h"

#import "SA_OAuthTwitterEngine.h"
#import "SA_OAuthTwitterController.h"

#import "UIDevice+Hardware.h"
#import "iPadMainMenu.h"

#import "NSString+md5.h"
#import "FMDatabase.h"

#import "SavedSettings.h"


@implementation SettingsTabViewController

@synthesize parentController, loadedTime;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	
	if (settings.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
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
	
	settings = [SavedSettings sharedInstance];
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicSingleton sharedInstance];
	socialControls = [SocialSingleton sharedInstance];
	databaseControls = [DatabaseSingleton sharedInstance];
	CacheSingleton *cacheControls = [CacheSingleton sharedInstance];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTwitterUIElements) name:@"twitterAuthenticated" object:nil];
	
	// Set version label
	NSString *build = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
#if DEBUG
	versionLabel.text = [NSString stringWithFormat:@"iSub version %@ build %@", build, version];
#else
	versionLabel.text = [NSString stringWithFormat:@"iSub version %@", version];
#endif
	
	// Main Settings
	enableScrobblingSwitch.on = settings.isScrobbleEnabled;
	
	//scrobblePercentSlider.value = [[appDelegate.settingsDictionary objectForKey:@"scrobblePercentSetting"] floatValue];
	scrobblePercentSlider.value = settings.scrobblePercent;
	[self updateScrobblePercentLabel];
	
	manualOfflineModeSwitch.on = settings.isForceOfflineMode;
	
	checkUpdatesSwitch.on = settings.isUpdateCheckEnabled;
	
	autoReloadArtistSwitch.on = settings.isAutoReloadArtistsEnabled;

	disablePopupsSwitch.on = !settings.isPopupsEnabled;
	
	disableRotationSwitch.on = settings.isRotationLockEnabled;
	
	disableScreenSleepSwitch.on = !settings.isScreenSleepEnabled;
	
	enableBasicAuthSwitch.on = settings.isBasicAuthEnabled;
	
	enableSongsTabSwitch.on = settings.isSongsTabEnabled;
	DLog(@"isSongsTabEnabled: %i", settings.isSongsTabEnabled);
	
	recoverSegmentedControl.selectedSegmentIndex = settings.recoverSetting;
	
	maxBitrateWifiSegmentedControl.selectedSegmentIndex = settings.maxBitrateWifi;
	maxBitrate3GSegmentedControl.selectedSegmentIndex = settings.maxBitrate3G;
	
	autoPlayerInfoSwitch.on = settings.isAutoShowSongInfoEnabled;
	
	enableLyricsSwitch.on = settings.isLyricsEnabled;
	
	// Cache Settings
	enableSongCachingSwitch.on = settings.isSongCachingEnabled;
	
	enableNextSongCacheSwitch.on = settings.isNextSongCacheEnabled;
		
	totalSpace = cacheControls.totalSpace;
	freeSpace = cacheControls.freeSpace;
	freeSpaceLabel.text = [NSString stringWithFormat:@"Free space: %@", [settings formatFileSize:freeSpace]];
	totalSpaceLabel.text = [NSString stringWithFormat:@"Total space: %@", [settings formatFileSize:totalSpace]];
	float percentFree = (float) freeSpace / (float) totalSpace;
	CGRect frame = freeSpaceBackground.frame;
	frame.size.width = frame.size.width * percentFree;
	freeSpaceBackground.frame = frame;
	cachingTypeSegmentedControl.selectedSegmentIndex = settings.cachingType;
	[self toggleCacheControlsVisibility];
	[self cachingTypeToggle];
	
	autoDeleteCacheSwitch.on = settings.isAutoDeleteCacheEnabled;
	
	autoDeleteCacheTypeSegmentedControl.selectedSegmentIndex = settings.autoDeleteCacheType;
	
	cacheSongCellColorSegmentedControl.selectedSegmentIndex = settings.cachedSongCellColorType;
	
	// Twitter settings
	if (socialControls.twitterEngine && socialControls.twitterEngine.isAuthorized)
	{
		twitterEnabledSwitch.enabled = YES;
		if (settings.isTwitterEnabled)
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
	if ([SavedSettings sharedInstance].isCacheUnlocked == NO)
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
		//if ([[appDelegate.settingsDictionary objectForKey:@"twitterEnabledSetting"] isEqualToString:@"YES"])
		if (settings.isTwitterEnabled)
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
		//cacheSpaceLabel2.text = [settings formatFileSize:[[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] unsignedLongLongValue]];
		cacheSpaceLabel2.text = [settings formatFileSize:settings.minFreeSpace];
		//cacheSpaceSlider.value = [[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] floatValue] / totalSpace;
		cacheSpaceSlider.value = (float)settings.minFreeSpace / totalSpace;
	}
	else if (cachingTypeSegmentedControl.selectedSegmentIndex == 1)
	{
		cacheSpaceLabel1.text = @"Maximum cache size:";
		//cacheSpaceLabel2.text = [settings formatFileSize:[[appDelegate.settingsDictionary objectForKey:@"maxCacheSize"] unsignedLongLongValue]];
		cacheSpaceLabel2.text = [settings formatFileSize:settings.maxCacheSize];
		//cacheSpaceSlider.value = [[appDelegate.settingsDictionary objectForKey:@"maxCacheSize"] floatValue] / totalSpace;
		cacheSpaceSlider.value = (float)settings.maxCacheSize / totalSpace;
	}
}

- (IBAction) segmentAction:(id)sender
{
	if ([[NSDate date] timeIntervalSinceDate:loadedTime] > 0.5)
	{
		if (sender == recoverSegmentedControl)
		{
			//[appDelegate.settingsDictionary setObject:[NSNumber numberWithInt:recoverSegmentedControl.selectedSegmentIndex] forKey:@"recoverSetting"];
			settings.recoverSetting = settings.recoverSetting;
		}
		//else if (sender == maxBitrateSegmentedControl)
		//{
		//	[appDelegate.settingsDictionary setObject:[NSNumber numberWithInt:maxBitrateSegmentedControl.selectedSegmentIndex] forKey:@"maxBitrateSetting"];
		//}
		else if (sender == maxBitrateWifiSegmentedControl)
		{
			//[appDelegate.settingsDictionary setObject:[NSNumber numberWithInt:maxBitrateWifiSegmentedControl.selectedSegmentIndex] forKey:@"maxBitrateWifiSetting"];
			settings.maxBitrateWifi = maxBitrateWifiSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == maxBitrate3GSegmentedControl)
		{
			//[appDelegate.settingsDictionary setObject:[NSNumber numberWithInt:maxBitrate3GSegmentedControl.selectedSegmentIndex] forKey:@"maxBitrate3GSetting"];
			settings.maxBitrate3G = maxBitrate3GSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == cachingTypeSegmentedControl)
		{
			//[appDelegate.settingsDictionary setObject:[NSNumber numberWithInt:cachingTypeSegmentedControl.selectedSegmentIndex] forKey:@"cachingTypeSetting"];
			settings.cachingType = cachingTypeSegmentedControl.selectedSegmentIndex;
			[self cachingTypeToggle];
		}
		else if (sender == autoDeleteCacheTypeSegmentedControl)
		{
			//[appDelegate.settingsDictionary setObject:[NSNumber numberWithInt:autoDeleteCacheTypeSegmentedControl.selectedSegmentIndex] forKey:@"autoDeleteCacheTypeSetting"];
			settings.autoDeleteCacheType = autoDeleteCacheTypeSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == cacheSongCellColorSegmentedControl)
		{
			//[appDelegate.settingsDictionary setObject:[NSNumber numberWithInt:cacheSongCellColorSegmentedControl.selectedSegmentIndex] forKey:@"cacheSongCellColorSetting"];
			settings.cachedSongCellColorType = cacheSongCellColorSegmentedControl.selectedSegmentIndex;
		}
		
		//[[NSUserDefaults standardUserDefaults] setObject:appDelegate.settingsDictionary forKey:@"settingsDictionary"];
		//[[NSUserDefaults standardUserDefaults] synchronize];
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
			settings.isForceOfflineMode = manualOfflineModeSwitch.on;
			if (manualOfflineModeSwitch.on)
			{
				[appDelegate enterOfflineModeForce];
			}
			else
			{
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
			settings.isScrobbleEnabled = enableScrobblingSwitch.on;
		}
		else if (sender == enableSongCachingSwitch)
		{
			settings.isSongCachingEnabled = enableSongCachingSwitch.on;
			[self toggleCacheControlsVisibility];
		}
		else if (sender == enableNextSongCacheSwitch)
		{
			settings.isNextSongCacheEnabled = enableNextSongCacheSwitch.on;
		}
		else if (sender == autoDeleteCacheSwitch)
		{
			settings.isAutoDeleteCacheEnabled = autoDeleteCacheSwitch.on;
		}
		else if (sender == twitterEnabledSwitch)
		{
			settings.isTwitterEnabled = twitterEnabledSwitch.on;
		}
		else if (sender == checkUpdatesSwitch)
		{
			settings.isUpdateCheckEnabled = checkUpdatesSwitch.on;
		}
		else if (sender == enableLyricsSwitch)
		{
			settings.isLyricsEnabled = enableLyricsSwitch.on;
		}
		else if (sender == autoPlayerInfoSwitch)
		{
			settings.isAutoShowSongInfoEnabled = autoPlayerInfoSwitch.on;
		}
		else if (sender == autoReloadArtistSwitch)
		{
			settings.isAutoReloadArtistsEnabled = autoReloadArtistSwitch.on;
		}
		else if (sender == disablePopupsSwitch)
		{
			settings.isPopupsEnabled = !disablePopupsSwitch.on;
		}
		else if (sender == enableSongsTabSwitch)
		{
			if (enableSongsTabSwitch.on)
			{
				settings.isSongsTabEnabled = YES;
				
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
				databaseControls.allAlbumsDb = [FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@allAlbums.db", databaseControls.databaseFolderPath, [[SavedSettings sharedInstance].urlString md5]]];
				[databaseControls.allAlbumsDb executeUpdate:@"PRAGMA cache_size = 1"];
				if ([databaseControls.allAlbumsDb open] == NO) { DLog(@"Could not open allAlbumsDb."); }
				
				// Setup the allSongs database
				databaseControls.allSongsDb = [FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@allSongs.db", databaseControls.databaseFolderPath, [[SavedSettings sharedInstance].urlString md5]]];
				[databaseControls.allSongsDb executeUpdate:@"PRAGMA cache_size = 1"];
				if ([databaseControls.allSongsDb open] == NO) { DLog(@"Could not open allSongsDb."); }
				
				// Setup the Genres database
				databaseControls.genresDb = [FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@genres.db", databaseControls.databaseFolderPath, [[SavedSettings sharedInstance].urlString md5]]];
				[databaseControls.genresDb executeUpdate:@"PRAGMA cache_size = 1"];
				if ([databaseControls.genresDb open] == NO) { DLog(@"Could not open genresDb."); }
			}
			else
			{
				settings.isSongsTabEnabled = NO;

				if (IS_IPAD())
					[appDelegate.mainMenu loadTable];
				else
					[viewObjects orderMainTabBarController];
				
				[databaseControls.allAlbumsDb close];
				[databaseControls.allSongsDb close];
				[databaseControls.genresDb close];
			}
		}
		else if (sender == disableRotationSwitch)
		{
			settings.isRotationLockEnabled = disableRotationSwitch.on;
		}
		else if (sender == disableScreenSleepSwitch)
		{
			settings.isScreenSleepEnabled = !disableScreenSleepSwitch.on;
			[UIApplication sharedApplication].idleTimerDisabled = disableScreenSleepSwitch.on;
		}
		else if (sender == enableBasicAuthSwitch)
		{
			settings.isBasicAuthEnabled = enableBasicAuthSwitch.on;
		}
	}
}

- (IBAction)resetFolderCacheAction
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Reset Album Folder Cache" message:@"Are you sure you want to do this? This clears just the cached folder listings, not the cached songs" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
	alert.tag = 0;
	[alert show];
	[alert release];
}

- (IBAction)resetAlbumArtCacheAction
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Reset Album Art Cache" message:@"Are you sure you want to do this? This will clear all saved album art." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
	alert.tag = 1;
	[alert show];
	[alert release];
}

- (void)resetFolderCache
{
	[databaseControls resetFolderCache];
	[viewObjects performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:YES];
	[self performSelectorOnMainThread:@selector(popFoldersTab) withObject:nil waitUntilDone:YES];
}

- (void)resetAlbumArtCache
{
	[databaseControls resetCoverArtCache];
	[viewObjects performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:YES];
	[self performSelectorOnMainThread:@selector(popFoldersTab) withObject:nil waitUntilDone:YES];
}

- (void)popFoldersTab
{
	if (IS_IPAD())
		[appDelegate.artistsNavigationController popToRootViewControllerAnimated:NO];
	else
		[appDelegate.rootViewController.navigationController popToRootViewControllerAnimated:NO];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView.tag == 0 && buttonIndex == 1)
	{
		[viewObjects showLoadingScreenOnMainWindow];
		[self performSelectorInBackground:@selector(resetFolderCache) withObject:nil];
	}
	else if (alertView.tag == 1 && buttonIndex == 1)
	{
		[viewObjects showLoadingScreenOnMainWindow];
		[self performSelectorInBackground:@selector(resetAlbumArtCache) withObject:nil];
	}
}

- (IBAction) updateMinFreeSpaceLabel
{
	//DLog(@"cacheSpaceSlider.value: %f", cacheSpaceSlider.value);
	cacheSpaceLabel2.text = [settings formatFileSize:(unsigned long long int) (cacheSpaceSlider.value * totalSpace)];
}

- (IBAction) updateMinFreeSpaceSetting
{
	//DLog(@"cacheSpaceSlider.value: %f", cacheSpaceSlider.value);
	if (cachingTypeSegmentedControl.selectedSegmentIndex == 0)
	{
		// Check if the user is trying to assing a higher min free space than is available space - 50MB
		if (cacheSpaceSlider.value * totalSpace > freeSpace - 52428800)
		{
			//[appDelegate.settingsDictionary setObject:[NSNumber numberWithLongLong:freeSpace] forKey:@"minFreeSpace"];
			settings.minFreeSpace = freeSpace;
			//cacheSpaceLabel2.text = [settings formatFileSize:[[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] unsignedLongLongValue]];
			cacheSpaceLabel2.text = [settings formatFileSize:settings.minFreeSpace];
			cacheSpaceSlider.value = ( (float)freeSpace / (float)totalSpace ) - 52428800.0; // Leave 50MB space
		}
		else 
		{
			//[appDelegate.settingsDictionary setObject:[NSNumber numberWithLongLong:(unsigned long long int) (cacheSpaceSlider.value * totalSpace)] forKey:@"minFreeSpace"];
			settings.minFreeSpace = (unsigned long long int) (cacheSpaceSlider.value * totalSpace);
			//cacheSpaceLabel2.text = [settings formatFileSize:[[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] unsignedLongLongValue]];
			cacheSpaceLabel2.text = [settings formatFileSize:settings.minFreeSpace];
		}
	}
	else if (cachingTypeSegmentedControl.selectedSegmentIndex == 1)
	{
		
		// Check if the user is trying to assign a larger max cache size than there is available space - 50MB
		if (cacheSpaceSlider.value * totalSpace > freeSpace - 52428800)
		{
			//[appDelegate.settingsDictionary setObject:[NSNumber numberWithLongLong:(freeSpace - 52428800)] forKey:@"minFreeSpace"];
			settings.maxCacheSize = (freeSpace - 52428800);
			//cacheSpaceLabel2.text = [settings formatFileSize:[[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] unsignedLongLongValue]];
			cacheSpaceLabel2.text = [settings formatFileSize:settings.maxCacheSize];
			cacheSpaceSlider.value = ( (float)freeSpace / (float)totalSpace ) - 52428800.0; // Leave 50MB space
		}
		else
		{
			//[appDelegate.settingsDictionary setObject:[NSNumber numberWithLongLong:(unsigned long long int) (cacheSpaceSlider.value * totalSpace)] forKey:@"maxCacheSize"];
			settings.maxCacheSize = (unsigned long long int) (cacheSpaceSlider.value * totalSpace);
			//cacheSpaceLabel2.text = [settings formatFileSize:[[appDelegate.settingsDictionary objectForKey:@"maxCacheSize"] unsignedLongLongValue]];
			cacheSpaceLabel2.text = [settings formatFileSize:settings.maxCacheSize];
		}
	}
	
	//[[NSUserDefaults standardUserDefaults] setObject:appDelegate.settingsDictionary forKey:@"settingsDictionary"];
	//[[NSUserDefaults standardUserDefaults] synchronize];
}

- (IBAction) revertMinFreeSpaceSlider
{
	//DLog(@"revertMinFreeSpaceSlider");
	//cacheSpaceLabel2.text = [settings formatFileSize:[[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] unsignedLongLongValue]];
	cacheSpaceLabel2.text = [settings formatFileSize:settings.minFreeSpace];
	//cacheSpaceSlider.value = [[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] floatValue] / totalSpace;
	cacheSpaceSlider.value = (float)settings.minFreeSpace / totalSpace;
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
	//NSNumber *percent = [NSNumber numberWithFloat:scrobblePercentSlider.value];
	//[appDelegate.settingsDictionary setObject:percent forKey:@"scrobblePercentSetting"];
	settings.scrobblePercent = scrobblePercentSlider.value;
	
	//[[NSUserDefaults standardUserDefaults] setObject:appDelegate.settingsDictionary forKey:@"settingsDictionary"];
	//[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
	//DLog(@"settigns tab view did unload");
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"twitterAuthenticated" object:nil];
	[parentController release];
}


- (void)dealloc 
{
	[loadedTime release];
    [super dealloc];
}


@end
