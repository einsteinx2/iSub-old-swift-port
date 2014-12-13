//
//  PlaylistSongsViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@class SUSServerPlaylist;

@interface PlaylistSongsViewController : CustomUITableViewController

@property (nonatomic, copy) NSString *md5;
@property (nonatomic, strong) SUSServerPlaylist *serverPlaylist;
@property (nonatomic, getter=isLocalPlaylist) BOOL localPlaylist;

@end
