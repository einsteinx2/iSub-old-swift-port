//
//  AlbumViewController.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@class iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, DatabaseSingleton, Artist, Album, EGORefreshTableHeaderView, FMResultSet;

@interface AlbumViewController : UITableViewController 
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
	
	NSMutableArray *listOfAlbums;
	NSMutableArray *listOfSongs;
	
	NSArray *sectionInfo;
	
	EGORefreshTableHeaderView *refreshHeaderView;
	BOOL _reloading;
			
	/*NSUInteger albumsCount;
	NSUInteger count;
	FMResultSet *albumsResult;
	FMResultSet *songsResult;*/
}

@property(assign,getter=isReloading) BOOL reloading;
	
@property (nonatomic, retain) NSString *myId;
@property (nonatomic, retain) Artist *myArtist;
@property (nonatomic, retain) Album *myAlbum;

@property (nonatomic, retain) NSMutableArray *listOfAlbums;
@property (nonatomic, retain) NSMutableArray *listOfSongs;

@property (nonatomic, retain) NSArray *sectionInfo;

/*@property (nonatomic, retain) FMResultSet *albumsResult;
@property (nonatomic, retain) FMResultSet *songsResult;*/

- (AlbumViewController *)initWithArtist:(Artist *)anArtist orAlbum:(Album *)anAlbum;

- (void)cancelLoad;

@end
