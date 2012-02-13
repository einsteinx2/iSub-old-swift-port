//
//  SavedSettings.h
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "BassEffectDAO.h"

@class AudioEngine;
@interface SavedSettings : NSObject 
{    
	NSUserDefaults *userDefaults;
	
	NSMutableArray *serverList;
	NSString *urlString;
	NSString *username;
	NSString *password;
	
	BOOL isPopupsEnabled;
	BOOL isJukeboxEnabled;
	BOOL isScreenSleepEnabled;
	float gainMultiplier;
	BOOL isPartialCacheNextSong;
	
	// State Saving
	BOOL isPlaying;	
	BOOL isShuffle;
	NSInteger normalPlaylistIndex;
	NSInteger shufflePlaylistIndex;
	NSInteger repeatMode;
	NSInteger bitRate;
	unsigned long long byteOffset;
	double secondsOffset;
	BOOL isRecover;
	NSInteger recoverSetting;
}

// Server Login Settings
@property (nonatomic, retain) NSMutableArray *serverList;
@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;

@property (nonatomic, copy) NSString *redirectUrlString;

// Root Folders Settings
@property (nonatomic, retain) NSDate *rootFoldersReloadTime;
@property (nonatomic, retain) NSNumber *rootFoldersSelectedFolderId;

// Lite Version Properties
@property (readonly) BOOL isPlaylistUnlocked;
@property (readonly) BOOL isJukeboxUnlocked;
@property (readonly) BOOL isCacheUnlocked;

@property BOOL isForceOfflineMode;
@property NSInteger recoverSetting;
@property NSInteger maxBitrateWifi;
@property NSInteger maxBitrate3G;
@property (readonly) NSInteger currentMaxBitrate;
@property BOOL isSongCachingEnabled;
@property BOOL isNextSongCacheEnabled;
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
@property BOOL isAutoShowSongInfoEnabled;
@property BOOL isAutoReloadArtistsEnabled;
@property float scrobblePercent;
@property BOOL isScrobbleEnabled;
@property BOOL isRotationLockEnabled;
@property BOOL isJukeboxEnabled;
@property BOOL isScreenSleepEnabled;
@property BOOL isPopupsEnabled;
@property BOOL isUpdateCheckEnabled;
@property BOOL isUpdateCheckQuestionAsked;
@property BOOL isNewSearchAPI;
@property (readonly) BOOL isTestServer;
@property BOOL isBasicAuthEnabled;
@property BOOL isTapAndHoldEnabled;
@property BOOL isSwipeEnabled;
@property float gainMultiplier;
@property BOOL isPartialCacheNextSong;
@property ISMSBassVisualType currentVisualizerType;

// State Saving
@property BOOL isRecover;
@property double seekTime;
@property unsigned long long byteOffset;
@property NSInteger bitRate;

// Document Paths
@property (readonly) NSString *documentsPath;
@property (readonly) NSString *databasePath;
@property (readonly) NSString *cachesPath;
@property (readonly) NSString *songCachePath;
@property (readonly) NSString *tempCachePath;

/*- (BOOL)isSelectedIndexForBassEffectADefault:(BassEffectType)type;
- (NSUInteger)selectedIndexForBassEffect:(BassEffectType)type;
- (void)selectedIndexForBassEffect:(BassEffectType)type index:(NSUInteger)index isDefault:(BOOL)isDefault;*/

//- (NSString *)formatFileSize:(unsigned long long int)size;

- (void)setupSaveState;
- (void)loadState;
- (void)saveState;

+ (SavedSettings *)sharedInstance;

@end
