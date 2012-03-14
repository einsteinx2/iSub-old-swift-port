//
//  iSubAppDelegate.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "MKStoreManager.h"
#import "SUSServerChecker.h"
#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>

#define appDelegateS [iSubAppDelegate sharedInstance]

@class BBSplitViewController, iPadRootViewController, InitialDetailViewController, SA_OAuthTwitterEngine, LoadingScreen, FMDatabase, Reachability, iPhoneStreamingPlayerViewController, SettingsViewController, FoldersViewController, AudioStreamer, Index, Artist, Album, Song, IntroViewController, HTTPServer;

@interface iSubAppDelegate : NSObject <UIApplicationDelegate, MKStoreKitDelegate, SUSServerURLCheckerDelegate, MFMailComposeViewControllerDelegate>
{		
	UIWindow *window;
	
	IntroViewController *introController;
	
	// Main interface elements for iPhone
	//
	SettingsViewController *settingsViewController;
	
	// Network connectivity objects
	//
    Reachability *wifiReach;
	int reachabilityStatus;
	
	// Multitasking stuff
	UIBackgroundTaskIdentifier backgroundTask;	
	
	BOOL showIntro;
	
	HTTPServer *httpServer;
	NSDictionary *addresses;
	BOOL *isHttpServerOn;
	
	BOOL isInBackground;
}

- (void)startStopServer;

@property (nonatomic, retain) IBOutlet UIWindow *window;

// Main interface elements for iPhone
//
@property (retain) IBOutlet UIImageView *background;
@property (retain) UITabBarController *currentTabBarController;
@property (retain) IBOutlet UITabBarController *mainTabBarController;
@property (retain) IBOutlet UITabBarController *offlineTabBarController;
@property (retain) IBOutlet UINavigationController *homeNavigationController;
@property (retain) IBOutlet UINavigationController *playerNavigationController;
@property (retain) IBOutlet UINavigationController *artistsNavigationController;
@property (retain) IBOutlet FoldersViewController *rootViewController;
@property (retain) IBOutlet UINavigationController *allAlbumsNavigationController;
@property (retain) IBOutlet UINavigationController *allSongsNavigationController;
@property (retain) IBOutlet UINavigationController *playlistsNavigationController;
@property (retain) IBOutlet UINavigationController *bookmarksNavigationController;
@property (retain) IBOutlet UINavigationController *playingNavigationController;
@property (retain) IBOutlet UINavigationController *genresNavigationController;
@property (retain) IBOutlet UINavigationController *cacheNavigationController;
@property (retain) IBOutlet UINavigationController *chatNavigationController;
@property (retain) UINavigationController *supportNavigationController;


@property (retain) iPadRootViewController *ipadRootViewController;

// Network connectivity objects and variables
//
@property (retain) Reachability *wifiReach;
@property (readonly) BOOL isWifi;

// Multitasking stuff
@property UIBackgroundTaskIdentifier backgroundTask;

+ (iSubAppDelegate *)sharedInstance;

- (void)enterOnlineModeForce;
- (void)enterOfflineModeForce;

- (void)loadFlurryAnalytics;
- (void)loadHockeyApp;
//- (void)loadCrittercism;
- (void)loadInAppPurchaseStore;
- (void)createHTTPServer;

- (void)reachabilityChanged: (NSNotification *)note;
- (NSInteger)getHour;

- (void)showSettings;

//- (BOOL)isWifi;

- (void)batteryStateChanged:(NSNotification *)notification;

- (void)startRedirectingLogToFile;
- (void)stopRedirectingLogToFile;

- (void)checkServer;

@end


