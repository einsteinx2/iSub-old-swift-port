//
//  SavedSettings.m
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SavedSettings.h"


@implementation SavedSettings

@synthesize settings, urlString, username, password;
//@synthesize cacheType, minFreeSpace, maxCacheSize, enableCache, autoDeleteCache;

- (NSDate *)rootFoldersReloadTime
{
	return [settings objectForKey:[NSString stringWithFormat:@"%@rootFoldersReloadTime", urlString]];
}

- (void)setRootFoldersReloadTime:(NSDate *)reloadTime
{
	[settings setObject:reloadTime forKey:[NSString stringWithFormat:@"%@rootFoldersReloadTime", urlString]];
	[settings synchronize];
}

- (NSNumber *)rootFoldersSelectedFolderId
{
	return [settings objectForKey:[NSString stringWithFormat:@"%@rootFoldersSelectedFolder", urlString]];
}

- (void)setRootFoldersSelectedFolderId:(NSNumber *)folderId
{
	[settings setObject:folderId forKey:[NSString stringWithFormat:@"%@rootFoldersSelectedFolder", urlString]];
	[settings synchronize];
}

- (NSString *)documentsPath
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	return [paths objectAtIndex: 0];
}

- (NSString *)databasePath
{
	return [self.documentsPath stringByAppendingPathComponent:@"database"];
}

- (NSString *)cachePath
{
	return [self.documentsPath stringByAppendingPathComponent:@"songCache"];
}

- (NSString *)tempCachePath
{
	return [self.documentsPath stringByAppendingPathComponent:@"tempCache"];
}

#pragma mark -
#pragma mark Singleton methods

static SavedSettings *sharedInstance = nil;

+ (SavedSettings *)sharedInstance
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
            return sharedInstance;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

-(id)init 
{
	if ((self = [super init]))
	{
		sharedInstance = self;
		self.settings = [NSUserDefaults standardUserDefaults];
	}
	
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain 
{
    return self;
}

- (unsigned)retainCount 
{
    return UINT_MAX;  // denotes an object that cannot be released
}

- (oneway void)release 
{
    //do nothing
}

- (id)autorelease 
{
    return self;
}

@end
