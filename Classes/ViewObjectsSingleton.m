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
#import "UIDevice+Hardware.h"
#import "SavedSettings.h"
#import "NSArray+Additions.h"

static ViewObjectsSingleton *sharedInstance = nil;

@implementation ViewObjectsSingleton

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

@synthesize isSettingsShowing;

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
    [HUD removeFromSuperview];
     HUD = nil;
}

- (void)showLoadingScreenOnMainWindowWithMessage:(NSString *)message
{	
	[self showLoadingScreen:appDelegateS.window withMessage:message];
}

- (void)showLoadingScreen:(UIView *)view withMessage:(NSString *)message
{
	if (isLoadingScreenShowing)
		return;
	
	isLoadingScreenShowing = YES;
	
	HUD = [[MBProgressHUD alloc] initWithView:view];
	[appDelegateS.window addSubview:HUD];
	HUD.delegate = self;
	HUD.labelText = message ? message : @"Loading";
	[HUD show:YES];
}

- (void)showAlbumLoadingScreen:(UIView *)view sender:(id)sender
{	
	if (isLoadingScreenShowing)
		return;
	
	isLoadingScreenShowing = YES;
	
	HUD = [[MBProgressHUD alloc] initWithView:appDelegateS.window];
	HUD.userInteractionEnabled = YES;
	
	// TODO: verify on iPad
	UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
	cancelButton.bounds = CGRectMake(0, 0, 1024, 1024);
	cancelButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[cancelButton addTarget:sender action:@selector(cancelLoad) forControlEvents:UIControlEventTouchUpInside];
	[HUD addSubview:cancelButton];
	
	[appDelegateS.window addSubview:HUD];
	HUD.delegate = self;
	HUD.labelText = @"Loading";
	HUD.detailsLabelText = @"tap to cancel";
	[HUD show:YES];
}
	
- (void)hideLoadingScreen
{
	if (!isLoadingScreenShowing)
		return;
	
	isLoadingScreenShowing = NO;
	
	[HUD hide:YES];
}

- (UIColor *) currentDarkColor
{
	//switch ([[appDelegateS.settingsDictionary objectForKey:@"cacheSongCellColorSetting"] intValue])
	switch(settingsS.cachedSongCellColorType)
	{
		case 0:
			return darkRed;
		case 1:
			return darkYellow;
		case 2:
			return darkGreen;
		case 3:
			return darkBlue;
		default:
			return darkNormal;
	}
	
	return darkNormal;
}

- (UIColor *) currentLightColor
{
	//switch ([[appDelegateS.settingsDictionary objectForKey:@"cacheSongCellColorSetting"] intValue])
	switch(settingsS.cachedSongCellColorType)
	{
		case 0:
			return lightRed;
		case 1:
			return lightYellow;
		case 2:
			return lightGreen;
		case 3:
			return lightBlue;
		default:
			return lightNormal;
	}
	
	return lightNormal;
}

#pragma mark Tab Saving

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
	if (isOfflineMode == NO)
		[[NSUserDefaults standardUserDefaults] setInteger:appDelegateS.mainTabBarController.selectedIndex forKey:@"mainTabBarControllerSelectedIndex"];
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
	if (isOfflineMode == NO)
		[[NSUserDefaults standardUserDefaults] setInteger:appDelegateS.mainTabBarController.selectedIndex forKey:@"mainTabBarControllerSelectedIndex"];
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController
{
	if (isOfflineMode == NO)
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
		backgroundView.backgroundColor = lightNormal;
	else
		backgroundView.backgroundColor = darkNormal;
	
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
	
	self.isCellEnabled = YES;
	self.isArtistsLoading = NO;
	//self.isAlbumsLoading = NO;
	//self.isSongsLoading = NO;
	self.isOnlineModeAlertShowing = NO;
	self.cancelLoading = NO;
	self.deleteButtonImage = [UIImage imageNamed:@"delete-button.png"];
	self.cacheButtonImage = [UIImage imageNamed:@"cache-button.png"];
	self.queueButtonImage = [UIImage imageNamed:@"queue-button.png"];
	self.isSettingsShowing = NO;
	
	//isJukebox = NO;
	
	isNoNetworkAlertShowing = NO;
	isLoadingScreenShowing = NO;
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(didReceiveMemoryWarning) 
												 name:UIApplicationDidReceiveMemoryWarningNotification 
											   object:nil];
}

+ (ViewObjectsSingleton*)sharedInstance
{
    @synchronized(self)
    {
		if (sharedInstance == nil)
			sharedInstance = [[ViewObjectsSingleton alloc] init];
    }
    return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone 
{
    @synchronized(self) 
	{
        if (sharedInstance == nil) 
		{
            sharedInstance = [super allocWithZone:zone];
            return sharedInstance;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

-(id)init 
{
	if ((self = [super init]))
	{
		sharedInstance = self;
		
		[self setup];
	}
	
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

/*- (id)retain 
{
    return self;
}

- (unsigned)retainCount 
{
    return UINT_MAX;  // denotes an object that cannot be released
}

- (oneway void)release 
{
    //do nothing
}

- (id)autorelease 
{
    return self;
}*/

@end
