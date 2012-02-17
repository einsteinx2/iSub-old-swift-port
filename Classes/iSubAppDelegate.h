//
//  iSubAppDelegate.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "MKStoreManager.h"
#import "SUSServerChecker.h"
#import "Crittercism.h"

@class BBSplitViewController, ViewObjectsSingleton, DatabaseSingleton, MusicSingleton, SocialSingleton, MGSplitViewController, iPadMainMenu, InitialDetailViewController, SA_OAuthTwitterEngine, LoadingScreen, FMDatabase, Reachability, iPhoneStreamingPlayerViewController, SettingsViewController, RootViewController, AudioStreamer, Index, Artist, Album, Song, IntroViewController, HTTPServer, CacheSingleton, AudioEngine;

@interface iSubAppDelegate : NSObject <UIApplicationDelegate, MKStoreKitDelegate, SUSServerURLCheckerDelegate, CrittercismDelegate>
{	
	ViewObjectsSingleton *viewObjects;
	DatabaseSingleton *databaseControls;
	MusicSingleton *musicControls;
	SocialSingleton *socialControls;
	CacheSingleton *cacheControls;
    AudioEngine *audio;
	
	UIWindow *window;
	
	IntroViewController *introController;
	
	// Main interface elements for iPhone
	//
	SettingsViewController *settingsViewController;
	
	// Main interface elements for iPad
	//
	IBOutlet MGSplitViewController *splitView;
	iPadMainMenu *mainMenu;
	InitialDetailViewController *initialDetail;
	
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
@property (retain) IBOutlet RootViewController *rootViewController;
@property (retain) IBOutlet UINavigationController *allAlbumsNavigationController;
@property (retain) IBOutlet UINavigationController *allSongsNavigationController;
@property (retain) IBOutlet UINavigationController *playlistsNavigationController;
@property (retain) IBOutlet UINavigationController *bookmarksNavigationController;
@property (retain) IBOutlet UINavigationController *playingNavigationController;
@property (retain) IBOutlet UINavigationController *genresNavigationController;
@property (retain) IBOutlet UINavigationController *cacheNavigationController;
@property (retain) IBOutlet UINavigationController *chatNavigationController;
@property (retain) UINavigationController *supportNavigationController;

@property (readonly) UIView *mainView;

// Main interface elements for iPad
//
@property (retain) IBOutlet MGSplitViewController *splitView;
@property (retain) IBOutlet iPadMainMenu *mainMenu;
@property (retain) IBOutlet InitialDetailViewController *initialDetail;

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
- (void)loadCrittercism;
- (void)loadInAppPurchaseStore;
- (void)createHTTPServer;

- (void)reachabilityChanged: (NSNotification *)note;
- (NSInteger)getHour;

//- (BOOL)isWifi;

- (void)batteryStateChanged:(NSNotification *)notification;

- (void)startRedirectingLogToFile;
- (void)stopRedirectingLogToFile;

- (void)checkServer;

@end


