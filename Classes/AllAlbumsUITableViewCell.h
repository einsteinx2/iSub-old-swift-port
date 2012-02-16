//
//  AllAlbumsUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@class AsynchronousImageViewCached, Artist;

@interface AllAlbumsUITableViewCell : CustomUITableViewCell 

@property (retain) NSString *myId;
@property (retain) Artist *myArtist;

@property (retain) AsynchronousImageViewCached *coverArtView;
@property (retain) UIScrollView *albumNameScrollView;
@property (retain) UILabel *albumNameLabel;
@property (retain) UILabel *artistNameLabel;

@end
