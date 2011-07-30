//
//  iSubAppDelegate.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#include "MKStoreManager.h"

@class BBSplitViewController, ViewObjectsSingleton, DatabaseControlsSingleton, MusicControlsSingleton, SocialControlsSingleton, MGSplitViewController, iPadMainMenu, InitialDetailViewController, ASIHTTPRequest, SA_OAuthTwitterEngine, LoadingScreen, FMDatabase, Reachability, iPhoneStreamingPlayerViewController, SettingsViewController, RootViewController, AudioStreamer, Index, Artist, Album, Song, IntroViewController, HTTPServer;

@interface iSubAppDelegate : NSObject <UIApplicationDelegate, MKStoreKitDelegate> 
{	
	ViewObjectsSingleton *viewObjects;
	DatabaseControlsSingleton *databaseControls;
	MusicControlsSingleton *musicControls;
	SocialControlsSingleton *socialControls;
	
	UIWindow *window;
	
	BOOL isIntroShowing;
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
	//IBOutlet BBSplitViewController *splitView;
	iPadMainMenu *mainMenu;
	InitialDetailViewController *initialDetail;
	
	// Network connectivity objects
	//
    Reachability *wifiReach;
	int reachabilityStatus;
	
	// User defaults
	//
	// TODO: Remove these
	NSString *defaultUrl;
	NSString *defaultUserName;
	NSString *defaultPassword;
	//NSString *cachedIP;
	//NSInteger cachedIPHour;
	
	// Settings
	//
	NSMutableDictionary *settingsDictionary;
	
	// Multitasking stuff
	BOOL isMultitaskingSupported;
	UIBackgroundTaskIdentifier backgroundTask;
	BOOL isHighRez;
	
	
	BOOL showIntro;
	
	HTTPServer *httpServer;
	NSDictionary *addresses;
	BOOL *isHttpServerOn;
	
	BOOL isInBackground;
}

- (void)startStopServer;

@property (nonatomic, retain) IBOutlet UIWindow *window;

@property BOOL isIntroShowing;

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
@property int reachabilityStatus;

// User defaults
//
// TODO: Remove these
@property (nonatomic, retain) NSString *defaultUrl;
@property (nonatomic, retain) NSString *defaultUserName;
@property (nonatomic, retain) NSString *defaultPassword;
//@property (nonatomic, retain) NSString *cachedIP;
//@property NSInteger cachedIPHour;

// Settings
//
@property (nonatomic, retain) NSMutableDictionary *settingsDictionary;

// Multitasking stuff
@property BOOL isMultitaskingSupported;
@property UIBackgroundTaskIdentifier backgroundTask;
@property BOOL isHighRez;

+ (iSubAppDelegate *)sharedInstance;

- (void)enterOnlineModeForce;
- (void)enterOfflineModeForce;

- (void)appInit;
- (void)appInit2;
- (void)appInit3;
- (void)appInit4;

- (void)saveDefaults;
- (NSString *)getBaseUrl:(NSString *)action;
- (void)reachabilityChanged: (NSNotification *)note;
- (BOOL)isURLValid:(NSString *)url error:(NSError **)error;
- (NSString *)getIPAddressForHost:(NSString *)theHost;
- (NSInteger)getHour;

- (NSString *) formatFileSize:(unsigned long long int)size;
- (NSString *) formatTime:(float)seconds;
- (NSString *) relativeTime:(NSDate *)date;

- (BOOL)isWifi;

- (void)batteryStateChanged:(NSNotification *)notification;

- (void) checkAPIVersion;

@end


