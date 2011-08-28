//
//  SavedSettings.h
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface SavedSettings : NSObject 
{
	NSUserDefaults *settings;
	
	NSString *urlString;
	NSString *username;
	NSString *password;
	
	BOOL isPopupsEnabled;
	BOOL isJukeboxEnabled;
	BOOL isScreenSleepEnabled;
	
	/*NSInteger cacheType;
	unsigned long long minFreeSpace;
	unsigned long long maxCacheSize;
	BOOL enableCache;
	BOOL autoDeleteCache;*/
	
	//NSDate *rootFoldersReloadTime;
	//NSNumber *rootFoldersSelectedFolderId;
}

// Server Login Settings
@property (nonatomic, retain) NSString *urlString;
@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *password;

// Root Folders Settings
@property (nonatomic, retain) NSDate *rootFoldersReloadTime;
@property (nonatomic, retain) NSNumber *rootFoldersSelectedFolderId;

@property BOOL isForceOfflineMode;
@property NSInteger recoverSetting;
@property NSInteger maxBitrateWifi;
@property NSInteger maxBitrate3G;
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

// Document Paths
@property (readonly) NSString *documentsPath;
@property (readonly) NSString *databasePath;
@property (readonly) NSString *cachePath;
@property (readonly) NSString *tempCachePath;

/*@property NSInteger cacheType;
@property unsigned long long minFreeSpace;
@property unsigned long long maxCacheSize;
@property BOOL enableCache;
@property BOOL autoDeleteCache;*/

+ (SavedSettings *)sharedInstance;

@end
