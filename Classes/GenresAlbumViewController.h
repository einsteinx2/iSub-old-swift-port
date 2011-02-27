//
//  CacheAlbumsViewController.h
//  iSub
//
//  Created by Ben Baron on 6/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class iSubAppDelegate, ViewObjectsSingleton, MusicControlsSingleton, DatabaseControlsSingleton;

@interface GenresAlbumViewController : UITableViewController 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicControlsSingleton *musicControls;
	DatabaseControlsSingleton *databaseControls;
	
	NSMutableArray *listOfAlbums;
	NSMutableArray *listOfSongs;
	
	NSInteger segment;
	NSString *seg1;
	NSString *genre;
}

@property (nonatomic, retain) NSMutableArray *listOfAlbums;
@property (nonatomic, retain) NSMutableArray *listOfSongs;

@property NSInteger segment;
@property (nonatomic, retain) NSString *seg1;
@property (nonatomic, retain) NSString *genre;

@end
