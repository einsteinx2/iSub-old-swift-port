//
//  PlaylistsUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@interface LocalPlaylistsUITableViewCell : CustomUITableViewCell 

@property (retain) NSString *md5;

@property (retain) UILabel *playlistCountLabel;
@property (retain) UIScrollView *playlistNameScrollView;
@property (retain) UILabel *playlistNameLabel;

@end
