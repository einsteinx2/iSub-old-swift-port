//
//  PlayingUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#include "CustomUITableViewCell.h"

@class AsynchronousImageView;

@interface CacheQueueSongUITableViewCell : CustomUITableViewCell 

@property (retain) AsynchronousImageView *coverArtView;
@property (retain) UILabel *cacheInfoLabel;
@property (retain) UIScrollView *nameScrollView;
@property (retain) UILabel *songNameLabel;
@property (retain) UILabel *artistNameLabel;
@property (copy) NSString *md5;

@end
