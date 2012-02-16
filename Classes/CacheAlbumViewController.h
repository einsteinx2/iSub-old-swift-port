//
//  CacheAlbumsViewController.h
//  iSub
//
//  Created by Ben Baron on 6/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, DatabaseSingleton;

@interface CacheAlbumViewController : UITableViewController 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	
	NSMutableArray *listOfAlbums;
	NSMutableArray *listOfSongs;
	
	NSArray *sectionInfo;
	
	NSInteger segment;
	NSString *seg1;
}

@property (retain) NSMutableArray *listOfAlbums;
@property (retain) NSMutableArray *listOfSongs;

@property (retain) NSArray *sectionInfo;


@property NSInteger segment;
@property (retain) NSString *seg1;

@end
