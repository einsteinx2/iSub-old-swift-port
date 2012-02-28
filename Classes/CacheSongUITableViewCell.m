//
//  SongUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CacheSongUITableViewCell.h"
#import "FMDatabaseAdditions.h"
#import "CellOverlay.h"
#import "Song.h"
#import "NSNotificationCenter+MainThread.h"
#import "CacheSingleton.h"

@implementation CacheSongUITableViewCell

@synthesize md5, trackNumberLabel, songNameScrollView, songNameLabel, artistNameLabel, songDurationLabel;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{		
		trackNumberLabel = [[UILabel alloc] init];
		trackNumberLabel.backgroundColor = [UIColor clearColor];
		trackNumberLabel.textAlignment = UITextAlignmentCenter;
		trackNumberLabel.font = [UIFont boldSystemFontOfSize:22];
		trackNumberLabel.adjustsFontSizeToFitWidth = YES;
		trackNumberLabel.minimumFontSize = 16;
		[self.contentView addSubview:trackNumberLabel];
		[trackNumberLabel release];
		
		songNameScrollView = [[UIScrollView alloc] init];
		songNameScrollView.frame = CGRectMake(35, 0, 235, 50);
		songNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		songNameScrollView.showsVerticalScrollIndicator = NO;
		songNameScrollView.showsHorizontalScrollIndicator = NO;
		songNameScrollView.userInteractionEnabled = NO;
		songNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:songNameScrollView];
		[songNameScrollView release];
		
		songNameLabel = [[UILabel alloc] init];
		songNameLabel.backgroundColor = [UIColor clearColor];
		songNameLabel.textAlignment = UITextAlignmentLeft;
		songNameLabel.font = [UIFont systemFontOfSize:20];
		[songNameScrollView addSubview:songNameLabel];
		[songNameLabel release];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = UITextAlignmentLeft;
		artistNameLabel.font = [UIFont systemFontOfSize:13];
		artistNameLabel.textColor = [UIColor colorWithWhite:.4 alpha:1];
		[songNameScrollView addSubview:artistNameLabel];
		[artistNameLabel release];
		
		songDurationLabel = [[UILabel alloc] init];
		songDurationLabel.frame = CGRectMake(270, 0, 45, 41);
		songDurationLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		songDurationLabel.backgroundColor = [UIColor clearColor];
		songDurationLabel.textAlignment = UITextAlignmentRight;
		songDurationLabel.font = [UIFont systemFontOfSize:16];
		songDurationLabel.adjustsFontSizeToFitWidth = YES;
		songDurationLabel.minimumFontSize = 12;
		songDurationLabel.textColor = [UIColor grayColor];
		[self.contentView addSubview:songDurationLabel];
		[songDurationLabel release];
	}
	
	return self;
}

- (void)layoutSubviews 
{
    [super layoutSubviews];
	
	trackNumberLabel.frame = CGRectMake(0, 4, 30, 41);
	
	// Automatically set the width based on the width of the text
	songNameLabel.frame = CGRectMake(0, 0, 235, 37);
	CGSize expectedLabelSize = [songNameLabel.text sizeWithFont:songNameLabel.font constrainedToSize:CGSizeMake(1000,60) lineBreakMode:songNameLabel.lineBreakMode]; 
	CGRect newFrame = songNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	songNameLabel.frame = newFrame;
	
	artistNameLabel.frame = CGRectMake(0, 33, 235, 15);
	expectedLabelSize = [artistNameLabel.text sizeWithFont:artistNameLabel.font constrainedToSize:CGSizeMake(1000,60) lineBreakMode:artistNameLabel.lineBreakMode]; 
	newFrame = artistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	artistNameLabel.frame = newFrame;
}

- (void)dealloc 
{
	[md5 release]; md5 = nil;

	[super dealloc];
}

#pragma mark - Overlay

- (void)showOverlay
{
	[super showOverlay];
	
	if (self.isOverlayShowing)
	{
		[self.overlayView.downloadButton setImage:[UIImage imageNamed:@"delete-button.png"] forState:UIControlStateNormal];
		[self.overlayView.downloadButton addTarget:self action:@selector(deleteAction) forControlEvents:UIControlEventTouchUpInside];
	}
}

- (void)deleteAction
{
	[Song removeSongFromCacheDbByMD5:md5];
	
	[cacheS findCacheSize];
		
	self.overlayView.downloadButton.alpha = .3;
	self.overlayView.downloadButton.enabled = NO;
	
	// Reload the cached songs table
	[NSNotificationCenter postNotificationToMainThreadWithName:@"cachedSongDeleted"];
	
	[self hideOverlay];
}

- (void)queueAction
{	
	[[Song songFromCacheDb:md5] addToCurrentPlaylist];

	[self hideOverlay];
}

#pragma mark - Scrolling

- (void)scrollLabels
{
	CGFloat scrollWidth = songNameLabel.frame.size.width > artistNameLabel.frame.size.width ? songNameLabel.frame.size.width : artistNameLabel.frame.size.width;
	if (scrollWidth > songNameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:songNameLabel.frame.size.width/150.];
		songNameScrollView.contentOffset = CGPointMake(scrollWidth - songNameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	CGFloat scrollWidth = songNameLabel.frame.size.width > artistNameLabel.frame.size.width ? songNameLabel.frame.size.width : artistNameLabel.frame.size.width;
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:scrollWidth/150.];
	songNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
