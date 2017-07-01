//
//  SavedSettings.swift
//  iSub
//
//  Created by Benjamin Baron on 1/23/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class SavedSettings {
    struct Keys {
        // MARK: Settings
        
        static let currentServerId              = "currentServerId"
        static let currentServer                = "currentServer"
        static let redirectUrlString            = "redirectUrlString"
        
        static let isScreenSleepEnabled         = "isScreenSleepEnabled"
        static let isDisableUsageOver3G         = "isDisableUsageOver3G"
        
        static let quickSkipNumberOfSeconds     = "quickSkipNumberOfSeconds"
        
        static let maxBitRate3G                 = "maxBitrate3GSetting"
        static let maxBitRateWifi               = "maxBitrateWifiSetting"
        static let maxVideoBitRate3G            = "maxVideoBitrate3G"
        static let maxVideoBitRateWifi          = "maxVideoBitrateWifi"
        
        static let isManualCachingOnWWANEnabled = "isManualCachingOnWWANEnabled"
        static let isAutoSongCachingEnabled     = "isSongCachingEnabled"
        static let isNextSongCacheEnabled       = "enableNextSongCacheSetting"
        static let isBackupCacheEnabled         = "isBackupCacheEnabled"
        
        static let minFreeSpace                 = "minFreeSpace"
        static let maxCacheSize                 = "maxCacheSize"
        
        // MARK: Saved state
        
        static let rootArtistSortOrder          = "rootArtistSortOrder"
        static let rootAlbumSortOrder           = "rootAlbumSortOrder"
        
        static let seekTime                     = "seekTime"
        static let byteOffset                   = "byteOffset"
        static let isEqualizerOn                = "isEqualizerOn"
        static let preampGain                   = "gainMultiplier"
    }
    
    struct JGUserDefaults {
        static let disableScreenSleep = JGUserDefault(key: Keys.isScreenSleepEnabled, defaultValue: true)
        static let disableUsageCell = JGUserDefault(key: Keys.isDisableUsageOver3G, defaultValue: false)
        
        static let quickSkipLength = JGUserDefault(key: Keys.quickSkipNumberOfSeconds, defaultValue: 10)
        
        static let maxAudioBitrateCell = JGUserDefault(key: Keys.maxBitRate3G, defaultValue: 7)
        static let maxAudioBitrateWifi = JGUserDefault(key: Keys.maxBitRateWifi, defaultValue: 7)
        static let maxVideoBitrateCell = JGUserDefault(key: Keys.maxVideoBitRate3G, defaultValue: 3)
        static let maxVideoBitrateWifi = JGUserDefault(key: Keys.maxVideoBitRateWifi, defaultValue: 3)
        
        static let downloadUsingCell = JGUserDefault(key: Keys.isManualCachingOnWWANEnabled, defaultValue: false)
        static let autoSongCaching = JGUserDefault(key: Keys.isAutoSongCachingEnabled, defaultValue: true)
        static let preloadNextSong = JGUserDefault(key: Keys.isNextSongCacheEnabled, defaultValue: true)
        static let backupDownloads = JGUserDefault(key: Keys.isBackupCacheEnabled, defaultValue: false)
        static let minFreeSpace = JGUserDefault(key: Keys.minFreeSpace, defaultValue: 256 * 1024 * 1024)
        static let maxCacheSize = JGUserDefault(key: Keys.maxCacheSize, defaultValue: 1024 * 1024 * 1024)
    }
    
    static let si = SavedSettings()
    fileprivate let storage = UserDefaults.standard
    
    fileprivate let lock = SpinLock()

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
             Keys.maxCacheSize: 1024 * 1024 * 1024, // 1GB
             Keys.minFreeSpace: 256 * 1024 * 1024,  // 256MB
             Keys.isScreenSleepEnabled: true,
             Keys.maxVideoBitRateWifi: 3,
             Keys.maxVideoBitRate3G: 3,
             Keys.currentServerId: Server.testServerId,
             Keys.rootArtistSortOrder: ArtistSortOrder.name.rawValue,
             Keys.rootAlbumSortOrder: AlbumSortOrder.name.rawValue]
        
        storage.register(defaults: defaults)
    }
    
    var currentServerId: Int64 {
        get { return lock.synchronizedResult { return self.storage.object(forKey: Keys.currentServerId) as? Int64 ?? -1 }}
        set { lock.synchronized {              self.storage.set(newValue, forKey: Keys.currentServerId) }}
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
        get { return lock.synchronizedResult { return self.storage.string(forKey: Keys.redirectUrlString) }}
        set { lock.synchronized {              self.storage.set(newValue, forKey: Keys.redirectUrlString) }}
    }
    
    var isOfflineMode: Bool = false
    
    var maxBitRateWifi: Int {
        get { return lock.synchronizedResult { return self.storage.integer(forKey: Keys.maxBitRateWifi) }}
        set { lock.synchronized { self.storage.set(newValue, forKey: Keys.maxBitRateWifi) }}
    }
    
    var maxBitRate3G: Int {
        get { return lock.synchronizedResult { return self.storage.integer(forKey: Keys.maxBitRate3G) }}
        set { lock.synchronized { self.storage.set(newValue, forKey: Keys.maxBitRate3G) }}
    }
    
    var currentMaxBitRate: Int {
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
    
    var maxVideoBitRateWifi: Int {
        get { return lock.synchronizedResult { return self.storage.integer(forKey: Keys.maxVideoBitRateWifi) }}
        set { lock.synchronized { self.storage.set(newValue, forKey: Keys.maxVideoBitRateWifi) }}
    }
    
    var maxVideoBitRate3G: Int {
        get { return lock.synchronizedResult { return self.storage.integer(forKey: Keys.maxVideoBitRate3G) }}
        set { lock.synchronized { self.storage.set(newValue, forKey: Keys.maxVideoBitRate3G) }}
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
        get { return lock.synchronizedResult { return self.storage.bool(forKey: Keys.isAutoSongCachingEnabled) }}
        set { lock.synchronized {              self.storage.set(newValue, forKey: Keys.isAutoSongCachingEnabled) }}
    }
    
    var isNextSongCacheEnabled: Bool {
        get { return lock.synchronizedResult { return self.storage.bool(forKey: Keys.isNextSongCacheEnabled) }}
        set { lock.synchronized {              self.storage.set(newValue, forKey: Keys.isNextSongCacheEnabled) }}
    }
    
    var isBackupCacheEnabled: Bool {
        get { return lock.synchronizedResult { return self.storage.bool(forKey: Keys.isBackupCacheEnabled) }}
        set { lock.synchronized {
            self.storage.set(newValue, forKey: Keys.isBackupCacheEnabled) }
            CacheManager.si.backupSongCache = newValue
        }
    }
    
    var isManualCachingOnWWANEnabled: Bool {
        get { return lock.synchronizedResult { return self.storage.bool(forKey: Keys.isManualCachingOnWWANEnabled) }}
        set { lock.synchronized {
            self.storage.set(newValue, forKey: Keys.isManualCachingOnWWANEnabled) }
            if AppDelegate.si.networkStatus.isReachableWWAN {
                newValue ? CacheQueue.si.start() : CacheQueue.si.stop()
            }
        }
    }
    
    var maxCacheSize: Int64 {
        get { return lock.synchronizedResult { return self.storage.object(forKey: Keys.maxCacheSize) as? Int64 ?? -1 }}
        set { lock.synchronized {              self.storage.set(newValue, forKey: Keys.maxCacheSize) }}
    }
    
    var minFreeSpace: Int64 {
        get { return lock.synchronizedResult { return self.storage.object(forKey: Keys.minFreeSpace) as? Int64 ?? -1 }}
        set { lock.synchronized {              self.storage.set(newValue, forKey: Keys.minFreeSpace) }}
    }
    
    var isScreenSleepEnabled: Bool {
        get { return lock.synchronizedResult { return self.storage.bool(forKey: Keys.isScreenSleepEnabled) }}
        set { lock.synchronized {              self.storage.set(newValue, forKey: Keys.isScreenSleepEnabled) }}
    }
    
    var quickSkipNumberOfSeconds: Int {
        get { return lock.synchronizedResult { return self.storage.integer(forKey: Keys.quickSkipNumberOfSeconds) }}
        set { lock.synchronized {              self.storage.set(newValue, forKey: Keys.quickSkipNumberOfSeconds) }}
    }
    
    var isDisableUsageOver3G: Bool {
        get { return lock.synchronizedResult { return self.storage.bool(forKey: Keys.isDisableUsageOver3G) }}
        set { lock.synchronized {              self.storage.set(newValue, forKey: Keys.isDisableUsageOver3G) }}
    }
    
    var rootArtistSortOrder: ArtistSortOrder {
        get { return lock.synchronizedResult {
            let rawValue = self.storage.integer(forKey: Keys.rootArtistSortOrder)
            return ArtistSortOrder(rawValue: rawValue) ?? .name
            }
        }
        set { lock.synchronized { self.storage.set(newValue.rawValue, forKey: Keys.rootArtistSortOrder) }}
    }
    
    var rootAlbumSortOrder: AlbumSortOrder {
        get { return lock.synchronizedResult {
            let rawValue = self.storage.integer(forKey: Keys.rootAlbumSortOrder)
            return AlbumSortOrder(rawValue: rawValue) ?? .name
            }
        }
        set { lock.synchronized { self.storage.set(newValue.rawValue, forKey: Keys.rootAlbumSortOrder) }}
    }
    
    // MARK: - State Saving -
    
    var seekTime: Double {
        get { return lock.synchronizedResult { return self.storage.double(forKey: Keys.seekTime) }}
        set { lock.synchronized {              self.storage.set(newValue, forKey: Keys.seekTime) }}
    }
    
    var byteOffset: Int64 {
        get { return lock.synchronizedResult { return self.storage.object(forKey: Keys.byteOffset) as? Int64 ?? 0 }}
        set { lock.synchronized {              self.storage.set(newValue, forKey: Keys.byteOffset) }}
    }
    
    var isEqualizerOn: Bool {
        get { return lock.synchronizedResult { return self.storage.bool(forKey: Keys.isEqualizerOn) }}
        set { lock.synchronized {              self.storage.set(newValue, forKey: Keys.isEqualizerOn) }}
    }
    
    var preampGain: Float {
        get { return lock.synchronizedResult { return self.storage.float(forKey: Keys.preampGain) }}
        set { lock.synchronized {              self.storage.set(newValue, forKey: Keys.preampGain) }}
    }
}
