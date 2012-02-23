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
	BOOL isExtraPlayerControlsShowing;
	BOOL isPlayerPlaylistShowing;
	NSUInteger quickSkipNumberOfSeconds;
	
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
@property (retain) NSMutableArray *serverList;
@property (copy) NSString *urlString;
@property (copy) NSString *username;
@property (copy) NSString *password;

@property (copy) NSString *redirectUrlString;

// Root Folders Settings
@property (retain) NSDate *rootFoldersReloadTime;
@property (retain) NSNumber *rootFoldersSelectedFolderId;

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
@property NSUInteger quickSkipNumberOfSeconds;

@property BOOL isExtraPlayerControlsShowing;
@property BOOL isPlayerPlaylistShowing;


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
