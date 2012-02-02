//
//  SavedSettings.m
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SavedSettings.h"
#import "NSString+md5.h"
#import "MusicSingleton.h"
#import "Song.h"
#import "Server.h"
#import "MKStoreManager.h"
#import "PlaylistSingleton.h"
#import "AudioEngine.h"
#import "iSubAppDelegate.h"
#import "Reachability.h"

@implementation SavedSettings

@synthesize serverList, redirectUrlString;

- (NSString *)formatFileSize:(unsigned long long int)size
{
	if (size < 1024)
	{
		return [NSString stringWithFormat:@"%qu bytes", size];
	}
	else if (size >= 1024 && size < 1048576)
	{
		return [NSString stringWithFormat:@"%.02f KB", ((double)size / 1024)];
	}
	else if (size >= 1048576 && size < 1073741824)
	{
		return [NSString stringWithFormat:@"%.02f MB", ((double)size / 1024 / 1024)];
	}
	else if (size >= 1073741824)
	{
		return [NSString stringWithFormat:@"%.02f GB", ((double)size / 1024 / 1024 / 1024)];
	}
	
	return @"";
}

- (void)loadState
{
	PlaylistSingleton *currentPlaylistDAO = [PlaylistSingleton sharedInstance];
	AudioEngine *audio = [AudioEngine sharedInstance];
	
	if (self.isJukeboxEnabled)
		isPlaying = NO;
	else
		isPlaying = [userDefaults boolForKey:@"isPlaying"];
		
	isShuffle = [userDefaults boolForKey:@"isShuffle"];
	currentPlaylistDAO.isShuffle = isShuffle;
	
	normalPlaylistIndex = [userDefaults integerForKey:@"normalPlaylistIndex"];
	currentPlaylistDAO.normalIndex = normalPlaylistIndex;
	
	shufflePlaylistIndex = [userDefaults integerForKey:@"shufflePlaylistIndex"];
	currentPlaylistDAO.shuffleIndex = shufflePlaylistIndex;
	
	repeatMode = [userDefaults integerForKey:@"repeatMode"];
	currentPlaylistDAO.repeatMode = repeatMode;
	
	bitRate = [userDefaults integerForKey:@"bitRate"];
	byteOffset = self.byteOffset;
	secondsOffset = self.seekTime;
	isRecover = self.isRecover;
	recoverSetting = self.recoverSetting;
	
	audio.startByteOffset = byteOffset;
	audio.startSecondsOffset = secondsOffset;
	DLog(@"startByteOffset: %llu  startSecondsOffset: %f", byteOffset, secondsOffset);
}

- (void)setupSaveState
{	
	// Load saved state first
	[self loadState];
	
	// Start the timer
	[NSTimer scheduledTimerWithTimeInterval:3.3 target:self selector:@selector(saveState) userInfo:nil repeats:YES];
}

- (void)saveState
{
	@autoreleasepool
	{
		AudioEngine *audio = [AudioEngine sharedInstance];
		PlaylistSingleton *currentPlaylistDAO = [PlaylistSingleton sharedInstance];
		BOOL isDefaultsDirty = NO;
		
		if (audio.isPlaying != isPlaying)
		{
			if (self.isJukeboxEnabled)
				isPlaying = NO;
			else
				isPlaying = audio.isPlaying;
			
			[userDefaults setBool:isPlaying forKey:@"isPlaying"];
			isDefaultsDirty = YES;
		}
		
		if (currentPlaylistDAO.isShuffle != isShuffle)
		{
			isShuffle = currentPlaylistDAO.isShuffle;
			[userDefaults setBool:isShuffle forKey:@"isShuffle"];
			isDefaultsDirty = YES;
		}
		
		if (currentPlaylistDAO.normalIndex != normalPlaylistIndex)
		{
			normalPlaylistIndex = currentPlaylistDAO.normalIndex;
			[userDefaults setInteger:normalPlaylistIndex forKey:@"normalPlaylistIndex"];
			isDefaultsDirty = YES;
		}
		
		if (currentPlaylistDAO.shuffleIndex != shufflePlaylistIndex)
		{
			shufflePlaylistIndex = currentPlaylistDAO.shuffleIndex;
			[userDefaults setInteger:shufflePlaylistIndex forKey:@"shufflePlaylistIndex"];
			isDefaultsDirty = YES;
		}
		
		if (currentPlaylistDAO.repeatMode != repeatMode)
		{
			repeatMode = currentPlaylistDAO.repeatMode;
			[userDefaults setInteger:repeatMode forKey:@"repeatMode"];
			isDefaultsDirty = YES;
		}
		
		if (audio.bitRate != bitRate && audio.bitRate >= 0)
		{
			bitRate = audio.bitRate;
			[userDefaults setInteger:bitRate forKey:@"bitRate"];
			isDefaultsDirty = YES;
		}
		
		if (secondsOffset != audio.progress)
		{
			secondsOffset = audio.progress;
			[userDefaults setDouble:secondsOffset forKey:@"seekTime"];
			isDefaultsDirty = YES;
		}
		
		if (byteOffset != audio.currentByteOffset)
		{
			byteOffset = audio.currentByteOffset;
			NSNumber *num = [NSNumber numberWithUnsignedLongLong:byteOffset];
			[userDefaults setObject:num forKey:@"byteOffset"];
			isDefaultsDirty = YES;
		}
				
		BOOL newIsRecover = NO;
		if (isPlaying)
		{
			if (recoverSetting == 0)
				newIsRecover = YES;
			else
				newIsRecover = NO;
		}
		else
		{
			newIsRecover = NO;
		}
		
		if (isRecover != newIsRecover)
		{
			isRecover = newIsRecover;
			[userDefaults setBool:isRecover forKey:@"recover"];
			isDefaultsDirty = YES;
		}
		
		// Only synchronize to disk if necessary
		if (isDefaultsDirty)
			[userDefaults synchronize];	
	}	
}

#pragma mark - Settings Setup

- (void)convertFromOldSettingsType
{	
	// Convert server list
	id servers = [userDefaults objectForKey:@"servers"];
	if ([servers isKindOfClass:[NSArray class]])
	{
		if ([servers count] > 0)
		{
			if ([[servers objectAtIndex:0] isKindOfClass:[NSArray class]])
			{
				NSMutableArray *newServerList = [NSMutableArray arrayWithCapacity:0];
				
				for (NSArray *serverInfo in servers)
				{
					Server *aServer = [[Server alloc] init];
					aServer.url = [NSString stringWithString:[serverInfo objectAtIndex:0]];
					aServer.username = [NSString stringWithString:[serverInfo objectAtIndex:1]];
					aServer.password = [NSString stringWithString:[serverInfo objectAtIndex:2]];
					aServer.type = SUBSONIC;
					
					[newServerList addObject:aServer];
					[aServer release];
				}
				
				self.serverList = newServerList;
				
				[userDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:serverList] forKey:@"servers"];
			}
		}
	}
	else
	{
		if (servers != nil)
			serverList = [NSKeyedUnarchiver unarchiveObjectWithData:servers];
	}
	
	// Convert the old settings format over
	NSDictionary *settingsDictionary = [userDefaults objectForKey:@"settingsDictionary"];
	if (settingsDictionary != nil)
	{
		NSArray *boolKeys = [NSArray arrayWithObjects:@"manualOfflineModeSetting" , @"enableSongCachingSetting" , @"enableNextSongCacheSetting", @"autoDeleteCacheSetting", @"twitterEnabledSetting", @"lyricsEnabledSetting", @"enableSongsTabSetting", @"autoPlayerInfoSetting", @"autoReloadArtistsSetting", @"enableScrobblingSetting", @"lockRotationSetting", @"checkUpdatesSetting", nil];
		NSArray *intKeys = [NSArray arrayWithObjects:@"recoverSetting", @"maxBitrateWifiSetting", @"maxBitrate3GSetting", @"cachingTypeSetting", @"autoDeleteCacheTypeSetting", @"cacheSongCellColorSetting", nil];
		NSArray *objKeys = [NSArray arrayWithObjects:@"maxCacheSize", @"minFreeSpace", nil];
		NSArray *floatKeys = [NSArray arrayWithObject:@"scrobblePercentSetting"];
		
		// Process BOOL keys
		for (NSString *key in boolKeys)
		{
			NSString *value = [settingsDictionary objectForKey:key];
			if (value)
			{
				[userDefaults setBool:[value boolValue] forKey:key];
			}
		}
		
		// Process int keys
		for (NSString *key in intKeys)
		{
			NSNumber *value = [settingsDictionary objectForKey:key];
			if (value)
			{
				[userDefaults setInteger:[value intValue] forKey:key];
			}
		}
		
		// Process Object keys (unsigned long long in NSNumber)
		for (NSString *key in objKeys)
		{
			NSNumber *value = [settingsDictionary objectForKey:key];
			if (value)
			{
				[userDefaults setObject:value forKey:key];
			}
		}
		
		// Process float key
		for (NSString *key in floatKeys)
		{
			NSNumber *value = [settingsDictionary objectForKey:key];
			if (value)
			{
				[userDefaults setFloat:[value floatValue] forKey:key];
			}
		}
		
		// Special Cases
		NSString *disableSleep = [settingsDictionary objectForKey:@"disableScreenSleepSetting"];
		if (disableSleep)
		{
			[userDefaults setBool:![disableSleep boolValue] forKey:@"isScreenSleepEnabled"];
		}
		NSString *disablePopups = [settingsDictionary objectForKey:@"disablePopupsSetting"];
		if (disablePopups)
		{
			[userDefaults setBool:![disablePopups boolValue] forKey:@"isPopupsEnabled"];
		}
		if ([settingsDictionary objectForKey:@"checkUpdatesSetting"] != nil)
		{
			[userDefaults setBool:YES forKey:@"isUpdateCheckQuestionAsked"];
		}
		
		// Delete the old settings
		//[settings removeObjectForKey:@"settingsDictionary"];
		
		[userDefaults synchronize];
	}
}

- (void)createInitialSettings
{
	if (![userDefaults boolForKey:@"areSettingsSetup"])
	{
		[userDefaults setBool:YES forKey:@"areSettingsSetup"];
		[userDefaults setBool:NO forKey:@"manualOfflineModeSetting"];
		[userDefaults setInteger:0 forKey:@"recoverSetting"];
		[userDefaults setInteger:7 forKey:@"maxBitrateWifiSetting"];
		[userDefaults setInteger:7 forKey:@"maxBitrate3GSetting"];
		[userDefaults setBool:YES forKey:@"enableSongCachingSetting"];
		[userDefaults setBool:YES forKey:@"enableNextSongCacheSetting"];
		[userDefaults setInteger:0 forKey:@"cachingTypeSetting"];
		[userDefaults setObject:[NSNumber numberWithUnsignedLongLong:1073741824] forKey:@"maxCacheSize"];
		[userDefaults setObject:[NSNumber numberWithUnsignedLongLong:268435456] forKey:@"minFreeSpace"];
		[userDefaults setBool:YES forKey:@"autoDeleteCacheSetting"];
		[userDefaults setInteger:0 forKey:@"autoDeleteCacheTypeSetting"];
		[userDefaults setInteger:3 forKey:@"cacheSongCellColorSetting"];
		[userDefaults setBool:NO forKey:@"twitterEnabledSetting"];
		[userDefaults setBool:NO forKey:@"lyricsEnabledSetting"];
		[userDefaults setBool:NO forKey:@"enableSongsTabSetting"];
		[userDefaults setBool:NO forKey:@"autoPlayerInfoSetting"];
		[userDefaults setBool:NO forKey:@"autoReloadArtistsSetting"];
		[userDefaults setFloat:0.5 forKey:@"scrobblePercentSetting"];
		[userDefaults setBool:NO forKey:@"enableScrobblingSetting"];
		[userDefaults setBool:NO forKey:@"disablePopupsSetting"];
		[userDefaults setBool:NO forKey:@"lockRotationSetting"];
		[userDefaults setBool:NO forKey:@"isJukeboxEnabled"];
		[userDefaults setBool:YES forKey:@"isScreenSleepEnabled"];
		[userDefaults setBool:YES forKey:@"isPopupsEnabled"];
		[userDefaults setBool:NO forKey:@"checkUpdatesSetting"];
		[userDefaults setBool:NO forKey:@"isUpdateCheckQuestionAsked"];
		[userDefaults setBool:NO forKey:@"isBasicAuthEnabled"];
		
		[self convertFromOldSettingsType];
	}
	
	// New settings 3.0.5 beta 18
	if (![userDefaults objectForKey:@"gainMultiplier"])
	{
		[userDefaults setBool:YES forKey:@"isTapAndHoldEnabled"];
		[userDefaults setBool:YES forKey:@"isSwipeEnabled"];
		[userDefaults setFloat:1.0 forKey:@"gainMultiplier"];
	}
	
	// Removal of 3rd recovery type option
	if (self.recoverSetting == 2)
	{
		// "Never" option removed, change to "Paused" option if set
		self.recoverSetting = 1;
	}
	
	[userDefaults synchronize];
}

- (void)addNewSettings
{
	//[userDefaults 
}

- (void)memCacheDefaults
{
	isJukeboxEnabled = [userDefaults boolForKey:@"isJukeboxEnabled"];
	isScreenSleepEnabled = [userDefaults boolForKey:@"isScreenSleepEnabled"];
	isPopupsEnabled = [userDefaults boolForKey:@"isPopupsEnabled"];
	
	gainMultiplier = [userDefaults floatForKey:@"gainMultiplier"];
	
	NSString *url = [userDefaults stringForKey:@"url"];
	if (url)
	{
		urlString = [[NSString alloc] initWithString:url];
	}
	
	NSString *user = [userDefaults stringForKey:@"username"];
	if (user)
	{
		username = [[NSString alloc] initWithString:user];
	}
	
	NSString *pass = [userDefaults stringForKey:@"password"];
	if (pass)
	{
		password = [[NSString alloc] initWithString:pass];
	}
}

#pragma mark - Login Settings

- (NSString *)urlString
{
	return urlString;
}

- (void)setUrlString:(NSString *)url
{
	[urlString release];
	urlString = [url copy];
	[userDefaults setObject:url forKey:@"url"];
	[userDefaults synchronize];
}

- (NSString *)username
{
	return username;
}

- (void)setUsername:(NSString *)user
{
	[username release];
	username = [user copy];
	[userDefaults setObject:user forKey:@"username"];
	[userDefaults synchronize];
}

- (NSString *)password
{
	return password;
}

- (void)setPassword:(NSString *)pass
{
	[password release];
	password = [pass copy];
	[userDefaults setObject:pass forKey:@"password"];
	[userDefaults synchronize];
}

#pragma mark - Document Folder Paths

- (NSString *)documentsPath
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	return [paths objectAtIndex: 0];
}

- (NSString *)databasePath
{
	return [self.documentsPath stringByAppendingPathComponent:@"database"];
}

- (NSString *)cachesPath
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	return [paths objectAtIndex: 0];
}

- (NSString *)songCachePath
{
	return [self.cachesPath stringByAppendingPathComponent:@"songCache"];
}

- (NSString *)tempCachePath
{
	return [self.cachesPath stringByAppendingPathComponent:@"tempCache"];
}

#pragma mark - Root Folders Settings

- (NSDate *)rootFoldersReloadTime
{
	return [userDefaults objectForKey:[NSString stringWithFormat:@"%@rootFoldersReloadTime", urlString]];
}

- (void)setRootFoldersReloadTime:(NSDate *)reloadTime
{
	[userDefaults setObject:reloadTime forKey:[NSString stringWithFormat:@"%@rootFoldersReloadTime", urlString]];
	[userDefaults synchronize];
}

- (NSNumber *)rootFoldersSelectedFolderId
{
	return [userDefaults objectForKey:[NSString stringWithFormat:@"%@rootFoldersSelectedFolder", urlString]];
}

- (void)setRootFoldersSelectedFolderId:(NSNumber *)folderId
{
	[userDefaults setObject:folderId forKey:[NSString stringWithFormat:@"%@rootFoldersSelectedFolder", urlString]];
	[userDefaults synchronize];
}

#pragma mark - Lite Version Properties

- (BOOL)isPlaylistUnlocked
{
	if (!IS_LITE() || [MKStoreManager isFeaturePurchased:kFeaturePlaylistsId] || [MKStoreManager isFeaturePurchased:kFeatureAllId])
		return YES;
	
	return NO;
}

- (BOOL)isCacheUnlocked
{
	if (!IS_LITE() || [MKStoreManager isFeaturePurchased:kFeatureCacheId] || [MKStoreManager isFeaturePurchased:kFeatureAllId])
		return YES;
	
	return NO;
}

- (BOOL)isJukeboxUnlocked
{
	if (!IS_LITE() || [MKStoreManager isFeaturePurchased:kFeatureJukeboxId] || [MKStoreManager isFeaturePurchased:kFeatureAllId])
		return YES;
	
	return NO;
}

#pragma mark - Other Settings

- (BOOL)isForceOfflineMode
{
	return [userDefaults boolForKey:@"manualOfflineModeSetting"];
}

- (void)setIsForceOfflineMode:(BOOL)isForceOfflineMode
{
	[userDefaults setBool:isForceOfflineMode forKey:@"manualOfflineModeSetting"];
	[userDefaults synchronize];
}

- (NSInteger)recoverSetting
{
	return [userDefaults integerForKey:@"recoverSetting"];
}

- (void)setRecoverSetting:(NSInteger)setting
{
	recoverSetting = setting;
	[userDefaults setInteger:setting forKey:@"recoverSetting"];
	[userDefaults synchronize];
}

- (NSInteger)maxBitrateWifi
{
	return [userDefaults integerForKey:@"maxBitrateWifiSetting"];
}

- (void)setMaxBitrateWifi:(NSInteger)maxBitrateWifi
{
	[userDefaults setInteger:maxBitrateWifi forKey:@"maxBitrateWifiSetting"];
	[userDefaults synchronize];
}

- (NSInteger)maxBitrate3G
{
	return [userDefaults integerForKey:@"maxBitrate3GSetting"];
}

- (void)setMaxBitrate3G:(NSInteger)maxBitrate3G
{
	[userDefaults setInteger:maxBitrate3G forKey:@"maxBitrate3GSetting"];
	[userDefaults synchronize];
}

- (NSInteger)currentMaxBitrate
{
	NSInteger bitrate;
	switch ([iSubAppDelegate sharedInstance].isWifi ? self.maxBitrateWifi : self.maxBitrate3G)
	{
		case 0:
			bitrate = 64;
			break;
		case 1:
			bitrate = 96;
			break;
		case 2:
			bitrate = 128;
			break;
		case 3:
			bitrate = 160;
			break;
		case 4:
			bitrate = 192;
			break;
		case 5:
			bitrate = 224;
			break;
		case 6:
			bitrate = 256;
			break;
		default:
			bitrate = 0;
			break;
	}
	
	return bitrate;
}

- (BOOL)isSongCachingEnabled
{
	if (self.isCacheUnlocked)
		return [userDefaults boolForKey:@"enableSongCachingSetting"];
	else
		return NO;
}

- (void)setIsSongCachingEnabled:(BOOL)isSongCachingEnabled
{
	[userDefaults setBool:isSongCachingEnabled forKey:@"enableSongCachingSetting"];
	[userDefaults synchronize];
}

- (BOOL)isNextSongCacheEnabled
{
	return [userDefaults boolForKey:@"enableNextSongCacheSetting"];
}

- (void)setIsNextSongCacheEnabled:(BOOL)isNextSongCacheEnabled
{
	[userDefaults setBool:isNextSongCacheEnabled forKey:@"enableNextSongCacheSetting"];
	[userDefaults synchronize];
}

- (NSInteger)cachingType
{
	return [userDefaults integerForKey:@"cachingTypeSetting"];
}

- (void)setCachingType:(NSInteger)cachingType
{
	[userDefaults setInteger:cachingType forKey:@"cachingTypeSetting"];
	[userDefaults synchronize];
}

- (unsigned long long)maxCacheSize
{
	return [[userDefaults objectForKey:@"maxCacheSize"] unsignedLongLongValue];
}

- (void)setMaxCacheSize:(unsigned long long)maxCacheSize
{
	NSNumber *value = [NSNumber numberWithUnsignedLongLong:maxCacheSize];
	[userDefaults setObject:value forKey:@"maxCacheSize"];
	[userDefaults synchronize];
}

- (unsigned long long)minFreeSpace
{
	return [[userDefaults objectForKey:@"minFreeSpace"] unsignedLongLongValue];
}

- (void)setMinFreeSpace:(unsigned long long)minFreeSpace
{
	NSNumber *value = [NSNumber numberWithUnsignedLongLong:minFreeSpace];
	[userDefaults setObject:value forKey:@"minFreeSpace"];
	[userDefaults synchronize];
}

- (BOOL)isAutoDeleteCacheEnabled
{
	return [userDefaults boolForKey:@"autoDeleteCacheSetting"];
}

- (void)setIsAutoDeleteCacheEnabled:(BOOL)isAutoDeleteCacheEnabled
{
	[userDefaults setBool:isAutoDeleteCacheEnabled forKey:@"autoDeleteCacheSetting"];
	[userDefaults synchronize];
}

- (NSInteger)autoDeleteCacheType
{
	return [userDefaults integerForKey:@"autoDeleteCacheTypeSetting"];
}

- (void)setAutoDeleteCacheType:(NSInteger)autoDeleteCacheType
{
	[userDefaults setInteger:autoDeleteCacheType forKey:@"autoDeleteCacheTypeSetting"];
	[userDefaults synchronize];
}

- (NSInteger)cachedSongCellColorType
{
	return [userDefaults integerForKey:@"cacheSongCellColorSetting"];
}

- (void)setCachedSongCellColorType:(NSInteger)cachedSongCellColorType
{
	[userDefaults setInteger:cachedSongCellColorType forKey:@"cacheSongCellColorSetting"];
	[userDefaults synchronize];
}

- (BOOL)isTwitterEnabled
{
	return [userDefaults boolForKey:@"twitterEnabledSetting"];
}

- (void)setIsTwitterEnabled:(BOOL)isTwitterEnabled
{
	[userDefaults setBool:isTwitterEnabled forKey:@"twitterEnabledSetting"];
	[userDefaults synchronize];
}

- (BOOL)isLyricsEnabled
{
	return [userDefaults boolForKey:@"lyricsEnabledSetting"];
}

- (void)setIsLyricsEnabled:(BOOL)isLyricsEnabled
{
	[userDefaults setBool:isLyricsEnabled forKey:@"lyricsEnabledSetting"];
	[userDefaults synchronize];
}

- (BOOL)isCacheStatusEnabled
{
	return [userDefaults boolForKey:@"isCacheStatusEnabled"];
}

- (void)setIsCacheStatusEnabled:(BOOL)isCacheStatusEnabled
{
	[userDefaults setBool:isCacheStatusEnabled forKey:@"isCacheStatusEnabled"];
	[userDefaults synchronize];
}

- (BOOL)isSongsTabEnabled
{
	return [userDefaults boolForKey:@"enableSongsTabSetting"];
}

- (void)setIsSongsTabEnabled:(BOOL)isSongsTabEnabled
{
	[userDefaults setBool:isSongsTabEnabled forKey:@"enableSongsTabSetting"];
	[userDefaults synchronize];
}

- (BOOL)isAutoShowSongInfoEnabled
{
	return [userDefaults boolForKey:@"autoPlayerInfoSetting"];
}

- (void)setIsAutoShowSongInfoEnabled:(BOOL)isAutoShowSongInfoEnabled
{
	[userDefaults setBool:isAutoShowSongInfoEnabled forKey:@"autoPlayerInfoSetting"];
	[userDefaults synchronize];
}

- (BOOL)isAutoReloadArtistsEnabled
{
	return [userDefaults boolForKey:@"autoReloadArtistsSetting"];
}

- (void)setIsAutoReloadArtistsEnabled:(BOOL)isAutoReloadArtistsEnabled
{
	[userDefaults setBool:isAutoReloadArtistsEnabled forKey:@"autoReloadArtistsSetting"];
	[userDefaults synchronize];
}

- (float)scrobblePercent
{
	return [userDefaults floatForKey:@"scrobblePercentSetting"];
}

- (void)setScrobblePercent:(float)scrobblePercent
{
	[userDefaults setFloat:scrobblePercent forKey:@"scrobblePercentSetting"];
	[userDefaults synchronize];
}

- (BOOL)isScrobbleEnabled
{
	return [userDefaults boolForKey:@"enableScrobblingSetting"];
}

- (void)setIsScrobbleEnabled:(BOOL)isScrobbleEnabled
{
	[userDefaults setBool:isScrobbleEnabled forKey:@"enableScrobblingSetting"];
	[userDefaults synchronize];
}

- (BOOL)isRotationLockEnabled
{
	return [userDefaults boolForKey:@"lockRotationSetting"];
}

- (void)setIsRotationLockEnabled:(BOOL)isRotationLockEnabled
{
	[userDefaults setBool:isRotationLockEnabled forKey:@"lockRotationSetting"];
	[userDefaults synchronize];
}

- (BOOL)isJukeboxEnabled
{
	if (self.isJukeboxUnlocked)
		return isJukeboxEnabled;
	else
		return NO;
}

- (void)setIsJukeboxEnabled:(BOOL)enabled
{
	isJukeboxEnabled = enabled;
	[userDefaults setBool:enabled forKey:@"isJukeboxEnabled"];
	[userDefaults synchronize];
}

- (BOOL)isScreenSleepEnabled
{
	return isScreenSleepEnabled;
}

- (void)setIsScreenSleepEnabled:(BOOL)enabled
{
	isScreenSleepEnabled = enabled;
	[userDefaults setBool:enabled forKey:@"isScreenSleepEnabled"];
	[userDefaults synchronize];
}

- (BOOL)isPopupsEnabled
{
	return isPopupsEnabled;
}

- (void)setIsPopupsEnabled:(BOOL)enabled
{
	isPopupsEnabled = enabled;
	[userDefaults setBool:enabled forKey:@"isPopupsEnabled"];
	[userDefaults synchronize];
}

- (BOOL)isUpdateCheckEnabled
{
	return [userDefaults boolForKey:@"checkUpdatesSetting"];
}

- (void)setIsUpdateCheckEnabled:(BOOL)isUpdateCheckEnabled
{
	[userDefaults setBool:isUpdateCheckEnabled forKey:@"checkUpdatesSetting"];
	[userDefaults synchronize];
}

- (BOOL)isUpdateCheckQuestionAsked
{
	return [userDefaults boolForKey:@"isUpdateCheckQuestionAsked"];
}

- (void)setIsUpdateCheckQuestionAsked:(BOOL)isUpdateCheckQuestionAsked
{
	[userDefaults setBool:isUpdateCheckQuestionAsked forKey:@"isUpdateCheckQuestionAsked"];
	[userDefaults synchronize];
}

- (BOOL)isNewSearchAPI
{
	NSString *key = [NSString stringWithFormat:@"isNewSearchAPI%@", [urlString md5]];
	return [userDefaults boolForKey:key];
}

- (void)setIsNewSearchAPI:(BOOL)isNewSearchAPI
{
	NSString *key = [NSString stringWithFormat:@"isNewSearchAPI%@", [urlString md5]];
	[userDefaults setBool:isNewSearchAPI forKey:key];
	[userDefaults synchronize];
}

- (BOOL)isRecover
{
	return [userDefaults boolForKey:@"recover"];
}

- (void)setIsRecover:(BOOL)recover
{
	isRecover = recover;
	[userDefaults setBool:recover forKey:@"recover"];
	[userDefaults synchronize];
}

- (double)seekTime
{
	return [userDefaults doubleForKey:@"seekTime"];
}

- (void)setSeekTime:(double)seekTime
{
	secondsOffset = seekTime;
	[userDefaults setDouble:seekTime forKey:@"seekTime"];
	[userDefaults synchronize];
}

- (unsigned long long)byteOffset
{
	unsigned long long retVal = [[userDefaults objectForKey:@"byteOffset"] unsignedLongLongValue];
	return retVal;
}

- (void)setByteOffset:(unsigned long long)bOffset
{
	byteOffset = bOffset;
	NSNumber *num = [NSNumber numberWithUnsignedLongLong:byteOffset];
	[userDefaults setObject:num forKey:@"byteOffset"];
	[userDefaults synchronize];
}

- (NSInteger)bitRate
{
	NSInteger rate = [[userDefaults objectForKey:@"bitRate"] integerValue];
	if (rate < 0) 
		return 128;
	else 
		return rate;
}

- (void)setBitRate:(NSInteger)rate
{
	bitRate = rate;
	NSNumber *num = [NSNumber numberWithInteger:bitRate];
	[userDefaults setObject:num forKey:@"bitRate"];
	[userDefaults synchronize];
}

- (BOOL)isBasicAuthEnabled
{
	return [userDefaults boolForKey:@"isBasicAuthEnabled"];
}

- (void)setIsBasicAuthEnabled:(BOOL)isBasicAuthEnabled
{
	[userDefaults setBool:isBasicAuthEnabled forKey:@"isBasicAuthEnabled"];
	[userDefaults synchronize];
}

- (BOOL)isTapAndHoldEnabled
{
	return [userDefaults boolForKey:@"isTapAndHoldEnabled"];
}

- (void)setIsTapAndHoldEnabled:(BOOL)isTapAndHoldEnabled
{
	[userDefaults setBool:isTapAndHoldEnabled forKey:@"isTapAndHoldEnabled"];
	[userDefaults synchronize];
}

- (BOOL)isSwipeEnabled
{
	return [userDefaults boolForKey:@"isSwipeEnabled"];
}

- (void)setIsSwipeEnabled:(BOOL)isSwipeEnabled
{
	[userDefaults setBool:isSwipeEnabled forKey:@"isSwipeEnabled"];
	[userDefaults synchronize];
}

- (float)gainMultiplier
{
	return gainMultiplier;
}

- (void)setGainMultiplier:(float)multiplier
{
	gainMultiplier = multiplier;
	[userDefaults setFloat:multiplier forKey:@"gainMultiplier"];
	[userDefaults synchronize];
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
	// Disable screen sleep if necessary
	if (!self.isScreenSleepEnabled)
		[UIApplication sharedApplication].idleTimerDisabled = YES;
	
	userDefaults = [[NSUserDefaults standardUserDefaults] retain];
	serverList = nil;
	urlString = [[NSString alloc] initWithString:DEFAULT_URL];
	username = [[NSString alloc] initWithString:DEFAULT_USER_NAME];
	password = [[NSString alloc] initWithString:DEFAULT_PASSWORD];
	redirectUrlString = nil;
	
	[self createInitialSettings];
    
	// If the settings are not set up, convert them
	if ([userDefaults boolForKey:@"areSettingsSetup"])
	{
		NSData *servers = [userDefaults objectForKey:@"servers"];
		if (servers)
		{
			self.serverList = [NSKeyedUnarchiver unarchiveObjectWithData:servers];
		}
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
			//[sharedInstance setup];
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
