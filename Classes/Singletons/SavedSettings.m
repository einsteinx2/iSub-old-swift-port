//
//  SavedSettings.m
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SavedSettings.h"
#import "iSub-Swift.h"
#import "BassGaplessPlayer.h"

@interface SavedSettings ()
{
    NSUserDefaults *_userDefaults;
    
    long long _currentServerId;
    Server *_currentServer;
    
    // State Saving
    BOOL _isPlaying;
    NSInteger _playQueueIndex;
    RepeatMode _repeatMode;
    ShuffleMode _shuffleMode;
    NSInteger _bitRate;
    unsigned long long _byteOffset;
    double _secondsOffset;
    BOOL _isRecover;
    NSString *_currentTwitterAccount;
}
@end

@implementation SavedSettings

- (void)loadState
{	
	_isPlaying = [_userDefaults boolForKey:@"isPlaying"];
		
	_shuffleMode = (ShuffleMode)[_userDefaults integerForKey:@"shuffleMode"];
	PlayQueue.si.shuffleMode = _shuffleMode;
	
	_playQueueIndex = [_userDefaults integerForKey:@"playQueueIndex"];
    // TODO: Is this next line necessary?
	//PlayQueue.si.currentIndex = _playQueueIndex;
	
    _currentTwitterAccount = [_userDefaults objectForKey:@"currentTwitterAccount"];
	
	_repeatMode = (RepeatMode)[_userDefaults integerForKey:@"repeatMode"];
	PlayQueue.si.repeatMode = _repeatMode;
	
	_bitRate = [_userDefaults integerForKey:@"bitRate"];
	_byteOffset = self.byteOffset;
	_secondsOffset = self.seekTime;
	_isRecover = self.isRecover;
    _sessionId = self.sessionId;
	
	AudioEngine.si.startByteOffset = _byteOffset;
}

- (void)setupSaveState
{	
	// Load saved state first
	[self loadState];
	
	// Start the timer
	[NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(saveState) userInfo:nil repeats:YES];
}

- (void)saveState
{
	@autoreleasepool
	{
		BOOL isDefaultsDirty = NO;
		
		if (PlayQueue.si.isPlaying != _isPlaying)
		{
			_isPlaying = PlayQueue.si.isPlaying;
			
			[_userDefaults setBool:_isPlaying forKey:@"isPlaying"];
			isDefaultsDirty = YES;
		}
        
        PlayQueue *playQueue = PlayQueue.si;
		
		if (playQueue.shuffleMode != _shuffleMode)
		{
			_shuffleMode = playQueue.shuffleMode;
			[_userDefaults setBool:_shuffleMode forKey:@"shuffleMode"];
			isDefaultsDirty = YES;
		}
		
		if (playQueue.currentIndex != _playQueueIndex)
		{
			_playQueueIndex = playQueue.currentIndex;
			[_userDefaults setInteger:_playQueueIndex forKey:@"playQueueIndex"];
			isDefaultsDirty = YES;
		}
		
		if (playQueue.repeatMode != _repeatMode)
		{
			_repeatMode = playQueue.repeatMode;
			[_userDefaults setInteger:_repeatMode forKey:@"repeatMode"];
			isDefaultsDirty = YES;
		}
		
		if (AudioEngine.si.player.bitRate != _bitRate && AudioEngine.si.player.bitRate >= 0)
		{
			_bitRate = AudioEngine.si.player.bitRate;
			[_userDefaults setInteger:_bitRate forKey:@"bitRate"];
			isDefaultsDirty = YES;
		}
		
        if (_secondsOffset != PlayQueue.si.currentSongProgress)
		{
			_secondsOffset = PlayQueue.si.currentSongProgress;
			[_userDefaults setDouble:_secondsOffset forKey:@"seekTime"];
			isDefaultsDirty = YES;
		}
        
        if (_byteOffset != AudioEngine.si.player.currentByteOffset)
		{
			_byteOffset = AudioEngine.si.player.currentByteOffset;
			[_userDefaults setObject:@(_byteOffset) forKey:@"byteOffset"];
			isDefaultsDirty = YES;
		}
				
		BOOL newIsRecover = NO;
		if (_isPlaying)
		{
			if (self.recoverSetting == 0)
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
		[_userDefaults setObject:@(1073741824) forKey:@"maxCacheSize"];
		[_userDefaults setObject:@(268435456) forKey:@"minFreeSpace"];
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
		[_userDefaults setBool:YES forKey:@"isScreenSleepEnabled"];
		[_userDefaults setBool:YES forKey:@"isPopupsEnabled"];
		[_userDefaults setBool:NO forKey:@"checkUpdatesSetting"];
		[_userDefaults setBool:NO forKey:@"isUpdateCheckQuestionAsked"];
		[_userDefaults setBool:NO forKey:@"isBasicAuthEnabled"];
		[_userDefaults setBool:YES forKey:@"checkUpdatesSetting"];
	}
	
	// New settings 3.0.5 beta 18
	if (![_userDefaults objectForKey:@"gainMultiplier"])
	{
		[_userDefaults setFloat:1.0 forKey:@"gainMultiplier"];
	}
    
    if (![_userDefaults objectForKey:@"maxVideoBitrateWifi"])
    {
        self.maxVideoBitrateWifi = 5;
        self.maxVideoBitrate3G = 5;
    }
    
    if (![_userDefaults objectForKey:@"currentServerId"]) {
        _currentServer = [Server testServer];
        _currentServerId = _currentServer.serverId;
    } else {
        _currentServerId = [_userDefaults integerForKey:@"currentServerId"];
    }
	
	[_userDefaults synchronize];
}

#pragma mark - Login Settings

- (long long)currentServerId
{
    @synchronized(self)
    {
        return _currentServerId;
    }
}

- (void)setCurrentServerId:(long long)currentServerId
{
    @synchronized(self)
    {
        _currentServer = [Server serverWithServerId: currentServerId];
        _currentServerId = _currentServer.serverId;
        [_userDefaults setObject:@(_currentServerId) forKey:@"currentServerId"];
        [_userDefaults synchronize];
    }
}

- (Server *)currentServer
{
	@synchronized(self)
	{
        if (_currentServerId == [Server testServerId])
        {
            return [Server testServer];
        }
        
        if (_currentServer == nil)
        {
            _currentServer = [Server serverWithServerId: _currentServerId];
        }
        
        return _currentServer;
	}
}

- (NSString *)currentTwitterAccount
{
	@synchronized(self)
	{
		return _currentTwitterAccount;
	}
}

- (void)setCurrentTwitterAccount:(NSString *)identifier
{
	@synchronized(self)
	{
		_currentTwitterAccount = [identifier copy];
        
        NSString *key = @"currentTwitterAccount";
		[_userDefaults setObject:_currentTwitterAccount forKey:key];
		[_userDefaults synchronize];
	}
}

#pragma mark - Document Folder Paths

+ (NSString *)documentsPath
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	return paths[0];
}

+ (NSString *)cachesPath
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	return paths[0];
}

#pragma mark - Other Settings

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
        switch (AppDelegate.si.networkStatus.isReachableWifi ? self.maxBitrateWifi : self.maxBitrate3G)
		{
			case 0: return 64;
			case 1: return 96;
			case 2: return 128;
			case 3: return 160;
			case 4: return 192;
			case 5: return 256;
			case 6: return 320;
			default: return 0;
		}
	}
}

- (NSInteger)maxVideoBitrateWifi
{
	@synchronized(self)
	{
		return [_userDefaults integerForKey:@"maxVideoBitrateWifi"];
	}
}

- (void)setMaxVideoBitrateWifi:(NSInteger)maxVideoBitrateWifi
{
	@synchronized(self)
	{
		[_userDefaults setInteger:maxVideoBitrateWifi forKey:@"maxVideoBitrateWifi"];
		[_userDefaults synchronize];
	}
}

- (NSInteger)maxVideoBitrate3G
{
	@synchronized(self)
	{
		return [_userDefaults integerForKey:@"maxVideoBitrate3G"];
	}
}

- (void)setMaxVideoBitrate3G:(NSInteger)maxVideoBitrate3G
{
	@synchronized(self)
	{
		[_userDefaults setInteger:maxVideoBitrate3G forKey:@"maxVideoBitrate3G"];
		[_userDefaults synchronize];
	}
}

- (NSArray *)currentVideoBitrates
{    
    @synchronized(self)
	{
        switch (AppDelegate.si.networkStatus.isReachableWifi ? self.maxVideoBitrateWifi : self.maxVideoBitrate3G)
		{
			case 0: return @[@60];
			case 1: return @[@256, @60];
			case 2: return @[@512, @256, @60];
			case 3: return @[@1024, @512, @256, @60];
			case 4: return @[@1536, @1024, @512, @256, @60];
			case 5: return @[@2048, @1536, @1024, @512, @256, @60];
			default: return nil;
		}
	}
}

- (NSInteger)currentMaxVideoBitrate
{
	@synchronized(self)
	{
        switch (AppDelegate.si.networkStatus.isReachableWifi ? self.maxVideoBitrateWifi : self.maxVideoBitrate3G)
        {
			case 0: return 60;
			case 1: return 256;
			case 2: return 512;
			case 3: return 1024;
			case 4: return 1536;
			case 5: return 2048;
			default: return 0;
		}
	}
}

- (BOOL)isSongCachingEnabled
{
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"enableSongCachingSetting"];
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

- (BOOL)isBackupCacheEnabled
{
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"isBackupCacheEnabled"];
	}
}

- (void)setIsBackupCacheEnabled:(BOOL)isBackupCacheEnabled
{
	@synchronized(self)
	{
		[_userDefaults setBool:isBackupCacheEnabled forKey:@"isBackupCacheEnabled"];
		[_userDefaults synchronize];
	}
    
    if (isBackupCacheEnabled)
    {
        // Set all cached songs to removeSkipBackup
        [CacheSingleton.si setAllCachedSongsToBackup];
 
    }
    else
    {
        //Set all cached songs to removeSkipBackup
        [CacheSingleton.si setAllCachedSongsToNotBackup];
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
        
        if (AppDelegate.si.networkStatus.isReachableWifi)
        {
            isManualCachingOnWWANEnabled ? [CacheQueueManager.si start] : [CacheQueueManager.si stop];
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
		[_userDefaults setObject:@(maxCacheSize) forKey:@"maxCacheSize"];
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
		[_userDefaults setObject:@(minFreeSpace) forKey:@"minFreeSpace"];
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
        return [_userDefaults boolForKey:@"enableSongsTabSetting"];
	}
}

- (void)setIsPlayerPlaylistShowing:(BOOL)isEnabled
{
	@synchronized(self)
	{
        [_userDefaults setBool:isEnabled forKey:@"isPlayerPlaylistShowing"];
        [_userDefaults synchronize];
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

- (BOOL)isScreenSleepEnabled
{
	@synchronized(self)
	{
        return [_userDefaults boolForKey:@"isScreenSleepEnabled"];
	}
}

- (void)setIsScreenSleepEnabled:(BOOL)enabled
{
	@synchronized(self)
	{
		[_userDefaults setBool:enabled forKey:@"isScreenSleepEnabled"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isPopupsEnabled
{
	@synchronized(self)
	{
        return [_userDefaults boolForKey:@"isPopupsEnabled"];
	}
}

- (void)setIsPopupsEnabled:(BOOL)enabled
{
	@synchronized(self)
	{
		[_userDefaults setBool:enabled forKey:@"isPopupsEnabled"];
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
		[_userDefaults setObject:@(_byteOffset) forKey:@"byteOffset"];
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
		[_userDefaults setObject:@(_bitRate) forKey:@"bitRate"];
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

- (float)gainMultiplier
{
	@synchronized(self)
	{
        return [_userDefaults floatForKey:@"gainMultiplier"];
	}
}

- (void)setGainMultiplier:(float)multiplier
{
	@synchronized(self)
	{
		[_userDefaults setFloat:multiplier forKey:@"gainMultiplier"];
		[_userDefaults synchronize];
	}
}

- (NSInteger)quickSkipNumberOfSeconds
{
	@synchronized(self)
	{
        return [_userDefaults integerForKey:@"quickSkipNumberOfSeconds"];
	}
}

- (void)setQuickSkipNumberOfSeconds:(NSInteger)numSeconds
{
	@synchronized(self)
	{
        [_userDefaults setInteger:numSeconds forKey:@"quickSkipNumberOfSeconds"];
        [_userDefaults synchronize];
	}
}

- (BOOL)isEqualizerOn
{
	@synchronized(self)
	{
        return [_userDefaults boolForKey:@"isEqualizerOn"];
	}
}

- (void)setIsEqualizerOn:(BOOL)isOn
{
	@synchronized(self)
	{
        [_userDefaults setBool:isOn forKey:@"isEqualizerOn"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isDisableUsageOver3G
{
	@synchronized(self)
	{
		return [_userDefaults boolForKey:@"isDisableUsageOver3G"];
	}
}

- (void)setIsDisableUsageOver3G:(BOOL)isDisableUsageOver3G
{
	@synchronized(self)
	{
		[_userDefaults setBool:isDisableUsageOver3G forKey:@"isDisableUsageOver3G"];
		[_userDefaults synchronize];
	}
}

- (BOOL)isTestServer
{
    return [self.currentServer isEqual:[Server testServer]];
}

#pragma mark - Singleton methods

- (void)setup
{
	[UIApplication sharedApplication].idleTimerDisabled = !self.isScreenSleepEnabled;
	
	_userDefaults = [NSUserDefaults standardUserDefaults];
	_serverList = nil;
			
	[self createInitialSettings];
    
    [self setupSaveState];
}

+ (instancetype)si
{
    static SavedSettings *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
	});
    return sharedInstance;
}

@end
