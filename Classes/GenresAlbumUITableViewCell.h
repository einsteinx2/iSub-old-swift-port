//
//  AlbumUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@class AsynchronousImageViewCached;

@interface GenresAlbumUITableViewCell : CustomUITableViewCell 

@property NSInteger segment;
@property (retain) NSString *seg1;
@property (retain) NSString *genre;

@property (retain) AsynchronousImageViewCached *coverArtView;
@property (retain) UIScrollView *albumNameScrollView;
@property (retain) UILabel *albumNameLabel;

@end
