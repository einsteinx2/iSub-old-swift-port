//
//  AllAlbumsUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#include "CustomUITableViewCell.h"

@class AsynchronousImageView;

@interface AllSongsUITableViewCell : CustomUITableViewCell 

@property (retain) NSString *md5;

@property (retain) AsynchronousImageView *coverArtView;
@property (retain) UIScrollView *songNameScrollView;
@property (retain) UILabel *songNameLabel;
@property (retain) UILabel *artistNameLabel;

@end
