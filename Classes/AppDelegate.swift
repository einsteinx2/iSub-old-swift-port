//
//  AppDelegate.swift
//  iSub
//
//  Created by Benjamin Baron on 1/16/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

// TODO: Check all number casts in app, an out of range cast will cause a crash. We should use/make some safe casting functions.

import UIKit
import Reachability

@objc final class AppDelegate: NSObject, UIApplicationDelegate, BITHockeyManagerDelegate, BITCrashManagerDelegate {
    struct Notifications {
        static let enteringOfflineMode = Notification.Name("AppDelegate_enteringOfflineMode")
        static let enteringOnlineMode  = Notification.Name("AppDelegate_enteringOnlineMode")
    }
    
    let networkStatus = NetworkStatus()
    
    var window: UIWindow?
    let sidePanelController = SidePanelController()
    var menuController: MenuViewController {
        return sidePanelController.leftPanel as! MenuViewController
    }
    
    fileprivate var showIntro = false
    fileprivate var isNoNetworkAlertShowing = false
    fileprivate var isOnlineModeAlertShowing = false
    fileprivate var statusLoader: StatusLoader? = nil
    fileprivate var backgroundTask = UIBackgroundTaskInvalid
    fileprivate var isInBackground = false
    fileprivate var referringAppUrl: URL? = nil
    
    static var si: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    static var shouldAutorotate: Bool {
        return true
    }
    
    func applicationDidFinishLaunching(_ application: UIApplication) {
        // Make sure the singletons get setup immediately and in the correct order
        // Perfect example of why using singletons is bad practice!
        SavedSettings.si.setup()
        Database.si.setup()
        CacheManager.si.setup()
        
        #if DebugBuild
            // Console logging only for Xcode builds
            DDTTYLogger.sharedInstance().colorsEnabled = true
            DDLog.add(DDTTYLogger.sharedInstance())
        #endif
        let fileLogger = DDFileLogger()
        fileLogger?.rollingFrequency = 60.0 * 60.0 * 24.0; // 24 hour rolling
        fileLogger?.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.add(fileLogger)
        
        // Setup network reachability notifications
        networkStatus.startMonitoring()
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reachabilityChanged), name: ReachabilityChangedNotification)
        
        // Check battery state and register for notifications
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(batteryStateChanged), name: NSNotification.Name.UIDeviceBatteryStateDidChange, object: UIDevice.current)
        batteryStateChanged()
        
        loadHockeyApp()
        
        let fingerTipWindow = MBFingerTipWindow(frame: UIScreen.main.bounds)
        //fingerTipWindow.alwaysShowTouches = true
        window = fingerTipWindow
        window?.backgroundColor = .black
        window?.makeKeyAndVisible()
        window?.rootViewController = sidePanelController
        
        // Handle offline mode
        if !networkStatus.isReachable || (!networkStatus.isReachableWifi && SavedSettings.si.isDisableUsageOver3G) {
            SavedSettings.si.isOfflineMode = true
        }
        
        // Show intro if necessary
        if SavedSettings.si.isTestServer {
            showIntro = true
        }
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        if showIntro {
            showIntro = false
            
            // Delay fixes unbalanced transition warning
            DispatchQueue.main.async(after: 0.1) {
                self.sidePanelController.present(IntroViewController(), animated: false, completion: nil)
            }
        }
        
        checkServer()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        backgroundTask = application.beginBackgroundTask {
            // App is about to be put to sleep, stop the cache download queue
            if CacheQueue.si.isDownloading {
                CacheQueue.si.stop()
            }
            
            // Make sure to end the background so we don't get killed by the OS
            application.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = UIBackgroundTaskInvalid;
        }
        
        isInBackground = true
        DispatchQueue.utility.async {
            while application.backgroundTimeRemaining > 1.0 && self.isInBackground {
                // Sleep early is nothing is happening
                if application.backgroundTimeRemaining < 200.0 && !CacheQueue.si.isDownloading {
                    application.endBackgroundTask(self.backgroundTask)
                    self.backgroundTask = UIBackgroundTaskInvalid;
                    break
                }
                
                // Warn at 2 minute mark if cache queue is downloading
                if application.backgroundTimeRemaining < 120.0 && CacheQueue.si.isDownloading {
                    let local = UILocalNotification()
                    local.alertBody = "Songs are still caching. Please return to iSub within 2 minutes, or it will be put to sleep and your song caching will be paused."
                    local.alertAction = "Open iSub"
                    application.presentLocalNotificationNow(local)
                    break
                }
                
                // Sleep for a second to avoid a fast loop eating all cpu cycles
                sleep(1);
            }
        }
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        isInBackground = false
        if backgroundTask != UIBackgroundTaskInvalid {
            application.endBackgroundTask(backgroundTask)
            backgroundTask = UIBackgroundTaskInvalid
        }
        
        // Update the lock screen art in case were were using another app
        PlayQueue.si.updateLockScreenInfo()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        application.endReceivingRemoteControlEvents()
        UserDefaults.standard.synchronize()
        PlayQueue.si.stop()
    }
    
    // TODO: Audit all this and test. Seems to duplicate code in Application
    // TODO: Double check play function on new app launch
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        // Handle being openned by a URL
        print("url host: \(url.host) path components: \(url.pathComponents)")
        
        if let host = url.host?.lowercased() {
            switch host {
            case "play": PlayQueue.si.play()
            case "pause": PlayQueue.si.play()
            case "playpause": PlayQueue.si.playPause()
            case "next": PlayQueue.si.playNextSong()
            case "prev": PlayQueue.si.playPreviousSong()
            default: break
            }
        }
        
        let queryParameters = (url as NSURL).queryParameterDictionary()
        if let ref = queryParameters["ref"] {
            referringAppUrl = URL(string: ref)
        }
 
        return true
    }
    
    fileprivate func backToReferringApp() {
        if let referringAppUrl = referringAppUrl {
            UIApplication.shared.openURL(referringAppUrl)
        }
    }
    
    @objc fileprivate func checkServer() {
        // Check if the subsonic URL is valid by attempting to access the ping.view page,
        // if it's not then display an alert and allow user to change settings if they want.
        // This is in case the user is, for instance, connected to a wifi network but does not
        // have internet access or if the host url entered was wrong.
        if !SavedSettings.si.isOfflineMode {
            statusLoader?.cancel()
            
            let currentServer = SavedSettings.si.currentServer
            statusLoader = StatusLoader(server: currentServer)
            statusLoader?.completionHandler = { success, error, loader in
                SavedSettings.si.redirectUrlString = loader.redirectUrlString
                
                if success {
                    // TODO: Find a better way to handle this, or at least a button in the download queue to allow resuming rather
                    // than having to know that they need to queue another song for download
                    //
                    // Since the download queue has been a frequent source of crashes in the past, and we start this on launch automatically
                    // potentially resulting in a crash loop, do NOT start the download queue automatically if the app crashed on last launch.
                    if !BITHockeyManager.shared().crashManager.didCrashInLastSession {
                        // Start the queued downloads if Wifi is available
                        CacheQueue.si.start()
                    }
                    
                    // Load media folders
                    MediaFoldersLoader(serverId: currentServer.serverId).start()
                    
                } else if !SavedSettings.si.isOfflineMode {
                    self.enterOfflineMode()
                }
                
                self.statusLoader = nil;
            }
            statusLoader?.start()
        }
        
        // Do a server check every half hour
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(checkServer), object: nil)
        self.perform(#selector(checkServer), with: nil, afterDelay: 30.0 * 60.0)
    }
    
    fileprivate func loadHockeyApp() {
        let hockeyManager = BITHockeyManager.shared()
        hockeyManager.crashManager.crashManagerStatus = .autoSend;
        
        #if BetaTarget
            NSLog("BetaTarget")
        #endif
        #if AdHocBuild
            NSLog("AdHocBuild")
        #endif
        #if (BetaTarget && AdHocBuild)
            NSLog("(BetaTarget && AdHocBuild)")
        #endif
        
//        // HockyApp Kits
//        #if (BetaTarget && AdHocBuild)
//            hockeyManager.configure(withIdentifier: "ada15ac4ffe3befbc66f0a00ef3d96af", delegate: self)
//            hockeyManager.start()
//        #elseif ReleaseBuild
//            hockeyManager.configure(withIdentifier: "7c9cb46dad4165c9d3919390b651f6bb", delegate: self)
//            hockeyManager.start()
//        #endif
        
        hockeyManager.configure(withIdentifier: "ada15ac4ffe3befbc66f0a00ef3d96af", delegate: self)
        hockeyManager.start()
    }
    
    func applicationLog(for crashManager: BITCrashManager!) -> String! {
        let logsFolder = Logging.logsFolder
        if let fileName = Logging.latestLogFileName {
            let path = logsFolder + "/" + fileName
            if let contents = try? String(contentsOfFile: path) {
                return contents
            }
        }
        return ""
    }
    
    // TODO: Implement offline mode
    func enterOfflineMode() {
        if !isNoNetworkAlertShowing {
            isNoNetworkAlertShowing = true
        }
    }
    
    func enterOnlineMode() {
        if isNoNetworkAlertShowing {
            isNoNetworkAlertShowing = false
        }
    }
    
    func enterOfflineModeForce() {
        if SavedSettings.si.isOfflineMode {
            return
        }
        
        NotificationCenter.postOnMainThread(name: Notifications.enteringOfflineMode)
        
        SavedSettings.si.isOfflineMode = true
        PlayQueue.si.stop()
        StreamQueue.si.stop()
        CacheQueue.si.stop()
        PlayQueue.si.updateLockScreenInfo()
    }
    
    func enterOnlineModeForce() {
        if !networkStatus.isReachable {
            return
        }
        
        NotificationCenter.postOnMainThread(name: Notifications.enteringOnlineMode)
        
        SavedSettings.si.isOfflineMode = false
        PlayQueue.si.stop()
        checkServer()
        CacheQueue.si.start()
        PlayQueue.si.updateLockScreenInfo()
    }
    
    @objc fileprivate func reachabilityChanged() {
        if !networkStatus.isReachable {
            if !SavedSettings.si.isOfflineMode {
                enterOfflineMode()
            }
        } else if !networkStatus.isReachableWifi && SavedSettings.si.isDisableUsageOver3G {
            if !SavedSettings.si.isOfflineMode {
                enterOfflineModeForce()
            }
        } else {
            checkServer()
            
            if SavedSettings.si.isOfflineMode {
                enterOnlineMode()
            } else {
                if networkStatus.isReachableWifi || SavedSettings.si.isManualCachingOnWWANEnabled {
                    CacheQueue.si.start()
                } else {
                    CacheQueue.si.stop()
                }
            }
        }
    }
    
    @objc fileprivate func batteryStateChanged() {
        if UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full {
            UIApplication.shared.isIdleTimerDisabled = true
        } else if SavedSettings.si.isScreenSleepEnabled {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    func showSettings() {
        menuController.showSettings()
    }
    
    func switchServer(to server: Server, redirectUrl: String?) {
        SavedSettings.si.currentServerId = server.serverId
        SavedSettings.si.redirectUrlString = redirectUrl
        
        // Create the default playlist tables
        PlaylistRepository.si.createDefaultPlaylists(serverId: server.serverId)
        
        // Cancel any caching
        StreamQueue.si.stop()
        CacheQueue.si.stop()
        
        // Reset UI
        menuController.resetMenuItems()
        
        // Load media folders
        MediaFoldersLoader(serverId: server.serverId).start()
    }
}
