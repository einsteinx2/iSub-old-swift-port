//
//  SongUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@class Song;

@interface SongUITableViewCell : CustomUITableViewCell 

@property (retain) Song *mySong;

@property (retain) UILabel *trackNumberLabel;
@property (retain) UIScrollView *songNameScrollView;
@property (retain) UILabel *songNameLabel;
@property (retain) UILabel *artistNameLabel;
@property (retain) UILabel *songDurationLabel;

@end
