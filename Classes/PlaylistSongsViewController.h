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

	EGORefreshTableHeaderView *refreshHeaderView;
	BOOL _reloading;
}

@property(assign,getter=isReloading) BOOL reloading;

@property (copy) NSString *md5;
@property NSUInteger playlistCount;

@property (copy) SUSServerPlaylist *serverPlaylist;
@property (retain) NSMutableData *receivedData;
@property (retain) NSURLConnection *connection;

- (void)parseData;

@end
