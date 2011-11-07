//
//  PlaylistSongsViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, DatabaseSingleton, EGORefreshTableHeaderView, SUSServerPlaylist;

@interface PlaylistSongsViewController : UITableViewController
{
	iSubAppDelegate *appDelegate;	
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;

	NSString *md5;
	
	NSMutableData *receivedData;
	NSURLConnection *connection;
	
	NSUInteger playlistCount;
	
	EGORefreshTableHeaderView *refreshHeaderView;
	BOOL _reloading;
}

@property(assign,getter=isReloading) BOOL reloading;

@property (nonatomic, copy) NSString *md5;

@property (nonatomic, copy) SUSServerPlaylist *serverPlaylist;

@end
