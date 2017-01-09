//
//  iSubAppDelegate.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "iSubAppDelegate.h"
#import "Imports.h"
#import "iSub-Swift.h"
#import <CoreFoundation/CoreFoundation.h>
#import <netinet/in.h>
#import <netdb.h>
#import <arpa/inet.h>
#import "IntroViewController.h"
#import "iPadRootViewController.h"
#import "MenuViewController.h"
#import "ISMSUpdateChecker.h"
#import <MediaPlayer/MediaPlayer.h>
#import "UIViewController+PushViewControllerCustom.h"
#import "HLSProxyConnection.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"
#import "ISMSLoaderDelegate.h"
#import <HockeySDK/HockeySDK.h>
#import "JASidePanelController.h"

#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>

//LOG_LEVEL_ISUB_DEFAULT

@interface iSubAppDelegate() <MFMailComposeViewControllerDelegate, BITHockeyManagerDelegate, BITCrashManagerDelegate>
@property (nonatomic) BOOL showIntro;
@end

@implementation iSubAppDelegate

+ (iSubAppDelegate *)sharedInstance
{
	return (iSubAppDelegate*)[UIApplication sharedApplication].delegate;
}

- (BOOL)shouldAutorotate
{
    if (SavedSettings.si.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

#pragma mark -
#pragma mark Application lifecycle
#pragma mark -

- (void)showPlayer
{
    // TODO: Update for new UI
//    iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
//    streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
//    [(UINavigationController*)self.currentTabBarController.selectedViewController pushViewController:streamingPlayerViewController animated:YES];
}

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    /*
        Setup data model
     */
    
    // Make sure the singletons get setup immediately and in the correct order
    // Perfect example of why using singletons is bad practice!
    [DatabaseSingleton si];
	[AudioEngine si];
	[CacheSingleton si];
    
    // Start the save defaults timer and mem cache initial defaults
	[SavedSettings.si setupSaveState];
	
#if !IS_ADHOC() && !IS_RELEASE()
    // Don't turn on console logging for adhoc or release builds
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [[DDTTYLogger sharedInstance] setColorsEnabled:YES];
#endif
	DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
	fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
	fileLogger.logFileManager.maximumNumberOfLogFiles = 7;
	[DDLog addLogger:fileLogger];
	
	// Setup network reachability notifications
    self.networkStatus = [[NetworkStatus alloc] init];
	[self.networkStatus startMonitoring];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged)
                                                 name:ISMSNotification_ReachabilityChanged object:nil];
	
	// Check battery state and register for notifications
	[UIDevice currentDevice].batteryMonitoringEnabled = YES;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryStateChanged:)
                                                 name:@"UIDeviceBatteryStateDidChangeNotification" object:[UIDevice currentDevice]];
	[self batteryStateChanged:nil];
		
	//[self loadFlurryAnalytics];
	[self loadHockeyApp];
		    
    // Check the server status in the background
    if (!SavedSettings.si.isOfflineMode)
    {
        [self checkServer];
    }
    
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(showPlayer) name:ISMSNotification_ShowPlayer object:nil];
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(playVideoNotification:) name:ISMSNotification_PlayVideo object:nil];
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(removeMoviePlayer) name:ISMSNotification_RemoveMoviePlayer object:nil];
    
    [self startHLSProxy];
    
    // Recover current state if player was interrupted. Do not resume if we're connected to the test server
    // because music will start playing behind the intro screen.
    [ISMSStreamManager sharedInstance];
    if (SavedSettings.si.isTestServer || !SavedSettings.si.isRecover)
    {
        [streamManagerS removeAllStreams];
    }
    else
    {
        ISMSSong *currentSong = PlayQueue.si.currentSong;
        if (currentSong)
        {
            [PlayQueue.si startSongWithOffsetBytes:SavedSettings.si.byteOffset offsetSeconds:SavedSettings.si.seekTime];
        }
        else
        {
            // TODO: Start handling this via PlayQueue
            AudioEngine.si.startByteOffset = SavedSettings.si.byteOffset;
            AudioEngine.si.startSecondsOffset = SavedSettings.si.seekTime;
        }
    }
    
    /*
        Setup UI
     */
    
    self.sidePanelController = (id)self.window.rootViewController;
    
    // Handle offline mode
    if (SavedSettings.si.isForceOfflineMode || !self.networkStatus.isReachable || (!self.networkStatus.isReachableWifi && SavedSettings.si.isDisableUsageOver3G))
    {
        SavedSettings.si.isOfflineMode = YES;
    }
    
    // Show intro if necessary
    if (SavedSettings.si.isTestServer)
    {
        if (SavedSettings.si.isOfflineMode)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Welcome!" message:@"Looks like this is your first time using iSub or you haven't set up your Subsonic account info yet.\n\nYou'll need an internet connection to watch the intro video and use the included demo account." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert performSelector:@selector(show) withObject:nil afterDelay:1.0];
        }
        else
        {
            self.showIntro = YES;
        }
    }
}

- (void)applicationDidBecomeActive:(UIApplication*)application
{
    if (self.showIntro)
    {
        self.showIntro = NO;
        
        // Fixes unbalanced transition warning
        [EX2Dispatch runInMainThreadAfterDelay:0.1 block:^{
            IntroViewController *vc = [[IntroViewController alloc] init];
            [self.sidePanelController presentViewController:vc animated:NO completion:nil];
        }];
    }
    
    [self checkServer];
    
    [self checkWaveBoxRelease];
}

- (void)startHLSProxy
{
    /*
    self.hlsProxyServer = [[HTTPServer alloc] init];
    self.hlsProxyServer.connectionClass = [HLSProxyConnection class];
    
    NSError *error;
	BOOL success = [self.hlsProxyServer start:&error];
	
	if(!success)
	{
		//DDLogError(@"Error starting HLS proxy server: %@", error);
	}
    */
}

// TODO: Audit all this and test. Seems to duplicate code in UAApplication
// TODO: Double check play function on new app launch
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    PlayQueue *playQueue = PlayQueue.si;
    
    // Handle being openned by a URL
    DLog(@"url host: %@ path components: %@", url.host, url.pathComponents );
    
    if (url.host)
    {
        if ([[url.host lowercaseString] isEqualToString:@"play"])
        {
            [playQueue play];
        }
        else if ([[url.host lowercaseString] isEqualToString:@"pause"])
        {
            [playQueue pause];
        }
        else if ([[url.host lowercaseString] isEqualToString:@"playpause"])
        {
            [playQueue playPause];
        }
        else if ([[url.host lowercaseString] isEqualToString:@"next"])
        {
            [playQueue playNextSong];
        }
        else if ([[url.host lowercaseString] isEqualToString:@"prev"])
        {
            [playQueue playPreviousSong];
        }
    }
    
    NSDictionary *queryParameters = url.queryParameterDictionary;
    if ([queryParameters.allKeys containsObject:@"ref"])
    {
        self.referringAppUrl = [NSURL URLWithString:[queryParameters objectForKey:@"ref"]];
        
        // On the iPad we need to reload the menu table to see the back button
        if (IS_IPAD())
        {
            [self.ipadRootViewController.menuViewController loadCellContents];
        }
    }
    
    return YES;
}

- (void)backToReferringApp
{
    if (self.referringAppUrl)
    {
        [[UIApplication sharedApplication] openURL:self.referringAppUrl];
    }
}

// Check server cancel load
- (void)cancelLoad
{
	[self.statusLoader cancelLoad];
	[ViewObjectsSingleton.si hideLoadingScreen];
}

- (void)checkServer
{
	ISMSUpdateChecker *updateChecker = [[ISMSUpdateChecker alloc] init];
	[updateChecker checkForUpdate];

    // Check if the subsonic URL is valid by attempting to access the ping.view page, 
	// if it's not then display an alert and allow user to change settings if they want.
	// This is in case the user is, for instance, connected to a wifi network but does not 
	// have internet access or if the host url entered was wrong.
    if (!SavedSettings.si.isOfflineMode) 
	{
        if (self.statusLoader)
        {
            [self.statusLoader cancelLoad];
        }
        
        Server *currentServer = SavedSettings.si.currentServer;
        self.statusLoader = [[ISMSStatusLoader alloc] initWithUrl:currentServer.url username:currentServer.username password:currentServer.password];
        __weak iSubAppDelegate *weakSelf = self;
        self.statusLoader.callbackBlock = ^(BOOL success,  NSError * error, ISMSLoader * loader) {
            SavedSettings.si.redirectUrlString = loader.redirectUrlString;
            
            if (success)
            {
                // TODO: Find a better way to handle this, or at least a button in the download queue to allow resuming rather
                // than having to know that they need to queue another song for download
                //
                // Since the download queue has been a frequent source of crashes in the past, and we start this on launch automatically
                // potentially resulting in a crash loop, do NOT start the download queue automatically if the app crashed on last launch.
                if (![BITHockeyManager sharedHockeyManager].crashManager.didCrashInLastSession)
                {
                    // Start the queued downloads if Wifi is available
                    [cacheQueueManagerS startDownloadQueue];
                }
            }
            else
            {
                if(!SavedSettings.si.isOfflineMode)
                {
                    [weakSelf enterOfflineMode];
                }
            }
            
            weakSelf.statusLoader = nil;
        };
        [self.statusLoader startLoad];
    }
	
	// Do a server check every half hour
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkServer) object:nil];
	NSTimeInterval delay = 30 * 60; // 30 minutes
	[self performSelector:@selector(checkServer) withObject:nil afterDelay:delay];
}

#pragma mark -

/*- (void)loadFlurryAnalytics
{
	BOOL isSessionStarted = NO;
#if IS_RELEASE()
    #if IS_LITE()
        // Lite version key
        [Flurry startSession:@"MQV1D5WQYUTCDAD6PFLU"];
        isSessionStarted = YES;
    #else
        // Full version key
        [Flurry startSession:@"3KK4KKD2PSEU5APF7PNX"];
        isSessionStarted = YES;
    #endif
#elif IS_BETA()
    // Beta version key
    [Flurry startSession:@"KNN9DUXQEENZUG4Q12UA"];
    isSessionStarted = YES;
#endif
	
	if (isSessionStarted)
	{
		// These set to no as per Flurry support instructions to prevent crashes
		[Flurry setSessionReportsOnPauseEnabled:NO];
		[Flurry setSessionReportsOnCloseEnabled:NO];
		
		// Send the firmware version
		UIDevice *device = [UIDevice currentDevice];
		NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:[device completeVersionString], @"FirmwareVersion", 
																		  [device platform], @"HardwareVersion", nil];
		[Flurry logEvent:@"DeviceInfo" withParameters:params];
	}
}*/

- (void)loadHockeyApp
{
    BITHockeyManager *hockeyManager = [BITHockeyManager sharedHockeyManager];
    
	// HockyApp Kits
#if IS_BETA() && IS_ADHOC() && !IS_LITE()
    [hockeyManager configureWithBetaIdentifier:@"ada15ac4ffe3befbc66f0a00ef3d96af" liveIdentifier:@"ada15ac4ffe3befbc66f0a00ef3d96af" delegate:self];
    hockeyManager.updateManager.alwaysShowUpdateReminder = NO;
    [hockeyManager startManager];
#elif IS_RELEASE()
    #if IS_LITE()
        [hockeyManager configureWithBetaIdentifier:@"36cd77b2ee78707009f0a9eb9bbdbec7" liveIdentifier:@"36cd77b2ee78707009f0a9eb9bbdbec7" delegate:self];
    #else
        [hockeyManager configureWithBetaIdentifier:@"7c9cb46dad4165c9d3919390b651f6bb" liveIdentifier:@"7c9cb46dad4165c9d3919390b651f6bb" delegate:self];
    #endif
        [hockeyManager startManager];
#endif
    hockeyManager.crashManager.crashManagerStatus = BITCrashManagerStatusAutoSend;
	
    if (hockeyManager.crashManager.didCrashInLastSession)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Oh no! iSub crashed!" message:@"iSub support has received your anonymous crash logs and they will be investigated. \n\nWould you also like to send an email to support with more details?" delegate:self cancelButtonTitle:@"No Thanks" otherButtonTitles:@"Send Email", @"Visit iSub Forum", nil];
		alert.tag = 7;
		[alert performSelector:@selector(show) withObject:nil afterDelay:2.];
	}
}

/*
#ifdef ADHOC
- (NSString *)userNameForCrashManager:(BITCrashManager *)crashManager
{
    if ([[UIDevice currentDevice] respondsToSelector:@selector(uniqueIdentifier)])
        return [[UIDevice currentDevice] performSelector:@selector(uniqueIdentifier)];
    return nil;
}
#endif

- (NSString *)customDeviceIdentifierForUpdateManager
{
#ifdef ADHOC
    if ([[UIDevice currentDevice] respondsToSelector:@selector(uniqueIdentifier)])
		return [[UIDevice currentDevice] performSelector:@selector(uniqueIdentifier)];
#endif
	
	return nil;
}
*/

- (NSString *)latestLogFileName
{
    NSString *logsFolder = [[SavedSettings cachesPath] stringByAppendingPathComponent:@"Logs"];
	NSArray *logFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:logsFolder error:nil];
	
	NSTimeInterval modifiedTime = 0.;
	NSString *fileNameToUse;
	for (NSString *file in logFiles)
	{
		NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[logsFolder stringByAppendingPathComponent:file] error:nil];
		NSDate *modified = [attributes fileModificationDate];
		//DLog(@"Checking file %@ with modified time of %f", file, [modified timeIntervalSince1970]);
		if (modified && [modified timeIntervalSince1970] >= modifiedTime)
		{
			//DLog(@"Using this file, since it's modified time %f is higher than %f", [modified timeIntervalSince1970], modifiedTime);
			
			// This file is newer
			fileNameToUse = file;
			modifiedTime = [modified timeIntervalSince1970];
		}
	}
    
    return fileNameToUse;
}

- (NSString *)applicationLogForCrashManager:(BITCrashManager *)crashManager
{
    NSString *logsFolder = [[SavedSettings cachesPath] stringByAppendingPathComponent:@"Logs"];
	NSString *fileNameToUse = [self latestLogFileName];
	
	if (fileNameToUse)
	{
		NSString *logPath = [logsFolder stringByAppendingPathComponent:fileNameToUse];
		NSString *contents = [[NSString alloc] initWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil];
		//DLog(@"Sending contents with length %u from path %@", contents.length, logPath);
		return contents;
	}
	
	return nil;
}

- (NSString *)zipAllLogFiles
{    
    NSString *zipFileName = @"iSub Logs.zip";
    NSString *zipFilePath = [[SavedSettings cachesPath] stringByAppendingPathComponent:zipFileName];
    NSString *logsFolder = [[SavedSettings cachesPath] stringByAppendingPathComponent:@"Logs"];
    
    // Delete the old zip if exists
    [[NSFileManager defaultManager] removeItemAtPath:zipFilePath error:nil];
    
    // Zip the logs
    ZKFileArchive *archive = [ZKFileArchive archiveWithArchivePath:zipFilePath];
    NSInteger result = [archive deflateDirectory:logsFolder relativeToPath:[SavedSettings cachesPath] usingResourceFork:NO];
    if (result == zkSucceeded)
    {
        return zipFilePath;
    }
    return nil;
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
		if (SavedSettings.si.isScreenSleepEnabled)
			[UIApplication sharedApplication].idleTimerDisabled = NO;
	}
}

- (void)applicationWillResignActive:(UIApplication*)application
{
	//DLog(@"applicationWillResignActive called");
	
	//DLog(@"applicationWillResignActive finished");
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	//DLog(@"applicationDidEnterBackground called");
	
	[SavedSettings.si saveState];
	
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	if ([[UIApplication sharedApplication] respondsToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)])
    {
		self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:
						  ^{
							  // App is about to be put to sleep, stop the cache download queue
							  if (cacheQueueManagerS.isQueueDownloading)
								  [cacheQueueManagerS stopDownloadQueue];
							  
							  // Make sure to end the background so we don't get killed by the OS
							  [application endBackgroundTask:self.backgroundTask];
							  self.backgroundTask = UIBackgroundTaskInvalid;
                              
                              // Cancel the next server check otherwise it will fire immediately on launch
                              [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkServer) object:nil];
						  }];
		
		// Check the remaining background time and alert the user if necessary
		dispatch_queue_t queue = dispatch_queue_create("isub.backgroundqueue", 0);
		dispatch_async(queue, 
		^{
			self.isInBackground = YES;
			UIApplication *application = [UIApplication sharedApplication];
			while ([application backgroundTimeRemaining] > 1.0 && self.isInBackground) 
			{
				@autoreleasepool 
				{
					//DLog(@"backgroundTimeRemaining: %f", [application backgroundTimeRemaining]);
					
					// Sleep early is nothing is happening after 500 seconds
					if ([application backgroundTimeRemaining] < 200.0 && !cacheQueueManagerS.isQueueDownloading)
					{
                        //DLog("Sleeping early, isQueueListDownloading: %i", cacheQueueManagerS.isQueueDownloading);
						[application endBackgroundTask:self.backgroundTask];
						self.backgroundTask = UIBackgroundTaskInvalid;
                        
                        // Cancel the next server check otherwise it will fire immediately on launch
                        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkServer) object:nil];
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
			}
		});
	}
}


- (void)applicationWillEnterForeground:(UIApplication *)application
{
	//DLog(@"applicationWillEnterForeground called");
	
	if ([[UIApplication sharedApplication] respondsToSelector:@selector(endBackgroundTask:)])
    {
		self.isInBackground = NO;
		if (self.backgroundTask != UIBackgroundTaskInvalid)
		{
			[[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
			self.backgroundTask = UIBackgroundTaskInvalid;
		}
	}

	// Update the lock screen art in case were were using another app
	[PlayQueue.si updateLockScreenInfo];
}


- (void)applicationWillTerminate:(UIApplication *)application
{
	//DLog(@"applicationWillTerminate called");
	
	[[UIApplication sharedApplication] endReceivingRemoteControlEvents];
	
	[SavedSettings.si saveState];
	
	[PlayQueue.si stop];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
	
}


#pragma mark Helper Methods

- (void)enterOfflineMode
{
	if (ViewObjectsSingleton.si.isNoNetworkAlertShowing == NO)
	{
		ViewObjectsSingleton.si.isNoNetworkAlertShowing = YES;
		
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Notice" message:@"Server unavailable, would you like to enter offline mode? Any currently playing music will stop.\n\nIf this is just temporary connection loss, select No." delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
		alert.tag = 4;
		[alert show];
	}
}


- (void)enterOnlineMode
{
	if (!ViewObjectsSingleton.si.isOnlineModeAlertShowing)
	{
		ViewObjectsSingleton.si.isOnlineModeAlertShowing = YES;
		
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Notice" message:@"Network detected, would you like to enter online mode? Any currently playing music will stop." delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
		alert.tag = 4;
		[alert show];
	}
}


- (void)enterOfflineModeForce
{
	if (SavedSettings.si.isOfflineMode)
		return;
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_EnteringOfflineMode];
	
    appDelegateS.window.backgroundColor = ViewObjectsSingleton.si.windowColor;
    
	SavedSettings.si.isOfflineMode = YES;
		
	[PlayQueue.si stop];
	
	[streamManagerS cancelAllStreams];
	
	[cacheQueueManagerS stopDownloadQueue];

    // TODO: Implement offline mode in new UI
//	if (IS_IPAD())
//		[self.ipadRootViewController.menuViewController toggleOfflineMode];
//	else
//		[self.mainTabBarController.view removeFromSuperview];
	
//	[DatabaseSingleton.si closeAllDatabases];
//	[DatabaseSingleton.si setupDatabases];
	
    // TODO: Implement offline mode in new UI
//	if (IS_IPAD())
//	{
//		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowPlayer];
//	}
//	else
//	{
//		self.currentTabBarController = self.offlineTabBarController;
//		//[self.window addSubview:self.offlineTabBarController.view];
//        self.window.rootViewController = self.offlineTabBarController;
//	}
	
	[PlayQueue.si updateLockScreenInfo];
}

- (void)enterOnlineModeForce
{
    if (!self.networkStatus.isReachable) {
        return;
    }
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_EnteringOnlineMode];
		
	SavedSettings.si.isOfflineMode = NO;
	
	[PlayQueue.si stop];
	
	if (IS_IPAD())
		[self.ipadRootViewController.menuViewController toggleOfflineMode];
	//else
	//	[self.offlineTabBarController.view removeFromSuperview];
	
//	[DatabaseSingleton.si closeAllDatabases];
//	[DatabaseSingleton.si setupDatabases];
	[self checkServer];
	[cacheQueueManagerS startDownloadQueue];
	
    // TODO: Implement offline mode in new UI
//	if (IS_IPAD())
//	{
//		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowPlayer];
//	}
//	else
//	{
//		[ViewObjectsSingleton.si orderMainTabBarController];
//		//[self.window addSubview:self.mainTabBarController.view];
//        self.window.rootViewController = self.mainTabBarController;
//	}
	
	[PlayQueue.si updateLockScreenInfo];
}

- (void)reachabilityChanged
{
	if (SavedSettings.si.isForceOfflineMode)
		return;
	
    if (!self.networkStatus.isReachable)
    {
        //Change over to offline mode
        if (!SavedSettings.si.isOfflineMode)
        {
            //DDLogVerbose(@"Reachability changed to NotReachable, prompting to go to offline mode");
            [self enterOfflineMode];
        }
    }
    else if (!self.networkStatus.isReachableWifi && SavedSettings.si.isDisableUsageOver3G)
    {
        if (!SavedSettings.si.isOfflineMode)
        {
            [self enterOfflineModeForce];
            
            // TODO: Use a different mechanism
            //[[EX2SlidingNotification slidingNotificationOnMainWindowWithMessage:@"You have chosen to disable usage over cellular in settings and are no longer on Wifi. Entering offline mode." image:nil] showAndHideSlidingNotification];
        }
    }
    else
    {
        [self checkServer];
        
        if (SavedSettings.si.isOfflineMode)
        {
            [self enterOnlineMode];
        }
        else
        {
            if (self.networkStatus.isReachableWifi || SavedSettings.si.isManualCachingOnWWANEnabled)
            {
                if (!cacheQueueManagerS.isQueueDownloading)
                {
                    [cacheQueueManagerS startDownloadQueue];
                }
            }
            else
            {
                [cacheQueueManagerS stopDownloadQueue];
            }
        }
    }
}

- (BOOL)isWifi
{
	if (self.networkStatus.isReachableWifi)
		return YES;
	else
		return NO;
}

- (void)showSettings
{
	if (IS_IPAD())
	{
		[self.ipadRootViewController.menuViewController showSettings];
	}
	else
	{
        [(NewMenuViewController *)self.sidePanelController.leftPanel showSettings];
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
			
			ViewObjectsSingleton.si.isOnlineModeAlertShowing = NO;
			ViewObjectsSingleton.si.isNoNetworkAlertShowing = NO;
			
			if (buttonIndex == 1)
			{
				if (SavedSettings.si.isOfflineMode)
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
				SavedSettings.si.isUpdateCheckEnabled = NO;
			}
			else if (buttonIndex == 1)
			{
				SavedSettings.si.isUpdateCheckEnabled = YES;
			}
			
			SavedSettings.si.isUpdateCheckQuestionAsked = YES;
			
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
					[mailer setToRecipients:@[@"support@isubapp.com"]];
					
					if ([[[BITHockeyManager sharedHockeyManager] crashManager] didCrashInLastSession])
					{
						// Set version label
						NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
						NSString *formattedVersion = nil;
                        #if IS_RELEASE()
                            formattedVersion = version;
                        #else
							NSString *build = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
							formattedVersion = [NSString stringWithFormat:@"%@ build %@", build, version];
                        #endif
						
						NSString *subject = [NSString stringWithFormat:@"I had a crash in iSub %@ :(", formattedVersion];
						[mailer setSubject:subject];
						
						[mailer setMessageBody:@"Here's what I was doing when iSub crashed..." isHTML:NO];
					}
					else 
					{
						[mailer setSubject:@"I need some help with iSub :)"];
					}
                    
                    NSString *zippedLogs = [self zipAllLogFiles];
                    if (zippedLogs)
                    {
                        NSError *fileError;
                        NSData *zipData = [NSData dataWithContentsOfFile:zippedLogs options:NSDataReadingMappedIfSafe error:&fileError];
                        if (!fileError)
                        {
                            [mailer addAttachmentData:zipData mimeType:@"application/x-zip-compressed" fileName:[zippedLogs lastPathComponent]];
                        }
                    }
					
					if (IS_IPAD())
						[self.ipadRootViewController presentViewController:mailer animated:YES completion:nil];
					else
						[self.sidePanelController presentViewController:mailer animated:YES completion:nil];
					
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
        case 10:
        {            
            // WaveBox Release message
            SavedSettings.si.isStopCheckingWaveboxRelease = YES;
            if (buttonIndex == 1)
            {
                // More Info
                NSString *moreInfoUrl = [alertView ex2CustomObjectForKey:@"moreInfoUrl"];
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:moreInfoUrl]];
            }
            else if (buttonIndex == 2)
            {
                // App Store
                NSString *appStoreUrl = [alertView ex2CustomObjectForKey:@"appStoreUrl"];
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:appStoreUrl]];
            }
        }
	}
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error 
{   
	if (IS_IPAD())
		[self.ipadRootViewController dismissViewControllerAnimated:YES completion:nil];
	else
		[self.sidePanelController dismissViewControllerAnimated:YES completion:nil];
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

/*- (NSInteger) getHour
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
}*/

- (void)checkWaveBoxRelease
{
    /*
    if (!SavedSettings.si.isStopCheckingWaveboxRelease && !SavedSettings.si.isWaveBoxAlertShowing)
    {
        [EX2Dispatch runInBackgroundAsync:^
         {
             NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"http://isubapp.com/wavebox.json"]];
             if (data.length > 0)
             {
                 NSDictionary *dict = [[[SBJsonParser alloc] init] objectWithData:data];
                 NSString *title = dict[@"title"];
                 NSString *message = dict[@"message"];
                 NSString *moreInfoUrl = dict[@"moreInfoUrl"];
                 NSString *appStoreUrl = dict[@"appStoreUrl"];
                 if (title && message && moreInfoUrl && appStoreUrl)
                 {
                     if (!SavedSettings.si.isWaveBoxAlertShowing)
                     {
                         SavedSettings.si.isWaveBoxAlertShowing = YES;
                         [EX2Dispatch runInMainThreadAsync:^
                          {
                              UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:@"Not Now" otherButtonTitles:@"More Info", @"Install Now", nil];
                              alert.tag = 10;
                              [alert ex2SetCustomObject:moreInfoUrl forKey:@"moreInfoUrl"];
                              [alert ex2SetCustomObject:appStoreUrl forKey:@"appStoreUrl"];
                              [alert show];
                          }];
                     }
                 }
             }
         }];
    }*/
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
		return [NSString stringWithFormat:@"%@/rest/stream.view?maxBitRate=%i&u=%@&p=%@&v=1.2.0&c=iSub&id=", SavedSettings.si.urlString, [musicS maxBitrateSetting], [encodedUserName autorelease], [encodedPassword autorelease]];
	}
    else
	{
		return [NSString stringWithFormat:@"%@/rest/stream.view?u=%@&p=%@&v=1.1.0&c=iSub&id=", SavedSettings.si.urlString, [encodedUserName autorelease], [encodedPassword autorelease]];
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

#pragma mark - Movie Playing

- (void)createMoviePlayer
{
    if (!self.moviePlayer)
    {
        self.moviePlayer = [[MPMoviePlayerController alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayerExitedFullscreen:) name:MPMoviePlayerDidExitFullscreenNotification object:self.moviePlayer];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayBackDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:self.moviePlayer];
        
        self.moviePlayer.controlStyle = MPMovieControlStyleDefault;
        self.moviePlayer.shouldAutoplay = YES;
        self.moviePlayer.movieSourceType = MPMovieSourceTypeStreaming;
        self.moviePlayer.allowsAirPlay = YES;
        
        // TODO: Implement video playback in new UI
//        if (IS_IPAD())
//        {
//            [appDelegateS.ipadRootViewController.menuViewController.playerHolder addSubview:self.moviePlayer.view];
//            self.moviePlayer.view.frame = self.moviePlayer.view.superview.bounds;
//        }
//        else
//        {
//            [appDelegateS.mainTabBarController.view addSubview:self.moviePlayer.view];
//            self.moviePlayer.view.frame = CGRectZero;
//        }
        
        [self.moviePlayer setFullscreen:YES animated:YES];
    }
}

- (void)removeMoviePlayer
{
    if (self.moviePlayer)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerDidExitFullscreenNotification object:self.moviePlayer];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:self.moviePlayer];
        
        // Dispose of any existing movie player
        [self.moviePlayer stop];
        [self.moviePlayer.view removeFromSuperview];
        self.moviePlayer = nil;
    }
}

- (void)playVideoNotification:(NSNotification *)notification
{
    id aSong = notification.userInfo[@"song"];
    if (aSong && [aSong isKindOfClass:[ISMSSong class]])
    {
        [self playVideo:aSong];
    }
}

- (void)playVideo:(ISMSSong *)aSong
{
    if (aSong.contentType.basicType != ISMSBasicContentTypeVideo)
        return;
    
    if (IS_IPAD())
    {
        // Turn off repeat one so user doesn't get stuck
        if (PlayQueue.si.repeatMode == RepeatModeRepeatOne)
            PlayQueue.si.repeatMode = RepeatModeNormal;
    }
    
    ServerType serverType = SavedSettings.si.currentServer.type;
    if (serverType == ServerTypeSubsonic)
    {
        [self playSubsonicVideo:aSong bitrates:SavedSettings.si.currentVideoBitrates];
    }
    else if (serverType == ServerTypeISubServer || serverType == ServerTypeWaveBox)
    {
        [self playWaveBoxVideo:aSong bitrates:SavedSettings.si.currentVideoBitrates];
    }
}

- (void)playSubsonicVideo:(ISMSSong *)aSong bitrates:(NSArray *)bitrates
{
    /*
    [PlayQueue.si stop];
    
    if (!aSong.itemId || !bitrates)
        return;
    
    NSDictionary *parameters = @{ @"id" : aSong.itemId, @"bitRate" : bitrates };
    NSURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"hls" parameters:parameters];
    
    // If we're on HTTPS, use our proxy to allow for playback from a self signed server
    NSString *host = request.URL.absoluteString;
    host = [host.lowercaseString hasPrefix:@"https"] ? [NSString stringWithFormat:@"http://localhost:%u%@", self.hlsProxyServer.listeningPort, request.URL.relativePath] : host;
    NSString *urlString = [NSString stringWithFormat:@"%@?%@", host, [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]];
    DLog(@"HLS urlString: %@", urlString);
    
    [self createMoviePlayer];
    
    [self.moviePlayer stop]; // Doing this to prevent potential crash
    self.moviePlayer.contentURL = [NSURL URLWithString:urlString];
    //[moviePlayer prepareToPlay];
    [self.moviePlayer play];
     */
}

- (void)playWaveBoxVideo:(ISMSSong *)aSong bitrates:(NSArray *)bitrates
{
    [PlayQueue.si stop];
    
    if (!aSong.itemId || !bitrates)
        return;
    
    NSDictionary *parameters = @{ @"id" : aSong.itemId, @"transQuality" : bitrates };
    NSURLRequest *request = [NSMutableURLRequest requestWithPMSAction:@"transcodehls" parameters:parameters];
    
    NSString *urlString = [NSString stringWithFormat:@"%@?%@", request.URL.absoluteString, [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]];
    
    //NSString *urlString = [NSString stringWithFormat:@"%@/rest/hls.m3u8?c=iSub&v=1.8.0&u=%@&p=%@&id=%@", SavedSettings.si.urlString, [SavedSettings.si.username URLEncodeString], [SavedSettings.si.password URLEncodeString], aSong.itemId];
    DLog(@"urlString: %@", urlString);
    
    [self createMoviePlayer];
    
    [self.moviePlayer stop]; // Doing this to prevent potential crash
    self.moviePlayer.contentURL = [NSURL URLWithString:urlString];
    //[moviePlayer prepareToPlay];
    [self.moviePlayer play];
}

- (void)moviePlayerExitedFullscreen:(NSNotification *)notification
{
    // Hack to fix broken navigation bar positioning
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    UIView *view = [window.subviews lastObject];
    if (view)
    {
        [view removeFromSuperview];
        [window addSubview:view];
    }
    
    if (!IS_IPAD())
    {
        [self removeMoviePlayer];
    }
}

- (void)moviePlayBackDidFinish:(NSNotification *)notification
{
    DLog(@"userInfo: %@", notification.userInfo);
    if (notification.userInfo)
    {
        NSNumber *reason = [notification.userInfo objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
        if (reason && reason.integerValue == MPMovieFinishReasonPlaybackEnded)
        {
            // Playback ended normally, so start the next item
            [PlayQueue.si playNextSong];
//            [playlistS incrementIndex];
//            [musicS playSongAtPosition:playlistS.currentIndex];
        }
    }
    else
    {
        //[self removeMoviePlayer];
    }
}

- (void)switchServerTo:(Server *)server redirectUrl:(NSString *)redirectUrl
{
    // Update the variables
    SavedSettings.si.currentServerId = server.serverId;
    SavedSettings.si.redirectUrlString = redirectUrl;
    
    // Create the playlist table if necessary (does nothing if they exist)
    [ISMSPlaylist createPlaylist:@"Play Queue" playlistId:[ISMSPlaylist playQueuePlaylistId] serverId:server.serverId];
    [ISMSPlaylist createPlaylist:@"Download Queue" playlistId:[ISMSPlaylist downloadQueuePlaylistId] serverId:server.serverId];
    [ISMSPlaylist createPlaylist:@"Downloaded Songs" playlistId:[ISMSPlaylist downloadedSongsPlaylistId] serverId:server.serverId];
    
    // Cancel any caching
    [streamManagerS removeAllStreams];
    
    // Reset UI
    [(NewMenuViewController *)self.sidePanelController.leftPanel resetMenuItems];

    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ServerSwitched];
}

@end

