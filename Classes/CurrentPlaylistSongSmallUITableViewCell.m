//
//  PlaylistSongUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CurrentPlaylistSongSmallUITableViewCell.h"

@implementation CurrentPlaylistSongSmallUITableViewCell

@synthesize numberLabel, songNameLabel, artistNameLabel, durationLabel;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{
		self.backgroundView.backgroundColor = [UIColor clearColor];
		self.contentView.backgroundColor = [UIColor clearColor];
		
		numberLabel = [[UILabel alloc] init];
		numberLabel.backgroundColor = [UIColor clearColor];
		numberLabel.textAlignment = UITextAlignmentCenter;
		numberLabel.textColor = [UIColor whiteColor];
		numberLabel.font = [UIFont boldSystemFontOfSize:24];
		numberLabel.adjustsFontSizeToFitWidth = YES;
		numberLabel.minimumFontSize = 12;
		[self.contentView addSubview:numberLabel];
		[numberLabel release];
		
		songNameLabel = [[UILabel alloc] init];
		songNameLabel.frame = CGRectMake(45, 0, 235, 30);
		songNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		songNameLabel.backgroundColor = [UIColor clearColor];
		songNameLabel.textAlignment = UITextAlignmentLeft; // default
		songNameLabel.textColor = [UIColor whiteColor];
		songNameLabel.font = [UIFont boldSystemFontOfSize:18];
		[self.contentView addSubview:songNameLabel];
		[songNameLabel release];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.frame = CGRectMake(45, 27, 235, 15);
		artistNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = UITextAlignmentLeft; // default
		artistNameLabel.textColor = [UIColor whiteColor];
		artistNameLabel.font = [UIFont systemFontOfSize:12];
		[self.contentView addSubview:artistNameLabel];
		[artistNameLabel release];
		
		durationLabel = [[UILabel alloc] init];
		durationLabel.frame = CGRectMake(270, 0, 45, 41);
		durationLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		durationLabel.backgroundColor = [UIColor clearColor];
		durationLabel.textAlignment = UITextAlignmentRight; // default
		durationLabel.textColor = [UIColor whiteColor];
		durationLabel.font = [UIFont systemFontOfSize:16];
		durationLabel.adjustsFontSizeToFitWidth = YES;
		durationLabel.minimumFontSize = 12;
		[self.contentView addSubview:durationLabel];
		[durationLabel release];
	}
	
	return self;
}

- (void)layoutSubviews 
{
    [super layoutSubviews];
	
	//self.deleteToggleImage.frame = CGRectMake(4, 11, 23, 23);
	numberLabel.frame = CGRectMake(2, 0, 40, 45);
}

#pragma mark - Overlay

- (void)showOverlay
{
	return;
}

- (void)hideOverlay
{
	return;
}

@end
