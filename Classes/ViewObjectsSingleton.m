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
#import "UIDevice-Hardware.h"
#import "MGSplitViewController.h"
#import "iPadMainMenu.h"
#import "SavedSettings.h"

static ViewObjectsSingleton *sharedInstance = nil;

@implementation ViewObjectsSingleton

// Constants
@synthesize kHorizSwipeDragMin, kVertSwipeDragMax;

// XMLParser objects used to tell the parser how to parse
@synthesize parseState, allAlbumsParseState, allSongsParseState;

// Home page objects
@synthesize homeListOfAlbums;

// Artists page objects
//@synthesize artistIndex, listOfArtists, isArtistsLoading;
@synthesize isArtistsLoading;

// Albums page objects and variables
@synthesize currentArtistName, currentArtistId; 

// All albums view objects
@synthesize allAlbumsListOfAlbums, allAlbumsAlbumObject, allAlbumsListOfSongs, allAlbumsCurrentArtistName, allAlbumsCurrentArtistId, allAlbumsLoadingScreen, allAlbumsLoadingProgress, isSearchingAllAlbums, isAlbumsLoading;

// All songs view objects
@synthesize isSongsLoading;

// Playlists view objects
@synthesize listOfPlaylists, listOfPlaylistSongs, localPlaylist, listOfLocalPlaylists, isLocalPlaylist;

// Playing view objects
@synthesize listOfPlayingSongs;

// Settings page objects
@synthesize serverToEdit;

// Chat page objects
@synthesize chatMessages;

// New stuff
@synthesize isCellEnabled, cellEnabledTimer, queueAlbumListOfAlbums, queueAlbumListOfSongs, isEditing, isEditing2, multiDeleteList, isOfflineMode, isOnlineModeAlertShowing, cancelLoading;

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

- (void)showLoadingScreenOnMainWindow
{
	if (isLoadingScreenShowing)
		return;
	
	isLoadingScreenShowing = YES;
	
	if (IS_IPAD())
		[self showLoadingScreen:appDelegate.splitView.view blockInput:YES mainWindow:YES];
	else
		[self showLoadingScreen:appDelegate.currentTabBarController.view blockInput:YES mainWindow:YES];
}

- (void)showLoadingScreen:(UIView *)view blockInput:(BOOL)blockInput mainWindow:(BOOL)mainWindow
{
	if (isLoadingScreenShowing)
		return;
	
	isLoadingScreenShowing = YES;
	
	CGRect newFrame = CGRectMake(0, 0, view.bounds.size.width, view.bounds.size.height);
	
	loadingBackground = [[UIView alloc] init];
	loadingBackground.frame = newFrame;
	if (mainWindow)
		loadingBackground.backgroundColor = [UIColor blackColor];
	else
		loadingBackground.backgroundColor = [UIColor clearColor];
	loadingBackground.alpha = 0.1;
	
	inputBlocker = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	inputBlocker.frame = newFrame;
	inputBlocker.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	inputBlocker.enabled = blockInput;
	[loadingBackground addSubview:inputBlocker];
	
	loadingScreen = [[UIImageView alloc] init];
	loadingScreen.frame = CGRectMake(0, 0, 240, 180);
	loadingScreen.center = CGPointMake(newFrame.size.width / 2, newFrame.size.height / 2);
	loadingScreen.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin;
	loadingScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
	loadingScreen.alpha = 0.1;
	
	loadingLabel = [[UILabel alloc] init];
	loadingLabel.backgroundColor = [UIColor clearColor];
	loadingLabel.textColor = [UIColor whiteColor];
	loadingLabel.font = [UIFont boldSystemFontOfSize:32];
	loadingLabel.textAlignment = UITextAlignmentCenter;
	[loadingLabel setText:@"Loading"];
	loadingLabel.frame = CGRectMake(20, 20, 200, 80);
	[loadingScreen addSubview:loadingLabel];
	[loadingLabel release];
	
	activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	activityIndicator.frame = CGRectMake(95, 100, 50, 50);
	[loadingScreen addSubview:activityIndicator];
	[activityIndicator startAnimating];
	[activityIndicator release];
	
	[view addSubview:loadingScreen];
	[view bringSubviewToFront:loadingScreen];
	[view addSubview:loadingBackground];
	[view bringSubviewToFront:loadingBackground];
		
	// Animate it on screen
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.4];
	loadingBackground.alpha = .20;
	loadingScreen.alpha = .80;
	[UIView commitAnimations];	
}

- (void)showAlbumLoadingScreen:(UIView *)view sender:(id)sender
{	
	if (isLoadingScreenShowing)
		return;
	
	isLoadingScreenShowing = YES;
	
	CGRect newFrame = CGRectMake(0, 0, view.bounds.size.width, view.bounds.size.height);
	
	loadingBackground = [[UIView alloc] init];
	loadingBackground.frame = newFrame;
	loadingBackground.backgroundColor = [UIColor clearColor];
	loadingBackground.alpha = 0.1;
	
	inputBlocker = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	inputBlocker.frame = newFrame;
	inputBlocker.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[inputBlocker addTarget:sender action:@selector(cancelLoad) forControlEvents:UIControlEventTouchUpInside];
	[loadingBackground addSubview:inputBlocker];
	
	loadingScreen = [[UIImageView alloc] init];
	loadingScreen.frame = CGRectMake(0, 0, 240, 180);
	loadingScreen.center = CGPointMake(newFrame.size.width / 2, newFrame.size.height / 2);
	loadingScreen.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin;
	loadingScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
	loadingScreen.alpha = 0.1;
	
	loadingLabel = [[UILabel alloc] init];
	loadingLabel.backgroundColor = [UIColor clearColor];
	loadingLabel.textColor = [UIColor whiteColor];
	loadingLabel.font = [UIFont boldSystemFontOfSize:32];
	loadingLabel.textAlignment = UITextAlignmentCenter;
	[loadingLabel setText:@"Loading"];
	loadingLabel.frame = CGRectMake(20, 5, 200, 80);
	[loadingScreen addSubview:loadingLabel];
	[loadingLabel release];
	
	activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	activityIndicator.frame = CGRectMake(95, 85, 50, 50);
	[loadingScreen addSubview:activityIndicator];
	[activityIndicator startAnimating];
	[activityIndicator release];
	
	UILabel *infoLabel = [[UILabel alloc] init];
	infoLabel.backgroundColor = [UIColor clearColor];
	infoLabel.textColor = [UIColor whiteColor];
	infoLabel.font = [UIFont systemFontOfSize:16];
	infoLabel.textAlignment = UITextAlignmentCenter;
	[infoLabel setText:@"Tap to cancel"];
	infoLabel.frame = CGRectMake(20, 110, 200, 80);
	[loadingScreen addSubview:infoLabel];
	[infoLabel release];
	
	[view addSubview:loadingScreen];
	[view bringSubviewToFront:loadingScreen];
	[view addSubview:loadingBackground];
	[view bringSubviewToFront:loadingBackground];
	
	// Animate it on screen
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.4];
	loadingBackground.alpha = .20;
	loadingScreen.alpha = .80;
	[UIView commitAnimations];
}
	
- (void)hideLoadingScreen
{
	if (!isLoadingScreenShowing)
		return;
	
	isLoadingScreenShowing = NO;
	
	// Animate it off screen
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(loadingScreenDidFadeOut:finished:context:)];
	loadingBackground.alpha = 0.0;
	loadingScreen.alpha = 0.0;
	[UIView commitAnimations];	
}

- (void)loadingScreenDidFadeOut:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
	if (loadingScreen != nil)
	{
		[loadingBackground removeFromSuperview];
		[loadingScreen removeFromSuperview];
		[inputBlocker removeFromSuperview];
		
		[loadingBackground release]; loadingBackground = nil;
		[loadingScreen release]; loadingScreen = nil;
		[inputBlocker release]; inputBlocker = nil;
	}
}
		

- (UIColor *) currentDarkColor
{
	//switch ([[appDelegate.settingsDictionary objectForKey:@"cacheSongCellColorSetting"] intValue])
	switch([SavedSettings sharedInstance].cachedSongCellColorType)
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
	//switch ([[appDelegate.settingsDictionary objectForKey:@"cacheSongCellColorSetting"] intValue])
	switch([SavedSettings sharedInstance].cachedSongCellColorType)
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
		[[NSUserDefaults standardUserDefaults] setInteger:appDelegate.mainTabBarController.selectedIndex forKey:@"mainTabBarControllerSelectedIndex"];
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
	if (isOfflineMode == NO)
		[[NSUserDefaults standardUserDefaults] setInteger:appDelegate.mainTabBarController.selectedIndex forKey:@"mainTabBarControllerSelectedIndex"];
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController
{
	if (isOfflineMode == NO)
		[[NSUserDefaults standardUserDefaults] setInteger:appDelegate.mainTabBarController.selectedIndex forKey:@"mainTabBarControllerSelectedIndex"];
}

- (void)tabBarController:(UITabBarController *)tabBarController didEndCustomizingViewControllers:(NSArray *)viewControllers changed:(BOOL)changed
{
    int count = tabBarController.viewControllers.count;
    NSMutableArray *savedTabsOrderArray = [[NSMutableArray alloc] initWithCapacity:count];
    for (int i = 0; i < count; i ++)
	{
        [savedTabsOrderArray addObject:[NSNumber numberWithInt:[[[tabBarController.viewControllers objectAtIndex:i] tabBarItem] tag]]];
    }
    [[NSUserDefaults standardUserDefaults] setObject:[NSArray arrayWithArray:savedTabsOrderArray] forKey:@"mainTabBarTabsOrder"];
	[[NSUserDefaults standardUserDefaults] synchronize];
    [savedTabsOrderArray release];
}

- (void) orderMainTabBarController
{
	appDelegate.currentTabBarController = appDelegate.mainTabBarController;
	appDelegate.mainTabBarController.delegate = self;
	
	NSArray *savedTabsOrderArray = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"mainTabBarTabsOrder"] retain];
	
	// If this is an old device, remove Albums and Songs tabs
	//if (![[appDelegate.settingsDictionary objectForKey:@"enableSongsTabSetting"] isEqualToString:@"YES"]) 
	if (![SavedSettings sharedInstance].isSongsTabEnabled)
	{
		DLog(@"isSongsTabEnabled: %i", [SavedSettings sharedInstance].isSongsTabEnabled);
		NSMutableArray *tabs = [[NSMutableArray alloc] init];
		for (UIViewController *controller in appDelegate.mainTabBarController.viewControllers)
		{
			if (controller.tabBarItem.tag != 1 && controller.tabBarItem.tag != 2 && controller.tabBarItem.tag != 6)
			{
				[tabs addObject:controller];
			}
		}
		appDelegate.mainTabBarController.viewControllers = tabs;
		[tabs release];
		
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
	
	int count = appDelegate.mainTabBarController.viewControllers.count;
	//DLog(@"savedTabsOrderArray: %@", savedTabsOrderArray);
	if (savedTabsOrderArray.count == count) 
	{
		BOOL needsReordering = NO;
		
		NSMutableDictionary *tabsOrderDictionary = [[NSMutableDictionary alloc] initWithCapacity:count];
		for (int i = 0; i < count; i ++) 
		{
			NSNumber *tag = [[NSNumber alloc] initWithInt:[[[appDelegate.mainTabBarController.viewControllers objectAtIndex:i] tabBarItem] tag]];
			[tabsOrderDictionary setObject:[NSNumber numberWithInt:i] forKey:[tag stringValue]];
			
			if (!needsReordering && ![(NSNumber *)[savedTabsOrderArray objectAtIndex:i] isEqualToNumber:tag]) 
			{
				needsReordering = YES;
			}
			[tag release];
		}
		
		if (needsReordering) 
		{
			NSMutableArray *tabsViewControllers = [[NSMutableArray alloc] initWithCapacity:count];
			for (int i = 0; i < count; i ++) 
			{
				[tabsViewControllers addObject:[appDelegate.mainTabBarController.viewControllers objectAtIndex:[(NSNumber *)[tabsOrderDictionary objectForKey:[(NSNumber *)[savedTabsOrderArray objectAtIndex:i] stringValue]] intValue]]];
			}
			[tabsOrderDictionary release];
			
			appDelegate.mainTabBarController.viewControllers = [NSArray arrayWithArray:tabsViewControllers];
			[tabsViewControllers release];
		}
	}
	[savedTabsOrderArray release];
	
	if ([[NSUserDefaults standardUserDefaults] integerForKey:@"mainTabBarControllerSelectedIndex"]) 
	{
		if ([[NSUserDefaults standardUserDefaults] integerForKey:@"mainTabBarControllerSelectedIndex"] == 2147483647) 
		{
			appDelegate.mainTabBarController.selectedViewController = appDelegate.mainTabBarController.moreNavigationController;
		}
		else 
		{
			appDelegate.mainTabBarController.selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"mainTabBarControllerSelectedIndex"];
		}
	}
	
	appDelegate.mainTabBarController.moreNavigationController.delegate = self;
}

- (UIView *)createCellBackground:(NSUInteger)row
{
	UIView *backgroundView = [[[UIView alloc] init] autorelease];
	if(row % 2 == 0)
		backgroundView.backgroundColor = lightNormal;
	else
		backgroundView.backgroundColor = darkNormal;
	
	return backgroundView;
}

#pragma mark -
#pragma mark Singleton methods

- (void)setup
{
	appDelegate = (iSubAppDelegate*)[[UIApplication sharedApplication] delegate];
	
	kHorizSwipeDragMin = 3;
	kVertSwipeDragMax = 80;
	
	lightRed = [[UIColor colorWithRed:255/255.0 green:146/255.0 blue:115/255.0 alpha:1] retain];
	darkRed = [[UIColor colorWithRed:226/255.0 green:0/255.0 blue:0/255.0 alpha:1] retain];
	
	lightYellow = [[UIColor colorWithRed:255/255.0 green:233/255.0 blue:115/255.0 alpha:1] retain];
	darkYellow = [[UIColor colorWithRed:255/255.0 green:215/255.0 blue:0/255.0 alpha:1] retain];
	
	lightGreen = [[UIColor colorWithRed:169/255.0 green:241/255.0 blue:108/255.0 alpha:1] retain];
	darkGreen = [[UIColor colorWithRed:103/255.0 green:227/255.0 blue:0/255.0 alpha:1] retain];
	
	//lightBlue = [[UIColor colorWithRed:100/255.0 green:168/255.0 blue:209/255.0 alpha:1] retain];
	//darkBlue = [[UIColor colorWithRed:9/255.0 green:105/255.0 blue:162/255.0 alpha:1] retain];
	
	lightBlue = [[UIColor colorWithRed:87/255.0 green:198/255.0 blue:255/255.0 alpha:1] retain];
	darkBlue = [[UIColor colorWithRed:28/255.0 green:163/255.0 blue:255/255.0 alpha:1] retain];
	
	//lightBlue = [[UIColor colorWithRed:14/255.0 green:148/255.0 blue:218/255.0 alpha:1] retain];
	//darkBlue = [[UIColor colorWithRed:54/255.0 green:142/255.0 blue:188/255.0 alpha:1] retain];
	
	lightNormal = [[UIColor whiteColor] retain];
	darkNormal = [[UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1] retain];
	
	//windowColor = [[UIColor colorWithRed:241.0/255.0 green:246.0/255.0 blue:253.0/255.0 alpha:1] retain];
	//windowColor = [[UIColor colorWithRed:206.0/255.0 green:211.0/255.0 blue:218.0/255.0 alpha:1] retain];
	windowColor = [[UIColor colorWithWhite:.3 alpha:1] retain];
	jukeboxColor = [[UIColor colorWithRed:140.0/255.0 green:0.0 blue:0.0 alpha:1.0] retain];
	
	self.isCellEnabled = YES;
	self.isEditing = NO;
	self.isArtistsLoading = NO;
	self.isAlbumsLoading = NO;
	self.isSongsLoading = NO;
	self.isOnlineModeAlertShowing = NO;
	self.cancelLoading = NO;
	self.deleteButtonImage = [UIImage imageNamed:@"delete-button.png"];
	self.cacheButtonImage = [UIImage imageNamed:@"cache-button.png"];
	self.queueButtonImage = [UIImage imageNamed:@"queue-button.png"];
	self.isSettingsShowing = NO;
	
	//isJukebox = NO;
	
	isNoNetworkAlertShowing = NO;
	isLoadingScreenShowing = NO;
}

+ (ViewObjectsSingleton*)sharedInstance
{
    @synchronized(self)
    {
		if (sharedInstance == nil)
			[[self alloc] init];
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
			[sharedInstance setup];
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

- (id)retain 
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
}

@end
