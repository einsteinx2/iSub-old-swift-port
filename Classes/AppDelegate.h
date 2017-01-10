//
//  AppDelegate.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#ifndef iSub_AppDelegate_h
#define iSub_AppDelegate_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class SidePanelController, NetworkStatus, Server;
@interface AppDelegate : NSObject <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;
@property (strong) SidePanelController *sidePanelController;

@property (strong) NetworkStatus *networkStatus;
@property (readonly) BOOL isWifi;

+ (AppDelegate *)si;

- (void)enterOnlineModeForce;
- (void)enterOfflineModeForce;

- (void)loadHockeyApp;

- (void)switchServerTo:(Server *)server redirectUrl:(NSString *)redirectionUrl;

@end

#endif

