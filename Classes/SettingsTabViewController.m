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
#import "FoldersViewController.h"
#import "CacheSingleton.h"

#import "SA_OAuthTwitterEngine.h"
#import "SA_OAuthTwitterController.h"

#import "UIDevice+Hardware.h"

#import "NSString+md5.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueueAdditions.h"

#import "SavedSettings.h"
#import "NSString+Additions.h"
#import "NSArray+Additions.h"
#import "iPadRootViewController.h"
#import "MenuViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "NSNotificationCenter+MainThread.h"

@implementation SettingsTabViewController

@synthesize parentController, loadedTime;

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if (settingsS.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	// Fix for UISwitch/UISegment bug in iOS 4.3 beta 1 and 2
	//
	self.loadedTime = [NSDate date];
	
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTwitterUIElements) name:@"twitterAuthenticated" object:nil];
	
	// Set version label
	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
#if DEBUG
	NSString *build = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
	versionLabel.text = [NSString stringWithFormat:@"iSub version %@ build %@", build, version];
#else
	versionLabel.text = [NSString stringWithFormat:@"iSub version %@", version];
#endif
	
	// Main Settings
	enableScrobblingSwitch.on = settingsS.isScrobbleEnabled;
	
	//scrobblePercentSlider.value = [[appDelegateS.settingsDictionary objectForKey:@"scrobblePercentSetting"] floatValue];
	scrobblePercentSlider.value = settingsS.scrobblePercent;
	[self updateScrobblePercentLabel];
	
	manualOfflineModeSwitch.on = settingsS.isForceOfflineMode;
	
	checkUpdatesSwitch.on = settingsS.isUpdateCheckEnabled;
	
	autoReloadArtistSwitch.on = settingsS.isAutoReloadArtistsEnabled;

	disablePopupsSwitch.on = !settingsS.isPopupsEnabled;
	
	disableRotationSwitch.on = settingsS.isRotationLockEnabled;
	
	disableScreenSleepSwitch.on = !settingsS.isScreenSleepEnabled;
	
	enableBasicAuthSwitch.on = settingsS.isBasicAuthEnabled;
	
	enableSongsTabSwitch.on = settingsS.isSongsTabEnabled;
	DLog(@"isSongsTabEnabled: %i", settingsS.isSongsTabEnabled);
	
	recoverSegmentedControl.selectedSegmentIndex = settingsS.recoverSetting;
	
	maxBitrateWifiSegmentedControl.selectedSegmentIndex = settingsS.maxBitrateWifi;
	maxBitrate3GSegmentedControl.selectedSegmentIndex = settingsS.maxBitrate3G;
		
	enableSwipeSwitch.on = settingsS.isSwipeEnabled;
	enableTapAndHoldSwitch.on = settingsS.isTapAndHoldEnabled;
	
	showLargeSongInfoSwitch.on = settingsS.isShowLargeSongInfoInPlayer;
	enableLyricsSwitch.on = settingsS.isLyricsEnabled;
	enableCacheStatusSwitch.on = settingsS.isCacheStatusEnabled;
	
	// Cache Settings
	enableSongCachingSwitch.on = settingsS.isSongCachingEnabled;
	enableNextSongCacheSwitch.on = settingsS.isNextSongCacheEnabled;
	enableNextSongPartialCacheSwitch.on = settingsS.isPartialCacheNextSong;
		
	totalSpace = cacheS.totalSpace;
	freeSpace = cacheS.freeSpace;
	freeSpaceLabel.text = [NSString stringWithFormat:@"Free space: %@", [NSString formatFileSize:freeSpace]];
	totalSpaceLabel.text = [NSString stringWithFormat:@"Total space: %@", [NSString formatFileSize:totalSpace]];
	float percentFree = (float) freeSpace / (float) totalSpace;
	CGRect frame = freeSpaceBackground.frame;
	frame.size.width = frame.size.width * percentFree;
	freeSpaceBackground.frame = frame;
	cachingTypeSegmentedControl.selectedSegmentIndex = settingsS.cachingType;
	[self toggleCacheControlsVisibility];
	[self cachingTypeToggle];
	
	autoDeleteCacheSwitch.on = settingsS.isAutoDeleteCacheEnabled;
	
	autoDeleteCacheTypeSegmentedControl.selectedSegmentIndex = settingsS.autoDeleteCacheType;
	
	cacheSongCellColorSegmentedControl.selectedSegmentIndex = settingsS.cachedSongCellColorType;
	
	switch (settingsS.quickSkipNumberOfSeconds) 
	{
		case 5: quickSkipSegmentControl.selectedSegmentIndex = 0; break;
		case 15: quickSkipSegmentControl.selectedSegmentIndex = 1; break;
		case 30: quickSkipSegmentControl.selectedSegmentIndex = 2; break;
		case 45: quickSkipSegmentControl.selectedSegmentIndex = 3; break;
		case 60: quickSkipSegmentControl.selectedSegmentIndex = 4; break;
		case 120: quickSkipSegmentControl.selectedSegmentIndex = 5; break;
		case 300: quickSkipSegmentControl.selectedSegmentIndex = 6; break;
		case 600: quickSkipSegmentControl.selectedSegmentIndex = 7; break;
		case 1200: quickSkipSegmentControl.selectedSegmentIndex = 8; break;
		default: break;
	}
	
	// Twitter settings
	if (socialS.twitterEngine.isAuthorized)
	{
		twitterEnabledSwitch.enabled = YES;
		if (settingsS.isTwitterEnabled)
			twitterEnabledSwitch.on = YES;
		else
			twitterEnabledSwitch.on = NO;
		
		twitterSigninButton.imageView.image = [UIImage imageNamed:@"twitter-signout.png"];
		
		twitterStatusLabel.text = [NSString stringWithFormat:@"%@ signed in", [socialS.twitterEngine username]];
	}
	else
	{
		twitterEnabledSwitch.on = NO;
		twitterEnabledSwitch.enabled = NO;
		
		twitterSigninButton.imageView.image = [UIImage imageNamed:@"twitter-signin.png"];
		
		twitterStatusLabel.text = @"Signed out";
	}
	
	// Handle In App Purchase settings
	if (settingsS.isCacheUnlocked == NO)
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
	
	[cacheSpaceLabel2 addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
	
	switch (settingsS.audioEngineStartNumberOfSeconds) 
	{
		case 5: secondsToStartPlayerSegmentControl.selectedSegmentIndex = 0; break;
		case 10: secondsToStartPlayerSegmentControl.selectedSegmentIndex = 1; break;
		case 15: secondsToStartPlayerSegmentControl.selectedSegmentIndex = 2; break;
		case 20: secondsToStartPlayerSegmentControl.selectedSegmentIndex = 3; break;
		case 25: secondsToStartPlayerSegmentControl.selectedSegmentIndex = 4; break;
		case 30: secondsToStartPlayerSegmentControl.selectedSegmentIndex = 5; break;
		case 45: secondsToStartPlayerSegmentControl.selectedSegmentIndex = 6; break;
		case 60: secondsToStartPlayerSegmentControl.selectedSegmentIndex = 7; break;
		case 120: secondsToStartPlayerSegmentControl.selectedSegmentIndex = 8; break;
		default: break;
	}
	
	switch (settingsS.audioEngineBufferNumberOfSeconds) 
	{
		case 5: secondsToBufferSegmentControl.selectedSegmentIndex = 0; break;
		case 10: secondsToBufferSegmentControl.selectedSegmentIndex = 1; break;
		case 15: secondsToBufferSegmentControl.selectedSegmentIndex = 2; break;
		case 20: secondsToBufferSegmentControl.selectedSegmentIndex = 3; break;
		case 25: secondsToBufferSegmentControl.selectedSegmentIndex = 4; break;
		case 30: secondsToBufferSegmentControl.selectedSegmentIndex = 5; break;
		case 45: secondsToBufferSegmentControl.selectedSegmentIndex = 6; break;
		case 60: secondsToBufferSegmentControl.selectedSegmentIndex = 7; break;
		case 120: secondsToBufferSegmentControl.selectedSegmentIndex = 8; break;
		default: break;
	}
}

/*- (void)viewWillAppear:(BOOL)animated
{
	if ([[appDelegateS.settingsDictionary objectForKey:@"manualOfflineModeSetting"] isEqualToString:@"YES"])
		manualOfflineModeSwitch.on = YES;
	else
		manualOfflineModeSwitch.on = NO;
}*/

- (void)reloadTwitterUIElements
{
	if (socialS.twitterEngine)
	{
		twitterEnabledSwitch.enabled = YES;
		//if ([[appDelegateS.settingsDictionary objectForKey:@"twitterEnabledSetting"] isEqualToString:@"YES"])
		if (settingsS.isTwitterEnabled)
			twitterEnabledSwitch.on = YES;
		else
			twitterEnabledSwitch.on = NO;
		
		twitterSigninButton.imageView.image = [UIImage imageNamed:@"twitter-signout.png"];
		
		twitterStatusLabel.text = [NSString stringWithFormat:@"%@ signed in", [socialS.twitterEngine username]];
	}
	else
	{
		twitterEnabledSwitch.on = NO;
		twitterEnabledSwitch.enabled = NO;
		
		twitterSigninButton.imageView.image = [UIImage imageNamed:@"twitter-signin.png"];

		twitterStatusLabel.text = @"Signed out";
	}
}

- (void)cachingTypeToggle
{
	if (cachingTypeSegmentedControl.selectedSegmentIndex == 0)
	{
		cacheSpaceLabel1.text = @"Minimum free space:";
		//cacheSpaceLabel2.text = [settings formatFileSize:[[appDelegateS.settingsDictionary objectForKey:@"minFreeSpace"] unsignedLongLongValue]];
		cacheSpaceLabel2.text = [NSString formatFileSize:settingsS.minFreeSpace];
		//cacheSpaceSlider.value = [[appDelegateS.settingsDictionary objectForKey:@"minFreeSpace"] floatValue] / totalSpace;
		cacheSpaceSlider.value = (float)settingsS.minFreeSpace / totalSpace;
	}
	else if (cachingTypeSegmentedControl.selectedSegmentIndex == 1)
	{
		cacheSpaceLabel1.text = @"Maximum cache size:";
		//cacheSpaceLabel2.text = [settings formatFileSize:[[appDelegateS.settingsDictionary objectForKey:@"maxCacheSize"] unsignedLongLongValue]];
		cacheSpaceLabel2.text = [NSString formatFileSize:settingsS.maxCacheSize];
		//cacheSpaceSlider.value = [[appDelegateS.settingsDictionary objectForKey:@"maxCacheSize"] floatValue] / totalSpace;
		cacheSpaceSlider.value = (float)settingsS.maxCacheSize / totalSpace;
	}
}

- (IBAction)segmentAction:(id)sender
{
	if ([[NSDate date] timeIntervalSinceDate:loadedTime] > 0.5)
	{
		if (sender == recoverSegmentedControl)
		{
			settingsS.recoverSetting = recoverSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == maxBitrateWifiSegmentedControl)
		{
			settingsS.maxBitrateWifi = maxBitrateWifiSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == maxBitrate3GSegmentedControl)
		{
			settingsS.maxBitrate3G = maxBitrate3GSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == cachingTypeSegmentedControl)
		{
			settingsS.cachingType = cachingTypeSegmentedControl.selectedSegmentIndex;
			[self cachingTypeToggle];
		}
		else if (sender == autoDeleteCacheTypeSegmentedControl)
		{
			settingsS.autoDeleteCacheType = autoDeleteCacheTypeSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == cacheSongCellColorSegmentedControl)
		{
			settingsS.cachedSongCellColorType = cacheSongCellColorSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == quickSkipSegmentControl)
		{
			switch (quickSkipSegmentControl.selectedSegmentIndex) 
			{
				case 0: settingsS.quickSkipNumberOfSeconds = 5; break;
				case 1: settingsS.quickSkipNumberOfSeconds = 15; break;
				case 2: settingsS.quickSkipNumberOfSeconds = 30; break;
				case 3: settingsS.quickSkipNumberOfSeconds = 45; break;
				case 4: settingsS.quickSkipNumberOfSeconds = 60; break;
				case 5: settingsS.quickSkipNumberOfSeconds = 120; break;
				case 6: settingsS.quickSkipNumberOfSeconds = 300; break;
				case 7: settingsS.quickSkipNumberOfSeconds = 600; break;
				case 8: settingsS.quickSkipNumberOfSeconds = 1200; break;
				default: break;
			}
			
			if (IS_IPAD())
				[appDelegateS.ipadRootViewController.menuViewController.playerController quickSecondsSetLabels];
		}
		else if (sender == secondsToStartPlayerSegmentControl)
		{
			switch (secondsToStartPlayerSegmentControl.selectedSegmentIndex) 
			{
				case 0: settingsS.audioEngineStartNumberOfSeconds = 5; break;
				case 1: settingsS.audioEngineStartNumberOfSeconds = 10; break;
				case 2: settingsS.audioEngineStartNumberOfSeconds = 15; break;
				case 3: settingsS.audioEngineStartNumberOfSeconds = 20; break;
				case 4: settingsS.audioEngineStartNumberOfSeconds = 25; break;
				case 5: settingsS.audioEngineStartNumberOfSeconds = 30; break;
				case 6: settingsS.audioEngineStartNumberOfSeconds = 45; break;
				case 7: settingsS.audioEngineStartNumberOfSeconds = 60; break;
				case 8: settingsS.audioEngineStartNumberOfSeconds = 120; break;
				default: break;
			}
		}
		else if (sender == secondsToBufferSegmentControl)
		{
			switch (secondsToBufferSegmentControl.selectedSegmentIndex) 
			{
				case 0: settingsS.audioEngineBufferNumberOfSeconds = 5; break;
				case 1: settingsS.audioEngineBufferNumberOfSeconds = 10; break;
				case 2: settingsS.audioEngineBufferNumberOfSeconds = 15; break;
				case 3: settingsS.audioEngineBufferNumberOfSeconds = 20; break;
				case 4: settingsS.audioEngineBufferNumberOfSeconds = 25; break;
				case 5: settingsS.audioEngineBufferNumberOfSeconds = 30; break;
				case 6: settingsS.audioEngineBufferNumberOfSeconds = 45; break;
				case 7: settingsS.audioEngineBufferNumberOfSeconds = 60; break;
				case 8: settingsS.audioEngineBufferNumberOfSeconds = 120; break;
				default: break;
			}
		}
	}
}

- (void)toggleCacheControlsVisibility
{
	if (enableSongCachingSwitch.on)
	{
		enableNextSongCacheLabel.alpha = 1;
		enableNextSongCacheSwitch.enabled = YES;
		enableNextSongCacheSwitch.alpha = 1;
		enableNextSongPartialCacheLabel.alpha = 1;
		enableNextSongPartialCacheSwitch.enabled = YES;
		enableNextSongPartialCacheSwitch.alpha = 1;
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
		
		if (!enableNextSongCacheSwitch.on)
		{
			enableNextSongPartialCacheLabel.alpha = .5;
			enableNextSongPartialCacheSwitch.enabled = NO;
			enableNextSongPartialCacheSwitch.alpha = .5;
		}
	}
	else
	{
		enableNextSongCacheLabel.alpha = .5;
		enableNextSongCacheSwitch.enabled = NO;
		enableNextSongCacheSwitch.alpha = .5;
		enableNextSongPartialCacheLabel.alpha = .5;
		enableNextSongPartialCacheSwitch.enabled = NO;
		enableNextSongPartialCacheSwitch.alpha = .5;
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

- (IBAction)switchAction:(id)sender
{
	if ([[NSDate date] timeIntervalSinceDate:loadedTime] > 0.5)
	{
		if (sender == manualOfflineModeSwitch)
		{
			settingsS.isForceOfflineMode = manualOfflineModeSwitch.on;
			if (manualOfflineModeSwitch.on)
			{
				[appDelegateS enterOfflineModeForce];
			}
			else
			{
				[appDelegateS enterOnlineModeForce];
			}
			
			// Handle the moreNavigationController stupidity
			if (appDelegateS.currentTabBarController.selectedIndex == 4)
			{
				[appDelegateS.currentTabBarController.moreNavigationController popToViewController:[appDelegateS.currentTabBarController.moreNavigationController.viewControllers objectAtIndexSafe:1] animated:YES];
			}
			else
			{
				[(UINavigationController*)appDelegateS.currentTabBarController.selectedViewController popToRootViewControllerAnimated:YES];
			}
		}
		else if (sender == enableScrobblingSwitch)
		{
			settingsS.isScrobbleEnabled = enableScrobblingSwitch.on;
		}
		else if (sender == enableSongCachingSwitch)
		{
			settingsS.isSongCachingEnabled = enableSongCachingSwitch.on;
			[self toggleCacheControlsVisibility];
		}
		else if (sender == enableNextSongCacheSwitch)
		{
			settingsS.isNextSongCacheEnabled = enableNextSongCacheSwitch.on;
			[self toggleCacheControlsVisibility];
		}
		else if (sender == enableNextSongPartialCacheSwitch)
		{
			settingsS.isPartialCacheNextSong = enableNextSongPartialCacheSwitch.on;
		}
		else if (sender == autoDeleteCacheSwitch)
		{
			settingsS.isAutoDeleteCacheEnabled = autoDeleteCacheSwitch.on;
		}
		else if (sender == twitterEnabledSwitch)
		{
			settingsS.isTwitterEnabled = twitterEnabledSwitch.on;
		}
		else if (sender == checkUpdatesSwitch)
		{
			settingsS.isUpdateCheckEnabled = checkUpdatesSwitch.on;
		}
		else if (sender == showLargeSongInfoSwitch)
		{
			settingsS.isShowLargeSongInfoInPlayer = showLargeSongInfoSwitch.on;
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LargeSongInfoToggle];
		}
		else if (sender == enableLyricsSwitch)
		{
			settingsS.isLyricsEnabled = enableLyricsSwitch.on;
		}
		else if (sender == enableCacheStatusSwitch)
		{
			settingsS.isCacheStatusEnabled = enableCacheStatusSwitch.on;
		}
		else if (sender == enableSwipeSwitch)
		{
			settingsS.isSwipeEnabled = enableSwipeSwitch.on;
		}
		else if (sender == enableTapAndHoldSwitch)
		{
			settingsS.isTapAndHoldEnabled = enableTapAndHoldSwitch.on;
		}
		else if (sender == autoReloadArtistSwitch)
		{
			settingsS.isAutoReloadArtistsEnabled = autoReloadArtistSwitch.on;
		}
		else if (sender == disablePopupsSwitch)
		{
			settingsS.isPopupsEnabled = !disablePopupsSwitch.on;
		}
		else if (sender == enableSongsTabSwitch)
		{
			if (enableSongsTabSwitch.on)
			{
				settingsS.isSongsTabEnabled = YES;
				
				if (IS_IPAD())
				{
					[appDelegateS.ipadRootViewController.menuViewController loadCellContents];
				}
				else
				{
					NSMutableArray *controllers = [NSMutableArray arrayWithArray:appDelegateS.mainTabBarController.viewControllers];
					[controllers addObject:appDelegateS.allAlbumsNavigationController];
					[controllers addObject:appDelegateS.allSongsNavigationController];
					[controllers addObject:appDelegateS.genresNavigationController];
					appDelegateS.mainTabBarController.viewControllers = controllers;
				}
				
				[databaseS setupAllSongsDb];
			}
			else
			{
				settingsS.isSongsTabEnabled = NO;

				if (IS_IPAD())
					[appDelegateS.ipadRootViewController.menuViewController loadCellContents];
				else
					[viewObjectsS orderMainTabBarController];
				
				[databaseS.allAlbumsDbQueue close];
				databaseS.allAlbumsDbQueue = nil;
				[databaseS.allSongsDbQueue close];
				databaseS.allSongsDbQueue = nil;
				[databaseS.genresDbQueue close];
				databaseS.genresDbQueue = nil;
			}
		}
		else if (sender == disableRotationSwitch)
		{
			settingsS.isRotationLockEnabled = disableRotationSwitch.on;
		}
		else if (sender == disableScreenSleepSwitch)
		{
			settingsS.isScreenSleepEnabled = !disableScreenSleepSwitch.on;
			[UIApplication sharedApplication].idleTimerDisabled = disableScreenSleepSwitch.on;
		}
		else if (sender == enableBasicAuthSwitch)
		{
			settingsS.isBasicAuthEnabled = enableBasicAuthSwitch.on;
		}
	}
}

- (IBAction)resetFolderCacheAction
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Reset Album Folder Cache" message:@"Are you sure you want to do this? This clears just the cached folder listings, not the cached songs" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
	alert.tag = 0;
	[alert show];
}

- (IBAction)resetAlbumArtCacheAction
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Reset Album Art Cache" message:@"Are you sure you want to do this? This will clear all saved album art." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
	alert.tag = 1;
	[alert show];
}

- (void)resetFolderCache
{
	[databaseS resetFolderCache];
	[viewObjectsS hideLoadingScreen];
	[self popFoldersTab];
}

- (void)resetAlbumArtCache
{
	[databaseS resetCoverArtCache];
	[viewObjectsS hideLoadingScreen];
	[self popFoldersTab];
}

- (void)popFoldersTab
{
	if (IS_IPAD())
		[appDelegateS.artistsNavigationController popToRootViewControllerAnimated:NO];
	else
		[appDelegateS.rootViewController.navigationController popToRootViewControllerAnimated:NO];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView.tag == 0 && buttonIndex == 1)
	{
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Processing"];
		[self performSelector:@selector(resetFolderCache) withObject:nil afterDelay:0.05];
	}
	else if (alertView.tag == 1 && buttonIndex == 1)
	{
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Processing"];
		[self performSelector:@selector(resetAlbumArtCache) withObject:nil afterDelay:0.05];
	}
}

- (void)updateCacheSpaceSlider
{
	cacheSpaceSlider.value = ((double)[cacheSpaceLabel2.text fileSizeFromFormat] / (double)totalSpace);
}

- (IBAction)updateMinFreeSpaceLabel
{
	cacheSpaceLabel2.text = [NSString formatFileSize:(unsigned long long int) (cacheSpaceSlider.value * totalSpace)];
}

- (IBAction)updateMinFreeSpaceSetting
{
	if (cachingTypeSegmentedControl.selectedSegmentIndex == 0)
	{
		// Check if the user is trying to assing a higher min free space than is available space - 50MB
		if (cacheSpaceSlider.value * totalSpace > freeSpace - 52428800)
		{
			settingsS.minFreeSpace = freeSpace - 52428800;
			cacheSpaceSlider.value = ((float)settingsS.minFreeSpace / (float)totalSpace); // Leave 50MB space
		}
		else if (cacheSpaceSlider.value * totalSpace < 52428800)
		{
			settingsS.minFreeSpace = 52428800;
			cacheSpaceSlider.value = ((float)settingsS.minFreeSpace / (float)totalSpace); // Leave 50MB space
		}
		else 
		{
			settingsS.minFreeSpace = (unsigned long long int) (cacheSpaceSlider.value * (float)totalSpace);
		}
		//cacheSpaceLabel2.text = [NSString formatFileSize:settingsS.minFreeSpace];
	}
	else if (cachingTypeSegmentedControl.selectedSegmentIndex == 1)
	{
		
		// Check if the user is trying to assign a larger max cache size than there is available space - 50MB
		if (cacheSpaceSlider.value * totalSpace > freeSpace - 52428800)
		{
			settingsS.maxCacheSize = freeSpace - 52428800;
			cacheSpaceSlider.value = ((float)settingsS.maxCacheSize / (float)totalSpace); // Leave 50MB space
		}
		else if (cacheSpaceSlider.value * totalSpace < 52428800)
		{
			settingsS.maxCacheSize = 52428800;
			cacheSpaceSlider.value = ((float)settingsS.maxCacheSize / (float)totalSpace); // Leave 50MB space
		}
		else
		{
			settingsS.maxCacheSize = (unsigned long long int) (cacheSpaceSlider.value * totalSpace);
		}
		//cacheSpaceLabel2.text = [NSString formatFileSize:settingsS.maxCacheSize];
	}
	[self updateMinFreeSpaceLabel];
}

- (IBAction)revertMinFreeSpaceSlider
{
	cacheSpaceLabel2.text = [NSString formatFileSize:settingsS.minFreeSpace];
	cacheSpaceSlider.value = (float)settingsS.minFreeSpace / totalSpace;
}

- (IBAction)twitterButtonAction
{
	if (socialS.twitterEngine.isAuthorized)
	{
		[socialS destroyTwitterEngine];
		[self reloadTwitterUIElements];
	}
	else
	{
		if (!socialS.twitterEngine)
			[socialS createTwitterEngine];
		
		UIViewController *controller = [SA_OAuthTwitterController controllerToEnterCredentialsWithTwitterEngine:socialS.twitterEngine delegate:socialS];
		if (controller) 
		{
			if (IS_IPAD())
				[appDelegateS.ipadRootViewController presentModalViewController:controller animated:YES];
			else
				[self.parentController presentModalViewController:controller animated:YES];
		}
	}
}

- (IBAction)updateScrobblePercentLabel
{
	NSUInteger percentInt = scrobblePercentSlider.value * 100;
	scrobblePercentLabel.text = [NSString stringWithFormat:@"%i", percentInt];
}

- (IBAction)updateScrobblePercentSetting;
{
	settingsS.scrobblePercent = scrobblePercentSlider.value;
}

- (void)didReceiveMemoryWarning 
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
	UITableView *tableView = (UITableView *)self.view.superview;
	CGRect rect = CGRectMake(0, 500, 320, 5);
	[tableView scrollRectToVisible:rect animated:NO];
	rect = UIInterfaceOrientationIsPortrait(self.interfaceOrientation) ? CGRectMake(0, 1600, 320, 5) : CGRectMake(0, 1455, 320, 5);
	[tableView scrollRectToVisible:rect animated:NO];
}

// This dismisses the keyboard when the "done" button is pressed
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[self updateMinFreeSpaceSetting];
	[textField resignFirstResponder];
	return YES;
}

- (void)textFieldDidChange:(UITextField *)textField
{
	[self updateCacheSpaceSlider];
	DLog(@"file size: %llu   formatted: %@", [textField.text fileSizeFromFormat], [NSString formatFileSize:[textField.text fileSizeFromFormat]]);
}

@end
