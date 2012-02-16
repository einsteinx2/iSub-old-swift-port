//
//  HomeAlbumViewController.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@class iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, DatabaseSingleton, Artist, Album;

@interface HomeAlbumViewController : UITableViewController 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
		
	NSMutableArray *listOfAlbums;
	
	NSString *searchModifier;
	NSUInteger offset;
	BOOL isMoreAlbums;
	BOOL isLoading;
}

@property (retain) NSMutableData *receivedData;

@property (retain) NSMutableArray *listOfAlbums;

@property (retain) NSString *modifier;
@property NSUInteger offset;
@property BOOL isMoreAlbums;

@end
