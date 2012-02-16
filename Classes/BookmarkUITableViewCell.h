//
//  PlayingUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@class AsynchronousImageViewCached;

@interface BookmarkUITableViewCell : CustomUITableViewCell 

@property (retain) AsynchronousImageViewCached *coverArtView;
@property (retain) UILabel *bookmarkNameLabel;
@property (retain) UIScrollView *nameScrollView;
@property (retain) UILabel *songNameLabel;
@property (retain) UILabel *artistNameLabel;

@end
