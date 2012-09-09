//
//  iSubAppDelegate.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "MKStoreManager.h"
#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>
#import "BWHockeyManager.h"
#import "ISMSLoaderDelegate.h"

#define appDelegateS [iSubAppDelegate sharedInstance]

@class BBSplitViewController, iPadRootViewController, InitialDetailViewController, SA_OAuthTwitterEngine, LoadingScreen, FMDatabase, Reachability, iPhoneStreamingPlayerViewController, SettingsViewController, FoldersViewController, AudioStreamer, Index, Artist, Album, Song, IntroViewController, HTTPServer, ISMSStatusLoader;

@interface iSubAppDelegate : NSObject <UIApplicationDelegate, MKStoreKitDelegate, MFMailComposeViewControllerDelegate, BWHockeyManagerDelegate, ISMSLoaderDelegate>
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

@property (strong) ISMSStatusLoader *statusLoader;

@property (nonatomic) IBOutlet UIWindow *window;

// Main interface elements for iPhone
//
@property (strong) IBOutlet UIImageView *background;
@property (strong) UITabBarController *currentTabBarController;
@property (strong) IBOutlet UITabBarController *mainTabBarController;
@property (strong) IBOutlet UITabBarController *offlineTabBarController;
@property (strong) IBOutlet UINavigationController *homeNavigationController;
@property (strong) IBOutlet UINavigationController *playerNavigationController;
@property (strong) IBOutlet UINavigationController *artistsNavigationController;
@property (strong) IBOutlet FoldersViewController *rootViewController;
@property (strong) IBOutlet UINavigationController *allAlbumsNavigationController;
@property (strong) IBOutlet UINavigationController *allSongsNavigationController;
@property (strong) IBOutlet UINavigationController *playlistsNavigationController;
@property (strong) IBOutlet UINavigationController *bookmarksNavigationController;
@property (strong) IBOutlet UINavigationController *playingNavigationController;
@property (strong) IBOutlet UINavigationController *genresNavigationController;
@property (strong) IBOutlet UINavigationController *cacheNavigationController;
@property (strong) IBOutlet UINavigationController *chatNavigationController;
@property (strong) UINavigationController *supportNavigationController;


@property (strong) iPadRootViewController *ipadRootViewController;

// Network connectivity objects and variables
//
@property (strong) Reachability *wifiReach;
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


