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

@property (nonatomic, retain) NSString *myId;
@property (nonatomic, retain) Artist *myArtist;

@property (nonatomic, retain) AsynchronousImageViewCached *coverArtView;
@property (nonatomic, retain) UIScrollView *albumNameScrollView;
@property (nonatomic, retain) UILabel *albumNameLabel;
@property (nonatomic, retain) UILabel *artistNameLabel;

@end
