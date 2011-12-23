//
//  ArtistUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 5/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@interface CacheArtistUITableViewCell : CustomUITableViewCell 

@property (nonatomic, retain) UIScrollView *artistNameScrollView;
@property (nonatomic, retain) UILabel *artistNameLabel;

@end
