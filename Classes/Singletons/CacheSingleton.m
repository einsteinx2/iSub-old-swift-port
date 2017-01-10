//
//  CacheSingleton.m
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "CacheSingleton.h"
#import "iSub-Swift.h"
#import "ISMSStreamManager.h"
#import "Imports.h"

LOG_LEVEL_ISUB_DEFAULT

@implementation CacheSingleton

- (unsigned long long)totalSpace
{
	NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[CacheSingleton songCachePath] error:NULL];
    return [attributes[NSFileSystemSize] unsignedLongLongValue];
}

- (unsigned long long)freeSpace
{
	NSString *path = [SavedSettings documentsPath];
	NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:path error:NULL];
	return [attributes[NSFileSystemFreeSize] unsignedLongLongValue];
}

- (void)startCacheCheckTimerWithInterval:(NSTimeInterval)interval
{
	self.cacheCheckInterval = interval;
	[self stopCacheCheckTimer];
	
	[self checkCache];
}

- (void)stopCacheCheckTimer
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkCache) object:nil];
}

- (NSInteger)numberOfCachedSongs
{
    NSString *query = @"SELECT COUNT(*) FROM cachedSongsMetadata WHERE fullyCached = 1";
    return [DatabaseSingleton.si.songModelReadDbPool intForQuery:query];
    
    //return [[ISMSPlaylist downloadedSongs] songCount];
}

//
// If the available space has dropped below the max cache size since last app load, adjust it.
//
- (void)adjustCacheSize
{
	// Only adjust if the user is using max cache size as option
	if (SavedSettings.si.cachingType == ISMSCachingType_maxSize)
	{
		unsigned long long possibleSize = self.freeSpace + self.cacheSize;
		unsigned long long maxCacheSize = SavedSettings.si.maxCacheSize;
		
		NSLog(@"adjustCacheSize:  possibleSize = %llu  maxCacheSize = %llu", possibleSize, maxCacheSize);
		
		if (possibleSize < maxCacheSize)
		{
			// Set the max cache size to 25MB less than the free space
			SavedSettings.si.maxCacheSize = possibleSize - BytesFromMiB(25);
		}
	}
}

- (void)removeOldestCachedSongs
{
    // TODO rewrite this with new data model
	/*
    NSString *songMD5 = nil;
    if (SavedSettings.si.cachingType == ISMSCachingType_minSpace)
	{
		// Remove the oldest songs based on either oldest played or oldest cached until free space is more than minFreeSpace
		while (self.freeSpace < SavedSettings.si.minFreeSpace)
		{
			@autoreleasepool 
			{
				if (SavedSettings.si.autoDeleteCacheType == 0)
					songMD5 = [DatabaseSingleton.si.songCacheDbQueue stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY playedDate ASC LIMIT 1"];
				else
					songMD5 = [DatabaseSingleton.si.songCacheDbQueue stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY cachedDate ASC LIMIT 1"];
				//DLog(@"removing %@", songMD5);
				[ISMSSong removeSongFromCacheDbQueueByMD5:songMD5];	
			}
		}
	}
	else if (SavedSettings.si.cachingType == ISMSCachingType_maxSize)
	{
		// Remove the oldest songs based on either oldest played or oldest cached until cache size is less than maxCacheSize
		unsigned long long size = self.cacheSize;
		while (size > SavedSettings.si.maxCacheSize)
		{
			@autoreleasepool 
			{
				if (SavedSettings.si.autoDeleteCacheType == 0)
				{
					songMD5 = [DatabaseSingleton.si.songCacheDbQueue stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY playedDate ASC LIMIT 1"];
				}
				else
				{
					songMD5 = [DatabaseSingleton.si.songCacheDbQueue stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY cachedDate ASC LIMIT 1"];
				}
				//songSize = [DatabaseSingleton.si.songCacheDbQueue intForQuery:@"SELECT size FROM cachedSongs WHERE md5 = ?", songMD5];
				ISMSSong *aSong = [ISMSSong songFromCacheDbQueue:songMD5];
				// Determine the name of the file we are downloading.
				//DLog(@"currentSongObject.path: %@", currentSongObject.path);
                
				NSString *songPath = [[SavedSettings songCachePath] stringByAppendingPathComponent:aSong.path.md5];
				unsigned long long songSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:songPath error:NULL] fileSize];
				
				//DLog(@"removing %@", songMD5);
				[ISMSSong removeSongFromCacheDbQueueByMD5:songMD5];
				
				size -= songSize;
			}
		}
	}*/
	
	[self findCacheSize];
	
	if (!CacheQueueManager.si.isDownloading)
		[CacheQueueManager.si start];
}

- (void)findCacheSize
{
    // TODO: Rewrite this with new data model
    /*
    [DatabaseSingleton.si.songCacheDbQueue inDatabase:^(FMDatabase *db)
    {
        unsigned long long size = [[db stringForQuery:@"SELECT sum(size) FROM sizesSongs"] longLongValue];
        
        FMResultSet *result = [db executeQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'NO'"];
        
        while ([result next])
        {
            NSString *path = [[SavedSettings songCachePath] stringByAppendingPathComponent:[result stringForColumn:@"md5"]];
            NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
            size += [attr fileSize];
            DLog(@"Added %llu to size for partially downloaded song", [attr fileSize]);
        }
        
        DLog(@"Total cache size was found to be: %llu", size);
        _cacheSize = size;
        
    }];*/
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CacheSizeChecked];
}

- (void)checkCache
{
	[self findCacheSize];
	
	// Adjust the cache size if needed
	[self adjustCacheSize];
	
	if (SavedSettings.si.cachingType == ISMSCachingType_minSpace && SavedSettings.si.isSongCachingEnabled)
	{		
		// Check to see if the free space left is lower than the setting
		if (self.freeSpace < SavedSettings.si.minFreeSpace)
		{
			// Check to see if the cache size + free space is still less than minFreeSpace
			unsigned long long size = self.cacheSize;
			if (size + self.freeSpace < SavedSettings.si.minFreeSpace)
			{
				// Looks like even removing all of the cache will not be enough so turn off caching
				SavedSettings.si.isSongCachingEnabled = NO;
			}
			else
			{
				// Remove the oldest cached songs until freeSpace > minFreeSpace or pop the free space low alert
				if (SavedSettings.si.isAutoDeleteCacheEnabled)
				{
					[self removeOldestCachedSongs];
				}
			}
		}
	}
	else if (SavedSettings.si.cachingType == ISMSCachingType_maxSize && SavedSettings.si.isSongCachingEnabled)
	{		
		// Check to see if the cache size is higher than the max
		if (self.cacheSize > SavedSettings.si.maxCacheSize)
		{
			if (SavedSettings.si.isAutoDeleteCacheEnabled)
			{
				[self removeOldestCachedSongs];
			}
			else
			{
				SavedSettings.si.isSongCachingEnabled = NO;
			}			
		}
	}
	
	[self stopCacheCheckTimer];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkCache) object:nil];
	[self performSelector:@selector(checkCache) withObject:nil afterDelay:self.cacheCheckInterval];
}

- (void)clearTempCache
{
	// Clear the temp cache directory
	[[NSFileManager defaultManager] removeItemAtPath:[CacheSingleton tempCachePath] error:NULL];
	[[NSFileManager defaultManager] createDirectoryAtPath:[CacheSingleton tempCachePath] withIntermediateDirectories:YES attributes:nil error:NULL];
	ISMSStreamManager.si.lastTempCachedSong = nil;
}

- (void)setAllCachedSongsToBackup
{
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    
    // Now set all of the files to be backed up
    NSArray *cachedSongNames = [defaultManager contentsOfDirectoryAtPath:[CacheSingleton songCachePath] error:nil];
    for (NSString *songName in cachedSongNames)
    {
        NSURL *fileUrl = [NSURL fileURLWithPath:[[CacheSingleton songCachePath] stringByAppendingPathComponent:songName]];
        [fileUrl removeSkipBackupAttribute];
    }
}

- (void)setAllCachedSongsToNotBackup
{
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    
    // Now set all of the files to be backed up
    NSArray *cachedSongNames = [defaultManager contentsOfDirectoryAtPath:[CacheSingleton songCachePath] error:nil];
    for (NSString *songName in cachedSongNames)
    {
        NSURL *fileUrl = [NSURL fileURLWithPath:[[CacheSingleton songCachePath] stringByAppendingPathComponent:songName]];
        
        [fileUrl addSkipBackupAttribute];
    }
}

#pragma mark - Singleton methods
			
- (void)setup
{
	NSFileManager *defaultManager = [NSFileManager defaultManager];
        
	// Make sure songCache directory exists, if not create it
	if (![defaultManager fileExistsAtPath:[CacheSingleton songCachePath]])
	{
        // First check to see if it's in the old Library/Caches location
        NSString *oldPath = [[SavedSettings cachesPath] stringByAppendingPathComponent:@"songCache"];
        if ([defaultManager fileExistsAtPath:oldPath])
        {
            // It exists there, so move it to the new location
            NSError *error;
            [defaultManager moveItemAtPath:oldPath toPath:[CacheSingleton songCachePath] error:&error];
            
            if (error)
            {
                DDLogError(@"Error moving cache path from %@ to %@", oldPath, [CacheSingleton songCachePath]);
            }
            else
            {
                DDLogInfo(@"Moved cache path from %@ to %@", oldPath, [CacheSingleton songCachePath]);
                
#ifdef IOS
                // Now set all of the files to not be backed up
                if (!SavedSettings.si.isBackupCacheEnabled)
                {
                    NSArray *cachedSongNames = [defaultManager contentsOfDirectoryAtPath:[CacheSingleton songCachePath] error:nil];
                    for (NSString *songName in cachedSongNames)
                    {
                        NSURL *fileUrl = [NSURL fileURLWithPath:[[CacheSingleton songCachePath] stringByAppendingPathComponent:songName]];
                        [fileUrl addSkipBackupAttribute];
                    }
                }
#endif
            }
        }
        else
        {
            // It doesn't exist in the old location, so just create it in the new one
            [defaultManager createDirectoryAtPath:[CacheSingleton songCachePath] withIntermediateDirectories:YES attributes:nil error:NULL];
        }
	}
    
    // Rename any cache files that still have extensions
    NSDirectoryEnumerator *direnum = [[NSFileManager defaultManager] enumeratorAtPath:[CacheSingleton songCachePath]];
    NSString *filename;
    while ((filename = [direnum nextObject]))
    {
        // Check if it contains an extension
        NSRange range = [filename rangeOfString:@"."];
        if (range.location != NSNotFound)
        {
            NSString *filenameNew = [[filename componentsSeparatedByString:@"."] firstObjectSafe];
            DDLogVerbose(@"[CacheSingleton] Moving filename: %@ to new filename: %@", filename, filenameNew);
            if (filenameNew)
            {
                NSString *fromPath = [[CacheSingleton songCachePath] stringByAppendingPathComponent:filename];
                NSString *toPath = [[CacheSingleton songCachePath] stringByAppendingPathComponent:filenameNew];
                NSError *error;
                
                if (![[NSFileManager defaultManager] moveItemAtPath:fromPath toPath:toPath error:&error])
                {
                    DDLogVerbose(@"[CacheSingleton] ERROR Moving filename: %@ to new filename: %@", filename, filenameNew);
                }
            }
        }
    }
    
    // Clear the temp cache
    [self clearTempCache];

	// Setup the cache check interval
	_cacheCheckInterval = 60.0;
	
	// Do the first check sooner
	[self performSelector:@selector(checkCache) withObject:nil afterDelay:0.05];
	
#ifdef IOS
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
}

+ (NSString *)songCachePath
{
    return [[SavedSettings documentsPath] stringByAppendingPathComponent:@"songCache"];
}

+ (NSString *)tempCachePath
{
    return [[SavedSettings documentsPath] stringByAppendingPathComponent:@"tempCache"];
}

+ (instancetype)si
{
    static CacheSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
	});
    return sharedInstance;
}

@end
