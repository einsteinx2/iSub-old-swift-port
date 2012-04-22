//
//  PlaylistSongsViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class EGORefreshTableHeaderView, SUSServerPlaylist;

@interface PlaylistSongsViewController : UITableViewController
{

	EGORefreshTableHeaderView *refreshHeaderView;
	BOOL _reloading;
}

@property(assign,getter=isReloading) BOOL reloading;

@property (copy) NSString *md5;
@property NSUInteger playlistCount;

@property (copy) SUSServerPlaylist *serverPlaylist;
@property (strong) NSMutableData *receivedData;
@property (strong) NSURLConnection *connection;

- (void)parseData;

@end
