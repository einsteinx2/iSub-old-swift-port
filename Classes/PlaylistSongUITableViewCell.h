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

@property (copy) NSString *playlistMD5;

@property (strong) AsynchronousImageView *coverArtView;
@property (strong) UILabel *numberLabel;
@property (strong) UIScrollView *nameScrollView;
@property (strong) UILabel *songNameLabel;
@property (strong) UILabel *artistNameLabel;

@end
