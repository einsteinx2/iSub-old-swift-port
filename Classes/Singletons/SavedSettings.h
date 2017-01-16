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

typedef NS_ENUM(NSInteger, ISMSCachingType)
{
	ISMSCachingType_minSpace = 0,
	ISMSCachingType_maxSize = 1
};

@class AudioEngine, Server;
@interface SavedSettings : NSObject 

@property BOOL isOfflineMode;

// Server Login Settings
@property long long currentServerId;
@property (nonnull, readonly) Server *currentServer;
@property (nullable, strong) NSMutableArray *serverList;
@property (nullable, copy) NSString *sessionId;
@property (nullable, copy) NSString *redirectUrlString;

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
@property BOOL isCacheStatusEnabled;
@property BOOL isSongsTabEnabled;
@property BOOL isAutoReloadArtistsEnabled;
@property float scrobblePercent;
@property BOOL isScrobbleEnabled;
@property BOOL isRotationLockEnabled;
@property BOOL isScreenSleepEnabled;
@property BOOL isPopupsEnabled;
@property (readonly) BOOL isTestServer;
@property BOOL isBasicAuthEnabled;
@property float gainMultiplier;
@property NSInteger quickSkipNumberOfSeconds;

@property BOOL isEqualizerOn;

@property BOOL isDisableUsageOver3G;
@property (nullable, strong) NSString *currentTwitterAccount;

// State Saving
@property BOOL isRecover;
@property double seekTime;
@property unsigned long long byteOffset;
@property NSInteger bitRate;

// Document Paths

+ (nonnull NSString *)documentsPath;
+ (nonnull NSString *)cachesPath;

- (void)setupSaveState;
- (void)loadState;
- (void)saveState;

+ (nonnull instancetype)si;
- (void)setup;

@end

#endif
