//
//  SearchSongUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@class AsynchronousImageViewCached, Song;

@interface SearchSongUITableViewCell : CustomUITableViewCell 

@property (retain) Song *mySong;
@property NSUInteger row;

@property (retain) AsynchronousImageViewCached *coverArtView;
@property (retain) UIScrollView *songNameScrollView;
@property (retain) UILabel *songNameLabel;
@property (retain) UILabel *artistNameLabel;

@end
