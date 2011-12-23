//
//  PlaylistsUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@interface LocalPlaylistsUITableViewCell : CustomUITableViewCell 

@property (nonatomic, retain) NSString *md5;

@property (nonatomic, retain) UILabel *playlistCountLabel;
@property (nonatomic, retain) UIScrollView *playlistNameScrollView;
@property (nonatomic, retain) UILabel *playlistNameLabel;

@end
