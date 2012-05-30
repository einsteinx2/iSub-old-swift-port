//
//  CacheSingleton.m
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "CacheSingleton.h"
#import "SavedSettings.h"
#import "DatabaseSingleton.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueueAdditions.h"

#import "Song.h"
#import "ISMSStreamManager.h"
#import "NSNotificationCenter+MainThread.h"
#import "ISMSCacheQueueManager.h"

@implementation CacheSingleton

@synthesize cacheCheckInterval, cacheSize;//, cacheCheckTimer;

- (unsigned long long)totalSpace
{
	NSString *path = settingsS.cachesPath;
	NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:path error:NULL];
	return [[attributes objectForKey:NSFileSystemSize] unsignedLongLongValue];
}

- (unsigned long long)freeSpace
{
	NSString *path = settingsS.cachesPath;
	NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:path error:NULL];
	return [[attributes objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
}

- (void)startCacheCheckTimerWithInterval:(NSTimeInterval)interval
{
	cacheCheckInterval = interval;
	[self stopCacheCheckTimer];
	
	[self checkCache];
}

- (void)stopCacheCheckTimer
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkCache) object:nil];
}

- (NSUInteger)numberOfCachedSongs
{
	return [databaseS.songCacheDbQueue intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE finished = 'YES'"];
}

//
// If the available space has dropped below the max cache size since last app load, adjust it.
//
- (void)adjustCacheSize
{
	// Only adjust if the user is using max cache size as option
	if (settingsS.cachingType == ISMSCachingType_maxSize)
	{
		unsigned long long possibleSize = self.freeSpace + self.cacheSize;
		unsigned long long maxCacheSize = settingsS.maxCacheSize;
		
		NSLog(@"adjustCacheSize:  possibleSize = %llu  maxCacheSize = %llu", possibleSize, maxCacheSize);
		
		if (possibleSize < maxCacheSize)
		{
			// Set the max cache size to 25MB less than the free space
			settingsS.maxCacheSize = possibleSize - BytesToMB(25);
		}
	}
}

- (void)removeOldestCachedSongs
{		
	NSString *songMD5 = nil;
	
	if (settingsS.cachingType == ISMSCachingType_minSpace)
	{
		// Remove the oldest songs based on either oldest played or oldest cached until free space is more than minFreeSpace
		while (self.freeSpace < settingsS.minFreeSpace)
		{
			@autoreleasepool 
			{
				if (settingsS.autoDeleteCacheType == 0)
					songMD5 = [databaseS.songCacheDbQueue stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY playedDate ASC LIMIT 1"];
				else
					songMD5 = [databaseS.songCacheDbQueue stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY cachedDate ASC LIMIT 1"];
				//DLog(@"removing %@", songMD5);
				[Song removeSongFromCacheDbQueueByMD5:songMD5];	
			}
		}
	}
	else if (settingsS.cachingType == ISMSCachingType_maxSize)
	{
		// Remove the oldest songs based on either oldest played or oldest cached until cache size is less than maxCacheSize
		unsigned long long size = self.cacheSize;
		while (size > settingsS.maxCacheSize)
		{
			@autoreleasepool 
			{
				if (settingsS.autoDeleteCacheType == 0)
				{
					songMD5 = [databaseS.songCacheDbQueue stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY playedDate ASC LIMIT 1"];
				}
				else
				{
					songMD5 = [databaseS.songCacheDbQueue stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY cachedDate ASC LIMIT 1"];
				}
				//songSize = [databaseS.songCacheDbQueue intForQuery:@"SELECT size FROM cachedSongs WHERE md5 = ?", songMD5];
				Song *aSong = [Song songFromCacheDbQueue:songMD5];
				// Determine the name of the file we are downloading.
				//DLog(@"currentSongObject.path: %@", currentSongObject.path);
				NSString *songPath = nil;
				if (aSong.transcodedSuffix)
					songPath = [settingsS.songCachePath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", songMD5, aSong.transcodedSuffix]];
				else
					songPath = [settingsS.songCachePath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", songMD5, aSong.suffix]];
				
				unsigned long long songSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:songPath error:NULL] fileSize];
				
				//DLog(@"removing %@", songMD5);
				[Song removeSongFromCacheDbQueueByMD5:songMD5];
				
				size -= songSize;
			}
		}
	}
	
	[self findCacheSize];
	
	if (!cacheQueueManagerS.isQueueDownloading)
		[cacheQueueManagerS startDownloadQueue];
}

- (void)findCacheSize
{
	unsigned long long size = 0;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *subpaths = [fileManager subpathsAtPath:settingsS.songCachePath];
	for (NSString *path in subpaths) 
	{
		NSString *fullPath = [settingsS.songCachePath stringByAppendingPathComponent:path];
		NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:NULL];
		size += [attributes fileSize];
	}
	
	cacheSize = size;
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CacheSizeChecked];
}

- (void)checkCache
{
	[self findCacheSize];
	
	// Adjust the cache size if needed
	[self adjustCacheSize];
	
	if (settingsS.cachingType == ISMSCachingType_minSpace && settingsS.isSongCachingEnabled)
	{		
		// Check to see if the free space left is lower than the setting
		if (self.freeSpace < settingsS.minFreeSpace)
		{
			// Check to see if the cache size + free space is still less than minFreeSpace
			unsigned long long size = self.cacheSize;
			if (size + self.freeSpace < settingsS.minFreeSpace)
			{
				// Looks like even removing all of the cache will not be enough so turn off caching
				settingsS.isSongCachingEnabled = NO;
				
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"IMPORTANT" message:@"Free space is running low, but even deleting the entire cache will not bring the free space up higher than your minimum setting. Automatic song caching has been turned off.\n\nYou can re-enable it in the Settings menu (tap the gear, tap Settings at the top)" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
				[alert show];
			}
			else
			{
				// Remove the oldest cached songs until freeSpace > minFreeSpace or pop the free space low alert
				if (settingsS.isAutoDeleteCacheEnabled)
				{
					[self removeOldestCachedSongs];
				}
				else
				{
					UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Notice" message:@"Free space is running low. Delete some cached songs or lower the minimum free space setting." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
					alert.tag = 4;
					[alert show];
				}
			}
		}
	}
	else if (settingsS.cachingType == ISMSCachingType_maxSize && settingsS.isSongCachingEnabled)
	{		
		// Check to see if the cache size is higher than the max
		if (self.cacheSize > settingsS.maxCacheSize)
		{
			if (settingsS.isAutoDeleteCacheEnabled)
			{
				[self removeOldestCachedSongs];
			}
			else
			{
				settingsS.isSongCachingEnabled = NO;
				
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Notice" message:@"The song cache is full. Automatic song caching has been disabled.\n\nYou can re-enable it in the Settings menu (tap the gear, tap Settings at the top)" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
				alert.tag = 4;
				[alert show];
			}			
		}
	}
	
	[self stopCacheCheckTimer];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkCache) object:nil];
	[self performSelector:@selector(checkCache) withObject:nil afterDelay:cacheCheckInterval];
}

- (void)clearTempCache
{
	// Clear the temp cache directory
	[[NSFileManager defaultManager] removeItemAtPath:settingsS.tempCachePath error:NULL];
	[[NSFileManager defaultManager] createDirectoryAtPath:settingsS.tempCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
	streamManagerS.lastTempCachedSong = nil;
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
	DLog(@"received memory warning");
	
	
}

#pragma mark - Singleton methods
			
- (void)setup
{
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	
	// Move the cache path if necessary
	if ([defaultManager fileExistsAtPath:[settingsS.documentsPath stringByAppendingPathComponent:@"songCache"]]) 
	{
		// The song cache is in the old place, move it
		[defaultManager moveItemAtURL:[NSURL fileURLWithPath:[settingsS.documentsPath stringByAppendingPathComponent:@"songCache"]] 
								toURL:[NSURL fileURLWithPath:settingsS.songCachePath] error:nil];
	}
	// Make sure songCache directory exists, if not create it
	if (![[NSFileManager defaultManager] fileExistsAtPath:settingsS.songCachePath]) 
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:settingsS.songCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
	}
	// Clear the temp cache directory
	dispatch_async(dispatch_get_main_queue(), ^{
		[self clearTempCache];
	});

	// Setup the cache check interval
	cacheCheckInterval = 60.0;
	
	// Do the first check sooner
	[self performSelector:@selector(checkCache) withObject:nil afterDelay:11.0];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(didReceiveMemoryWarning) 
												 name:UIApplicationDidReceiveMemoryWarningNotification 
											   object:nil];
}

+ (id)sharedInstance
{
    static CacheSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
