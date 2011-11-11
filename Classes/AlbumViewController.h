//
//  AlbumViewController.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SUSLoaderDelegate.h"

@class iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, DatabaseSingleton, Artist, Album, EGORefreshTableHeaderView, SUSSubFolderDAO;

@interface AlbumViewController : UITableViewController <SUSLoaderDelegate>
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	
	NSURLConnection *connection;
	NSMutableData *loadingData;
	
	NSString *myId;
	Artist *myArtist;
	Album *myAlbum;
	
	NSArray *sectionInfo;
	
	EGORefreshTableHeaderView *refreshHeaderView;
	BOOL _reloading;
}

@property(assign,getter=isReloading) BOOL reloading;
	
@property (nonatomic, retain) NSString *myId;
@property (nonatomic, retain) Artist *myArtist;
@property (nonatomic, retain) Album *myAlbum;

@property (nonatomic, retain) NSArray *sectionInfo;

@property (nonatomic, retain) SUSSubFolderDAO *dataModel;

- (AlbumViewController *)initWithArtist:(Artist *)anArtist orAlbum:(Album *)anAlbum;

- (void)cancelLoad;

@end
