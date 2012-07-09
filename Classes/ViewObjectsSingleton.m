//
//  ViewObjectsSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ViewObjectsSingleton.h"
#import "iSubAppDelegate.h"
#import "MKStoreManager.h"
#import "Server.h"
#import "SavedSettings.h"

@implementation ViewObjectsSingleton

@synthesize HUD;

// XMLParser objects used to tell the parser how to parse
@synthesize parseState, allAlbumsParseState, allSongsParseState;

// Home page objects
@synthesize homeListOfAlbums;

// Artists page objects
@synthesize isArtistsLoading;

// Albums page objects and variables
@synthesize currentArtistName, currentArtistId; 

/*// All albums view objects
@synthesize allAlbumsListOfAlbums, allAlbumsAlbumObject, allAlbumsListOfSongs, allAlbumsCurrentArtistName, allAlbumsCurrentArtistId, allAlbumsLoadingScreen, allAlbumsLoadingProgress, isAlbumsLoading;

// All songs view objects
@synthesize isSongsLoading;*/

// Playlists view objects
@synthesize listOfPlaylists, listOfPlaylistSongs, localPlaylist, listOfLocalPlaylists, isLocalPlaylist;

// Settings page objects
@synthesize serverToEdit;

// Chat page objects
@synthesize chatMessages;

// New stuff
@synthesize isCellEnabled, cellEnabledTimer, queueAlbumListOfAlbums, queueAlbumListOfSongs, multiDeleteList, isOfflineMode, isOnlineModeAlertShowing, cancelLoading;

// Cell colors
@synthesize lightRed, darkRed, lightYellow, darkYellow, lightGreen, darkGreen, lightBlue, darkBlue, lightNormal, darkNormal, windowColor, jukeboxColor;

@synthesize deleteButtonImage, cacheButtonImage, queueButtonImage;

@synthesize currentLoadingFolderId;

@synthesize isNoNetworkAlertShowing;

@synthesize isLoadingScreenShowing;

#pragma mark -
#pragma mark Class instance methods


- (void)enableCells
{
	isCellEnabled = YES;
}

- (void)hudWasHidden:(MBProgressHUD *)hud 
{
    // Remove HUD from screen when the HUD was hidden
    [self.HUD removeFromSuperview];
	self.HUD = nil;
}

- (void)showLoadingScreenOnMainWindowWithMessage:(NSString *)message
{	
	[self showLoadingScreen:appDelegateS.window withMessage:message];
}

- (void)showLoadingScreen:(UIView *)view withMessage:(NSString *)message
{
	if (isLoadingScreenShowing)
		return;
	
	self.isLoadingScreenShowing = YES;
	
	self.HUD = [[MBProgressHUD alloc] initWithView:view];
	[appDelegateS.window addSubview:HUD];
	self.HUD.delegate = self;
	self.HUD.labelText = message ? message : @"Loading";
	[self.HUD show:YES];
}

- (void)showAlbumLoadingScreen:(UIView *)view sender:(id)sender
{	
	if (self.isLoadingScreenShowing)
		return;
	
	self.isLoadingScreenShowing = YES;
	
	self.HUD = [[MBProgressHUD alloc] initWithView:appDelegateS.window];
	self.HUD.userInteractionEnabled = YES;
	
	// TODO: verify on iPad
	UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
	cancelButton.bounds = CGRectMake(0, 0, 1024, 1024);
	cancelButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[cancelButton addTarget:sender action:@selector(cancelLoad) forControlEvents:UIControlEventTouchUpInside];
	[self.HUD addSubview:cancelButton];
	
	[appDelegateS.window addSubview:self.HUD];
	self.HUD.delegate = self;
	self.HUD.labelText = @"Loading";
	self.HUD.detailsLabelText = @"tap to cancel";
	[self.HUD show:YES];
}
	
- (void)hideLoadingScreen
{
	if (!self.isLoadingScreenShowing)
		return;
	
	self.isLoadingScreenShowing = NO;
	
	[HUD hide:YES];
}

- (UIColor *)currentDarkColor
{
	//switch ([[appDelegateS.settingsDictionary objectForKey:@"cacheSongCellColorSetting"] intValue])
	switch(settingsS.cachedSongCellColorType)
	{
		case 0:
			return self.darkRed;
		case 1:
			return self.darkYellow;
		case 2:
			return self.darkGreen;
		case 3:
			return self.darkBlue;
		default:
			return self.darkNormal;
	}
	
	return self.darkNormal;
}

- (UIColor *) currentLightColor
{
	//switch ([[appDelegateS.settingsDictionary objectForKey:@"cacheSongCellColorSetting"] intValue])
	switch(settingsS.cachedSongCellColorType)
	{
		case 0:
			return self.lightRed;
		case 1:
			return self.lightYellow;
		case 2:
			return self.lightGreen;
		case 3:
			return self.lightBlue;
		default:
			return self.lightNormal;
	}
	
	return self.lightNormal;
}

#pragma mark Tab Saving

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
	if (self.isOfflineMode == NO)
		[[NSUserDefaults standardUserDefaults] setInteger:appDelegateS.mainTabBarController.selectedIndex forKey:@"mainTabBarControllerSelectedIndex"];
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
	if (self.isOfflineMode == NO)
		[[NSUserDefaults standardUserDefaults] setInteger:appDelegateS.mainTabBarController.selectedIndex forKey:@"mainTabBarControllerSelectedIndex"];
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController
{
	if (self.isOfflineMode == NO)
		[[NSUserDefaults standardUserDefaults] setInteger:appDelegateS.mainTabBarController.selectedIndex forKey:@"mainTabBarControllerSelectedIndex"];
}

- (void)tabBarController:(UITabBarController *)tabBarController didEndCustomizingViewControllers:(NSArray *)viewControllers changed:(BOOL)changed
{
    int count = tabBarController.viewControllers.count;
    NSMutableArray *savedTabsOrderArray = [[NSMutableArray alloc] initWithCapacity:count];
    for (int i = 0; i < count; i ++)
	{
        [savedTabsOrderArray addObject:[NSNumber numberWithInt:[[[tabBarController.viewControllers objectAtIndexSafe:i] tabBarItem] tag]]];
    }
    [[NSUserDefaults standardUserDefaults] setObject:[NSArray arrayWithArray:savedTabsOrderArray] forKey:@"mainTabBarTabsOrder"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)orderMainTabBarController
{
	appDelegateS.currentTabBarController = appDelegateS.mainTabBarController;
	appDelegateS.mainTabBarController.delegate = self;
	
	NSArray *savedTabsOrderArray = [[NSUserDefaults standardUserDefaults] arrayForKey:@"mainTabBarTabsOrder"];
	
	// If this is an old device, remove Albums and Songs tabs
	//if (![[appDelegateS.settingsDictionary objectForKey:@"enableSongsTabSetting"] isEqualToString:@"YES"]) 
	if (!settingsS.isSongsTabEnabled)
	{
		//DLog(@"isSongsTabEnabled: %i", settingsS.isSongsTabEnabled);
		NSMutableArray *tabs = [[NSMutableArray alloc] init];
		for (UIViewController *controller in appDelegateS.mainTabBarController.viewControllers)
		{
			if (controller.tabBarItem.tag != 1 && controller.tabBarItem.tag != 2 && controller.tabBarItem.tag != 6)
			{
				[tabs addObject:controller];
			}
		}
		appDelegateS.mainTabBarController.viewControllers = tabs;
		
		tabs = [[NSMutableArray alloc] init];
		for (NSNumber *tag in savedTabsOrderArray)
		{
			if ([tag intValue] != 1 && [tag intValue] != 2 && [tag intValue] != 6)
			{
				[tabs addObject:tag];
			}
		}
		savedTabsOrderArray = tabs;
	}
	
	int count = appDelegateS.mainTabBarController.viewControllers.count;
	//DLog(@"savedTabsOrderArray: %@", savedTabsOrderArray);
	if (savedTabsOrderArray.count == count) 
	{
		BOOL needsReordering = NO;
		
		NSMutableDictionary *tabsOrderDictionary = [[NSMutableDictionary alloc] initWithCapacity:count];
		for (int i = 0; i < count; i ++) 
		{
			NSNumber *tag = [[NSNumber alloc] initWithInt:[[[appDelegateS.mainTabBarController.viewControllers objectAtIndexSafe:i] tabBarItem] tag]];
			[tabsOrderDictionary setObject:[NSNumber numberWithInt:i] forKey:[tag stringValue]];
			
			if (!needsReordering && ![(NSNumber *)[savedTabsOrderArray objectAtIndexSafe:i] isEqualToNumber:tag]) 
			{
				needsReordering = YES;
			}
		}
		
		if (needsReordering) 
		{
			NSMutableArray *tabsViewControllers = [[NSMutableArray alloc] initWithCapacity:count];
			for (int i = 0; i < count; i ++) 
			{
				[tabsViewControllers addObject:[appDelegateS.mainTabBarController.viewControllers objectAtIndexSafe:[(NSNumber *)[tabsOrderDictionary objectForKey:[(NSNumber *)[savedTabsOrderArray objectAtIndexSafe:i] stringValue]] intValue]]];
			}
			
			appDelegateS.mainTabBarController.viewControllers = [NSArray arrayWithArray:tabsViewControllers];
		}
	}
	
	if ([[NSUserDefaults standardUserDefaults] integerForKey:@"mainTabBarControllerSelectedIndex"]) 
	{
		if ([[NSUserDefaults standardUserDefaults] integerForKey:@"mainTabBarControllerSelectedIndex"] == 2147483647) 
		{
			appDelegateS.mainTabBarController.selectedViewController = appDelegateS.mainTabBarController.moreNavigationController;
		}
		else 
		{
			appDelegateS.mainTabBarController.selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"mainTabBarControllerSelectedIndex"];
		}
	}
	
	appDelegateS.mainTabBarController.moreNavigationController.delegate = self;
}

- (UIView *)createCellBackground:(NSUInteger)row
{
	UIView *backgroundView = [[UIView alloc] init];
	if(row % 2 == 0)
		backgroundView.backgroundColor = self.lightNormal;
	else
		backgroundView.backgroundColor = self.darkNormal;
	
	return backgroundView;
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
	DLog(@"received memory warning");
}

#pragma mark - Singleton methods

- (void)setup
{
	lightRed = [UIColor colorWithRed:255/255.0 green:146/255.0 blue:115/255.0 alpha:1];
	darkRed = [UIColor colorWithRed:226/255.0 green:0/255.0 blue:0/255.0 alpha:1];
	
	lightYellow = [UIColor colorWithRed:255/255.0 green:233/255.0 blue:115/255.0 alpha:1];
	darkYellow = [UIColor colorWithRed:255/255.0 green:215/255.0 blue:0/255.0 alpha:1];
	
	lightGreen = [UIColor colorWithRed:169/255.0 green:241/255.0 blue:108/255.0 alpha:1];
	darkGreen = [UIColor colorWithRed:103/255.0 green:227/255.0 blue:0/255.0 alpha:1];
	
	//lightBlue = [[UIColor colorWithRed:100/255.0 green:168/255.0 blue:209/255.0 alpha:1] retain];
	//darkBlue = [[UIColor colorWithRed:9/255.0 green:105/255.0 blue:162/255.0 alpha:1] retain];
	
	lightBlue = [UIColor colorWithRed:87/255.0 green:198/255.0 blue:255/255.0 alpha:1];
	darkBlue = [UIColor colorWithRed:28/255.0 green:163/255.0 blue:255/255.0 alpha:1];
	
	//lightBlue = [[UIColor colorWithRed:14/255.0 green:148/255.0 blue:218/255.0 alpha:1] retain];
	//darkBlue = [[UIColor colorWithRed:54/255.0 green:142/255.0 blue:188/255.0 alpha:1] retain];
	
	lightNormal = [UIColor whiteColor];
	darkNormal = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];
	
	//windowColor = [[UIColor colorWithRed:241.0/255.0 green:246.0/255.0 blue:253.0/255.0 alpha:1] retain];
	//windowColor = [[UIColor colorWithRed:206.0/255.0 green:211.0/255.0 blue:218.0/255.0 alpha:1] retain];
	windowColor = [UIColor colorWithWhite:.3 alpha:1];
	jukeboxColor = [UIColor colorWithRed:140.0/255.0 green:0.0 blue:0.0 alpha:1.0];
	
	isCellEnabled = YES;
	deleteButtonImage = [UIImage imageNamed:@"delete-button.png"];
	cacheButtonImage = [UIImage imageNamed:@"cache-button.png"];
	queueButtonImage = [UIImage imageNamed:@"queue-button.png"];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(didReceiveMemoryWarning) 
												 name:UIApplicationDidReceiveMemoryWarningNotification 
											   object:nil];
}

+ (id)sharedInstance
{
    static ViewObjectsSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
