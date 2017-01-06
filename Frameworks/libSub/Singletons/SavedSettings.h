//
//  SavedSettings.h
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#ifndef iSub_SavedSettings_h
#define iSub_SavedSettings_h

#import "BassEffectDAO.h"
#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import "libSubDefines.h"

#define settingsS ((SavedSettings *)[SavedSettings sharedInstance])

typedef NS_ENUM(NSInteger, ISMSCachingType)
{
	ISMSCachingType_minSpace = 0,
	ISMSCachingType_maxSize = 1
};

@class AudioEngine, Server;
@interface SavedSettings : NSObject 

@property BOOL isOfflineMode;

// Server Login Settings
@property NSInteger currentServerId;
@property (nonnull, readonly) NSString *currentServerUrl;
@property (nonnull, readonly) Server *currentServer;
@property (nullable, strong) NSMutableArray *serverList;
@property (nullable, copy) NSString *sessionId;

@property (nullable, copy) NSString *redirectUrlString;

// Root Folders Settings
@property (nullable, strong) NSDate *rootFoldersReloadTime;
@property (nullable, strong) NSNumber *rootFoldersSelectedFolderId;

// Lite Version Properties
@property (readonly) BOOL isPlaylistUnlocked;
@property (readonly) BOOL isCacheUnlocked;
@property (readonly) BOOL isVideoUnlocked;

@property BOOL isForceOfflineMode;
@property NSInteger recoverSetting;
@property NSInteger maxBitrateWifi;
@property NSInteger maxBitrate3G;
@property (readonly) NSInteger currentMaxBitrate;
@property NSInteger maxVideoBitrateWifi;
@property NSInteger maxVideoBitrate3G;
@property (nullable, readonly) NSArray *currentVideoBitrates;
@property BOOL isSongCachingEnabled;
@property BOOL isNextSongCacheEnabled;
@property BOOL isBackupCacheEnabled;
@property BOOL isManualCachingOnWWANEnabled;
@property NSInteger cachingType;
@property unsigned long long maxCacheSize;
@property unsigned long long minFreeSpace;
@property BOOL isAutoDeleteCacheEnabled;
@property NSInteger autoDeleteCacheType;
@property NSInteger cachedSongCellColorType;
@property BOOL isTwitterEnabled;
@property BOOL isLyricsEnabled;
@property BOOL isCacheStatusEnabled;
@property BOOL isSongsTabEnabled;
@property BOOL isAutoReloadArtistsEnabled;
@property float scrobblePercent;
@property BOOL isScrobbleEnabled;
@property BOOL isRotationLockEnabled;
@property BOOL isScreenSleepEnabled;
@property BOOL isPopupsEnabled;
@property BOOL isUpdateCheckEnabled;
@property BOOL isUpdateCheckQuestionAsked;
@property BOOL isNewSearchAPI;
@property BOOL isVideoSupported;
@property (readonly) BOOL isTestServer;
@property BOOL isBasicAuthEnabled;
@property BOOL isTapAndHoldEnabled;
@property BOOL isSwipeEnabled;
@property float gainMultiplier;
@property BOOL isPartialCacheNextSong;
@property ISMSBassVisualType currentVisualizerType;
@property NSUInteger quickSkipNumberOfSeconds;

@property BOOL isExtraPlayerControlsShowing;
@property BOOL isPlayerPlaylistShowing;

@property BOOL isShouldShowEQViewInstructions;

@property BOOL isShowLargeSongInfoInPlayer;

@property BOOL isLockScreenArtEnabled;

@property BOOL isEqualizerOn;

@property BOOL isDisableUsageOver3G;
@property (nullable, strong) NSString *currentTwitterAccount;

@property BOOL isCacheSizeTableFinished;

@property BOOL isStopCheckingWaveboxRelease;
@property BOOL isWaveBoxAlertShowing;

// State Saving
@property BOOL isRecover;
@property double seekTime;
@property unsigned long long byteOffset;
@property NSInteger bitRate;

// Document Paths

+ (nonnull NSString *)documentsPath;
+ (nonnull NSString *)databasePath;
+ (nonnull NSString *)cachesPath;
+ (nonnull NSURL *)cachesUrl;
+ (nonnull NSString *)currentCacheRoot;
+ (nonnull NSString *)songCachePath;
+ (nonnull NSString *)tempCachePath;

- (void)setupSaveState;
- (void)loadState;
- (void)saveState;

+ (nonnull instancetype)sharedInstance;

@end

#endif
