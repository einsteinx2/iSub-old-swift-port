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
	
	/*NSInteger cacheType;
	unsigned long long minFreeSpace;
	unsigned long long maxCacheSize;
	BOOL enableCache;
	BOOL autoDeleteCache;*/
	
	//NSDate *rootFoldersReloadTime;
	//NSNumber *rootFoldersSelectedFolderId;
}

@property (nonatomic, retain) NSUserDefaults *settings;
@property (nonatomic, retain) NSString *urlString;
@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *password;

@property (nonatomic, retain) NSDate *rootFoldersReloadTime;
@property (nonatomic, retain) NSNumber *rootFoldersSelectedFolderId;

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
