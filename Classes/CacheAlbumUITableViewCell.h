//
//  AlbumUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#include "CustomUITableViewCell.h"

@interface CacheAlbumUITableViewCell : CustomUITableViewCell 

@property NSInteger segment;
@property (nonatomic, retain) NSString *seg1;

@property (nonatomic, retain) UIImageView *coverArtView;
@property (nonatomic, retain) UIScrollView *albumNameScrollView;
@property (nonatomic, retain) UILabel *albumNameLabel;

@end
