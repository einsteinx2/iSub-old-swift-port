//
//  AllAlbumsUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@class AsynchronousImageView, Artist;

@interface AllAlbumsUITableViewCell : CustomUITableViewCell 

@property (copy) NSString *myId;
@property (strong) Artist *myArtist;

@property (strong) AsynchronousImageView *coverArtView;
@property (strong) UIScrollView *albumNameScrollView;
@property (strong) UILabel *albumNameLabel;
@property (strong) UILabel *artistNameLabel;

@end
