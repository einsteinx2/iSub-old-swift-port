//
//  CacheManager.swift
//  iSub
//
//  Created by Benjamin Baron on 1/23/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class CacheManager {
    static let si = CacheManager()
    
    let cacheCheckInterval = 60.0
    
    var totalSpace: Int64 {
        let attributes = try? FileManager.default.attributesOfFileSystem(forPath: songCachePath)
        return attributes?[.systemSize] as? Int64 ?? Int64.max
    }
    
    var freeSpace: Int64 {
        let attributes = try? FileManager.default.attributesOfFileSystem(forPath: songCachePath)
        return attributes?[.systemFreeSize] as? Int64 ?? Int64.max
    }
    
    var numberOfCachedSongs: Int {
        let query = "SELECT COUNT(*) FROM cachedSongsMetadata WHERE fullyCached = 1"
        return Database.si.read.intForQuery(query)
    }
    
    var backupSongCache: Bool = SavedSettings.si.isBackupCacheEnabled {
        didSet {
            if oldValue != backupSongCache {
                let fileManager = FileManager.default
                do {
                    let fileNames = try fileManager.contentsOfDirectory(atPath: songCachePath)
                    for fileName in fileNames {
                        var fileUrl = URL(fileURLWithPath: songCachePath + "/" + fileName)
                        fileUrl.isExcludedFromBackup = !backupSongCache
                    }
                } catch {
                    printError(error)
                }
            }
        }
    }
    
    func setup() {
        // Make sure songCache directory exists, if not create it
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: songCachePath) {
            do {
                try fileManager.createDirectory(atPath: songCachePath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                printError(error)
            }
        }
        
        // Clear the temp cache
        clearTempCache()
        
        // Do the first check sooner
        DispatchQueue.main.async {
            self.checkCache()
        }
    }
    
    func removeOldestCachedSongs() {
        // TODO: rewrite this with new data model
        
//        NSString *songMD5 = nil;
//        if (SavedSettings.si.cachingType == ISMSCachingType_minSpace)
//        {
//            // Remove the oldest songs based on either oldest played or oldest cached until free space is more than minFreeSpace
//            while (self.freeSpace < SavedSettings.si.minFreeSpace)
//            {
//                @autoreleasepool
//                {
//                    if (SavedSettings.si.autoDeleteCacheType == 0)
//                    songMD5 = [Database.si.songCacheDbQueue stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY playedDate ASC LIMIT 1"];
//                    else
//                    songMD5 = [Database.si.songCacheDbQueue stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY cachedDate ASC LIMIT 1"];
//                    //DLog(@"removing %@", songMD5);
//                    [Song removeSongFromCacheDbQueueByMD5:songMD5];
//                }
//            }
//        }
//        else if (SavedSettings.si.cachingType == ISMSCachingType_maxSize)
//        {
//            // Remove the oldest songs based on either oldest played or oldest cached until cache size is less than maxCacheSize
//            unsigned long long size = self.cacheSize;
//            while (size > SavedSettings.si.maxCacheSize)
//            {
//                @autoreleasepool
//                {
//                    if (SavedSettings.si.autoDeleteCacheType == 0)
//                    {
//                        songMD5 = [Database.si.songCacheDbQueue stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY playedDate ASC LIMIT 1"];
//                    }
//                    else
//                    {
//                        songMD5 = [Database.si.songCacheDbQueue stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY cachedDate ASC LIMIT 1"];
//                    }
//                    //songSize = [Database.si.songCacheDbQueue intForQuery:@"SELECT size FROM cachedSongs WHERE md5 = ?", songMD5];
//                    Song *aSong = [Song songFromCacheDbQueue:songMD5];
//                    // Determine the name of the file we are downloading.
//                    //DLog(@"currentSongObject.path: %@", currentSongObject.path);
//                    
//                    NSString *songPath = [[SavedSettings songCachePath] stringByAppendingPathComponent:aSong.path.md5];
//                    unsigned long long songSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:songPath error:NULL] fileSize];
//                    
//                    //DLog(@"removing %@", songMD5);
//                    [Song removeSongFromCacheDbQueueByMD5:songMD5];
//                    
//                    size -= songSize;
//                }
//            }
//        }
        
        findCacheSize()
        CacheQueue.si.start()
    }
    
    func findCacheSize() {
        // TODO: Rewrite this with new data model
        
//        [Database.si.songCacheDbQueue inDatabase:^(FMDatabase *db)
//            {
//            unsigned long long size = [[db stringForQuery:@"SELECT sum(size) FROM sizesSongs"] longLongValue];
//            
//            FMResultSet *result = [db executeQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'NO'"];
//            
//            while ([result next])
//            {
//            NSString *path = [[SavedSettings songCachePath] stringByAppendingPathComponent:[result stringForColumn:@"md5"]];
//            NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
//            size += [attr fileSize];
//            DLog(@"Added %llu to size for partially downloaded song", [attr fileSize]);
//            }
//            
//            DLog(@"Total cache size was found to be: %llu", size);
//            _cacheSize = size;
//            
//            }];
    
    //[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CacheSizeChecked];
    }

    
    func checkCache() {
        // TODO: rewrite this with new data model
        
//        [self findCacheSize];
//        
//        // Adjust the cache size if needed
//        [self adjustCacheSize];
//        
//        if (SavedSettings.si.cachingType == CachingTypeMinSpace && SavedSettings.si.isAutoSongCachingEnabled)
//        {
//            // Check to see if the free space left is lower than the setting
//            if (self.freeSpace < SavedSettings.si.minFreeSpace)
//            {
//                // Check to see if the cache size + free space is still less than minFreeSpace
//                unsigned long long size = self.cacheSize;
//                if (size + self.freeSpace < SavedSettings.si.minFreeSpace)
//                {
//                    // Looks like even removing all of the cache will not be enough so turn off caching
//                    SavedSettings.si.isAutoSongCachingEnabled = NO;
//                }
//                else
//                {
//                    // Remove the oldest cached songs until freeSpace > minFreeSpace or pop the free space low alert
//                    if (SavedSettings.si.isAutoDeleteCacheEnabled)
//                    {
//                        [self removeOldestCachedSongs];
//                    }
//                }
//            }
//        }
//        else if (SavedSettings.si.cachingType == CachingTypeMaxSize && SavedSettings.si.isAutoSongCachingEnabled)
//        {
//            // Check to see if the cache size is higher than the max
//            if (self.cacheSize > SavedSettings.si.maxCacheSize)
//            {
//                if (SavedSettings.si.isAutoDeleteCacheEnabled)
//                {
//                    [self removeOldestCachedSongs];
//                }
//                else
//                {
//                    SavedSettings.si.isAutoSongCachingEnabled = NO;
//                }			
//            }
//        }
//        
//        [self stopCacheCheckTimer];
//        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkCache) object:nil];
//        [self performSelector:@selector(checkCache) withObject:nil afterDelay:self.cacheCheckInterval];
    }
    
    func clearTempCache() {
        try? FileManager.default.removeItem(atPath: tempCachePath)
        
        do {
            try FileManager.default.createDirectory(atPath: tempCachePath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            printError(error)
        }
    }
}
