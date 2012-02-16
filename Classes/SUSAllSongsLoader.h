//
//  SUSAllSongsLoader.h
//  iSub
//
//  Created by Ben Baron on 9/23/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSLoader.h"

#define READ_BUFFER_AMOUNT 400
#define WRITE_BUFFER_AMOUNT 400

@class ViewObjectsSingleton, DatabaseSingleton, SavedSettings, Artist, Album, SUSRootFoldersDAO;

@interface SUSAllSongsLoader : SUSLoader
{
	ViewObjectsSingleton *viewObjects;
	DatabaseSingleton *databaseControls;
	SavedSettings *settings;
}

@property NSInteger iteration;
@property NSUInteger albumCount;
@property NSUInteger artistCount;
@property NSUInteger currentRow;

@property NSUInteger tempAlbumsCount;
@property NSUInteger tempSongsCount;
@property NSUInteger tempGenresCount;
@property NSUInteger tempGenresLayoutCount;

@property NSUInteger totalAlbumsProcessed;
@property NSUInteger totalSongsProcessed;

@property (retain) Artist *currentArtist;
@property (retain) Album *currentAlbum;
@property (retain) SUSRootFoldersDAO *rootFolders;
@property (retain) NSDate *notificationTimeArtist;
@property (retain) NSDate *notificationTimeAlbum;
@property (retain) NSDate *notificationTimeSong;
@property (retain) NSDate *notificationTimeArtistAlbum;

+ (BOOL)isLoading;
+ (void)setIsLoading:(BOOL)isLoading;

@end
