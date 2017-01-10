//
//  AppDelegate.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "AppDelegate.h"
#import "Imports.h"
#import "iSub-Swift.h"
#import <CoreFoundation/CoreFoundation.h>
#import <netinet/in.h>
#import <netdb.h>
#import <arpa/inet.h>
#import "IntroViewController.h"
#import "ISMSUpdateChecker.h"
#import <MediaPlayer/MediaPlayer.h>
#import "HLSProxyConnection.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"
#import <HockeySDK/HockeySDK.h>
#import "JASidePanelController.h"
#import "Logging.h"

#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>

//LOG_LEVEL_ISUB_DEFAULT

@interface AppDelegate() <MFMailComposeViewControllerDelegate, BITHockeyManagerDelegate, BITCrashManagerDelegate>
@property (nonatomic) BOOL showIntro;
@property (nonatomic) BOOL isNoNetworkAlertShowing;
@property (nonatomic) BOOL isOnlineModeAlertShowing;
@property (strong) StatusLoader *statusLoader;
@property UIBackgroundTaskIdentifier backgroundTask;
@property BOOL isInBackground;
@property (strong) NSURL *referringAppUrl;
@end

@implementation AppDelegate

+ (AppDelegate *)si
{
	return (AppDelegate*)[UIApplication sharedApplication].delegate;
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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged) name:ISMSNotification_ReachabilityChanged object:nil];
	
	// Check battery state and register for notifications
	[UIDevice currentDevice].batteryMonitoringEnabled = YES;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryStateChanged:) name:@"UIDeviceBatteryStateDidChangeNotification" object:[UIDevice currentDevice]];
	[self batteryStateChanged:nil];
		
	//[self loadFlurryAnalytics];
	[self loadHockeyApp];
		    
    // Check the server status in the background
    if (!SavedSettings.si.isOfflineMode)
    {
        [self checkServer];
    }
        
    // Recover current state if player was interrupted. Do not resume if we're connected to the test server
    // because music will start playing behind the intro screen.
    [ISMSStreamManager si];
    if (SavedSettings.si.isTestServer || !SavedSettings.si.isRecover)
    {
        [ISMSStreamManager.si removeAllStreams];
    }
    else
    {
        ISMSSong *currentSong = PlayQueue.si.currentSong;
        if (currentSong)
        {
            [PlayQueue.si startSongWithOffsetBytes:(NSInteger)SavedSettings.si.byteOffset offsetSeconds:SavedSettings.si.seekTime];
        }
        else
        {
            // TODO: Start handling this via PlayQueue
            AudioEngine.si.startByteOffset = (NSUInteger)SavedSettings.si.byteOffset;
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
	[self.statusLoader cancel];
	[LoadingScreen hideLoadingScreen];
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
            [self.statusLoader cancel];
        }
        
        Server *currentServer = SavedSettings.si.currentServer;
        self.statusLoader = [[StatusLoader alloc] initWithUrl:currentServer.url username:currentServer.username password:currentServer.password];
        __weak AppDelegate *weakSelf = self;
        self.statusLoader.completionHandler = ^(BOOL success,  NSError * error, ApiLoader * loader) {
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
                    [CacheQueueManager.si start];
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
        [self.statusLoader start];
    }
	
	// Do a server check every half hour
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkServer) object:nil];
	NSTimeInterval delay = 30 * 60; // 30 minutes
	[self performSelector:@selector(checkServer) withObject:nil afterDelay:delay];
}

#pragma mark -

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

- (NSString *)applicationLogForCrashManager:(BITCrashManager *)crashManager
{
    NSString *logsFolder = [[SavedSettings cachesPath] stringByAppendingPathComponent:@"Logs"];
	NSString *fileNameToUse = [Logging latestLogFileName];
	
	if (fileNameToUse)
	{
		NSString *logPath = [logsFolder stringByAppendingPathComponent:fileNameToUse];
		NSString *contents = [[NSString alloc] initWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil];
		//DLog(@"Sending contents with length %u from path %@", contents.length, logPath);
		return contents;
	}
	
	return nil;
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

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	[SavedSettings.si saveState];
	
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	if ([[UIApplication sharedApplication] respondsToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)])
    {
		self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:
						  ^{
							  // App is about to be put to sleep, stop the cache download queue
							  if (CacheQueueManager.si.isDownloading)
								  [CacheQueueManager.si stop];
							  
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
					if ([application backgroundTimeRemaining] < 200.0 && !CacheQueueManager.si.isDownloading)
					{
                        //DLog("Sleeping early, isQueueListDownloading: %i", CacheQueueManager.si.isDownloading);
						[application endBackgroundTask:self.backgroundTask];
						self.backgroundTask = UIBackgroundTaskInvalid;
                        
                        // Cancel the next server check otherwise it will fire immediately on launch
                        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkServer) object:nil];
						break;
					}
					
					// Warn at 2 minute mark if cache queue is downloading
					if ([application backgroundTimeRemaining] < 120.0 && CacheQueueManager.si.isDownloading)
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
	[[UIApplication sharedApplication] endReceivingRemoteControlEvents];
	
	[SavedSettings.si saveState];
	
	[PlayQueue.si stop];
}

#pragma mark Helper Methods

- (void)enterOfflineMode
{
	if (!self.isNoNetworkAlertShowing)
	{
		self.isNoNetworkAlertShowing = YES;
		
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Notice" message:@"Server unavailable, would you like to enter offline mode? Any currently playing music will stop.\n\nIf this is just temporary connection loss, select No." delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
		alert.tag = 4;
		[alert show];
	}
}


- (void)enterOnlineMode
{
	if (!self.isOnlineModeAlertShowing)
	{
        self.isOnlineModeAlertShowing = YES;
		
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
	    
	SavedSettings.si.isOfflineMode = YES;
		
	[PlayQueue.si stop];
	
	[ISMSStreamManager.si cancelAllStreams];
	
	[CacheQueueManager.si stop];
    
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
    
	[self checkServer];
	[CacheQueueManager.si start];
    
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
                if (!CacheQueueManager.si.isDownloading)
                {
                    [CacheQueueManager.si start];
                }
            }
            else
            {
                [CacheQueueManager.si stop];
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
	[(MenuViewController *)self.sidePanelController.leftPanel showSettings];
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
			
			self.isOnlineModeAlertShowing = NO;
			self.isNoNetworkAlertShowing = NO;
			
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
                    
                    NSString *zippedLogs = [Logging zipAllLogFiles];
                    if (zippedLogs)
                    {
                        NSError *fileError;
                        NSData *zipData = [NSData dataWithContentsOfFile:zippedLogs options:NSDataReadingMappedIfSafe error:&fileError];
                        if (!fileError)
                        {
                            [mailer addAttachmentData:zipData mimeType:@"application/x-zip-compressed" fileName:[zippedLogs lastPathComponent]];
                        }
                    }
					
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
	[self.sidePanelController dismissViewControllerAnimated:YES completion:nil];
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
    [ISMSStreamManager.si removeAllStreams];
    
    // Reset UI
    [(MenuViewController *)self.sidePanelController.leftPanel resetMenuItems];
}

@end

