//
//  SongUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@interface GenresSongUITableViewCell : CustomUITableViewCell 

@property (nonatomic, retain) NSString *md5;

@property (nonatomic, retain) UILabel *trackNumberLabel;
@property (nonatomic, retain) UIScrollView *songNameScrollView;
@property (nonatomic, retain) UILabel *songNameLabel;
@property (nonatomic, retain) UILabel *artistNameLabel;
@property (nonatomic, retain) UILabel *songDurationLabel;

@end
