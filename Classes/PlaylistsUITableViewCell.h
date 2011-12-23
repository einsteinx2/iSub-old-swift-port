//
//  PlaylistsUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@class SUSServerPlaylist;

@interface PlaylistsUITableViewCell : CustomUITableViewCell 

@property (nonatomic, retain) UIScrollView *playlistNameScrollView;
@property (nonatomic, retain) UILabel *playlistNameLabel;

@property (nonatomic, retain) NSMutableData *receivedData;

@property (nonatomic, copy) SUSServerPlaylist *serverPlaylist;

@property (nonatomic) BOOL isDownload;

@end
