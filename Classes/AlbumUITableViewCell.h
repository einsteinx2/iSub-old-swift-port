//
//  AlbumUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@class AsynchronousImageView, Artist;

@interface AlbumUITableViewCell : CustomUITableViewCell 

@property (retain) NSString *myId;
@property (retain) Artist *myArtist;

@property (retain) AsynchronousImageView *coverArtView;
@property (retain) UIScrollView *albumNameScrollView;
@property (retain) UILabel *albumNameLabel;

@end
