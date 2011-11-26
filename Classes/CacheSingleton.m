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
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "Song.h"

static CacheSingleton *sharedInstance = nil;

@implementation CacheSingleton

@synthesize cacheCheckInterval, cacheSize;

- (unsigned long long)freeSpace
{
	return [[[[NSFileManager defaultManager] attributesOfFileSystemForPath:[SavedSettings sharedInstance].cachePath error:NULL] objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
}

- (void)startCacheCheckTimer
{
	[self stopCacheCheckTimer];
	cacheCheckTimer = [NSTimer timerWithTimeInterval:cacheCheckInterval target:self 
											selector:@selector(checkCache) userInfo:nil repeats:YES];
}

- (void)startCacheCheckTimerWithInterval:(NSTimeInterval)interval
{
	cacheCheckInterval = interval;
	[self startCacheCheckTimer];
}

- (void)stopCacheCheckTimer
{
	[cacheCheckTimer invalidate];
	cacheCheckTimer = nil;
}

- (NSUInteger)numberOfCachedSongs
{
	DatabaseSingleton *databaseControls = [DatabaseSingleton sharedInstance];
	return [databaseControls.songCacheDb intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE finished = 'YES'"];
}

//
// If the available space has dropped below the max cache size since last app load, adjust it.
//
- (void) adjustCacheSize
{
	SavedSettings *settings = [SavedSettings sharedInstance];
	
	// Only adjust if the user is using max cache size as option
	//if ([[settingsDictionary objectForKey:@"cachingTypeSetting"] intValue] == 1)
	if (settings.cachingType == 1)
	{
		unsigned long long int freeSpace = [[[[NSFileManager defaultManager] attributesOfFileSystemForPath:settings.cachePath error:NULL] objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
		unsigned long long int maxCacheSize = settings.maxCacheSize;
		
		NSLog(@"adjustCacheSize:  freeSpace = %llu  maxCacheSize = %llu", freeSpace, maxCacheSize);
		
		if (freeSpace < maxCacheSize)
		{
			unsigned long long int newMaxCacheSize = freeSpace - 26214400; // Set the max cache size to 25MB less than the free space
			settings.maxCacheSize = newMaxCacheSize;
		}
	}
}

- (void)removeOldestCachedSongs
{
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	SavedSettings *settings = [SavedSettings sharedInstance];
	DatabaseSingleton *databaseControls = [DatabaseSingleton sharedInstance];
	
	NSString *songMD5 = nil;
	
	if (settings.cachingType == 0)
	{
		// Remove the oldest songs based on either oldest played or oldest cached until free space is more than minFreeSpace
		while (self.freeSpace < settings.minFreeSpace)
		{
			if (settings.autoDeleteCacheType == 0)
				songMD5 = [databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY playedDate ASC LIMIT 1"];
			else
				songMD5 = [databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY chachedDate ASC LIMIT 1"];
			//DLog(@"removing %@", songMD5);
			[Song removeSongFromCacheDbByMD5:songMD5];			
		}
	}
	else if (settings.cachingType == 1)
	{
		// Remove the oldest songs based on either oldest played or oldest cached until cache size is less than maxCacheSize
		unsigned long long size = self.cacheSize;
		while (size > settings.maxCacheSize)
		{
			if (settings.autoDeleteCacheType == 0)
			{
				songMD5 = [databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY playedDate ASC LIMIT 1"];
			}
			else
			{
				songMD5 = [databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY chachedDate ASC LIMIT 1"];
			}
			//songSize = [databaseControls.songCacheDb intForQuery:@"SELECT size FROM cachedSongs WHERE md5 = ?", songMD5];
			Song *aSong = [Song songFromCacheDb:songMD5];
			// Determine the name of the file we are downloading.
			//DLog(@"currentSongObject.path: %@", currentSongObject.path);
			NSString *songPath = nil;
			if (aSong.transcodedSuffix)
				songPath = [settings.cachePath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", songMD5, aSong.transcodedSuffix]];
			else
				songPath = [settings.cachePath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", songMD5, aSong.suffix]];
			
			unsigned long long songSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:songPath error:NULL] fileSize];
			
			[Song removeSongFromCacheDbByMD5:songMD5];
			
			size -= songSize;
			
			// Sleep the thread so the repeated cacheSize calls don't kill performance
			[NSThread sleepForTimeInterval:5];
		}
	}
	
	[autoreleasePool release];
}

- (void)findCacheSize
{
	//NSDate *startTime = [NSDate date];
	
	SavedSettings *settings = [SavedSettings sharedInstance];
		
	unsigned long long size = 0;
	for (NSString *path in [[NSFileManager defaultManager] subpathsAtPath:settings.cachePath]) 
	{
		size += [[[NSFileManager defaultManager] attributesOfItemAtPath:[settings.cachePath stringByAppendingPathComponent:path] error:NULL] fileSize];
	}
	
	cacheSize = size;
	
	//DLog(@"cache size: %i", cacheSize);
	//DLog(@"findCacheSize took %f", [[NSDate date] timeIntervalSinceDate:startTime]); 
}

- (void) checkCache
{
	[self findCacheSize];
	
	SavedSettings *settings = [SavedSettings sharedInstance];
	
	if (settings.cachingType == 0 && settings.isSongCachingEnabled)
	{
		// User has chosen to limit cache by minimum free space
		
		// Check to see if the free space left is lower than the setting
		if (self.freeSpace < settings.minFreeSpace)
		{
			// Check to see if the cache size + free space is still less than minFreeSpace
			unsigned long long size = self.cacheSize;
			if (size + self.freeSpace < settings.minFreeSpace)
			{
				// Looks like even removing all of the cache will not be enough so turn off caching
				settings.isSongCachingEnabled = NO;
				
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"IMPORTANT" message:@"Free space is running low, but even deleting the entire cache will not bring the free space up higher than your minimum setting. Automatic song caching has been turned off.\n\nYou can re-enable it in the Settings menu (tap the gear, tap Settings at the top)" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
				[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
				[alert release];
			}
			else
			{
				// Remove the oldest cached songs until freeSpace > minFreeSpace or pop the free space low alert
				if (settings.isAutoDeleteCacheEnabled)
				{
					[self performSelectorInBackground:@selector(removeOldestCachedSongs) withObject:nil];
				}
				else
				{
					UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Notice" message:@"Free space is running low. Delete some cached songs or lower the minimum free space setting." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
					alert.tag = 4;
					[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
					[alert release];
				}
			}
		}
	}
	else if (settings.cachingType == 1 && settings.isSongCachingEnabled)
	{
		// User has chosen to limit cache by maximum size
		
		// Check to see if the cache size is higher than the max
		if (self.cacheSize > settings.maxCacheSize)
		{
			if (settings.isAutoDeleteCacheEnabled)
			{
				[self performSelectorInBackground:@selector(removeOldestCachedSongs) withObject:nil];
			}
			else
			{
				settings.isSongCachingEnabled = NO;
				
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Notice" message:@"The song cache is full. Automatic song caching has been disabled.\n\nYou can re-enable it in the Settings menu (tap the gear, tap Settings at the top)" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
				alert.tag = 4;
				[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
				[alert release];
			}			
		}
	}
}

#pragma mark - Singleton methods
			
- (void)setup
{
	cacheCheckInterval = 120.0;
	
	[self adjustCacheSize];
	
	[self checkCache];
	[self startCacheCheckTimer];
}

+ (CacheSingleton *)sharedInstance
{
    @synchronized(self)
    {
        if (sharedInstance == nil)
			[[self alloc] init];
    }
    return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone 
{
    @synchronized(self) 
	{
        if (sharedInstance == nil) 
		{
            sharedInstance = [super allocWithZone:zone];
			[sharedInstance setup];
            return sharedInstance;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

-(id)init 
{
	if ((self = [super init]))
	{
		[self setup];
		sharedInstance = self;
	}

	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain {
    return self;
}

- (unsigned)retainCount {
    return UINT_MAX;  // denotes an object that cannot be released
}

- (oneway void)release {
    //do nothing
}

- (id)autorelease {
    return self;
}


@end
