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
#import "MGSplitViewController.h"
#import "iPadMainMenu.h"
#import "InitialDetailViewController.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString+md5.h"
#import "ServerListViewController.h"
#import "RootViewController.h"
#import "Reachability.h"
#import "UpdateXMLParser.h"
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
#import "SUSStreamSingleton.h"

#import "BassWrapperSingleton.h"

@implementation iSubAppDelegate

@synthesize window;

// Main interface elements for iPhone
@synthesize background, currentTabBarController, mainTabBarController, offlineTabBarController;
@synthesize homeNavigationController, playerNavigationController, artistsNavigationController, rootViewController, allAlbumsNavigationController, allSongsNavigationController, playlistsNavigationController, bookmarksNavigationController, playingNavigationController, genresNavigationController, cacheNavigationController, chatNavigationController;

// Main interface elemements for iPad
@synthesize splitView, mainMenu, initialDetail;

// Network connectivity objects
@synthesize wifiReach;

// Multitasking stuff
@synthesize backgroundTask;


+ (iSubAppDelegate *)sharedInstance
{
	return (iSubAppDelegate*)[UIApplication sharedApplication].delegate;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
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

	SavedSettings *settings = [SavedSettings sharedInstance];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	databaseControls = [DatabaseSingleton sharedInstance];
	musicControls = [MusicSingleton sharedInstance];
	socialControls = [SocialSingleton sharedInstance];
	cacheControls = [CacheSingleton sharedInstance];
    bassWrapper = [BassWrapperSingleton sharedInstance];
    
    introController = nil;
	showIntro = NO;
	
	DLog(@"md5: %@", [settings.urlString md5]);
	
	[self loadFlurryAnalytics];
	[self loadHockeyApp];
	
	[self loadInAppPurchaseStore];
	
	// Setup network reachability notifications
	wifiReach = [[Reachability reachabilityForLocalWiFi] retain];
	[wifiReach startNotifier];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(reachabilityChanged:) name: kReachabilityChangedNotification object:nil];
	
	// Check battery state and register for notifications
	[UIDevice currentDevice].batteryMonitoringEnabled = YES;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryStateChanged:) name:@"UIDeviceBatteryStateDidChangeNotification" object:[UIDevice currentDevice]];
	[self batteryStateChanged:nil];	
		

	// appinit 1
	//
	if (settings.isForceOfflineMode)
	{
		viewObjects.isOfflineMode = YES;
		
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"Offline mode switch on, entering offline mode." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		alert.tag = 4;
		[alert show];
		[alert release];
	}
	else if ([wifiReach currentReachabilityStatus] == NotReachable)
	{
		viewObjects.isOfflineMode = YES;
		
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"No network detected, entering offline mode." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		alert.tag = 4;
		[alert show];
		[alert release];
	}
	else 
	{
		viewObjects.isOfflineMode = NO;
	}
	
	if (settings.isTestServer)
	{
		if (viewObjects.isOfflineMode)
		{
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Welcome!" message:@"Looks like this is your first time using iSub or you haven't set up your Subsonic account info yet.\n\nYou'll need an internet connection to watch the intro video and use the included demo account." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
			[alert show];
			[alert release];
		}
		else
		{
			showIntro = YES;
		}
	}
	
	// app init 2
	[databaseControls initDatabases];
	
	// CAN'T GET THIS TO WORK
	// Setup the HTTP Basic Auth credentials
	//NSURLCredential *credential = [NSURLCredential credentialWithUser:self.defaultUserName password:self.defaultPassword persistence:NSURLCredentialPersistenceForSession];
	//NSURLProtectionSpace *protectionSpace = [[NSURLProtectionSpace alloc] initWithHost:@"example.com" port:0 protocol:@"http" realm:nil authenticationMethod:NSURLAuthenticationMethodHTTPBasic];
	
	// Setup Twitter connection
	if (!viewObjects.isOfflineMode && [[NSUserDefaults standardUserDefaults] objectForKey: @"twitterAuthData"])
	{
		[socialControls createTwitterEngine];
	}
	
	// appinit 3
	//
	// Start the queued downloads if Wifi is available
	[musicControls downloadNextQueuedSong];
	
	// Start the save defaults timer and mem cache initial defaults
	[settings setupSaveState];
	
	[self createAndDisplayUI];
	
	// Check the server status in the background
    DLog(@"adding loading screen");
    [viewObjects showLoadingScreenOnMainWindow];
    
	[self checkServer];
    
	// Recover current state if player was interrupted
	//[musicControls resumeSong];
}

- (void)checkServer
{
	SavedSettings *settings = [SavedSettings sharedInstance];
	
	// Ask the update question if necessary
	if (!settings.isUpdateCheckQuestionAsked)
	{
		// Ask to check for updates if haven't asked yet
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Update Alerts" message:@"Would you like iSub to notify you when app updates are available?\n\nYou can change this setting at any time from the settings menu." delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
		alert.tag = 6;
		[alert show];
		[alert release];
	}
	else if (settings.isUpdateCheckEnabled)
	{
		[self performSelectorInBackground:@selector(checkForUpdate) withObject:nil];
	}
    
    // Check if the subsonic URL is valid by attempting to access the ping.view page, 
	// if it's not then display an alert and allow user to change settings if they want.
	// This is in case the user is, for instance, connected to a wifi network but does not 
	// have internet access or if the host url entered was wrong.
    if (!viewObjects.isOfflineMode) 
	{
        SUSServerURLChecker *checker = [[SUSServerURLChecker alloc] initWithDelegate:self];
        [checker checkURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/rest/ping.view", settings.urlString]]];
    }
}

#pragma mark - SUS Server Check Delegate

- (void)SUSServerURLCheckRedirected:(SUSServerURLChecker *)checker redirectUrl:(NSURL *)url
{
    SavedSettings *settings = [SavedSettings sharedInstance];
    settings.redirectUrlString = [NSString stringWithFormat:@"%@://%@:%@", url.scheme, url.host, url.port];
    //DLog(@"redirectUrlString: %@", settings.redirectUrlString);
}

- (void)SUSServerURLCheckFailed:(SUSServerURLChecker *)checker withError:(NSError *)error
{
    DLog(@"server check failed");
    if(!viewObjects.isOfflineMode)
	{
		viewObjects.isOfflineMode = YES;
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Server Unavailable" message:[NSString stringWithFormat:@"Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\n☆☆ Tap the gear in the top left and choose a server to return to online mode. ☆☆\n\nError code %i:\n%@", [error code], [error localizedDescription]] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:@"Settings", nil];
		alert.tag = 3;
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
		
		[self performSelectorOnMainThread:@selector(enterOfflineModeForce) withObject:nil waitUntilDone:NO];
	}
    
    [checker release]; checker = nil;
	
	[SavedSettings sharedInstance].isNewSearchAPI = checker.isNewSearchAPI;
    
    DLog(@"server verification failed, hiding loading screen");
    [viewObjects hideLoadingScreen];
}

- (void)SUSServerURLCheckPassed:(SUSServerURLChecker *)checker
{
    //DLog(@"server check passed");
	
	[SavedSettings sharedInstance].isNewSearchAPI = checker.isNewSearchAPI;
    
    [checker release]; checker = nil;
    
    DLog(@"server verification passed, hiding loading screen");
    [viewObjects hideLoadingScreen];
}

#pragma mark -

- (void)createAndDisplayUI
{
	introController = nil;
	
	if (IS_IPAD())
	{
		// Setup the split view
		[window addSubview:splitView.view];
		splitView.showsMasterInPortrait = YES;
		splitView.splitPosition = 220;
		mainMenu = [[iPadMainMenu alloc] initWithNibName:@"iPadMainMenu" bundle:nil];
		
		splitView.masterViewController = mainMenu;
		
		if (showIntro)
		{
			introController = [[IntroViewController alloc] init];
			introController.modalPresentationStyle = UIModalPresentationFormSheet;
			[splitView presentModalViewController:introController animated:NO];
			[introController release];
		}
	}
	else
	{
		// Setup the tabBarController
		mainTabBarController.moreNavigationController.navigationBar.barStyle = UIBarStyleBlack;
		
		//DLog(@"isOfflineMode: %i", viewObjects.isOfflineMode);
		if (viewObjects.isOfflineMode)
		{
			//DLog(@"--------------- isOfflineMode");
			currentTabBarController = offlineTabBarController;
			[window addSubview:offlineTabBarController.view];
		}
		else 
		{
			// Recover the tab order and load the main tabBarController
			currentTabBarController = mainTabBarController;
			[viewObjects orderMainTabBarController];
			[window addSubview:mainTabBarController.view];
		}
		
		if (showIntro)
		{
			introController = [[IntroViewController alloc] init];
			[currentTabBarController presentModalViewController:introController animated:NO];
			[introController release];
		}
	}
	
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
		window.backgroundColor = viewObjects.jukeboxColor;
	else 
		window.backgroundColor = viewObjects.windowColor;
	
	[window makeKeyAndVisible];	
	/*[self startStopServer];*/
}

- (void)loadFlurryAnalytics
{
	if (IS_RELEASE())
	{
		if (IS_LITE())
		{
			[FlurryAnalytics startSession:@"MQV1D5WQYUTCDAD6PFLU"];
		}
		else
		{
			[FlurryAnalytics startSession:@"3KK4KKD2PSEU5APF7PNX"];
		}
	}
}

- (void)loadHockeyApp
{
	// HockyApp Kits
	if (IS_BETA() && IS_ADHOC() && !IS_LITE())
	{
		[[BWQuincyManager sharedQuincyManager] setAppIdentifier:@"ada15ac4ffe3befbc66f0a00ef3d96af"];
		[[BWQuincyManager sharedQuincyManager] setShowAlwaysButton:YES];
		
		[[BWHockeyManager sharedHockeyManager] setAppIdentifier:@"ada15ac4ffe3befbc66f0a00ef3d96af"];
		[[BWHockeyManager sharedHockeyManager] setAlwaysShowUpdateReminder:YES];
	}
	else if (IS_RELEASE())
	{
		if (IS_LITE())
			[[BWQuincyManager sharedQuincyManager] setAppIdentifier:@"36cd77b2ee78707009f0a9eb9bbdbec7"];
		else
			[[BWQuincyManager sharedQuincyManager] setAppIdentifier:@"7c9cb46dad4165c9d3919390b651f6bb"];
		
		[[BWQuincyManager sharedQuincyManager] setShowAlwaysButton:YES];
	}
}

- (void)loadInAppPurchaseStore
{
	if (IS_LITE())
	{
		[MKStoreManager sharedManager];
		[MKStoreManager setDelegate:self];
		
		if (IS_DEBUG())
		{
			// Reset features
			
			/*[SFHFKeychainUtils storeUsername:kFeaturePlaylistsId andPassword:@"NO" forServiceName:kServiceName updateExisting:YES error:nil];
			 [SFHFKeychainUtils storeUsername:kFeatureJukeboxId andPassword:@"NO" forServiceName:kServiceName updateExisting:YES error:nil];
			 [SFHFKeychainUtils storeUsername:kFeatureCacheId andPassword:@"NO" forServiceName:kServiceName updateExisting:YES error:nil];
			 [SFHFKeychainUtils storeUsername:kFeatureAllId andPassword:@"NO" forServiceName:kServiceName updateExisting:YES error:nil];*/
			
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
	NSString *root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];
	[httpServer setDocumentRoot:[NSURL fileURLWithPath:root]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayInfoUpdate:) name:@"LocalhostAdressesResolved" object:nil];
	[LocalhostAddresses performSelectorInBackground:@selector(list) withObject:nil];
}

- (void)startRedirectingLogToFile
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
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
		if ([SavedSettings sharedInstance].isScreenSleepEnabled)
			[UIApplication sharedApplication].idleTimerDisabled = NO;
	}
}

- (void)displayInfoUpdate:(NSNotification *) notification
{
	DLog(@"displayInfoUpdate:");
	
	if(notification)
	{
		[addresses release];
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


- (void)checkForUpdate
{
#if RELEASE
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:@"http://isubapp.com/update.xml"]];
	[request startSynchronous];
	if ([request error])
	{
		/*CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error checking for app updates." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];*/
		
		DLog(@"There was an error checking for app updates.");
	}
	else
	{
		DLog(@"%@", [[[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding] autorelease]);
		NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:[request responseData]];
		UpdateXMLParser *parser = [(UpdateXMLParser*) [UpdateXMLParser alloc] initXMLParser];
		[xmlParser setDelegate:parser];
		[xmlParser parse];
		
		[xmlParser release];
		[parser release];
	}
	
	[autoreleasePool release];
#endif
}

- (void)applicationWillResignActive:(UIApplication*)application
{
	//DLog(@"applicationWillResignActive called");
	
	//DLog(@"applicationWillResignActive finished");
}


- (void)applicationDidBecomeActive:(UIApplication*)application
{
	//DLog(@"applicationDidBecomeActive called");
	
	//DLog(@"applicationDidBecomeActive finished");
}


- (void)applicationDidEnterBackground:(UIApplication *)application
{
	//DLog(@"applicationDidEnterBackground called");
	
	[[SavedSettings sharedInstance] saveState];
	
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	if ([[UIApplication sharedApplication] respondsToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)])
    {
		backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:
						  ^{
							  // App is about to be put to sleep, stop the cache download queue
							  if (musicControls.isQueueListDownloading)
								  [musicControls stopDownloadQueue];
							  
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
				
				// Sleep early is nothing is happening
				if ([application backgroundTimeRemaining] < 570.0 && !musicControls.isQueueListDownloading)
				{
					//DLog("Sleeping early, isQueueListDownloading: %i", musicControls.isQueueListDownloading);
					[application endBackgroundTask:backgroundTask];
					backgroundTask = UIBackgroundTaskInvalid;
					break;
				}
				
				// Warn at 2 minute mark if cache queue is downloading
				if ([application backgroundTimeRemaining] < 120.0 && musicControls.isQueueListDownloading)
				{
					UILocalNotification *localNotif = [[UILocalNotification alloc] init];
					if (localNotif) 
					{
						localNotif.alertBody = NSLocalizedString(@"Songs are still caching. Please return to iSub within 2 minutes, or it will be put to sleep and your song caching will be paused.", nil);
						localNotif.alertAction = NSLocalizedString(@"Open iSub", nil);
						[application presentLocalNotificationNow:localNotif];
						[localNotif release];
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
}


- (void)applicationWillTerminate:(UIApplication *)application
{
	//DLog(@"applicationWillTerminate called");
	
	if (IS_MULTITASKING())
	{
		[[UIApplication sharedApplication] endReceivingRemoteControlEvents];
	}
	
	[[SavedSettings sharedInstance] saveState];
	
	[[BassWrapperSingleton sharedInstance] bassFree];
}

#pragma mark -
#pragma mark Other methods
#pragma mark -


#pragma mark Helper Methods


- (void)enterOfflineMode
{
	if (viewObjects.isNoNetworkAlertShowing == NO)
	{
		viewObjects.isNoNetworkAlertShowing = YES;
		
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"No network detected, would you like to enter offline mode? Any currently playing music will stop.\n\nIf this is just temporary connection loss, select No." delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
		alert.tag = 4;
		[alert show];
		[alert release];
	}
}


- (void)enterOnlineMode
{
	if (!viewObjects.isOnlineModeAlertShowing)
	{
		viewObjects.isOnlineModeAlertShowing = YES;
		
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"Network detected, would you like to enter online mode? Any currently playing music will stop." delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
		alert.tag = 4;
		[alert show];
		[alert release];
	}
}


- (void)enterOfflineModeForce
{
	if (viewObjects.isOfflineMode)
		return;
	
	viewObjects.isOfflineMode = YES;
		
	[bassWrapper stop];
	
	[[SUSStreamSingleton sharedInstance] cancelAllStreams];

	[mainTabBarController.view removeFromSuperview];
	[databaseControls closeAllDatabases];
	[databaseControls initDatabases];
	currentTabBarController = offlineTabBarController;
	[window addSubview:[offlineTabBarController view]];
}

- (void)enterOnlineModeForce
{
	if ([wifiReach currentReachabilityStatus] == NotReachable)
		return;
		
	viewObjects.isOfflineMode = NO;
	
	[bassWrapper stop];
	[offlineTabBarController.view removeFromSuperview];
	[databaseControls closeAllDatabases];
	[databaseControls initDatabases];
	[self checkServer];
	[viewObjects orderMainTabBarController];
	[window addSubview:[mainTabBarController view]];
}


- (void)reachabilityChanged: (NSNotification *)note
{
	if ([SavedSettings sharedInstance].isForceOfflineMode)
		return;
	
	Reachability* curReach = [note object];
	NSParameterAssert([curReach isKindOfClass: [Reachability class]]);
	
	if ([curReach currentReachabilityStatus] == NotReachable)
	{
		DLog(@"Reachability Changed: NotReachable");
		//reachabilityStatus = 0;
		//[self stopDownloadQueue];
		
		//Change over to offline mode
		if (!viewObjects.isOfflineMode)
		{
			[self enterOfflineMode];
		}
	}
	else if ([curReach currentReachabilityStatus] == ReachableViaWiFi || IS_3G_UNRESTRICTED)
	{
		DLog(@"Reachability Changed: ReachableViaWiFi");
		//reachabilityStatus = 2;
		
		if (viewObjects.isOfflineMode)
		{
			[self enterOnlineMode];
		}
		else
		{
			DLog(@"musicControls.isQueueListDownloading: %i", musicControls.isQueueListDownloading);
			if (!musicControls.isQueueListDownloading) {
				DLog(@"Calling [musicControls downloadNextQueuedSong]");
				[musicControls downloadNextQueuedSong];
			}
		}
	}
	else if ([curReach currentReachabilityStatus] == ReachableViaWWAN)
	{
		DLog(@"Reachability Changed: ReachableViaWWAN");
		//reachabilityStatus = 1;
		
		if (viewObjects.isOfflineMode)
		{
			[self enterOnlineMode];
		}
		else 
		{
			[musicControls stopDownloadQueue];
		}
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
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	
	if (currentTabBarController.selectedIndex == 4)
	{
		[currentTabBarController.moreNavigationController popToViewController:[currentTabBarController.moreNavigationController.viewControllers objectAtIndex:1] animated:YES];
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
	
	[serverListViewController release];
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
				if (IS_IPAD())
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
				}
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
			
			viewObjects.isOnlineModeAlertShowing = NO;
			viewObjects.isNoNetworkAlertShowing = NO;
			
			if (buttonIndex == 1)
			{
				if (viewObjects.isOfflineMode)
				{
					viewObjects.isOfflineMode = NO;
					
					[bassWrapper stop];
					[offlineTabBarController.view removeFromSuperview];
					[databaseControls closeAllDatabases];
					[databaseControls initDatabases];
					[viewObjects orderMainTabBarController];
					[window addSubview:[mainTabBarController view]];
				}
				else
				{
					viewObjects.isOfflineMode = YES;
					[SavedSettings sharedInstance].isJukeboxEnabled = NO;
					
					[bassWrapper stop];
					[[SUSStreamSingleton sharedInstance] cancelAllStreams];
					[musicControls stopDownloadQueue];
					[mainTabBarController.view removeFromSuperview];
					[databaseControls closeAllDatabases];
					[databaseControls initDatabases];
					[self checkServer];
					currentTabBarController = offlineTabBarController;
					[window addSubview:[offlineTabBarController view]];
				}
			}
			
			break;
		}
		case 5:
		{
			// Title: @"Resume?"
			if (buttonIndex == 0)
			{
				musicControls.bitRate = 192;
			}
			if (buttonIndex == 1)
			{
				//[musicControls resumeSong];
				//[musicControls performSelectorInBackground:@selector(resumeSong) withObject:nil];
				// TODO: Test this
				[SavedSettings sharedInstance].isRecover = YES;
				[musicControls resumeSong];
				
				// Reload the tab to display the Now Playing button - NOTE: DOESN'T WORK WHEN MORE TAB IS SELECTED
				if (currentTabBarController.selectedIndex == 4)
				{
					[[currentTabBarController.moreNavigationController topViewController] viewWillAppear:NO];				
				}
				else if (currentTabBarController.selectedIndex == NSNotFound)
				{
					[[currentTabBarController.moreNavigationController topViewController] viewWillAppear:NO];
				}
				else
				{
					[[(UINavigationController*)currentTabBarController.selectedViewController topViewController] viewWillAppear:NO];				
				}
			}
			
			break;
		}
		case 6:
		{
			// Title: @"Update Alerts"
			if (buttonIndex == 0)
			{
				[SavedSettings sharedInstance].isUpdateCheckEnabled = NO;
			}
			else if (buttonIndex == 1)
			{
				[SavedSettings sharedInstance].isUpdateCheckEnabled = YES;
			}
			
			[SavedSettings sharedInstance].isUpdateCheckQuestionAsked = YES;
			
			break;
		}
	}
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
	
	[calendar release];
	return [dateComponents hour];
}

#pragma mark -
#pragma mark Music Streamer
#pragma mark -

/*- (NSString *)getStreamURLStringForSongId:(NSString *)songId
{	
    SavedSettings *settings = [SavedSettings sharedInstance];
    
    NSString *encodedUserName = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)settings.username, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
	NSString *encodedPassword = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)settings.password, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
    
	if ([musicControls maxBitrateSetting] != 0)
	{
		return [NSString stringWithFormat:@"%@/rest/stream.view?maxBitRate=%i&u=%@&p=%@&v=1.2.0&c=iSub&id=", settings.urlString, [musicControls maxBitrateSetting], [encodedUserName autorelease], [encodedPassword autorelease]];
	}
    else
	{
		return [NSString stringWithFormat:@"%@/rest/stream.view?u=%@&p=%@&v=1.1.0&c=iSub&id=", settings.urlString, [encodedUserName autorelease], [encodedPassword autorelease]];
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
		return [NSString stringWithFormat:@"%@/rest/stream.view?maxBitRate=%i&u=%@&p=%@&v=1.2.0&c=iSub&id=", urlString, [musicControls maxBitrateSetting], [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else if ([action isEqualToString:@"addChatMessage.view"])
	{
		return [NSString stringWithFormat:@"%@/rest/addChatMessage.view?&u=%@&p=%@&v=1.2.0&c=iSub&message=", urlString, [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else if ([action isEqualToString:@"getLyrics.view"])
	{
		NSString *encodedArtist = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)musicControls.currentSongObject.artist, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
		NSString *encodedTitle = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)musicControls.currentSongObject.title, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
		
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
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
	[alert release];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"storePurchaseComplete" object:nil];
}

- (void)transactionCanceled
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Store" message:@"Transaction canceled. Try again." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
	[alert release];
}


#pragma mark -
#pragma mark Memory management
#pragma mark -

//
// Not necessary in the application delegate, all memory is automatically reclaimed by OS on closing
//
- (void)dealloc 
{	
	//[wwanReach release];
	[wifiReach release];
	
	//[defaultUrl release];
	//[defaultUserName release];
	//[defaultPassword release];
	//[cachedIP release];
	
	[super dealloc];
}


@end

