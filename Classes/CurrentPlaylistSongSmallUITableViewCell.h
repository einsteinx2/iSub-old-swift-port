//
//  PlaylistSongUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@interface CurrentPlaylistSongSmallUITableViewCell : CustomUITableViewCell 

@property (retain) UILabel *numberLabel;
@property (retain) UILabel *songNameLabel;
@property (retain) UILabel *artistNameLabel;
@property (retain) UILabel *durationLabel;

@end
