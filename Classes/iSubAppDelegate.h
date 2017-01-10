//
//  iSubAppDelegate.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#ifndef iSub_iSubAppDelegate_h
#define iSub_iSubAppDelegate_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class BBSplitViewController, iPadRootViewController, InitialDetailViewController, LoadingScreen, FMDatabase, iPhoneStreamingPlayerViewController, SettingsViewController, FoldersViewController, AudioStreamer, IntroViewController, StatusLoader, MPMoviePlayerController, HTTPServer, ServerListViewController, EX2Reachability, ItemViewController, ItemViewController, SidePanelController, Server, NetworkStatus, MBProgressHUD;

@interface iSubAppDelegate : NSObject <UIApplicationDelegate>

@property (strong) iPadRootViewController *ipadRootViewController;

@property (strong) HTTPServer *hlsProxyServer;

@property (strong) StatusLoader *statusLoader;

// New UI
@property (nonatomic, strong) UIWindow *window;
@property (strong) SidePanelController *sidePanelController;

// Network connectivity objects and variables
//
@property (strong) NetworkStatus *networkStatus;
@property (readonly) BOOL isWifi;

// Multitasking stuff
@property UIBackgroundTaskIdentifier backgroundTask;
@property BOOL isInBackground;

@property (strong) NSURL *referringAppUrl;

@property (strong) MPMoviePlayerController *moviePlayer;

@property (nonatomic) BOOL isLoadingScreenShowing;
@property (strong) MBProgressHUD *HUD;

- (void)backToReferringApp;

+ (iSubAppDelegate *)si;

- (void)enterOnlineModeForce;
- (void)enterOfflineModeForce;

//- (void)loadFlurryAnalytics;
- (void)loadHockeyApp;

- (void)reachabilityChanged;

- (void)showSettings;

- (void)batteryStateChanged:(NSNotification *)notification;

- (void)checkServer;

- (NSString *)zipAllLogFiles;

- (void)checkWaveBoxRelease;

- (void)switchServerTo:(Server *)server redirectUrl:(NSString *)redirectionUrl;

- (void)showLoadingScreenOnMainWindowWithMessage:(NSString *)message;
- (void)showLoadingScreen:(UIView *)view withMessage:(NSString *)message;
- (void)showAlbumLoadingScreenOnMainWindowWithSender:(id)sender;
- (void)showAlbumLoadingScreen:(UIView *)view sender:(id)sender;
- (void)hideLoadingScreen;

@end

#endif

