//
//  CacheSingleton.m
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "CacheSingleton.h"
#import "SavedSettings.h"
#import "iSubAppDelegate.h"

static CacheSingleton *sharedInstance = nil;

@implementation CacheSingleton

@synthesize cacheCheckInterval, cacheSize, freeSpace;

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

- (void) removeOldestCachedSongs
{
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	unsigned long long int freeSpace = [[[[NSFileManager defaultManager] attributesOfFileSystemForPath:audioFolderPath error:NULL] objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
	unsigned long long int minFreeSpace = [[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] unsignedLongLongValue];
	unsigned long long int maxCacheSize = [[appDelegate.settingsDictionary objectForKey:@"maxCacheSize"] unsignedLongLongValue];
	NSString *songMD5;
	int songSize;
	
	if ([[appDelegate.settingsDictionary objectForKey:@"cachingTypeSetting"] intValue] == 0)
	{
		// Remove the oldest songs based on either oldest played or oldest cached until free space is more than minFreeSpace
		while (freeSpace < minFreeSpace)
		{
			if ([[appDelegate.settingsDictionary objectForKey:@"autoDeleteCacheTypeSetting"] intValue] == 0)
				songMD5 = [databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY playedDate ASC LIMIT 1"];
			else
				songMD5 = [databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY chachedDate ASC LIMIT 1"];
			//DLog(@"removing %@", songMD5);
			[databaseControls removeSongFromCacheDb:songMD5];
			
			freeSpace = [[[[NSFileManager defaultManager] attributesOfFileSystemForPath:audioFolderPath error:NULL] objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
		}
	}
	else if ([[appDelegate.settingsDictionary objectForKey:@"cachingTypeSetting"] intValue] == 1)
	{
		// Remove the oldest songs based on either oldest played or oldest cached until cache size is less than maxCacheSize
		unsigned long long cacheSize = 0;
		for (NSString *path in [[NSFileManager defaultManager] subpathsAtPath:documentsPath]) 
		{
			cacheSize += [[[NSFileManager defaultManager] attributesOfItemAtPath:[documentsPath stringByAppendingPathComponent:path] error:NULL] fileSize];
		}
		
		while (cacheSize > maxCacheSize)
		{
			if ([[appDelegate.settingsDictionary objectForKey:@"autoDeleteCacheTypeSetting"] intValue] == 0)
			{
				songMD5 = [databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY playedDate ASC LIMIT 1"];
			}
			else
			{
				songMD5 = [databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY chachedDate ASC LIMIT 1"];
			}
			songSize = [databaseControls.songCacheDb intForQuery:@"SELECT size FROM cachedSongs WHERE md5 = ?", songMD5];
			DLog(@"removing %@", songMD5);
			[databaseControls removeSongFromCacheDb:songMD5];
			
			DLog(@"cacheSize: %i", cacheSize);
			cacheSize = cacheSize - songSize;
			DLog(@"new cacheSize: %i", cacheSize);
			DLog(@"maxCacheSize: %i", maxCacheSize);
			
			// Sleep the thread so the repeated cacheSize calls don't kill performance
			[NSThread sleepForTimeInterval:5];
		}
	}
	
	[autoreleasePool release];
}

- (void) checkCache
{
	unsigned long long size = 0;
	NSString *cachePath = [[SavedSettings sharedInstance] cachePath];
	for (NSString *path in [[NSFileManager defaultManager] subpathsAtPath:cachePath]) 
	{
		size += [[[NSFileManager defaultManager] attributesOfItemAtPath:[cachePath stringByAppendingPathComponent:path] 
																  error:NULL] fileSize];
	}
	cacheSize = size;
	
	freeSpace = [[[[NSFileManager defaultManager] attributesOfFileSystemForPath:cachePath error:NULL] 
												  objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
	
	iSubAppDelegate *appDelegate = [iSubAppDelegate sharedInstance];
	unsigned long long int minFreeSpace = [[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] unsignedLongLongValue];
	unsigned long long int maxCacheSize = [[appDelegate.settingsDictionary objectForKey:@"maxCacheSize"] unsignedLongLongValue];
	DLog(@"cacheSize: %qu", cacheSize);
	DLog(@"freeSpace: %qu", freeSpace);
	DLog(@"minFreeSpace: %qu", minFreeSpace);
	DLog(@"maxCacheSize: %qu", maxCacheSize);
	
	if ([[appDelegate.settingsDictionary objectForKey:@"cachingTypeSetting"] intValue] == 0 &&
		[[appDelegate.settingsDictionary objectForKey:@"enableSongCachingSetting"] isEqualToString:@"YES"])
	{
		// User has chosen to limit cache by minimum free space
		
		// Check to see if the free space left is lower than the setting
		if (freeSpace < minFreeSpace)
		{
			// Check to see if the cache size + free space is still less than minFreeSpace
			if (cacheSize + freeSpace < minFreeSpace)
			{
				// Looks like even removing all of the cache will not be enough so turn off caching
				[appDelegate.settingsDictionary setObject:@"NO" forKey:@"enableSongCachingSetting"];
				
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"IMPORTANT" message:@"Free space is running low, but even deleting the entire cache will not bring the free space up higher than your minimum setting. Automatic song caching has been turned off.\n\nYou can re-enable it in the Settings menu (tap the gear, tap Settings at the top)" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
				[alert show];
				[alert release];
			}
			else
			{
				// Remove the oldest cached songs until freeSpace > minFreeSpace or pop the free space low alert
				if ([[appDelegate.settingsDictionary objectForKey:@"autoDeleteCacheSetting"] isEqualToString:@"YES"])
				{
					[self performSelectorInBackground:@selector(removeOldestCachedSongs) withObject:nil];
				}
				else
				{
					UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Notice" message:@"Free space is running low. Delete some cached songs or lower the minimum free space setting." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
					[alert show];
					[alert release];
				}
			}
		}
	}
	else if ([[appDelegate.settingsDictionary objectForKey:@"cachingTypeSetting"] intValue] == 1 &&
			 [[appDelegate.settingsDictionary objectForKey:@"enableSongCachingSetting"] isEqualToString:@"YES"])
	{
		// User has chosen to limit cache by maximum size
		
		// Check to see if the cache size is higher than the max
		if (cacheSize > maxCacheSize)
		{
			if ([[appDelegate.settingsDictionary objectForKey:@"autoDeleteCacheSetting"] isEqualToString:@"YES"])
			{
				[self performSelectorInBackground:@selector(removeOldestCachedSongs) withObject:nil];
			}
			else
			{
				[appDelegate.settingsDictionary setObject:@"NO" forKey:@"enableSongCachingSetting"];
				
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Notice" message:@"The song cache is full. Automatic song caching has been disabled.\n\nYou can re-enable it in the Settings menu (tap the gear, tap Settings at the top)" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
				[alert show];
				[alert release];
			}			
		}
	}
}

#pragma mark - Singleton methods
			
- (void)setup
{
	cacheCheckInterval = 120.0;
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
