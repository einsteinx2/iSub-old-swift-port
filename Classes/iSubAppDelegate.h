//
//  iSubAppDelegate.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#ifndef iSub_iSubAppDelegate_h
#define iSub_iSubAppDelegate_h

#define appDelegateS [iSubAppDelegate sharedInstance]

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class BBSplitViewController, iPadRootViewController, InitialDetailViewController, LoadingScreen, FMDatabase, iPhoneStreamingPlayerViewController, SettingsViewController, FoldersViewController, AudioStreamer, IntroViewController, ISMSStatusLoader, MPMoviePlayerController, HTTPServer, ServerListViewController, EX2Reachability, ItemViewController, NewItemViewController, JASidePanelController, ISMSServer;

@interface iSubAppDelegate : NSObject <UIApplicationDelegate>

@property (strong) iPadRootViewController *ipadRootViewController;

@property (strong) HTTPServer *hlsProxyServer;

@property (strong) ISMSStatusLoader *statusLoader;

// New UI
@property (nonatomic, strong) UIWindow *window;
@property (strong) JASidePanelController *sidePanelController;



@property (strong) IntroViewController *introController;
@property (strong) SettingsViewController *settingsViewController;
@property (strong) IBOutlet UIImageView *background;
@property (strong) UITabBarController *currentTabBarController;

@property (strong) UINavigationController *supportNavigationController;

@property (strong) ServerListViewController *serverListViewController;

// Network connectivity objects and variables
//
@property (strong) EX2Reachability *wifiReach;
@property (readonly) BOOL isWifi;

// Multitasking stuff
@property UIBackgroundTaskIdentifier backgroundTask;
@property BOOL isInBackground;

@property BOOL showIntro;

@property (strong) NSURL *referringAppUrl;

@property (strong) MPMoviePlayerController *moviePlayer;

- (void)backToReferringApp;

+ (iSubAppDelegate *)sharedInstance;

- (void)enterOnlineModeForce;
- (void)enterOfflineModeForce;

- (void)loadFlurryAnalytics;
- (void)loadHockeyApp;
- (void)loadInAppPurchaseStore;

- (void)reachabilityChanged:(NSNotification *)note;

- (void)showSettings;

- (void)batteryStateChanged:(NSNotification *)notification;

- (void)checkServer;

- (NSString *)zipAllLogFiles;

- (void)checkWaveBoxRelease;

- (void)switchServer:(ISMSServer *)server redirectUrl:(NSString *)redirectionUrl;


@end

#endif

