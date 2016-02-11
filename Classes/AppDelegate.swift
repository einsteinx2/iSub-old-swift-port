//
//  AppDelegate.swift
//  iSub
//
//  Created by Benjamin Baron on 2/5/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import libSub
import Foundation

class AppDelegate: NSObject, UIApplicationDelegate, UIAlertViewDelegate, BITHockeyManagerDelegate, BITCrashManagerDelegate {//, ISMSLoaderDelegate {
    
    var window: UIWindow?
    
    var referringAppUrl: NSURL?
    var backgroundTask = UIBackgroundTaskInvalid
    var inBackground = false
    let hlsProxyServer = HTTPServer()
    
    let reachability = EX2Reachability.reachabilityForLocalWiFi()
    
    static func sharedInstance() -> AppDelegate {
        return UIApplication.sharedApplication().delegate as! AppDelegate
    }
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        // Turn on console logging for debug builds
        #if DebugBuild
        DDLog.addLogger(DDTTYLogger.sharedInstance())
        DDTTYLogger.sharedInstance().colorsEnabled = true
        #endif
        
        // Turn on file logging
        // TODO: Verify the logs directory is correct
        let fileLogger = DDFileLogger()
        fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        fileLogger.logFileManager.logsDirectory()
        DDLog.addLogger(fileLogger)
        
        let settings = SavedSettings.sharedInstance()
        let notificationCenter = NSNotificationCenter.defaultCenter()
        
        // Make sure audio engine and cache singletons get loaded
        AudioEngine.sharedInstance()
        CacheSingleton.sharedInstance()
        
        // Start the save defaults timer and mem cache initial defaults
        settings.setupSaveState()
        
        // Setup network reachability notifications
        self.reachability.startNotifier()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reachabilityChanged:", name: EX2ReachabilityNotification_ReachabilityChanged, object: nil)
        self.reachability.currentReachabilityStatus()
        
        // Check battery state and register for notifications
        UIDevice.currentDevice().batteryMonitoringEnabled = true
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "batteryStateChanged:", name: "UIDeviceBatteryStateDidChangeNotification", object: UIDevice.currentDevice())
        batteryStateChanged(nil)
        
        // Handle offline mode
        let reachabilityStatus = self.reachability.currentReachabilityStatus()
        if settings.isForceOfflineMode {
            settings.isOfflineMode = true
        } else if reachabilityStatus == .NotReachable {
            settings.isOfflineMode = true
        } else if reachabilityStatus == .ReachableViaWWAN && settings.isDisableUsageOver3G {
            settings.isOfflineMode = true
        } else {
            settings.isOfflineMode = false
        }
        
        var showIntro = false
        if settings.isTestServer {
            if settings.isOfflineMode {
                let alert = UIAlertView(title: "Welcome!", message: "Looks like this is your first time using iSub or you haven't set up your Subsonic account info yet.\n\nYou'll need an internet connection to watch the intro video and use the included demo account.", delegate: self, cancelButtonTitle: "OK")
                alert.performSelector("show", withObject: nil, afterDelay: 1.0)
            } else {
                showIntro = true
            }
        }
        
        loadFlurryAnalytics()
        loadHockeyApp()
        loadInAppPurchaseStore()
        
        // Show intro if needed
        if showIntro {
            let introController = IntroViewController()
            self.window?.rootViewController?.presentViewController(introController, animated: false, completion: nil)
        }
        
        // Check the server status in the background
        if !settings.isOfflineMode {
            ViewObjectsSingleton.sharedInstance().showAlbumLoadingScreenOnMainWindowWithSender(self)
            checkServer()
        }
        
        notificationCenter.addObserver(self, selector: "playVideoNotification:", name: ISMSNotification_PlayVideo, object: nil)
        notificationCenter.addObserver(self, selector: "removeMoviePlayer", name: ISMSNotification_RemoveMoviePlayer, object: nil)
        
        startHLSProxy()
        
        // Recover current state if player was interrupted
        ISMSStreamManager.sharedInstance()
        MusicSingleton.sharedInstance().resumeSong()
        
        return true
    }
    
    // TODO: Test this
    func application(app: UIApplication, openURL url: NSURL, options: [String : AnyObject]) -> Bool {
        let audioEngine = AudioEngine.sharedInstance()
        let musicSingleton = MusicSingleton.sharedInstance()
        let playlistSingleton = PlaylistSingleton.sharedInstance()
        
        if let host = url.host?.lowercaseString {
            switch host {
            case "play":
                if let player = audioEngine.player {
                    if !player.isPlaying {
                        player.playPause()
                    }
                } else {
                    musicSingleton.playSongAtPosition(playlistSingleton.currentIndex)
                }
            case "pause":
                if let player = audioEngine.player {
                    if player.isPlaying {
                        player.playPause()
                    }
                }
            case "playpause":
                if let player = audioEngine.player {
                    player.playPause()
                } else {
                    musicSingleton.playSongAtPosition(playlistSingleton.currentIndex)
                }
            case "next":
                musicSingleton.playSongAtPosition(playlistSingleton.nextIndex)
            case "prev":
                musicSingleton.playSongAtPosition(playlistSingleton.prevIndex)
            default:
                break
            }
        }
        
        let queryParameters = url.queryParameterDictionary()
        if let urlString = queryParameters["ref"] {
            self.referringAppUrl = NSURL(string: urlString)
            
//            // On the iPad we need to reload the menu table to see the back button
//            if (IS_IPAD())
//            {
//                [self.ipadRootViewController.menuViewController loadCellContents];
//            }
        }
        
        return true
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        checkServer()
        //checkWaveBoxRelease()
    }
    
    func applicationDidEnterBackground(application: UIApplication) {
        SavedSettings.sharedInstance().saveState()
        NSUserDefaults.standardUserDefaults().synchronize()
        
        self.backgroundTask = application.beginBackgroundTaskWithExpirationHandler() {
            // App is about to be put to sleep, stop the cache download queue
            if ISMSCacheQueueManager.sharedInstance().isQueueDownloading == true {
                ISMSCacheQueueManager.sharedInstance().stopDownloadQueue()
            }
            
            // Make sure to end the background so we don't get killed by the OS
            application.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = UIBackgroundTaskInvalid;
            
            // Cancel the next server check otherwise it will fire immediately on launch
            // TODO: Rewrite this without using NSObject methods
            //[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkServer) object:nil];
        }
        
        // Check the remaining background time and alert the user if necessary
        let queue = dispatch_queue_create("isub.backgroundqueue", DISPATCH_QUEUE_CONCURRENT)
        dispatch_async(queue) {
            self.inBackground = true
            timeCheck: while application.backgroundTimeRemaining > 1.0 && self.inBackground == true {
                // Sleep early is nothing is happening after 500 seconds
                if application.backgroundTimeRemaining < 200.0 && ISMSCacheQueueManager.sharedInstance().isQueueDownloading == false {
                    //DLog("Sleeping early, isQueueListDownloading: %i", cacheQueueManagerS.isQueueDownloading);
                    application.endBackgroundTask(self.backgroundTask)
                    self.backgroundTask = UIBackgroundTaskInvalid;
                    
                    // Cancel the next server check otherwise it will fire immediately on launch
                    // TODO: Rewrite without NSObject methods
                    //[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkServer) object:nil];
                    break timeCheck
                }
                
                // Warn at 2 minute mark if cache queue is downloading
                if application.backgroundTimeRemaining < 120.0 && ISMSCacheQueueManager.sharedInstance().isQueueDownloading == true {
                    let localNotification = UILocalNotification()
                    localNotification.alertBody = "Songs are still caching. Please return to iSub within 2 minutes, or it will be put to sleep and your song caching will be paused."
                    localNotification.alertAction = "Open iSub"
                    application.presentLocalNotificationNow(localNotification)
                }
                
                // Sleep for a second to avoid a fast loop eating all cpu cycles
                sleep(1)
            }
        }
    }
    
    func applicationWillEnterForeground(application: UIApplication) {
        self.inBackground = false
        if self.backgroundTask != UIBackgroundTaskInvalid {
            application.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = UIBackgroundTaskInvalid
        }
        
        // Update the lock screen art in case were were using another app
        MusicSingleton.sharedInstance().updateLockScreenInfo()
    }
    
    func applicationWillTerminate(application: UIApplication) {
        application.endReceivingRemoteControlEvents()
        SavedSettings.sharedInstance().saveState()
        AudioEngine.sharedInstance().player.stop()
    }
    
    func batteryStateChanged(notification: NSNotification?) {
        let batteryState = UIDevice.currentDevice().batteryState
        
        if batteryState == .Charging || batteryState == .Full {
            UIApplication.sharedApplication().idleTimerDisabled = true
        } else if SavedSettings.sharedInstance().isScreenSleepEnabled {
            UIApplication.sharedApplication().idleTimerDisabled = false
        }
    }
    
    func startHLSProxy() {
        self.hlsProxyServer.setConnectionClass(HLSProxyConnection)
        
        do {
            try self.hlsProxyServer.start()
        } catch let error as NSError {
            
            DDLogError("Error starting HLS proxy server: \(error)")
        }
    }
    
    func loadFlurryAnalytics() {
        var key = ""
        #if ReleaseTarget
            key = "MQV1D5WQYUTCDAD6PFLU"
        #elseif LiteTarget
            key = "3KK4KKD2PSEU5APF7PNX"
        #elseif BetaTarget
            key = "KNN9DUXQEENZUG4Q12UA"
        #endif

        #if !DebugBuild
            // These set to no as per Flurry support instructions to prevent crashes
            Flurry.setSessionReportsOnPauseEnabled(false)
            Flurry.setSessionReportsOnCloseEnabled(false)
            
            // Send the firmware version
            let device = UIDevice.currentDevice()
            let params = ["FirmwareVersion": device.completeVersionString(), "HardwareVersion": device.platform()]
            Flurry.logEvent("DeviceInfo", withParameters: params)
        #endif
    }
    
    func loadHockeyApp() {
        let hockeyManager = BITHockeyManager.sharedHockeyManager()
        
        var identifier = ""
        var showUpdateReminder = false
        
        #if ReleaseTarget
            identifier = "7c9cb46dad4165c9d3919390b651f6bb"
        #elseif LiteTarget
            identifier = "36cd77b2ee78707009f0a9eb9bbdbec7"
        #elseif BetaTarget
            identifier = "ada15ac4ffe3befbc66f0a00ef3d96af"
            showUpdateReminder = true
        #endif
        
        #if !DebugBuild
            hockeyManager.crashManager.crashManagerStatus = BITCrashManagerStatusAutoSend;
//            if (hockeyManager.crashManager.didCrashInLastSession)
//            {
//                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Oh no! iSub crashed!" message:@"iSub support has received your anonymous crash logs and they will be investigated. \n\nWould you also like to send an email to support with more details?" delegate:self cancelButtonTitle:@"No Thanks" otherButtonTitles:@"Send Email", @"Visit iSub Forum", nil];
//                alert.tag = 7;
//                [alert performSelector:@selector(show) withObject:nil afterDelay:2.];
//            }
        #endif
    }
    
    func applicationLogForCrashManager(crashManager: BITCrashManager) -> String {
        // TODO: Redo this when logging is fixed
//        NSString *logsFolder = [settingsS.cachesPath stringByAppendingPathComponent:@"Logs"];
//        NSString *fileNameToUse = [self latestLogFileName];
//        
//        if (fileNameToUse)
//        {
//            NSString *logPath = [logsFolder stringByAppendingPathComponent:fileNameToUse];
//            NSString *contents = [[NSString alloc] initWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil];
//            //DLog(@"Sending contents with length %u from path %@", contents.length, logPath);
//            return contents;
//        }
        
        return ""
    }
    
    func loadInAppPurchaseStore() {
        // TODO: Update this for latest MKStoreKit
        #if LiteTarget
            MKStoreManager.sharedManager()
            //MKStoreManager.setDelegate(self)
        #endif
        
        #if DebugBuild
            // TODO: Implement this
            // Reset features
//            [SFHFKeychainUtils storeUsername:kFeaturePlaylistsId andPassword:@"NO" forServiceName:kServiceName updateExisting:YES error:nil];
//            [SFHFKeychainUtils storeUsername:kFeatureCacheId andPassword:@"NO" forServiceName:kServiceName updateExisting:YES error:nil];
//            [SFHFKeychainUtils storeUsername:kFeatureVideoId andPassword:@"NO" forServiceName:kServiceName updateExisting:YES error:nil];
//            [SFHFKeychainUtils storeUsername:kFeatureAllId andPassword:@"NO" forServiceName:kServiceName updateExisting:YES error:nil];
        #endif
    }
    
    // TODO: Fill in for new UI
    func jukeboxToggled() {
        
    }

    func backToReferringApp() {
        if let url = self.referringAppUrl {
            UIApplication.sharedApplication().openURL(url)
        }
    }
    
    func checkServer() {
        
    }
}