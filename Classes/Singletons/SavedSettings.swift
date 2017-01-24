//
//  SavedSettings.swift
//  iSub
//
//  Created by Benjamin Baron on 1/23/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

@objc enum CachingType: Int {
    case minSpace = 0
    case maxSize = 1
};

@objc class SavedSettings: NSObject {
    struct Keys {
        static let currentServerId              = "currentServerId"
        static let currentServer                = "currentServer"
        static let redirectUrlString            = "redirectUrlString"
        // TODO: isBasicAuthEnabled should be a server specific setting stored in servers table
        static let isBasicAuthEnabled           = "isBasicAuthEnabled"
        
        static let maxBitRateWifi               = "maxBitrateWifiSetting"
        static let maxBitRate3G                 = "maxBitrate3GSetting"
        static let maxVideoBitRateWifi          = "maxVideoBitrateWifi"
        static let maxVideoBitRate3G            = "maxVideoBitrate3G"
        
        static let isAutoSongCachingEnabled     = "isSongCachingEnabled"
        static let isNextSongCacheEnabled       = "enableNextSongCacheSetting"
        static let isBackupCacheEnabled         = "isBackupCacheEnabled"
        static let isManualCachingOnWWANEnabled = "isManualCachingOnWWANEnabled"
        static let cachingType                  = "cachingTypeSetting"
        static let maxCacheSize                 = "maxCacheSize"
        static let minFreeSpace                 = "minFreeSpace"
        static let isAutoDeleteCacheEnabled     = "autoDeleteCacheSetting"
        static let autoDeleteCacheType          = "autoDeleteCacheTypeSetting"
        
        static let isScreenSleepEnabled         = "isScreenSleepEnabled"
        static let quickSkipNumberOfSeconds     = "quickSkipNumberOfSeconds"
        static let isDisableUsageOver3G         = "isDisableUsageOver3G"
        
        static let seekTime                     = "seekTime"
        static let byteOffset                   = "byteOffset"
        static let isEqualizerOn                = "isEqualizerOn"
        static let preampGain                   = "gainMultiplier"
    }
    
    static let si = SavedSettings()
    fileprivate let storage = UserDefaults.standard
    
    fileprivate let lock = NSRecursiveLock()
    fileprivate func synchronizedResult<T>(criticalSection: () -> T) -> T {
        return iSub.synchronizedResult(lockable: lock, criticalSection: criticalSection)
    }
    fileprivate func synchronized(criticalSection: () -> ()) {
        iSub.synchronized(lockable: lock, criticalSection: criticalSection)
    }
    
    func setup() {
        UIApplication.shared.isIdleTimerDisabled = !isScreenSleepEnabled
        createInitialSettings()
    }
    
    fileprivate func createInitialSettings() {
        let defaults: [String: Any] =
            [Keys.maxBitRateWifi: 7,
             Keys.maxBitRate3G: 7,
             Keys.isAutoSongCachingEnabled: true,
             Keys.isNextSongCacheEnabled: true,
             Keys.cachingType: CachingType.minSpace.rawValue,
             Keys.maxCacheSize: 1024 * 1024 * 1024, // 1GB
             Keys.minFreeSpace: 256 * 1024 * 1024,  // 256MB
             Keys.isAutoDeleteCacheEnabled: true,
             Keys.autoDeleteCacheType: 0,
             Keys.isScreenSleepEnabled: true,
             Keys.isBasicAuthEnabled: false,
             Keys.maxVideoBitRateWifi: 5,
             Keys.maxVideoBitRate3G: 5,
             Keys.currentServerId: Server.testServerId]
        
        storage.register(defaults: defaults)
    }
    
    var currentServerId: Int64 {
        get { return synchronizedResult { return self.storage.object(forKey: Keys.currentServerId) as? Int64 ?? -1 }}
        set { synchronized {              self.storage.set(newValue, forKey: Keys.currentServerId) }}
    }
    
    var isTestServer: Bool {
        return currentServerId == Server.testServerId
    }
    
    var currentServer: Server {
        let serverId = currentServerId
        if serverId == Server.testServerId {
            return Server.testServer
        } else {
            return ServerRepository.si.server(serverId: serverId) ?? Server.testServer
        }
    }
    
    var redirectUrlString: String? {
        get { return synchronizedResult { return self.storage.string(forKey: Keys.redirectUrlString) }}
        set { synchronized {              self.storage.set(newValue, forKey: Keys.redirectUrlString) }}
    }
    
    var isOfflineMode: Bool = false
    
    var maxBitRateWifi: Int {
        get { return synchronizedResult { return self.storage.integer(forKey: Keys.maxBitRateWifi) }}
        set { synchronized { self.storage.set(newValue, forKey: Keys.maxBitRateWifi) }}
    }
    
    var maxBitRate3G: Int {
        get { return synchronizedResult { return self.storage.integer(forKey: Keys.maxBitRate3G) }}
        set { synchronized { self.storage.set(newValue, forKey: Keys.maxBitRate3G) }}
    }
    
    var currentMaxBitRate: Int {
        get {
            return synchronizedResult {
                let maxBitRate = AppDelegate.si.networkStatus.isReachableWifi ? maxBitRateWifi : maxBitRate3G
                switch maxBitRate {
                case 0: return  64;
                case 1: return  96;
                case 2: return 128;
                case 3: return 160;
                case 4: return 192;
                case 5: return 256;
                case 6: return 320;
                default: return 0;
                }
            }
        }
    }
    
    var maxVideoBitRateWifi: Int {
        get { return synchronizedResult { return self.storage.integer(forKey: Keys.maxVideoBitRateWifi) }}
        set { synchronized { self.storage.set(newValue, forKey: Keys.maxVideoBitRateWifi) }}
    }
    
    var maxVideoBitRate3G: Int {
        get { return synchronizedResult { return self.storage.integer(forKey: Keys.maxVideoBitRate3G) }}
        set { synchronized { self.storage.set(newValue, forKey: Keys.maxVideoBitRate3G) }}
    }
    
    var currentVideoBitRates: [Int] {
        let maxBitRate = AppDelegate.si.networkStatus.isReachableWifi ? maxVideoBitRateWifi : maxVideoBitRate3G
        switch maxBitRate {
        case 0: return [60]
        case 1: return [256, 60]
        case 2: return [512, 256, 60]
        case 3: return [1024, 512, 60]
        case 4: return [1536, 768, 60]
        case 5: return [2048, 1024, 60]
        default: return []
        }
    }
    
    var isAutoSongCachingEnabled: Bool {
        get { return synchronizedResult { return self.storage.bool(forKey: Keys.isAutoSongCachingEnabled) }}
        set { synchronized {              self.storage.set(newValue, forKey: Keys.isAutoSongCachingEnabled) }}
    }
    
    var isNextSongCacheEnabled: Bool {
        get { return synchronizedResult { return self.storage.bool(forKey: Keys.isNextSongCacheEnabled) }}
        set { synchronized {              self.storage.set(newValue, forKey: Keys.isNextSongCacheEnabled) }}
    }
    
    var isBackupCacheEnabled: Bool {
        get { return synchronizedResult { return self.storage.bool(forKey: Keys.isBackupCacheEnabled) }}
        set { synchronized {
            self.storage.set(newValue, forKey: Keys.isBackupCacheEnabled) }
            CacheManager.si.backupSongCache = newValue
        }
    }
    
    var isManualCachingOnWWANEnabled: Bool {
        get { return synchronizedResult { return self.storage.bool(forKey: Keys.isManualCachingOnWWANEnabled) }}
        set { synchronized {
            self.storage.set(newValue, forKey: Keys.isManualCachingOnWWANEnabled) }
            if AppDelegate.si.networkStatus.isReachableWWAN {
                newValue ? CacheQueue.si.start() : CacheQueue.si.stop()
            }
        }
    }
    
    var cachingType: CachingType {
        get { return synchronizedResult { return CachingType(rawValue: self.storage.integer(forKey: Keys.cachingType)) ?? .minSpace }}
        set { synchronized { self.storage.set(newValue.rawValue, forKey: Keys.cachingType) }}
    }
    
    var maxCacheSize: Int64 {
        get { return synchronizedResult { return self.storage.object(forKey: Keys.maxCacheSize) as? Int64 ?? -1 }}
        set { synchronized {              self.storage.set(newValue, forKey: Keys.maxCacheSize) }}
    }
    
    var minFreeSpace: Int64 {
        get { return synchronizedResult { return self.storage.object(forKey: Keys.minFreeSpace) as? Int64 ?? -1 }}
        set { synchronized {              self.storage.set(newValue, forKey: Keys.minFreeSpace) }}
    }
    
    var isAutoDeleteCacheEnabled: Bool {
        get { return synchronizedResult { return self.storage.bool(forKey: Keys.isAutoDeleteCacheEnabled) }}
        set { synchronized {              self.storage.set(newValue, forKey: Keys.isAutoDeleteCacheEnabled) }}
    }
    
    var autoDeleteCacheType: Bool {
        get { return synchronizedResult { return self.storage.bool(forKey: Keys.autoDeleteCacheType) }}
        set { synchronized {              self.storage.set(newValue, forKey: Keys.autoDeleteCacheType) }}
    }
    
    var isScreenSleepEnabled: Bool {
        get { return synchronizedResult { return self.storage.bool(forKey: Keys.isScreenSleepEnabled) }}
        set { synchronized {              self.storage.set(newValue, forKey: Keys.isScreenSleepEnabled) }}
    }
    
    var isBasicAuthEnabled: Bool {
        get { return synchronizedResult { return self.storage.bool(forKey: Keys.isBasicAuthEnabled) }}
        set { synchronized {              self.storage.set(newValue, forKey: Keys.isBasicAuthEnabled) }}
    }
    
    var quickSkipNumberOfSeconds: Int {
        get { return synchronizedResult { return self.storage.integer(forKey: Keys.quickSkipNumberOfSeconds) }}
        set { synchronized {              self.storage.set(newValue, forKey: Keys.quickSkipNumberOfSeconds) }}
    }
    
    var isDisableUsageOver3G: Bool {
        get { return synchronizedResult { return self.storage.bool(forKey: Keys.isDisableUsageOver3G) }}
        set { synchronized {              self.storage.set(newValue, forKey: Keys.isDisableUsageOver3G) }}
    }
    
    // MARK: - State Saving -
    
    var seekTime: Double {
        get { return synchronizedResult { return self.storage.double(forKey: Keys.seekTime) }}
        set { synchronized {              self.storage.set(newValue, forKey: Keys.seekTime) }}
    }
    
    var byteOffset: Int64 {
        get { return synchronizedResult { return self.storage.object(forKey: Keys.byteOffset) as? Int64 ?? 0 }}
        set { synchronized {              self.storage.set(newValue, forKey: Keys.byteOffset) }}
    }
    
    var isEqualizerOn: Bool {
        get { return synchronizedResult { return self.storage.bool(forKey: Keys.isEqualizerOn) }}
        set { synchronized {              self.storage.set(newValue, forKey: Keys.isEqualizerOn) }}
    }
    
    var preampGain: Float {
        get { return synchronizedResult { return self.storage.float(forKey: Keys.preampGain) }}
        set { synchronized {              self.storage.set(newValue, forKey: Keys.preampGain) }}
    }
}
























