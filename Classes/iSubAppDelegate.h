//
//  iSubAppDelegate.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "MKStoreManager.h"
#import "SUSServerURLChecker.h"

@class BBSplitViewController, ViewObjectsSingleton, DatabaseSingleton, MusicSingleton, SocialSingleton, MGSplitViewController, iPadMainMenu, InitialDetailViewController, SA_OAuthTwitterEngine, LoadingScreen, FMDatabase, Reachability, iPhoneStreamingPlayerViewController, SettingsViewController, RootViewController, AudioStreamer, Index, Artist, Album, Song, IntroViewController, HTTPServer, CacheSingleton;

@interface iSubAppDelegate : NSObject <UIApplicationDelegate, MKStoreKitDelegate, SUSServerURLCheckerDelegate> 
{	
	ViewObjectsSingleton *viewObjects;
	DatabaseSingleton *databaseControls;
	MusicSingleton *musicControls;
	SocialSingleton *socialControls;
	CacheSingleton *cacheControls;
	
	UIWindow *window;
	
	IntroViewController *introController;
	
	// Main interface elements for iPhone
	//
	IBOutlet UIImageView *background;
	UITabBarController *currentTabBarController;
	IBOutlet UITabBarController *mainTabBarController;
	IBOutlet UITabBarController *offlineTabBarController;
	SettingsViewController *settingsViewController;
	// Tab Controllers
	IBOutlet UINavigationController *homeNavigationController;
	IBOutlet UINavigationController *playerNavigationController;
    IBOutlet UINavigationController *artistsNavigationController;
	IBOutlet RootViewController *rootViewController;
	IBOutlet UINavigationController *allAlbumsNavigationController;
	IBOutlet UINavigationController *allSongsNavigationController;
	IBOutlet UINavigationController *playlistsNavigationController;
	IBOutlet UINavigationController *bookmarksNavigationController;
	IBOutlet UINavigationController *playingNavigationController;
	IBOutlet UINavigationController *genresNavigationController;
	IBOutlet UINavigationController *cacheNavigationController;
	IBOutlet UINavigationController *chatNavigationController;	
	
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
@property (nonatomic, retain) IBOutlet UIImageView *background;
@property (nonatomic, retain) UITabBarController *currentTabBarController;
@property (nonatomic, retain) IBOutlet UITabBarController *mainTabBarController;
@property (nonatomic, retain) IBOutlet UITabBarController *offlineTabBarController;
@property (nonatomic, retain) IBOutlet UINavigationController *homeNavigationController;
@property (nonatomic, retain) IBOutlet UINavigationController *playerNavigationController;
@property (nonatomic, retain) IBOutlet UINavigationController *artistsNavigationController;
@property (nonatomic, retain) IBOutlet RootViewController *rootViewController;
@property (nonatomic, retain) IBOutlet UINavigationController *allAlbumsNavigationController;
@property (nonatomic, retain) IBOutlet UINavigationController *allSongsNavigationController;
@property (nonatomic, retain) IBOutlet UINavigationController *playlistsNavigationController;
@property (nonatomic, retain) IBOutlet UINavigationController *bookmarksNavigationController;
@property (nonatomic, retain) IBOutlet UINavigationController *playingNavigationController;
@property (nonatomic, retain) IBOutlet UINavigationController *genresNavigationController;
@property (nonatomic, retain) IBOutlet UINavigationController *cacheNavigationController;
@property (nonatomic, retain) IBOutlet UINavigationController *chatNavigationController;

// Main interface elements for iPad
//
@property (nonatomic, retain) IBOutlet MGSplitViewController *splitView;
@property (nonatomic, retain) IBOutlet iPadMainMenu *mainMenu;
@property (nonatomic, retain) IBOutlet InitialDetailViewController *initialDetail;

// Network connectivity objects and variables
//
@property (nonatomic, retain) Reachability *wifiReach;
@property (readonly) BOOL isWifi;

// Multitasking stuff
@property UIBackgroundTaskIdentifier backgroundTask;

+ (iSubAppDelegate *)sharedInstance;

- (void)enterOnlineModeForce;
- (void)enterOfflineModeForce;

- (void)loadFlurryAnalytics;
- (void)loadHockeyApp;
- (void)loadInAppPurchaseStore;
- (void)createHTTPServer;
- (void)appInit2;
- (void)createAndDisplayUI;

- (void)reachabilityChanged: (NSNotification *)note;
- (NSString *)getIPAddressForHost:(NSString *)theHost;
- (NSInteger)getHour;

//- (BOOL)isWifi;

- (void)batteryStateChanged:(NSNotification *)notification;

- (void) checkAPIVersion;

- (void)startRedirectingLogToFile;
- (void)stopRedirectingLogToFile;

- (void)checkServer;

- (NSString *)getStreamURLStringForSongId:(NSString *)songId;

@end


