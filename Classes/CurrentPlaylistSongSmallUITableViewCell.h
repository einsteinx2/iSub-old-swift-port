//
//  PlaylistSongUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@interface CurrentPlaylistSongSmallUITableViewCell : CustomUITableViewCell 

@property (nonatomic, retain) UILabel *numberLabel;
@property (nonatomic, retain) UILabel *songNameLabel;
@property (nonatomic, retain) UILabel *artistNameLabel;
@property (nonatomic, retain) UILabel *durationLabel;

@end
