//
//  iSubAppDelegate.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "DatabaseSingleton.h"
#import "MusicSingleton.h"
#import "SocialSingleton.h"
#import "FMDatabaseAdditions.h"
#import "NSString+md5.h"
#import "ServerListViewController.h"
#import "FoldersViewController.h"
#import "Reachability.h"
#import "Album.h"
#import "Song.h"
#import <CoreFoundation/CoreFoundation.h>
#import <SystemConfiguration/SCNetworkReachability.h>
#include <netinet/in.h> 
#include <netdb.h>
#include <arpa/inet.h>
#import "NSString+hex.h"
#import "MKStoreManager.h"
#import "Server.h"
#import "UIDevice+Hardware.h"
#import "IntroViewController.h"
#import "CustomUIAlertView.h"
#import "HTTPServer.h"
#import "MyHTTPConnection.h"
#import "LocalhostAddresses.h"
#import "SFHFKeychainUtils.h"
#import "BWQuincyManager.h"
#import "BWHockeyManager.h"
#import "FlurryAnalytics.h"
#import "SavedSettings.h"
#import "CacheSingleton.h"
#import "NSMutableURLRequest+SUS.h"
#import "ISMSStreamManager.h"
#import "AudioEngine.h"
#import "UIDevice+Software.h"
#import "NSObject+ListMethods.h"
#import "ISMSUpdateChecker.h"
#import "NSArray+Additions.h"
#import "iPadRootViewController.h"
#import "MenuViewController.h"
#import "NSNotificationCenter+MainThread.h"
#import "ISMSCacheQueueManager.h"
#import "NSObject+GCDExtention.h"

@implementation iSubAppDelegate

@synthesize window;

// Main interface elements for iPhone
@synthesize background, currentTabBarController, mainTabBarController, offlineTabBarController;
@synthesize homeNavigationController, playerNavigationController, artistsNavigationController, rootViewController, allAlbumsNavigationController, allSongsNavigationController, playlistsNavigationController, bookmarksNavigationController, playingNavigationController, genresNavigationController, cacheNavigationController, chatNavigationController, supportNavigationController;

// Main interface elemements for iPad
@synthesize ipadRootViewController;

// Network connectivity objects
@synthesize wifiReach;

// Multitasking stuff
@synthesize backgroundTask;


+ (iSubAppDelegate *)sharedInstance
{
	return (iSubAppDelegate*)[UIApplication sharedApplication].delegate;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
	if (settingsS.isRotationLockEnabled && interfaceOrientation != UIInterfaceOrientationPortrait)
		return NO;
	return YES;
	
    // Return YES for supported orientations
    //return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark -
#pragma mark Application lifecycle
#pragma mark -


/*void onUncaughtException(NSException* exception)
{
    NSLog(@"uncaught exception: %@", exception.description);
}*/

- (void)applicationDidFinishLaunching:(UIApplication *)application
{   
    //NSSetUncaughtExceptionHandler(&onUncaughtException);

	// Start the save defaults timer and mem cache initial defaults
	[settingsS setupSaveState];
	
	// Setup network reachability notifications
	self.wifiReach = [Reachability reachabilityForLocalWiFi];
	[wifiReach startNotifier];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(reachabilityChanged:) name: kReachabilityChangedNotification object:nil];
	[wifiReach currentReachabilityStatus];
	
	// Check battery state and register for notifications
	[UIDevice currentDevice].batteryMonitoringEnabled = YES;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryStateChanged:) name:@"UIDeviceBatteryStateDidChangeNotification" object:[UIDevice currentDevice]];
	[self batteryStateChanged:nil];	

	// Handle offline mode
	if (settingsS.isForceOfflineMode)
	{
		viewObjectsS.isOfflineMode = YES;
		
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"Offline mode switch on, entering offline mode." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		alert.tag = 4;
		[alert performSelector:@selector(show) withObject:nil afterDelay:1.1];
	}
	else if ([wifiReach currentReachabilityStatus] == NotReachable)
	{
		viewObjectsS.isOfflineMode = YES;
		
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"No network detected, entering offline mode." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		alert.tag = 4;
		[alert performSelector:@selector(show) withObject:nil afterDelay:1.1];
	}
	else 
	{
		viewObjectsS.isOfflineMode = NO;
	}
	
	showIntro = NO;
	if (settingsS.isTestServer)
	{
		if (viewObjectsS.isOfflineMode)
		{
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Welcome!" message:@"Looks like this is your first time using iSub or you haven't set up your Subsonic account info yet.\n\nYou'll need an internet connection to watch the intro video and use the included demo account." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
			[alert performSelector:@selector(show) withObject:nil afterDelay:1.0];
		}
		else
		{
			showIntro = YES;
		}
	}
	
	// Make sure audio engine and cache singletons get loaded
	audioEngineS;
	cacheS;
	
    introController = nil;
	
	//DLog(@"md5: %@", [settings.urlString md5]);
	
	[self loadFlurryAnalytics];
	[self loadHockeyApp];
	//[self loadCrittercism];
	
	[self loadInAppPurchaseStore];
		
	// Setup Twitter connection
	if (!viewObjectsS.isOfflineMode && [[NSUserDefaults standardUserDefaults] objectForKey:@"twitterAuthData"])
	{
		[socialS createTwitterEngine];
	}
		
	// Create and display UI
	introController = nil;
	if (IS_IPAD())
	{
		ipadRootViewController = [[iPadRootViewController alloc] initWithNibName:nil bundle:nil];
		[self.window setBackgroundColor:[UIColor clearColor]];
		[self.window addSubview:ipadRootViewController.view];
		[self.window makeKeyAndVisible];
		
		if (showIntro)
		{
			introController = [[IntroViewController alloc] init];
			introController.modalPresentationStyle = UIModalPresentationFormSheet;
			[ipadRootViewController presentModalViewController:introController animated:NO];
		}
	}
	else
	{
		// Setup the tabBarController
		mainTabBarController.moreNavigationController.navigationBar.barStyle = UIBarStyleBlack;
		/*// Add the support tab
		[Crittercism showCrittercism:nil];
		UIViewController *vc = (UIViewController *)[Crittercism sharedInstance].crittercismViewController;
		self.supportNavigationController = [[UINavigationController alloc] initWithRootViewController:vc];
		supportNavigationController.tabBarItem.tag = 9;
		supportNavigationController.tabBarItem.image = [UIImage imageNamed:@"support-tabbaricon.png"];
		supportNavigationController.tabBarItem.title = @"Support";
		NSMutableArray *viewControllers = [NSMutableArray arrayWithArray:mainTabBarController.viewControllers];
		[viewControllers addObject:supportNavigationController];
		[mainTabBarController setViewControllers:viewControllers animated:NO];
		[vc logMethods];
		DLog(@"toolbarItems: %@", [vc toolbarItems]);*/
		
		//DLog(@"isOfflineMode: %i", viewObjectsS.isOfflineMode);
		if (viewObjectsS.isOfflineMode)
		{
			//DLog(@"--------------- isOfflineMode");
			self.currentTabBarController = self.offlineTabBarController;
			[self.window addSubview:self.offlineTabBarController.view];
		}
		else 
		{
			// Recover the tab order and load the main tabBarController
			self.currentTabBarController = self.mainTabBarController;
			
			//[viewObjectsS orderMainTabBarController]; // Do this after server check
			[self.window addSubview:self.mainTabBarController.view];
		}
		
		if (showIntro)
		{
			introController = [[IntroViewController alloc] init];
			[self.currentTabBarController presentModalViewController:introController animated:NO];
		}
	}
	if (settingsS.isJukeboxEnabled)
		window.backgroundColor = viewObjectsS.jukeboxColor;
	else 
		window.backgroundColor = viewObjectsS.windowColor;
	[window makeKeyAndVisible];	
	
	// Check the server status in the background
    if (!viewObjectsS.isOfflineMode)
	{
		//DLog(@"adding loading screen");
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
		
		[self checkServer];
	}
    
	// Recover current state if player was interrupted
	[ISMSStreamManager sharedInstance];
	[musicS resumeSong];
}

- (void)checkServer
{
	ISMSUpdateChecker *updateChecker = [[ISMSUpdateChecker alloc] init];
	[updateChecker checkForUpdate];

    // Check if the subsonic URL is valid by attempting to access the ping.view page, 
	// if it's not then display an alert and allow user to change settings if they want.
	// This is in case the user is, for instance, connected to a wifi network but does not 
	// have internet access or if the host url entered was wrong.
    if (!viewObjectsS.isOfflineMode) 
	{
        SUSServerChecker *checker = [[SUSServerChecker alloc] initWithDelegate:self];
		[checker checkServerUrlString:settingsS.urlString username:settingsS.username password:settingsS.password];
    }
	
	// Do a server check every half hour
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkServer) object:nil];
	NSTimeInterval delay = 30 * 60; // 30 minutes
	[self performSelector:@selector(checkServer) withObject:nil afterDelay:delay];
}

#pragma mark - SUS Server Check Delegate

- (void)SUSServerURLCheckRedirected:(SUSServerChecker *)checker redirectUrl:(NSURL *)url
{
	NSMutableString *redirectUrlString = [NSMutableString stringWithFormat:@"%@://%@", url.scheme, url.host];
	if (url.port)
		[redirectUrlString appendFormat:@":%@", url.port];
	
	if ([url.pathComponents count] > 3)
	{
		for (NSString *component in url.pathComponents)
		{
			if ([component isEqualToString:@"rest"])
				break;
			
			if (![component isEqualToString:@"/"])
			{
				[redirectUrlString appendFormat:@"/%@", component];
			}
		}
	}
	
	DLog(@"redirectUrlString: %@", redirectUrlString);
	
	settingsS.redirectUrlString = [NSString stringWithString:redirectUrlString];
}

- (void)SUSServerURLCheckFailed:(SUSServerChecker *)checker withError:(NSError *)error
{
	[viewObjectsS hideLoadingScreen];
	
    if(!viewObjectsS.isOfflineMode)
	{
		/*UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Server Unavailable" message:[NSString stringWithFormat:@"Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\n☆☆ Tap the gear in the top left and choose a server to return to online mode. ☆☆\n\nError code %i:\n%@", [error code], [error localizedDescription]] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:@"Settings", nil];
		alert.tag = 3;
		[alert show];
		[alert release];
		
		[self enterOfflineModeForce];*/
		
		[self enterOfflineMode];
	}
    
     checker = nil;
	
	settingsS.isNewSearchAPI = checker.isNewSearchAPI;
}

- (void)SUSServerURLCheckPassed:(SUSServerChecker *)checker
{
    //DLog(@"server check passed");
	
	settingsS.isNewSearchAPI = checker.isNewSearchAPI;
    
     checker = nil;
    
    //DLog(@"server verification passed, hiding loading screen");
    [viewObjectsS hideLoadingScreen];
	
	if (!IS_IPAD() && !viewObjectsS.isOfflineMode)
		[viewObjectsS orderMainTabBarController];
	
	// Start the queued downloads if Wifi is available
	[cacheQueueManagerS startDownloadQueue];
}

#pragma mark -

- (void)loadFlurryAnalytics
{
	BOOL isSessionStarted = NO;
	if (IS_RELEASE())
	{
		if (IS_LITE())
		{
			// Lite version key
			[FlurryAnalytics startSession:@"MQV1D5WQYUTCDAD6PFLU"];
			isSessionStarted = YES;
		}
		else
		{
			// Full version key
			[FlurryAnalytics startSession:@"3KK4KKD2PSEU5APF7PNX"];
			isSessionStarted = YES;
		}
	}
	else if (IS_BETA())
	{
		// Beta version key
		[FlurryAnalytics startSession:@"KNN9DUXQEENZUG4Q12UA"];
		isSessionStarted = YES;
	}
	
	if (isSessionStarted)
	{
		[FlurryAnalytics setSessionReportsOnPauseEnabled:YES];
		[FlurryAnalytics setSecureTransportEnabled:YES];
		
		// Send the firmware version
		UIDevice *device = [UIDevice currentDevice];
		NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:[device completeVersionString], @"FirmwareVersion", 
																		  [device platform], @"HardwareVersion", nil];
		[FlurryAnalytics logEvent:@"DeviceInfo" withParameters:params];
	}
}

- (void)loadHockeyApp
{
	// HockyApp Kits
	if (IS_BETA() && IS_ADHOC() && !IS_LITE())
	{
		[[BWQuincyManager sharedQuincyManager] setAppIdentifier:@"ada15ac4ffe3befbc66f0a00ef3d96af"];
		
		[[BWHockeyManager sharedHockeyManager] setAppIdentifier:@"ada15ac4ffe3befbc66f0a00ef3d96af"];
		[[BWHockeyManager sharedHockeyManager] setAlwaysShowUpdateReminder:NO];
		[[BWHockeyManager sharedHockeyManager] setDelegate:self];
	}
	else if (IS_RELEASE())
	{
		if (IS_LITE())
			[[BWQuincyManager sharedQuincyManager] setAppIdentifier:@"36cd77b2ee78707009f0a9eb9bbdbec7"];
		else
			[[BWQuincyManager sharedQuincyManager] setAppIdentifier:@"7c9cb46dad4165c9d3919390b651f6bb"];
	}
	[[BWQuincyManager sharedQuincyManager] setAutoSubmitCrashReport:YES];
	
	if ([[BWQuincyManager sharedQuincyManager] didCrashInLastSession])
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Oh no! iSub crashed!" message:@"iSub support has received your anonymous crash logs and they will be investigated. \n\nWould you also like to send an email to support with more details?" delegate:self cancelButtonTitle:@"No Thanks" otherButtonTitles:@"Send Email", @"Visit iSub Forum", nil];
		alert.tag = 7;
		[alert performSelector:@selector(show) withObject:nil afterDelay:2.];
	}
}

- (NSString *)customDeviceIdentifier 
{
#ifdef ADHOC
    if ([[UIDevice currentDevice] respondsToSelector:@selector(uniqueIdentifier)])
		return [[UIDevice currentDevice] performSelector:@selector(uniqueIdentifier)];
#endif
	
	return nil;
}

/*- (void)loadCrittercism
{
	//if (IS_BETA() && IS_ADHOC() && !IS_LITE())
	if (1)
	{
		[Crittercism initWithAppID:@"4f504545b093157173000017" 
							andKey:@"4f504545b093157173000017lh4java7"
						 andSecret:@"trzmcvolbfqgnphhisc8jdvunqy2es5b" 
			 andMainViewController:nil];
	}
	else if (IS_RELEASE())
	{
		[Crittercism initWithAppID:@"4f1f9785b093150d5500008c" 
							andKey:@"4f1f9785b093150d5500008cpu3zoqbu" 
						 andSecret:@"2ayz0tlckhhu4jjsb8dzxuqmfnexcqkn"
			 andMainViewController:nil];
	}
	[Crittercism sharedInstance].delegate = (id<CrittercismDelegate>)self;
}

- (void)crittercismDidCrashOnLastLoad
{
	DLog(@"App crashed on last load. Do something here.");
	
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Oh no! :(" message:@"It looks like iSub crashed recently!\n\nWell never fear, iSub support is happy to help. \n\nWould you like to send an email to support?" delegate:self cancelButtonTitle:@"No Thanks" otherButtonTitles:@"Yes Please", nil];
	alert.tag = 7;
	[alert show];
	[alert release];
}*/

- (void)loadInAppPurchaseStore
{
	if (IS_LITE())
	{
		[MKStoreManager sharedManager];
		[MKStoreManager setDelegate:self];
		
		if (IS_DEBUG())
		{
			// Reset features
			[SFHFKeychainUtils storeUsername:kFeaturePlaylistsId andPassword:@"NO" forServiceName:kServiceName updateExisting:YES error:nil];
			[SFHFKeychainUtils storeUsername:kFeatureJukeboxId andPassword:@"NO" forServiceName:kServiceName updateExisting:YES error:nil];
			[SFHFKeychainUtils storeUsername:kFeatureCacheId andPassword:@"NO" forServiceName:kServiceName updateExisting:YES error:nil];
			[SFHFKeychainUtils storeUsername:kFeatureAllId andPassword:@"NO" forServiceName:kServiceName updateExisting:YES error:nil];
			
			DLog(@"is kFeaturePlaylistsId enabled: %i", [MKStoreManager isFeaturePurchased:kFeaturePlaylistsId]);
			DLog(@"is kFeatureJukeboxId enabled: %i", [MKStoreManager isFeaturePurchased:kFeatureJukeboxId]);
			DLog(@"is kFeatureCacheId enabled: %i", [MKStoreManager isFeaturePurchased:kFeatureCacheId]);
			DLog(@"is kFeatureAllId enabled: %i", [MKStoreManager isFeaturePurchased:kFeatureAllId]);
		}
	}
}

- (void)createHTTPServer
{
	// Create http server
	httpServer = [HTTPServer new];
	[httpServer setType:@"_http._tcp."];
	[httpServer setConnectionClass:[MyHTTPConnection class]];
	NSString *root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndexSafe:0];
	[httpServer setDocumentRoot:[NSURL fileURLWithPath:root]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayInfoUpdate:) name:@"LocalhostAdressesResolved" object:nil];
	[LocalhostAddresses performSelectorInBackground:@selector(list) withObject:nil];
}

- (void)startRedirectingLogToFile
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndexSafe:0];
	NSString *logPath = [documentsDirectory stringByAppendingPathComponent:@"console.log"];
	freopen([logPath cStringUsingEncoding:NSASCIIStringEncoding],"a+",stderr);
}

- (void)stopRedirectingLogToFile
{
	freopen("/dev/tty","w",stderr);
}

- (void)batteryStateChanged:(NSNotification *)notification
{
	UIDevice *device = [UIDevice currentDevice];
	if (device.batteryState == UIDeviceBatteryStateCharging || device.batteryState == UIDeviceBatteryStateFull) 
	{
			[UIApplication sharedApplication].idleTimerDisabled = YES;
    }
	else
	{
		if (settingsS.isScreenSleepEnabled)
			[UIApplication sharedApplication].idleTimerDisabled = NO;
	}
}

- (void)displayInfoUpdate:(NSNotification *) notification
{
	DLog(@"displayInfoUpdate:");
	
	if(notification)
	{
		addresses = [[notification object] copy];
		DLog(@"addresses: %@", addresses);
	}
	
	if(addresses == nil)
	{
		return;
	}
	
	NSString *info;
	UInt16 port = [httpServer port];
	
	NSString *localIP = nil;
	
	localIP = [addresses objectForKey:@"en0"];
	
	if (!localIP)
	{
		localIP = [addresses objectForKey:@"en1"];
	}
	
	if (!localIP)
		info = @"Wifi: No Connection!\n";
	else
		info = [NSString stringWithFormat:@"http://iphone.local:%d		http://%@:%d\n", port, localIP, port];
	
	NSString *wwwIP = [addresses objectForKey:@"www"];
	
	if (wwwIP)
		info = [info stringByAppendingFormat:@"Web: %@:%d\n", wwwIP, port];
	else
		info = [info stringByAppendingString:@"Web: Unable to determine external IP\n"];
	
	//displayInfo.text = info;
	DLog(@"info: %@", info);
}


- (void)startStopServer
{
	if (isHttpServerOn)
	{
		[httpServer stop];
	}
	else
	{
		// You may OPTIONALLY set a port for the server to run on.
		// 
		// If you don't set a port, the HTTP server will allow the OS to automatically pick an available port,
		// which avoids the potential problem of port conflicts. Allowing the OS server to automatically pick
		// an available port is probably the best way to do it if using Bonjour, since with Bonjour you can
		// automatically discover services, and the ports they are running on.
		//	[httpServer setPort:8080];
		
		NSError *error;
		if(![httpServer start:&error])
		{
			DLog(@"Error starting HTTP Server: %@", error);
		}
		
		[self displayInfoUpdate:nil];
	}
}

- (void)applicationWillResignActive:(UIApplication*)application
{
	//DLog(@"applicationWillResignActive called");
	
	//DLog(@"applicationWillResignActive finished");
}


- (void)applicationDidBecomeActive:(UIApplication*)application
{
	//DLog(@"isWifi: %i", [self isWifi]);
	//DLog(@"applicationDidBecomeActive called");
	
	//DLog(@"applicationDidBecomeActive finished");
}


- (void)applicationDidEnterBackground:(UIApplication *)application
{
	//DLog(@"applicationDidEnterBackground called");
	
	[settingsS saveState];
	
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	if ([[UIApplication sharedApplication] respondsToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)])
    {
		backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:
						  ^{
							  // App is about to be put to sleep, stop the cache download queue
							  if (cacheQueueManagerS.isQueueDownloading)
								  [cacheQueueManagerS stopDownloadQueue];
							  
							  // Make sure to end the background so we don't get killed by the OS
							  [application endBackgroundTask:backgroundTask];
							  backgroundTask = UIBackgroundTaskInvalid;
						  }];
		
		// Check the remaining background time and alert the user if necessary
		dispatch_queue_t queue = dispatch_queue_create("isub.backgroundqueue", 0);
		dispatch_async(queue, 
		^{
			isInBackground = YES;
			UIApplication *application = [UIApplication sharedApplication];
			while ([application backgroundTimeRemaining] > 1.0 && isInBackground) 
			{
				//DLog(@"backgroundTimeRemaining: %f", [application backgroundTimeRemaining]);
				
				// Sleep early is nothing is happening after 500 seconds
				if ([application backgroundTimeRemaining] < 200.0 && !cacheQueueManagerS.isQueueDownloading)
				{
					DLog("Sleeping early, isQueueListDownloading: %i", cacheQueueManagerS.isQueueDownloading);
					[application endBackgroundTask:backgroundTask];
					backgroundTask = UIBackgroundTaskInvalid;
					break;
				}
				
				// Warn at 2 minute mark if cache queue is downloading
				if ([application backgroundTimeRemaining] < 120.0 && cacheQueueManagerS.isQueueDownloading)
				{
					UILocalNotification *localNotif = [[UILocalNotification alloc] init];
					if (localNotif) 
					{
						localNotif.alertBody = NSLocalizedString(@"Songs are still caching. Please return to iSub within 2 minutes, or it will be put to sleep and your song caching will be paused.", nil);
						localNotif.alertAction = NSLocalizedString(@"Open iSub", nil);
						[application presentLocalNotificationNow:localNotif];
						break;
					}
				}
				
				// Sleep for a second to avoid a fast loop eating all cpu cycles
				sleep(1);
			}
		});
	}
}


- (void)applicationWillEnterForeground:(UIApplication *)application
{
	//DLog(@"applicationWillEnterForeground called");
	
	if ([[UIApplication sharedApplication] respondsToSelector:@selector(endBackgroundTask:)])
    {
		isInBackground = NO;
		if (backgroundTask != UIBackgroundTaskInvalid)
		{
			[[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
			backgroundTask = UIBackgroundTaskInvalid;
		}
	}

	// Update the lock screen art in case were were using another app
	[musicS updateLockScreenInfo];
}


- (void)applicationWillTerminate:(UIApplication *)application
{
	//DLog(@"applicationWillTerminate called");
	
	if (IS_MULTITASKING())
	{
		[[UIApplication sharedApplication] endReceivingRemoteControlEvents];
	}
	
	[settingsS saveState];
	
	[audioEngineS bassFree];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
	
}


#pragma mark Helper Methods


- (void)enterOfflineMode
{
	if (viewObjectsS.isNoNetworkAlertShowing == NO)
	{
		viewObjectsS.isNoNetworkAlertShowing = YES;
		
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"Server unavailable, would you like to enter offline mode? Any currently playing music will stop.\n\nIf this is just temporary connection loss, select No." delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
		alert.tag = 4;
		[alert show];
	}
}


- (void)enterOnlineMode
{
	if (!viewObjectsS.isOnlineModeAlertShowing)
	{
		viewObjectsS.isOnlineModeAlertShowing = YES;
		
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"Network detected, would you like to enter online mode? Any currently playing music will stop." delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
		alert.tag = 4;
		[alert show];
	}
}


- (void)enterOfflineModeForce
{
	if (viewObjectsS.isOfflineMode)
		return;
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_EnteringOfflineMode];
	
	viewObjectsS.isOfflineMode = YES;
		
	[audioEngineS stop];
	
	[streamManagerS cancelAllStreams];
	
	[cacheQueueManagerS stopDownloadQueue];

	if (IS_IPAD())
		[self.ipadRootViewController.menuViewController toggleOfflineMode];
	else
		[self.mainTabBarController.view removeFromSuperview];
	
	[databaseS closeAllDatabases];
	[databaseS setupDatabases];
	
	if (IS_IPAD())
	{
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowPlayer];
	}
	else
	{
		self.currentTabBarController = self.offlineTabBarController;
		[self.window addSubview:self.offlineTabBarController.view];
	}
	
	[musicS updateLockScreenInfo];
}

- (void)enterOnlineModeForce
{
	if ([wifiReach currentReachabilityStatus] == NotReachable)
		return;
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_EnteringOnlineMode];
		
	viewObjectsS.isOfflineMode = NO;
	
	[audioEngineS stop];
	
	if (IS_IPAD())
		[self.ipadRootViewController.menuViewController toggleOfflineMode];
	else
		[self.offlineTabBarController.view removeFromSuperview];
	
	[databaseS closeAllDatabases];
	[databaseS setupDatabases];
	[self checkServer];
	[cacheQueueManagerS startDownloadQueue];
	
	if (IS_IPAD())
	{
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowPlayer];
	}
	else
	{
		[viewObjectsS orderMainTabBarController];
		[window addSubview:mainTabBarController.view];
	}
	
	[musicS updateLockScreenInfo];
}

- (void)reachabilityChangedInternal:(Reachability *)curReach
{	
	if ([curReach currentReachabilityStatus] == NotReachable)
	{
		//DLog(@"Reachability Changed: NotReachable");
		//reachabilityStatus = 0;
		//[self stopDownloadQueue];
		
		//Change over to offline mode
		if (!viewObjectsS.isOfflineMode)
		{
			[self enterOfflineMode];
		}
	}
	else if ([curReach currentReachabilityStatus] == ReachableViaWiFi || IS_3G_UNRESTRICTED)
	{
		//DLog(@"Reachability Changed: ReachableViaWiFi");
		//reachabilityStatus = 2;
		
		[self checkServer];
		
		if (viewObjectsS.isOfflineMode)
		{
			[self enterOnlineMode];
		}
		else
		{
			//DLog(@"musicS.isQueueListDownloading: %i", musicS.isQueueListDownloading);
			if (!cacheQueueManagerS.isQueueDownloading) 
			{
				//DLog(@"Calling [musicS downloadNextQueuedSong]");
				[cacheQueueManagerS startDownloadQueue];
			}
		}
	}
	else if ([curReach currentReachabilityStatus] == ReachableViaWWAN)
	{
		[self checkServer];
		
		//DLog(@"Reachability Changed: ReachableViaWWAN");
		//reachabilityStatus = 1;
		
		if (viewObjectsS.isOfflineMode)
		{
			[self enterOnlineMode];
		}
		else 
		{
			[cacheQueueManagerS stopDownloadQueue];
		}
	}
}


- (void)reachabilityChanged: (NSNotification *)note
{
	if (settingsS.isForceOfflineMode)
		return;
	
	if ([[note object] isKindOfClass:[Reachability class]])
	{
		// Cancel any previous requests
		[NSObject gcdCancelTimerBlockWithName:@"Reachability Changed"];
		
		// Perform the actual check in two seconds to make sure it's the last message received
		// this prevents a bug where the status changes from wifi to not reachable, but first it receives
		// some messages saying it's still on wifi, then gets the not reachable messages
		[self gcdTimerPerformBlockInMainQueue:^{
			[self reachabilityChangedInternal:[note object]];
		} afterDelay:2.0 withName:@"Reachability Changed"];
	}
}

- (BOOL)isWifi
{
	if ([wifiReach currentReachabilityStatus] == ReachableViaWiFi || IS_3G_UNRESTRICTED)
		return YES;
	else
		return NO;
}

- (void)showSettings
{
	if (IS_IPAD())
	{
		[ipadRootViewController.menuViewController showSettings];
	}
	else
	{
		ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
		
		if (currentTabBarController.selectedIndex == 4)
		{
			[currentTabBarController.moreNavigationController popToViewController:[currentTabBarController.moreNavigationController.viewControllers objectAtIndexSafe:1] animated:YES];
			[currentTabBarController.moreNavigationController pushViewController:serverListViewController animated:YES];
		}
		else if (currentTabBarController.selectedIndex == NSNotFound)
		{
			[currentTabBarController.moreNavigationController popToRootViewControllerAnimated:YES];
			[currentTabBarController.moreNavigationController pushViewController:serverListViewController animated:YES];
		}
		else
		{
			[(UINavigationController*)currentTabBarController.selectedViewController popToRootViewControllerAnimated:YES];
			[(UINavigationController*)currentTabBarController.selectedViewController pushViewController:serverListViewController animated:YES];
		}
		
	}
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	switch (alertView.tag)
	{
		case 1:
		{
			// Title: @"Subsonic Error"
			if(buttonIndex == 1)
			{
				[self showSettings];
				
				/*if (IS_IPAD())
				{
					[mainMenu showSettings];
				}
				else
				{
					ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
					
					if (currentTabBarController.selectedIndex == 4)
					{
						[currentTabBarController.moreNavigationController pushViewController:serverListViewController animated:YES];
					}
					else
					{
						[(UINavigationController*)currentTabBarController.selectedViewController pushViewController:serverListViewController animated:YES];
					}
					
					[serverListViewController release];
				}*/
			}
			
			break;
		}
		/*case 2: // Isn't used
		{
			// Title: @"Error"
			[introController dismissModalViewControllerAnimated:NO];
			
			if (buttonIndex == 0)
			{
				[self appInit2];
			}
			else if (buttonIndex == 1)
			{
				if (IS_IPAD())
				{
					[mainMenu showSettings];
				}
				else
				{
					[self showSettings];
				}
			}
			
			break;
		}*/
		case 3:
		{
			// Title: @"Server Unavailable"
			if (buttonIndex == 1)
			{
				[self showSettings];
			}
			
			break;
		}
		case 4:
		{
			// Title: @"Notice"
			
			// Offline mode handling
			
			viewObjectsS.isOnlineModeAlertShowing = NO;
			viewObjectsS.isNoNetworkAlertShowing = NO;
			
			if (buttonIndex == 1)
			{
				if (viewObjectsS.isOfflineMode)
				{
					[self enterOnlineModeForce];
				}
				else
				{
					[self enterOfflineModeForce];
				}
			}
			
			break;
		}
		case 6:
		{
			// Title: @"Update Alerts"
			if (buttonIndex == 0)
			{
				settingsS.isUpdateCheckEnabled = NO;
			}
			else if (buttonIndex == 1)
			{
				settingsS.isUpdateCheckEnabled = YES;
			}
			
			settingsS.isUpdateCheckQuestionAsked = YES;
			
			break;
		}
		case 7:
		{
			// Title: Oh no! :(
			if (buttonIndex == 1)
			{
				if ([MFMailComposeViewController canSendMail])
				{
					MFMailComposeViewController *mailer = [[MFMailComposeViewController alloc] init];
					[mailer setMailComposeDelegate:self];
					[mailer setToRecipients:[NSArray arrayWithObject:@"support@isubapp.com"]];
					
					if ([BWQuincyManager sharedQuincyManager].didCrashInLastSession)
					{
						// Set version label
						NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
						NSString *formattedVersion = nil;
						if (IS_RELEASE())
						{
							formattedVersion = version;
						}
						else 
						{
							NSString *build = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
							formattedVersion = [NSString stringWithFormat:@"%@ build %@", build, version];
						}
						
						NSString *subject = [NSString stringWithFormat:@"I had a crash in iSub %@ :(", formattedVersion];
						[mailer setSubject:subject];
						
						[mailer setMessageBody:@"Here's what I was doing when iSub crashed..." isHTML:NO];
					}
					else 
					{
						[mailer setSubject:@"I need some help with iSub :)"];
					}
					
					if (IS_IPAD())
						[self.ipadRootViewController presentModalViewController:mailer animated:YES];
					else
						[self.currentTabBarController presentModalViewController:mailer animated:YES];
					
				}
				else
				{
					UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Uh Oh!" message:@"It looks like you don't have an email account set up, but you can reach support from your computer by emailing support@isubapp.com" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
					[alert show];
				}
			}
			else if (buttonIndex == 2)
			{
				NSString *urlString = IS_IPAD() ? @"http://isubapp.com/forum" : @"http://isubapp.com/vanilla";
				NSURL *url = [NSURL URLWithString:urlString];
				[[UIApplication sharedApplication] openURL:url];
			}
		}
	}
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error 
{   
	if (IS_IPAD())
		[self.ipadRootViewController dismissModalViewControllerAnimated:YES];
	else
		[self.currentTabBarController dismissModalViewControllerAnimated:YES];
}


/*- (BOOL)wifiReachability
{
	switch ([wifiReach currentReachabilityStatus])
	{
		case NotReachable:
		{
			return NO;
		}
		case ReachableViaWWAN:
		{
			return NO;
		}
		case ReachableViaWiFi:
		{
			return YES;
		}
	}
	
	return NO;
}*/


/*- (BOOL) connectedToNetwork
{
	// Create zero addy
	struct sockaddr_in zeroAddress;
	bzero(&zeroAddress, sizeof(zeroAddress));
	zeroAddress.sin_len = sizeof(zeroAddress);
	zeroAddress.sin_family = AF_INET;
	
	// Recover reachability flags
	SCNetworkReachabilityRef defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&zeroAddress);
	SCNetworkReachabilityFlags flags;
	
	BOOL didRetrieveFlags = SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags);
	CFRelease(defaultRouteReachability);
	
	if (!didRetrieveFlags) {
		printf("Error. Could not recover network reachability flags\n"); return 0;
	}
	
	BOOL isReachable = flags & kSCNetworkFlagsReachable;
	BOOL needsConnection = flags & kSCNetworkFlagsConnectionRequired;
	return (isReachable && !needsConnection) ? YES : NO;
}*/

- (NSInteger) getHour
{
	// Get the time
	NSCalendar *calendar= [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	NSCalendarUnit unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
	NSDate *date = [NSDate date];
	NSDateComponents *dateComponents = [calendar components:unitFlags fromDate:date];

	// Turn the date into Integers
	//NSInteger year = [dateComponents year];
	//NSInteger month = [dateComponents month];
	//NSInteger day = [dateComponents day];
	//NSInteger hour = [dateComponents hour];
	//NSInteger min = [dateComponents minute];
	//NSInteger sec = [dateComponents second];
	
	return [dateComponents hour];
}

#pragma mark -
#pragma mark Music Streamer
#pragma mark -

/*- (NSString *)getStreamURLStringForSongId:(NSString *)songId
{	    
    NSString *encodedUserName = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)settings.username, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
	NSString *encodedPassword = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)settings.password, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
    
	if ([musicS maxBitrateSetting] != 0)
	{
		return [NSString stringWithFormat:@"%@/rest/stream.view?maxBitRate=%i&u=%@&p=%@&v=1.2.0&c=iSub&id=", settingsS.urlString, [musicS maxBitrateSetting], [encodedUserName autorelease], [encodedPassword autorelease]];
	}
    else
	{
		return [NSString stringWithFormat:@"%@/rest/stream.view?u=%@&p=%@&v=1.1.0&c=iSub&id=", settingsS.urlString, [encodedUserName autorelease], [encodedPassword autorelease]];
	}
}*/

/*- (NSString *)getBaseUrl:(NSString *)action
{	
	NSString *urlString = [[[NSString alloc] init] autorelease];

	urlString = defaultUrl;
	
	NSString *encodedUserName = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)defaultUserName, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
	NSString *encodedPassword = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)defaultPassword, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
    
	//DLog(@"username: %@    password: %@", encodedUserName, encodedPassword);
	
	// Return the base URL
	if ([action isEqualToString:@"getIndexes.view"] || [action isEqualToString:@"search.view"] || [action isEqualToString:@"search2.view"] || [action isEqualToString:@"getNowPlaying.view"] || [action isEqualToString:@"getPlaylists.view"] || [action isEqualToString:@"getMusicFolders.view"] || [action isEqualToString:@"createPlaylist.view"])
	{
		return [NSString stringWithFormat:@"%@/rest/%@?u=%@&p=%@&v=1.1.0&c=iSub", urlString, action, [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else if ([action isEqualToString:@"stream.view"] && [[settingsDictionary objectForKey:@"maxBitrateSetting"] intValue] != 7)
	{
		return [NSString stringWithFormat:@"%@/rest/stream.view?maxBitRate=%i&u=%@&p=%@&v=1.2.0&c=iSub&id=", urlString, [musicS maxBitrateSetting], [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else if ([action isEqualToString:@"addChatMessage.view"])
	{
		return [NSString stringWithFormat:@"%@/rest/addChatMessage.view?&u=%@&p=%@&v=1.2.0&c=iSub&message=", urlString, [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else if ([action isEqualToString:@"getLyrics.view"])
	{
		NSString *encodedArtist = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)musicS.currentSongObject.artist, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
		NSString *encodedTitle = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)musicS.currentSongObject.title, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
		
		return [NSString stringWithFormat:@"%@/rest/getLyrics.view?artist=%@&title=%@&u=%@&p=%@&v=1.2.0&c=iSub", urlString, [encodedArtist autorelease], [encodedTitle autorelease], [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else if ([action isEqualToString:@"getRandomSongs.view"] || [action isEqualToString:@"getAlbumList.view"] || [action isEqualToString:@"jukeboxControl.view"])
	{
		return [NSString stringWithFormat:@"%@/rest/%@?u=%@&p=%@&v=1.2.0&c=iSub", urlString, action, [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else
	{
		return [NSString stringWithFormat:@"%@/rest/%@?u=%@&p=%@&v=1.1.0&c=iSub&id=", urlString, action, [encodedUserName autorelease], [encodedPassword autorelease]];
	}
}*/


#pragma mark -
#pragma mark Store Manager delegate
#pragma mark -

/*- (void)productFetchComplete
 {
 CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Store" message:@"Product fetch complete" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
 [alert show];
 [alert release];
 }*/

- (void)productPurchased:(NSString *)productId
{
	NSString *message = nil;
	if ([productId isEqualToString:kFeatureAllId])
		message = @"You may now use all of the iSub features.";
	else if ([productId isEqualToString:kFeaturePlaylistsId])
		message = @"You may now use the playlist feature.";
	else if ([productId isEqualToString:kFeatureCacheId])
		message = @"You may now use the song caching feature.";
	else if ([productId isEqualToString:kFeatureJukeboxId])
		message = @"You may now use the jukebox feature.";
	else
		message = @"";
	
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Purchase Successful!" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
	[alert show];
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_StorePurchaseComplete];
}

- (void)transactionCanceled
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Store" message:@"Transaction canceled. Try again." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
	[alert show];
}


#pragma mark -
#pragma mark Memory management
#pragma mark -

//
// Not necessary in the application delegate, all memory is automatically reclaimed by OS on closing
//


@end

