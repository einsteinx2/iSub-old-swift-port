//
//  SavedSettings.m
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SavedSettings.h"
#import "MKStoreManager.h"
#import "PlaylistSingleton.h"
#import "BassGaplessPlayer.h"

// Test server details
#define DEFAULT_SERVER_TYPE SUBSONIC
#define DEFAULT_URL @"http://isubapp.com:9001"
#define DEFAULT_USER_NAME @"isub-guest"
#define DEFAULT_PASSWORD @"1sub1snumb3r0n3"

@implementation SavedSettings

/*- (NSString *)formatFileSize:(unsigned long long int)size
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
}*/

- (void)loadState
{	
	if (self.isJukeboxEnabled)
		_isPlaying = NO;
	else
		_isPlaying = [_userDefaults boolForKey:@"isPlaying"];
		
	_isShuffle = [_userDefaults boolForKey:@"isShuffle"];
	playlistS.isShuffle = _isShuffle;
	
	_normalPlaylistIndex = [_userDefaults integerForKey:@"normalPlaylistIndex"];
	playlistS.normalIndex = _normalPlaylistIndex;
	
	_shufflePlaylistIndex = [_userDefaults integerForKey:@"shufflePlaylistIndex"];
	playlistS.shuffleIndex = _shufflePlaylistIndex;
	
	_repeatMode = [_userDefaults integerForKey:@"repeatMode"];
	playlistS.repeatMode = _repeatMode;
	
	_bitRate = [_userDefaults integerForKey:@"bitRate"];
	_byteOffset = self.byteOffset;
	_secondsOffset = self.seekTime;
	_isRecover = self.isRecover;
	_recoverSetting = self.recoverSetting;
    _sessionId = self.sessionId;
	
	audioEngineS.startByteOffset = _byteOffset;
	audioEngineS.startSecondsOffset = _secondsOffset;
    //DLog(@"startByteOffset: %llu  startSecondsOffset: %f", byteOffset, secondsOffset);
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
		BOOL isDefaultsDirty = NO;
		
		if (audioEngineS.player.isPlaying != _isPlaying)
		{
			if (self.isJukeboxEnabled)
				_isPlaying = NO;
			else
				_isPlaying = audioEngineS.player.isPlaying;
			
			[_userDefaults setBool:_isPlaying forKey:@"isPlaying"];
			isDefaultsDirty = YES;
		}
		
		if (playlistS.isShuffle != _isShuffle)
		{
			_isShuffle = playlistS.isShuffle;
			[_userDefaults setBool:_isShuffle forKey:@"isShuffle"];
			isDefaultsDirty = YES;
		}
		
		if (playlistS.normalIndex != _normalPlaylistIndex)
		{
			_normalPlaylistIndex = playlistS.normalIndex;
			[_userDefaults setInteger:_normalPlaylistIndex forKey:@"normalPlaylistIndex"];
			isDefaultsDirty = YES;
		}
		
		if (playlistS.shuffleIndex != _shufflePlaylistIndex)
		{
			_shufflePlaylistIndex = playlistS.shuffleIndex;
			[_userDefaults setInteger:_shufflePlaylistIndex forKey:@"shufflePlaylistIndex"];
			isDefaultsDirty = YES;
		}
		
		if (playlistS.repeatMode != _repeatMode)
		{
			_repeatMode = playlistS.repeatMode;
			[_userDefaults setInteger:_repeatMode forKey:@"repeatMode"];
			isDefaultsDirty = YES;
		}
		
		if (audioEngineS.player.bitRate != _bitRate && audioEngineS.player.bitRate >= 0)
		{
			_bitRate = audioEngineS.player.bitRate;
			[_userDefaults setInteger:_bitRate forKey:@"bitRate"];
			isDefaultsDirty = YES;
		}
		
		if (_secondsOffset != audioEngineS.player.progress)
		{
			_secondsOffset = audioEngineS.player.progress;
			[_userDefaults setDouble:_secondsOffset forKey:@"seekTime"];
			isDefaultsDirty = YES;
		}
		
		if (_byteOffset != audioEngineS.player.currentByteOffset)
		{
			_byteOffset = audioEngineS.player.currentByteOffset;
			NSNumber *num = [NSNumber numberWithUnsignedLongLong:_byteOffset];
			[_userDefaults setObject:num forKey:@"byteOffset"];
			isDefaultsDirty = YES;
		}
				
		BOOL newIsRecover = NO;
		if (_isPlaying)
		{
			if (_recoverSetting == 0)
				newIsRecover = YES;
			else
				newIsRecover = NO;
		}
		else
		{
			newIsRecover = NO;
		}
		
		if (_isRecover != newIsRecover)
		{
			_isRecover = newIsRecover;
			[_userDefaults setBool:_isRecover forKey:@"recover"];
			isDefaultsDirty = YES;
		}
		
		// Only synchronize to disk if necessary
		if (isDefaultsDirty)
			[_userDefaults synchronize];
	}	
}

#pragma mark - Settings Setup

- (void)convertFromOldSettingsType
{	
	// Convert server list
	id servers = [_userDefaults objectForKey:@"servers"];
	if ([servers isKindOfClass:[NSArray class]])
	{
		if ([servers count] > 0)
		{
			if ([[servers objectAtIndexSafe:0] isKindOfClass:[NSArray class]])
			{
				NSMutableArray *newServerList = [NSMutableArray arrayWithCapacity:0];
				
				for (NSArray *serverInfo in servers)
				{
					ISMSServer *aServer = [[ISMSServer alloc] init];
					aServer.url = [NSString stringWithString:[serverInfo objectAtIndexSafe:0]];
					aServer.username = [NSString stringWithString:[serverInfo objectAtIndexSafe:1]];
					aServer.password = [NSString stringWithString:[serverInfo objectAtIndexSafe:2]];
					aServer.type = SUBSONIC;
					
					[newServerList addObject:aServer];
				}
				
				self.serverList = newServerList;
				
				[_userDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:_serverList] forKey:@"servers"];
			}
		}
	}
	else
	{
		if (servers != nil)
			self.serverList = [NSKeyedUnarchiver unarchiveObjectWithData:servers];
	}
	
	// Convert the old settings format over
	NSDictionary *settingsDictionary = [_userDefaults objectForKey:@"settingsDictionary"];
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
				[_userDefaults setBool:[value boolValue] forKey:key];
			}
		}
		
		// Process int keys
		for (NSString *key in intKeys)
		{
			NSNumber *value = [settingsDictionary objectForKey:key];
			if (value)
			{
				[_userDefaults setInteger:[value intValue] forKey:key];
			}
		}
		
		// Process Object keys (unsigned long long in NSNumber)
		for (NSString *key in objKeys)
		{
			NSNumber *value = [settingsDictionary objectForKey:key];
			if (value)
			{
				[_userDefaults setObject:value forKey:key];
			}
		}
		
		// Process float key
		for (NSString *key in floatKeys)
		{
			NSNumber *value = [settingsDictionary objectForKey:key];
			if (value)
			{
				[_userDefaults setFloat:[value floatValue] forKey:key];
			}
		}
		
		// Special Cases
		NSString *disableSleep = [settingsDictionary objectForKey:@"disableScreenSleepSetting"];
		if (disableSleep)
		{
			[_userDefaults setBool:![disableSleep boolValue] forKey:@"isScreenSleepEnabled"];
		}
		NSString *disablePopups = [settingsDictionary objectForKey:@"disablePopupsSetting"];
		if (disablePopups)
		{
			[_userDefaults setBool:![disablePopups boolValue] forKey:@"isPopupsEnabled"];
		}
		if ([settingsDictionary objectForKey:@"checkUpdatesSetting"] != nil)
		{
			[_userDefaults setBool:YES forKey:@"isUpdateCheckQuestionAsked"];
		}
		
		// Delete the old settings
		//[settings removeObjectForKey:@"settingsDictionary"];
		
		[_userDefaults synchronize];
	}
}

- (void)createInitialSettings
{
	if (![_userDefaults boolForKey:@"areSettingsSetup"])
	{
		[_userDefaults setBool:YES forKey:@"areSettingsSetup"];
		[_userDefaults setBool:NO forKey:@"manualOfflineModeSetting"];
		[_userDefaults setInteger:0 forKey:@"recoverSetting"];
		[_userDefaults setInteger:7 forKey:@"maxBitrateWifiSetting"];
		[_userDefaults setInteger:7 forKey:@"maxBitrate3GSetting"];
		[_userDefaults setBool:YES forKey:@"enableSongCachingSetting"];
		[_userDefaults setBool:YES forKey:@"enableNextSongCacheSetting"];
		[_userDefaults setInteger:0 forKey:@"cachingTypeSetting"];
		[_userDefaults setObject:[NSNumber numberWithUnsignedLongLong:1073741824] forKey:@"maxCacheSize"];
		[_userDefaults setObject:[NSNumber numberWithUnsignedLongLong:268435456] forKey:@"minFreeSpace"];
		[_userDefaults setBool:YES forKey:@"autoDeleteCacheSetting"];
		[_userDefaults setInteger:0 forKey:@"autoDeleteCacheTypeSetting"];
		[_userDefaults setInteger:3 forKey:@"cacheSongCellColorSetting"];
		[_userDefaults setBool:NO forKey:@"twitterEnabledSetting"];
		[_userDefaults setBool:NO forKey:@"lyricsEnabledSetting"];
		[_userDefaults setBool:NO forKey:@"enableSongsTabSetting"];
		[_userDefaults setBool:NO forKey:@"autoPlayerInfoSetting"];
		[_userDefaults setBool:NO forKey:@"autoReloadArtistsSetting"];
		[_userDefaults setFloat:0.5 forKey:@"scrobblePercentSetting"];
		[_userDefaults setBool:NO forKey:@"enableScrobblingSetting"];
		[_userDefaults setBool:NO forKey:@"disablePopupsSetting"];
		[_userDefaults setBool:NO forKey:@"lockRotationSetting"];
		[_userDefaults setBool:NO forKey:@"isJukeboxEnabled"];
		[_userDefaults setBool:YES forKey:@"isScreenSleepEnabled"];
		[_userDefaults setBool:YES forKey:@"isPopupsEnabled"];
		[_userDefaults setBool:NO forKey:@"checkUpdatesSetting"];
		[_userDefaults setBool:NO forKey:@"isUpdateCheckQuestionAsked"];
		[_userDefaults setBool:NO forKey:@"isBasicAuthEnabled"];
		[_userDefaults setBool:YES forKey:@"checkUpdatesSetting"];
		
		[self convertFromOldSettingsType];
	}
	
	// New settings 3.0.5 beta 18
	if (![_userDefaults objectForKey:@"gainMultiplier"])
	{
		[_userDefaults setBool:YES forKey:@"isTapAndHoldEnabled"];
		[_userDefaults setBool:YES forKey:@"isSwipeEnabled"];
		[_userDefaults setFloat:1.0 forKey:@"gainMultiplier"];
	}
	
	// Removal of 3rd recovery type option
	if (self.recoverSetting == 2)
	{
		// "Never" option removed, change to "Paused" option if set
		self.recoverSetting = 1;
	}
	
	// Partial caching of next song
	if (![_userDefaults objectForKey:@"isPartialCacheNextSong"])
	{
		self.isPartialCacheNextSong = YES;
	}
	
	// Visualizer Type
	if (![_userDefaults objectForKey:@"currentVisualizerType"])
	{
		self.currentVisualizerType = ISMSBassVisualType_none;
	}
	
	// Quick Skip
	if (![_userDefaults objectForKey:@"quickSkipNumberOfSeconds"])
	{
		self.quickSkipNumberOfSeconds = 30;
	}
	
	if (![_userDefaults objectForKey:@"isShouldShowEQViewInstructions"])
	{
		self.isShouldShowEQViewInstructions = YES;
	}
	
	if (![_userDefaults objectForKey:@"audioEngineStartNumberOfSeconds"])
	{
		self.audioEngineStartNumberOfSeconds = 10;
		self.audioEngineBufferNumberOfSeconds = 10;
	}
	
	if (![_userDefaults objectForKey:@"isLockScreenArtEnabled"])
	{
		self.isLockScreenArtEnabled = YES;
	}
	
	[_userDefaults synchronize];
}

- (void)memCacheDefaults
{
	_isJukeboxEnabled = [_userDefaults boolForKey:@"isJukeboxEnabled"];
	_isScreenSleepEnabled = [_userDefaults boolForKey:@"isScreenSleepEnabled"];
	_isPopupsEnabled = [_userDefaults boolForKey:@"isPopupsEnabled"];
	_gainMultiplier = [_userDefaults floatForKey:@"gainMultiplier"];
	_isPartialCacheNextSong = [_userDefaults boolForKey:@"isPartialCacheNextSong"];
	_isExtraPlayerControlsShowing = [_userDefaults boolForKey:@"isExtraPlayerControlsShowing"];
	_isPlayerPlaylistShowing = [_userDefaults boolForKey:@"isPlayerPlaylistShowing"];
	_quickSkipNumberOfSeconds = [_userDefaults integerForKey:@"quickSkipNumberOfSeconds"];
	_audioEngineBufferNumberOfSeconds = [_userDefaults integerForKey:@"audioEngineBufferNumberOfSeconds"];
	_audioEngineStartNumberOfSeconds = [_userDefaults integerForKey:@"audioEngineStartNumberOfSeconds"];
	_isShowLargeSongInfoInPlayer = [_userDefaults boolForKey:@"isShowLargeSongInfoInPlayer"];
	_isLockScreenArtEnabled = [_userDefaults boolForKey:@"isLockScreenArtEnabled"];
	_isEqualizerOn = [_userDefaults boolForKey:@"isEqualizerOn"];
	
	_serverType = [_userDefaults stringForKey:@"serverType"];
	_serverType = _serverType ? _serverType : DEFAULT_SERVER_TYPE;
	_urlString = [_userDefaults stringForKey:@"url"];
	_urlString = _urlString ? _urlString : DEFAULT_URL;
	_username = [_userDefaults stringForKey:@"username"];
	_username = _username ? _username : DEFAULT_USER_NAME;
	_password = [_userDefaults stringForKey:@"password"];
	_password = _password ? _password : DEFAULT_PASSWORD;
    _sessionId = [_userDefaults stringForKey:[NSString stringWithFormat:@"sessionId%@", self.urlString.md5]];
}

#pragma mark - Login Settings

- (NSString *)serverType
{
	@synchronized(self)
	{
		return _serverType;
	}
}

- (void)setServerType:(NSString *)type
{
	@synchronized(self)
	{
		_serverType = [type copy];
		[_userDefaults setObject:type forKey:@"serverType"];
		[_userDefaults synchronize];
	}
}

- (NSString *)urlString
{
	@synchronized(self)
	{
		return _urlString;
	}
}

- (void)setUrlString:(NSString *)url
{
	@synchronized(self)
	{
		_urlString = [url copy];
		[_userDefaults setObject:url forKey:@"url"];
		[_userDefaults synchronize];
	}
}

- (NSString *)username
{
	@synchronized(self)
	{
		return _username;
	}
}

- (void)setUsername:(NSString *)user
{
	@synchronized(self)
	{
		_username = [user copy];
		[_userDefaults setObject:user forKey:@"username"];
		[_userDefaults synchronize];
	}
}

- (NSString *)password
{
	@synchronized(self)
	{
		return _password;
	}
}

- (void)setPassword:(NSString *)pass
{
	@synchronized(self)
	{
		_password = [pass copy];
		[_userDefaults setObject:pass forKey:@"password"];
		[_userDefaults synchronize];
	}
}

- (NSString *)sessionId
{
	@synchronized(self)
	{
		return _sessionId;
	}
}

- (void)setSessionId:(NSString *)sId
{
	@synchronized(self)
	{
		_sessionId = [sId copy];
        
        NSString *key = [NSString stringWithFormat:@"sessionId%@", self.urlString.md5];
		[_userDefaults setObject:_sessionId forKey:key];
		[_userDefaults synchronize];
	}
}

#pragma mark - Document Folder Paths

- (NSString *)documentsPath
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	return [paths objectAtIndexSafe: 0];
}

- (NSString *)databasePath
{
	return [self.documentsPath stringByAppendingPathComponent:@"database"];
}

- (NSString *)cachesPath
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	return [paths objectAtIndexSafe:0];
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
	@synchronized(self)
	{
		return [_userDefaults objectForKey:[NSString stringWithFormat:@"%@rootFoldersReloadTime", _urlString]];
	}
}

- (void)setRootFoldersReloadTime:(NSDate *)reloadTime
{
	@synchronized(self)
	{
		[_userDefaults setObject:reloadTime forKey:[NSString stringWithFormat:@"%@rootFoldersReloadTime", _urlString]];
		[_userDefaults synchronize];
	}
}

- (NSNumber *)rootFoldersSelectedFolderId
{
	@synchronized(self)
	{
		return [_userDefaults objectForKey:[NSString stringWithFormat:@"%@rootFoldersSelectedFolder", _urlString]];
	}
}

- (void)setRootFoldersSelectedFolderId:(NSNumber *)folderId
{
	@synchronized(self)
	{
		[_userDefaults setObject:folderId forKey:[NSString stringWithFormat:@"%@rootFoldersSelectedFolder", _urlString]];
		[_userDefaults synchronize];
	}
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
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"manualOfflineModeSetting"];
	}
}

- (void)setIsForceOfflineMode:(BOOL)isForceOfflineMode
{
	@synchronized(self)
	{
		[_userDefaults setBool:isForceOfflineMode forKey:@"manualOfflineModeSetting"];
		[_userDefaults synchronize];
	}
}

- (NSInteger)recoverSetting
{
	@synchronized(self)
	{
		return [_userDefaults integerForKey:@"recoverSetting"];
	}
}

- (void)setRecoverSetting:(NSInteger)setting
{
	@synchronized(self)
	{
		_recoverSetting = setting;
		[_userDefaults setInteger:setting forKey:@"recoverSetting"];
		[_userDefaults synchronize];
	}
}

- (NSInteger)maxBitrateWifi
{
	@synchronized(self)
	{
		return [_userDefaults integerForKey:@"maxBitrateWifiSetting"];
	}
}

- (void)setMaxBitrateWifi:(NSInteger)maxBitrateWifi
{
	@synchronized(self)
	{
		[_userDefaults setInteger:maxBitrateWifi forKey:@"maxBitrateWifiSetting"];
		[_userDefaults synchronize];
	}
}

- (NSInteger)maxBitrate3G
{
	@synchronized(self)
	{
		return [_userDefaults integerForKey:@"maxBitrate3GSetting"];
	}
}

- (void)setMaxBitrate3G:(NSInteger)maxBitrate3G
{
	@synchronized(self)
	{
		[_userDefaults setInteger:maxBitrate3G forKey:@"maxBitrate3GSetting"];
		[_userDefaults synchronize];
	}
}

- (NSInteger)currentMaxBitrate
{
	@synchronized(self)
	{
		NSInteger bitrate;
		switch ([iSubAppDelegate sharedInstance].isWifi ? self.maxBitrateWifi : self.maxBitrate3G)
		{
			case 0: bitrate = 64; break;
			case 1: bitrate = 96; break;
			case 2: bitrate = 128; break;
			case 3: bitrate = 160; break;
			case 4: bitrate = 192; break;
			case 5: bitrate = 256; break;
			case 6: bitrate = 320; break;
			default: bitrate = 0; break;
		}
		return bitrate;
	}
}

- (BOOL)isSongCachingEnabled
{
	@synchronized(self)
	{
		if (self.isCacheUnlocked)
			return [_userDefaults boolForKey:@"enableSongCachingSetting"];
		else
			return NO;
	}
}

- (void)setIsSongCachingEnabled:(BOOL)isSongCachingEnabled
{
	@synchronized(self)
	{
		[_userDefaults setBool:isSongCachingEnabled forKey:@"enableSongCachingSetting"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isNextSongCacheEnabled
{
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"enableNextSongCacheSetting"];
	}
}

- (void)setIsNextSongCacheEnabled:(BOOL)isNextSongCacheEnabled
{
	@synchronized(self)
	{
		[_userDefaults setBool:isNextSongCacheEnabled forKey:@"enableNextSongCacheSetting"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isManualCachingOnWWANEnabled
{
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"isManualCachingOnWWANEnabled"];
	}
}

- (void)setIsManualCachingOnWWANEnabled:(BOOL)isManualCachingOnWWANEnabled
{
	@synchronized(self)
	{
		[_userDefaults setBool:isManualCachingOnWWANEnabled forKey:@"isManualCachingOnWWANEnabled"];
		[_userDefaults synchronize];
        
        if (appDelegateS.wifiReach.currentReachabilityStatus == ReachableViaWWAN)
        {
            isManualCachingOnWWANEnabled ? [cacheQueueManagerS startDownloadQueue] : [cacheQueueManagerS stopDownloadQueue];
        }
	}
}

- (NSInteger)cachingType
{
	@synchronized(self)
	{
		return [_userDefaults integerForKey:@"cachingTypeSetting"];
	}
}

- (void)setCachingType:(NSInteger)cachingType
{
	@synchronized(self)
	{
		[_userDefaults setInteger:cachingType forKey:@"cachingTypeSetting"];
		[_userDefaults synchronize];
	}
}

- (unsigned long long)maxCacheSize
{
	@synchronized(self)
	{
		return [[_userDefaults objectForKey:@"maxCacheSize"] unsignedLongLongValue];
	}
}

- (void)setMaxCacheSize:(unsigned long long)maxCacheSize
{
	@synchronized(self)
	{
		NSNumber *value = [NSNumber numberWithUnsignedLongLong:maxCacheSize];
		[_userDefaults setObject:value forKey:@"maxCacheSize"];
		[_userDefaults synchronize];
	}
}

- (unsigned long long)minFreeSpace
{
	@synchronized(self)
	{
		return [[_userDefaults objectForKey:@"minFreeSpace"] unsignedLongLongValue];
	}
}

- (void)setMinFreeSpace:(unsigned long long)minFreeSpace
{
	@synchronized(self)
	{
		NSNumber *value = [NSNumber numberWithUnsignedLongLong:minFreeSpace];
		[_userDefaults setObject:value forKey:@"minFreeSpace"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isAutoDeleteCacheEnabled
{
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"autoDeleteCacheSetting"];
	}
}

- (void)setIsAutoDeleteCacheEnabled:(BOOL)isAutoDeleteCacheEnabled
{
	@synchronized(self)
	{
		[_userDefaults setBool:isAutoDeleteCacheEnabled forKey:@"autoDeleteCacheSetting"];
		[_userDefaults synchronize];
	}
}

- (NSInteger)autoDeleteCacheType
{
	@synchronized(self)
	{
		return [_userDefaults integerForKey:@"autoDeleteCacheTypeSetting"];
	}
}

- (void)setAutoDeleteCacheType:(NSInteger)autoDeleteCacheType
{
	@synchronized(self)
	{
		[_userDefaults setInteger:autoDeleteCacheType forKey:@"autoDeleteCacheTypeSetting"];
		[_userDefaults synchronize];
	}
}

- (NSInteger)cachedSongCellColorType
{
	@synchronized(self)
	{
		return [_userDefaults integerForKey:@"cacheSongCellColorSetting"];
	}
}

- (void)setCachedSongCellColorType:(NSInteger)cachedSongCellColorType
{
	@synchronized(self)
	{
		[_userDefaults setInteger:cachedSongCellColorType forKey:@"cacheSongCellColorSetting"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isTwitterEnabled
{
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"twitterEnabledSetting"];
	}
}

- (void)setIsTwitterEnabled:(BOOL)isTwitterEnabled
{
	@synchronized(self)
	{
		[_userDefaults setBool:isTwitterEnabled forKey:@"twitterEnabledSetting"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isLyricsEnabled
{
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"lyricsEnabledSetting"];
	}
}

- (void)setIsLyricsEnabled:(BOOL)isLyricsEnabled
{
	@synchronized(self)
	{
		[_userDefaults setBool:isLyricsEnabled forKey:@"lyricsEnabledSetting"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isCacheStatusEnabled
{
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"isCacheStatusEnabled"];
	}
}

- (void)setIsCacheStatusEnabled:(BOOL)isCacheStatusEnabled
{
	@synchronized(self)
	{
		[_userDefaults setBool:isCacheStatusEnabled forKey:@"isCacheStatusEnabled"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isSongsTabEnabled
{
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"enableSongsTabSetting"];
	}
}

- (void)setIsSongsTabEnabled:(BOOL)isSongsTabEnabled
{
	@synchronized(self)
	{
		[_userDefaults setBool:isSongsTabEnabled forKey:@"enableSongsTabSetting"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isPlayerPlaylistShowing
{
	@synchronized(self)
	{
		return _isPlayerPlaylistShowing;
	}
}

- (void)setIsPlayerPlaylistShowing:(BOOL)isEnabled
{
	@synchronized(self)
	{
		if (_isPlayerPlaylistShowing != isEnabled)
		{
			_isPlayerPlaylistShowing = isEnabled;
			[_userDefaults setBool:isEnabled forKey:@"isPlayerPlaylistShowing"];
			[_userDefaults synchronize];
		}
	}
}

- (BOOL)isAutoReloadArtistsEnabled
{
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"autoReloadArtistsSetting"];
	}
}

- (void)setIsAutoReloadArtistsEnabled:(BOOL)isAutoReloadArtistsEnabled
{
	@synchronized(self)
	{
		[_userDefaults setBool:isAutoReloadArtistsEnabled forKey:@"autoReloadArtistsSetting"];
		[_userDefaults synchronize];
	}
}

- (float)scrobblePercent
{
	@synchronized(self)
	{
		return [_userDefaults floatForKey:@"scrobblePercentSetting"];
	}
}

- (void)setScrobblePercent:(float)scrobblePercent
{
	@synchronized(self)
	{
		[_userDefaults setFloat:scrobblePercent forKey:@"scrobblePercentSetting"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isScrobbleEnabled
{
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"enableScrobblingSetting"];
	}
}

- (void)setIsScrobbleEnabled:(BOOL)isScrobbleEnabled
{
	@synchronized(self)
	{
		[_userDefaults setBool:isScrobbleEnabled forKey:@"enableScrobblingSetting"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isRotationLockEnabled
{
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"lockRotationSetting"];
	}
}

- (void)setIsRotationLockEnabled:(BOOL)isRotationLockEnabled
{
	@synchronized(self)
	{
		[_userDefaults setBool:isRotationLockEnabled forKey:@"lockRotationSetting"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isJukeboxEnabled
{
	@synchronized(self)
	{
		if (self.isJukeboxUnlocked)
			return _isJukeboxEnabled;
		else
			return NO;
	}
}

- (void)setIsJukeboxEnabled:(BOOL)enabled
{
	@synchronized(self)
	{
		_isJukeboxEnabled = enabled;
		[_userDefaults setBool:enabled forKey:@"isJukeboxEnabled"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isScreenSleepEnabled
{
	@synchronized(self)
	{
		return _isScreenSleepEnabled;
	}
}

- (void)setIsScreenSleepEnabled:(BOOL)enabled
{
	@synchronized(self)
	{
		_isScreenSleepEnabled = enabled;
		[_userDefaults setBool:enabled forKey:@"isScreenSleepEnabled"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isPopupsEnabled
{
	@synchronized(self)
	{
		return _isPopupsEnabled;
	}
}

- (void)setIsPopupsEnabled:(BOOL)enabled
{
	@synchronized(self)
	{
		_isPopupsEnabled = enabled;
		[_userDefaults setBool:enabled forKey:@"isPopupsEnabled"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isUpdateCheckEnabled
{
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"checkUpdatesSetting"];
	}
}

- (void)setIsUpdateCheckEnabled:(BOOL)isUpdateCheckEnabled
{
	@synchronized(self)
	{
		[_userDefaults setBool:isUpdateCheckEnabled forKey:@"checkUpdatesSetting"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isUpdateCheckQuestionAsked
{
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"isUpdateCheckQuestionAsked"];
	}
}

- (void)setIsUpdateCheckQuestionAsked:(BOOL)isUpdateCheckQuestionAsked
{
	@synchronized(self)
	{
		[_userDefaults setBool:isUpdateCheckQuestionAsked forKey:@"isUpdateCheckQuestionAsked"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isVideoSupported
{
	@synchronized(self)
	{
		NSString *key = [NSString stringWithFormat:@"isVideoSupported%@", _urlString.md5];
		return [_userDefaults boolForKey:key];
	}
}

- (void)setIsVideoSupported:(BOOL)isVideoSupported
{
	@synchronized(self)
	{
		NSString *key = [NSString stringWithFormat:@"isVideoSupported%@", _urlString.md5];
		[_userDefaults setBool:isVideoSupported forKey:key];
		[_userDefaults synchronize];
	}
}

- (BOOL)isNewSearchAPI
{
	@synchronized(self)
	{
		NSString *key = [NSString stringWithFormat:@"isNewSearchAPI%@", _urlString.md5];
		return [_userDefaults boolForKey:key];
	}
}

- (void)setIsNewSearchAPI:(BOOL)isNewSearchAPI
{
	@synchronized(self)
	{
		NSString *key = [NSString stringWithFormat:@"isNewSearchAPI%@", _urlString.md5];
		[_userDefaults setBool:isNewSearchAPI forKey:key];
		[_userDefaults synchronize];
	}
}

- (BOOL)isRecover
{
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"recover"];
	}
}

- (void)setIsRecover:(BOOL)recover
{
	@synchronized(self)
	{
		_isRecover = recover;
		[_userDefaults setBool:recover forKey:@"recover"];
		[_userDefaults synchronize];
	}
}

- (double)seekTime
{
	@synchronized(self)
	{
		return [_userDefaults doubleForKey:@"seekTime"];
	}
}

- (void)setSeekTime:(double)seekTime
{
	@synchronized(self)
	{
		_secondsOffset = seekTime;
		[_userDefaults setDouble:seekTime forKey:@"seekTime"];
		[_userDefaults synchronize];
	}
}

- (unsigned long long)byteOffset
{
	@synchronized(self)
	{
		unsigned long long retVal = [[_userDefaults objectForKey:@"byteOffset"] unsignedLongLongValue];
		return retVal;
	}
}

- (void)setByteOffset:(unsigned long long)bOffset
{
	@synchronized(self)
	{
		_byteOffset = bOffset;
		NSNumber *num = [NSNumber numberWithUnsignedLongLong:_byteOffset];
		[_userDefaults setObject:num forKey:@"byteOffset"];
		[_userDefaults synchronize];
	}
}

- (NSInteger)bitRate
{
	@synchronized(self)
	{
		NSInteger rate = [[_userDefaults objectForKey:@"bitRate"] integerValue];
		if (rate < 0) 
			return 128;
		else 
			return rate;
	}
}

- (void)setBitRate:(NSInteger)rate
{
	@synchronized(self)
	{
		_bitRate = rate;
		NSNumber *num = [NSNumber numberWithInteger:_bitRate];
		[_userDefaults setObject:num forKey:@"bitRate"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isBasicAuthEnabled
{
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"isBasicAuthEnabled"];
	}
}

- (void)setIsBasicAuthEnabled:(BOOL)isBasicAuthEnabled
{
	@synchronized(self)
	{
		[_userDefaults setBool:isBasicAuthEnabled forKey:@"isBasicAuthEnabled"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isTapAndHoldEnabled
{
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"isTapAndHoldEnabled"];
	}
}

- (void)setIsTapAndHoldEnabled:(BOOL)isTapAndHoldEnabled
{
	@synchronized(self)
	{
		[_userDefaults setBool:isTapAndHoldEnabled forKey:@"isTapAndHoldEnabled"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isSwipeEnabled
{
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"isSwipeEnabled"];
	}
}

- (void)setIsSwipeEnabled:(BOOL)isSwipeEnabled
{
	@synchronized(self)
	{
		[_userDefaults setBool:isSwipeEnabled forKey:@"isSwipeEnabled"];
		[_userDefaults synchronize];
	}
}

- (float)gainMultiplier
{
	@synchronized(self)
	{
		return _gainMultiplier;
	}
}

- (void)setGainMultiplier:(float)multiplier
{
	@synchronized(self)
	{
		_gainMultiplier = multiplier;
		[_userDefaults setFloat:multiplier forKey:@"gainMultiplier"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isPartialCacheNextSong
{
	@synchronized(self)
	{
		return _isPartialCacheNextSong;
	}
}

- (void)setIsPartialCacheNextSong:(BOOL)partialCache
{
	@synchronized(self)
	{
		_isPartialCacheNextSong = partialCache;
		[_userDefaults setBool:_isPartialCacheNextSong forKey:@"isPartialCacheNextSong"];
		[_userDefaults synchronize];
	}
}

- (ISMSBassVisualType)currentVisualizerType
{
	@synchronized(self)
	{
		return [_userDefaults integerForKey:@"currentVisualizerType"];
	}
}

- (void)setCurrentVisualizerType:(ISMSBassVisualType)currentVisualizerType
{
	@synchronized(self)
	{
		[_userDefaults setInteger:currentVisualizerType forKey:@"currentVisualizerType"];
		[_userDefaults synchronize];
	}

}

- (BOOL)isExtraPlayerControlsShowing
{
	@synchronized(self)
	{
		return _isExtraPlayerControlsShowing;
	}
}

- (void)setIsExtraPlayerControlsShowing:(BOOL)isShowing
{
	@synchronized(self)
	{
		if (_isExtraPlayerControlsShowing != isShowing)
		{
			_isExtraPlayerControlsShowing = isShowing;
			[_userDefaults setBool:isShowing forKey:@"isExtraPlayerControlsShowing"];
			[_userDefaults synchronize];
		}
	}
}

- (NSUInteger)quickSkipNumberOfSeconds
{
	@synchronized(self)
	{
		return _quickSkipNumberOfSeconds;
	}
}

- (void)setQuickSkipNumberOfSeconds:(NSUInteger)numSeconds
{
	@synchronized(self)
	{
		if (_quickSkipNumberOfSeconds != numSeconds)
		{
			_quickSkipNumberOfSeconds = numSeconds;
			[_userDefaults setInteger:numSeconds forKey:@"quickSkipNumberOfSeconds"];
			[_userDefaults synchronize];
		}
	}
}

- (BOOL)isShouldShowEQViewInstructions
{
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"isShouldShowEQViewInstructions"];
	}
}

- (void)setIsShouldShowEQViewInstructions:(BOOL)isShouldShowEQViewInstructions
{
	@synchronized(self)
	{
		[_userDefaults setBool:isShouldShowEQViewInstructions forKey:@"isShouldShowEQViewInstructions"];
		[_userDefaults synchronize];
	}
}

- (NSUInteger)audioEngineStartNumberOfSeconds
{
	@synchronized(self)
	{
		return _audioEngineStartNumberOfSeconds;
	}
}

- (void)setAudioEngineStartNumberOfSeconds:(NSUInteger)numSeconds
{
	@synchronized(self)
	{
		if (_audioEngineStartNumberOfSeconds != numSeconds)
		{
			_audioEngineStartNumberOfSeconds = numSeconds;
			[_userDefaults setInteger:numSeconds forKey:@"audioEngineStartNumberOfSeconds"];
			[_userDefaults synchronize];
		}
	}
}

- (NSUInteger)audioEngineBufferNumberOfSeconds
{
	@synchronized(self)
	{
		return _audioEngineBufferNumberOfSeconds;
	}
}

- (void)setAudioEngineBufferNumberOfSeconds:(NSUInteger)numSeconds
{
	@synchronized(self)
	{
		if (_audioEngineBufferNumberOfSeconds != numSeconds)
		{
			_audioEngineBufferNumberOfSeconds = numSeconds;
			[_userDefaults setInteger:numSeconds forKey:@"audioEngineBufferNumberOfSeconds"];
			[_userDefaults synchronize];
		}
	}
}

- (BOOL)isShowLargeSongInfoInPlayer
{
	@synchronized(self)
	{
		return _isShowLargeSongInfoInPlayer;
	}
}

- (void)setIsShowLargeSongInfoInPlayer:(BOOL)isShow
{
	@synchronized(self)
	{
		if (_isShowLargeSongInfoInPlayer != isShow)
		{
			_isShowLargeSongInfoInPlayer = isShow;
			[_userDefaults setBool:isShow forKey:@"isShowLargeSongInfoInPlayer"];
			[_userDefaults synchronize];
		}
	}
}

- (BOOL)isLockScreenArtEnabled
{
	@synchronized(self)
	{
		return _isLockScreenArtEnabled;
	}
}

- (void)setIsLockScreenArtEnabled:(BOOL)isEnabled
{
	@synchronized(self)
	{
		if (_isLockScreenArtEnabled != isEnabled)
		{
			_isLockScreenArtEnabled = isEnabled;
			[_userDefaults setBool:isEnabled forKey:@"isLockScreenArtEnabled"];
			[_userDefaults synchronize];
		}
	}
}

- (BOOL)isEqualizerOn
{
	@synchronized(self)
	{
		return _isEqualizerOn;
	}
}

- (void)setIsEqualizerOn:(BOOL)isOn
{
	@synchronized(self)
	{
		_isEqualizerOn = isOn;
		[_userDefaults setBool:_isEqualizerOn forKey:@"isEqualizerOn"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isTestServer
{
	return [_urlString isEqualToString:DEFAULT_URL];
}

- (NSUInteger)oneTimeRunIncrementor
{
	@synchronized(self)
	{
		return [_userDefaults integerForKey:@"oneTimeRunIncrementor"];
	}
}

- (void)setOneTimeRunIncrementor:(NSUInteger)oneTimeRunIncrementor
{
	@synchronized(self)
	{
        [_userDefaults setInteger:oneTimeRunIncrementor forKey:@"oneTimeRunIncrementor"];
        [_userDefaults synchronize];
	}
}

#pragma mark - Singleton methods

- (void)setup
{	
	// Disable screen sleep if necessary
	if (!self.isScreenSleepEnabled)
		[UIApplication sharedApplication].idleTimerDisabled = YES;
	
	_userDefaults = [NSUserDefaults standardUserDefaults];
	_serverList = nil;
	
	_redirectUrlString = nil;
	
    //DLog(@"urlString: %@", urlString);
	
	[self createInitialSettings];
	
    //DLog(@"urlString: %@", urlString);
    
	// If the settings are not set up, convert them
	if ([_userDefaults boolForKey:@"areSettingsSetup"])
	{
		NSData *servers = [_userDefaults objectForKey:@"servers"];
		if (servers)
		{
			self.serverList = [NSKeyedUnarchiver unarchiveObjectWithData:servers];
		}
	}
	
//DLog(@"urlString: %@", urlString);
	
	// Cache certain settings to memory for speed
	[self memCacheDefaults];
	
//DLog(@"urlString: %@", urlString);
}

+ (id)sharedInstance
{
    static SavedSettings *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
