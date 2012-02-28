//
//  PlaylistSongUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@class AsynchronousImageView;

@interface PlaylistSongUITableViewCell : CustomUITableViewCell 

@property (retain) NSString *playlistMD5;

@property (retain) AsynchronousImageView *coverArtView;
@property (retain) UILabel *numberLabel;
@property (retain) UIScrollView *nameScrollView;
@property (retain) UILabel *songNameLabel;
@property (retain) UILabel *artistNameLabel;

@end
