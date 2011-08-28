//
//  SavedSettings.m
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SavedSettings.h"
#import "NSString-md5.h"

@implementation SavedSettings

#pragma mark - 
#pragma mark Settings Setup

- (void)createInitialSettings
{
	[settings setBool:YES forKey:@"areSettingsSetup"];
	[settings setBool:NO forKey:@"manualOfflineModeSetting"];
	[settings setInteger:0 forKey:@"recoverSetting"];
	[settings setInteger:7 forKey:@"maxBitrateWifiSetting"];
	[settings setInteger:7 forKey:@"maxBitrate3GSetting"];
	[settings setBool:YES forKey:@"enableSongCachingSetting"];
	[settings setBool:YES forKey:@"enableNextSongCacheSetting"];
	[settings setInteger:0 forKey:@"cachingTypeSetting"];
	[settings setObject:[NSNumber numberWithUnsignedLongLong:1073741824] forKey:@"maxCacheSize"];
	[settings setObject:[NSNumber numberWithUnsignedLongLong:268435456] forKey:@"minFreeSpace"];
	[settings setBool:YES forKey:@"autoDeleteCacheSetting"];
	[settings setInteger:0 forKey:@"autoDeleteCacheTypeSetting"];
	[settings setInteger:3 forKey:@"cacheSongCellColorSetting"];
	[settings setBool:NO forKey:@"twitterEnabledSetting"];
	[settings setBool:YES forKey:@"lyricsEnabledSetting"];
	[settings setBool:NO forKey:@"enableSongsTabSetting"];
	[settings setBool:NO forKey:@"autoPlayerInfoSetting"];
	[settings setBool:NO forKey:@"autoReloadArtistsSetting"];
	[settings setFloat:0.5 forKey:@"scrobblePercentSetting"];
	[settings setBool:NO forKey:@"enableScrobblingSetting"];
	[settings setBool:NO forKey:@"disablePopupsSetting"];
	[settings setBool:NO forKey:@"lockRotationSetting"];
	[settings setBool:NO forKey:@"isJukeboxEnabled"];
	[settings setBool:YES forKey:@"isScreenSleepEnabled"];
	[settings setBool:YES forKey:@"isPopupsEnabled"];
	[settings setBool:NO forKey:@"checkUpdatesSetting"];
	[settings setBool:NO forKey:@"isUpdateCheckQuestionAsked"];
	[settings synchronize];
}

- (void)convertFromOldSettingsType
{
	[self createInitialSettings];
	
	// If the settings dictionary does not exist at all, create the defaults
	NSDictionary *settingsDictionary = [settings objectForKey:@"settingsDictionary"];
	if (settingsDictionary != nil)
	{
		NSArray *boolKeys = [NSArray arrayWithObjects:@"areSettingsSetup" , @"manualOfflineModeSetting" , @"enableSongCachingSetting" , @"enableNextSongCacheSetting", @"autoDeleteCacheSetting", @"twitterEnabledSetting", @"lyricsEnabledSetting", @"enableSongsTabSetting", @"autoPlayerInfoSetting", @"autoReloadArtistsSetting", @"enableScrobblingSetting", @"lockRotationSetting", @"checkUpdatesSetting", nil];
		NSArray *intKeys = [NSArray arrayWithObjects:@"recoverSetting", @"maxBitrateWifiSetting", @"maxBitrate3GSetting", @"cachingTypeSetting", @"autoDeleteCacheTypeSetting", @"cacheSongCellColorSetting", nil];
		NSArray *objKeys = [NSArray arrayWithObjects:@"maxCacheSize", @"minFreeSpace", nil];
		NSArray *floatKeys = [NSArray arrayWithObject:@"scrobblePercentSetting"];
		
		// Process BOOL keys
		for (NSString *key in boolKeys)
		{
			NSString *value = [settingsDictionary objectForKey:key];
			if (value)
			{
				[settings setBool:[value boolValue] forKey:key];
			}
		}
		
		// Process int keys
		for (NSString *key in intKeys)
		{
			NSNumber *value = [settingsDictionary objectForKey:key];
			if (value)
			{
				[settings setInteger:[value intValue] forKey:key];
			}
		}
		
		// Process Object keys (unsigned long long in NSNumber)
		for (NSString *key in objKeys)
		{
			NSNumber *value = [settingsDictionary objectForKey:key];
			if (value)
			{
				[settings setObject:value forKey:key];
			}
		}
		
		// Process float key
		for (NSString *key in floatKeys)
		{
			NSNumber *value = [settingsDictionary objectForKey:key];
			if (value)
			{
				[settings setFloat:[value floatValue] forKey:key];
			}
		}
		
		// Special Cases
		NSString *disableSleep = [settingsDictionary objectForKey:@"disableScreenSleepSetting"];
		if (disableSleep)
		{
			[settings setBool:![disableSleep boolValue] forKey:@"isScreenSleepEnabled"];
		}
		NSString *disablePopups = [settingsDictionary objectForKey:@"disablePopupsSetting"];
		if (disablePopups)
		{
			[settings setBool:![disablePopups boolValue] forKey:@"isPopupsEnabled"];
		}
		if ([settingsDictionary objectForKey:@"checkUpdatesSetting"] != nil)
		{
			[settings setBool:YES forKey:@"isUpdateCheckQuestionAsked"];
		}
		
		// Delete the old settings
		//[settings removeObjectForKey:@"settingsDictionary"];
		
		[settings synchronize];
	}
}

- (void)memCacheDefaults
{
	isJukeboxEnabled = [settings boolForKey:@"isJukeboxEnabled"];
	isScreenSleepEnabled = [settings boolForKey:@"isScreenSleepEnabled"];
	isPopupsEnabled = [settings boolForKey:@"isPopupsEnabled"];
	
	NSString *url = [settings stringForKey:@"url"];
	if (url)
	{
		urlString = [[NSString alloc] initWithString:url];
	}
	
	NSString *user = [settings stringForKey:@"username"];
	if (user)
	{
		username = [[NSString alloc] initWithString:user];
	}
	
	NSString *pass = [settings stringForKey:@"password"];
	if (pass)
	{
		password = [[NSString alloc] initWithString:pass];
	}
}

#pragma mark - 
#pragma mark Login Settings

- (NSString *)urlString
{
	return urlString;
}

- (void)setUrlString:(NSString *)url
{
	[urlString release];
	urlString = [[NSString alloc] initWithString:url];
	[settings setObject:url forKey:@"url"];
	[settings synchronize];
}

- (NSString *)username
{
	return username;
}

- (void)setUsername:(NSString *)user
{
	[username release];
	username = [[NSString alloc] initWithString:user];
	[settings setObject:user forKey:@"username"];
	[settings synchronize];
}

- (NSString *)password
{
	return password;
}

- (void)setPassword:(NSString *)pass
{
	[password release];
	password = [[NSString alloc] initWithString:pass];
	[settings setObject:pass forKey:@"password"];
	[settings synchronize];
}

#pragma mark - 
#pragma mark Document Folder Paths

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
#pragma mark Root Folders Settings

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

#pragma mark - 
#pragma mark Other Settings

- (BOOL)isForceOfflineMode
{
	return [settings boolForKey:@"manualOfflineModeSetting"];
}

- (void)setIsForceOfflineMode:(BOOL)isForceOfflineMode
{
	[settings setBool:isForceOfflineMode forKey:@"manualOfflineModeSetting"];
	[settings synchronize];
}

- (NSInteger)recoverSetting
{
	return [settings integerForKey:@"recoverSetting"];
}

- (void)setRecoverSetting:(NSInteger)recoverSetting
{
	[settings setInteger:recoverSetting forKey:@"recoverSetting"];
	[settings synchronize];
}

- (NSInteger)maxBitrateWifi
{
	return [settings integerForKey:@"maxBitrateWifiSetting"];
}

- (void)setMaxBitrateWifi:(NSInteger)maxBitrateWifi
{
	[settings setInteger:maxBitrateWifi forKey:@"maxBitrateWifiSetting"];
	[settings synchronize];
}

- (NSInteger)maxBitrate3G
{
	return [settings integerForKey:@"maxBitrate3GSetting"];
}

- (void)setMaxBitrate3G:(NSInteger)maxBitrate3G
{
	[settings setInteger:maxBitrate3G forKey:@"maxBitrate3GSetting"];
	[settings synchronize];
}

- (BOOL)isSongCachingEnabled
{
	return [settings boolForKey:@"enableSongCachingSetting"];
}

- (void)setIsSongCachingEnabled:(BOOL)isSongCachingEnabled
{
	[settings setBool:isSongCachingEnabled forKey:@"enableSongCachingSetting"];
	[settings synchronize];
}

- (BOOL)isNextSongCacheEnabled
{
	return [settings boolForKey:@"enableNextSongCacheSetting"];
}

- (void)setIsNextSongCacheEnabled:(BOOL)isNextSongCacheEnabled
{
	[settings setBool:isNextSongCacheEnabled forKey:@"enableNextSongCacheSetting"];
	[settings synchronize];
}

- (NSInteger)cachingType
{
	return [settings integerForKey:@"cachingTypeSetting"];
}

- (void)setCachingType:(NSInteger)cachingType
{
	[settings setInteger:cachingType forKey:@"cachingTypeSetting"];
	[settings synchronize];
}

- (unsigned long long)maxCacheSize
{
	return [[settings objectForKey:@"maxCacheSize"] unsignedLongLongValue];
}

- (void)setMaxCacheSize:(unsigned long long)maxCacheSize
{
	NSNumber *value = [NSNumber numberWithUnsignedLongLong:maxCacheSize];
	[settings setObject:value forKey:@"maxCacheSize"];
	[settings synchronize];
}

- (unsigned long long)minFreeSpace
{
	return [[settings objectForKey:@"minFreeSpace"] unsignedLongLongValue];
}

- (void)setMinFreeSpace:(unsigned long long)minFreeSpace
{
	NSNumber *value = [NSNumber numberWithUnsignedLongLong:minFreeSpace];
	[settings setObject:value forKey:@"minFreeSpace"];
	[settings synchronize];
}

- (BOOL)isAutoDeleteCacheEnabled
{
	return [settings boolForKey:@"autoDeleteCacheSetting"];
}

- (void)setIsAutoDeleteCacheEnabled:(BOOL)isAutoDeleteCacheEnabled
{
	[settings setBool:isAutoDeleteCacheEnabled forKey:@"autoDeleteCacheSetting"];
	[settings synchronize];
}

- (NSInteger)autoDeleteCacheType
{
	return [settings integerForKey:@"autoDeleteCacheTypeSetting"];
}

- (void)setAutoDeleteCacheType:(NSInteger)autoDeleteCacheType
{
	[settings setInteger:autoDeleteCacheType forKey:@"autoDeleteCacheTypeSetting"];
	[settings synchronize];
}

- (NSInteger)cachedSongCellColorType
{
	return [settings integerForKey:@"cacheSongCellColorSetting"];
}

- (void)setCachedSongCellColorType:(NSInteger)cachedSongCellColorType
{
	[settings setInteger:cachedSongCellColorType forKey:@"cacheSongCellColorSetting"];
	[settings synchronize];
}

- (BOOL)isTwitterEnabled
{
	return [settings boolForKey:@"twitterEnabledSetting"];
}

- (void)setIsTwitterEnabled:(BOOL)isTwitterEnabled
{
	[settings setBool:isTwitterEnabled forKey:@"twitterEnabledSetting"];
	[settings synchronize];
}

- (BOOL)isLyricsEnabled
{
	return [settings boolForKey:@"lyricsEnabledSetting"];
}

- (void)setIsLyricsEnabled:(BOOL)isLyricsEnabled
{
	[settings setBool:isLyricsEnabled forKey:@"lyricsEnabledSetting"];
	[settings synchronize];
}

- (BOOL)isSongsTabEnabled
{
	return [settings boolForKey:@"enableSongsTabSetting"];
}

- (void)setIsSongsTabEnabled:(BOOL)isSongsTabEnabled
{
	[settings setBool:isSongsTabEnabled forKey:@"enableSongsTabSetting"];
	[settings synchronize];
}

- (BOOL)isAutoShowSongInfoEnabled
{
	return [settings boolForKey:@"autoPlayerInfoSetting"];
}

- (void)setIsAutoShowSongInfoEnabled:(BOOL)isAutoShowSongInfoEnabled
{
	[settings setBool:isAutoShowSongInfoEnabled forKey:@"autoPlayerInfoSetting"];
	[settings synchronize];
}

- (BOOL)isAutoReloadArtistsEnabled
{
	return [settings boolForKey:@"autoReloadArtistsSetting"];
}

- (void)setIsAutoReloadArtistsEnabled:(BOOL)isAutoReloadArtistsEnabled
{
	[settings setBool:isAutoReloadArtistsEnabled forKey:@"autoReloadArtistsSetting"];
	[settings synchronize];
}

- (float)scrobblePercent
{
	return [settings floatForKey:@"scrobblePercentSetting"];
}

- (void)setScrobblePercent:(float)scrobblePercent
{
	[settings setFloat:scrobblePercent forKey:@"scrobblePercentSetting"];
	[settings synchronize];
}

- (BOOL)isScrobbleEnabled
{
	return [settings boolForKey:@"enableScrobblingSetting"];
}

- (void)setIsScrobbleEnabled:(BOOL)isScrobbleEnabled
{
	[settings setBool:isScrobbleEnabled forKey:@"enableScrobblingSetting"];
	[settings synchronize];
}

- (BOOL)isRotationLockEnabled
{
	return [settings boolForKey:@"lockRotationSetting"];
}

- (void)setIsRotationLockEnabled:(BOOL)isRotationLockEnabled
{
	[settings setBool:isRotationLockEnabled forKey:@"lockRotationSetting"];
	[settings synchronize];
}

- (BOOL)isJukeboxEnabled
{
	return isJukeboxEnabled;
}

- (void)setIsJukeboxEnabled:(BOOL)enabled
{
	isJukeboxEnabled = enabled;
	[settings setBool:enabled forKey:@"isJukeboxEnabled"];
	[settings synchronize];
}

- (BOOL)isScreenSleepEnabled
{
	return isScreenSleepEnabled;
}

- (void)setIsScreenSleepEnabled:(BOOL)enabled
{
	isScreenSleepEnabled = enabled;
	[settings setBool:enabled forKey:@"isScreenSleepEnabled"];
	[settings synchronize];
}

- (BOOL)isPopupsEnabled
{
	return isPopupsEnabled;
}

- (void)setIsPopupsEnabled:(BOOL)enabled
{
	isPopupsEnabled = enabled;
	[settings setBool:enabled forKey:@"isPopupsEnabled"];
	[settings synchronize];
}

- (BOOL)isUpdateCheckEnabled
{
	return [settings boolForKey:@"checkUpdatesSetting"];
}

- (void)setIsUpdateCheckEnabled:(BOOL)isUpdateCheckEnabled
{
	[settings setBool:isUpdateCheckEnabled forKey:@"checkUpdatesSetting"];
	[settings synchronize];
}

- (BOOL)isUpdateCheckQuestionAsked
{
	return [settings boolForKey:@"isUpdateCheckQuestionAsked"];
}

- (void)setIsUpdateCheckQuestionAsked:(BOOL)isUpdateCheckQuestionAsked
{
	[settings setBool:isUpdateCheckQuestionAsked forKey:@"isUpdateCheckQuestionAsked"];
	[settings synchronize];
}

- (BOOL)isNewSearchAPI
{
	NSString *key = [NSString stringWithFormat:@"isNewSearchAPI%@", [urlString md5]];
	return [settings boolForKey:key];
}

- (void)setIsNewSearchAPI:(BOOL)isNewSearchAPI
{
	NSString *key = [NSString stringWithFormat:@"isNewSearchAPI%@", [urlString md5]];
	[settings setBool:isNewSearchAPI forKey:key];
	[settings synchronize];
}

// Test server details
#define DEFAULT_URL @"http://isubapp.com:9000"
#define DEFAULT_USER_NAME @"isub-guest"
#define DEFAULT_PASSWORD @"1sub1snumb3r0n3"

- (BOOL)isTestServer
{
	return [urlString isEqualToString:DEFAULT_URL];
}


#pragma mark - Singleton methods

static SavedSettings *sharedInstance = nil;

- (void)setup
{
	settings = [[NSUserDefaults standardUserDefaults] retain];
	urlString = [[NSString alloc] initWithString:DEFAULT_URL];
	username = [[NSString alloc] initWithString:DEFAULT_USER_NAME];
	password = [[NSString alloc] initWithString:DEFAULT_PASSWORD];
	
	// If the settings are not set up, convert them
	if (![settings boolForKey:@"areSettingsSetup"])
	{
		[self convertFromOldSettingsType];
	}
	
	// Cache certain settings to memory for speed
	[self memCacheDefaults];
}

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
		sharedInstance = self;
		[self setup];
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
