//
//  CacheAlbumsViewController.h
//  iSub
//
//  Created by Ben Baron on 6/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <UIKit/UIKit.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

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

@property (nonatomic, retain) NSMutableArray *listOfAlbums;
@property (nonatomic, retain) NSMutableArray *listOfSongs;

@property (nonatomic, retain) NSArray *sectionInfo;


@property NSInteger segment;
@property (nonatomic, retain) NSString *seg1;

@end
