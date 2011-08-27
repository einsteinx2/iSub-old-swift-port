//
//  CacheDAO.m
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "CacheDAO.h"

@implementation CacheDAO

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void) checkCache
{
	unsigned long long cacheSize = 0;
	for (NSString *path in [[NSFileManager defaultManager] subpathsAtPath:documentsPath]) 
	{
		cacheSize += [[[NSFileManager defaultManager] attributesOfItemAtPath:[documentsPath stringByAppendingPathComponent:path] error:NULL] fileSize];
	}
	unsigned long long int freeSpace = [[[[NSFileManager defaultManager] attributesOfFileSystemForPath:audioFolderPath error:NULL] objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
	unsigned long long int minFreeSpace = [[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] unsignedLongLongValue];
	unsigned long long int maxCacheSize = [[appDelegate.settingsDictionary objectForKey:@"maxCacheSize"] unsignedLongLongValue];
	//DLog(@"cacheSize: %qu", cacheSize);
	//DLog(@"freeSpace: %qu", freeSpace);
	//DLog(@"minFreeSpace: %qu", minFreeSpace);
	//DLog(@"maxCacheSize: %qu", maxCacheSize);
	
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

@end
