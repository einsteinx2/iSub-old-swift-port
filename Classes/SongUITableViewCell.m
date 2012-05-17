//
//  SongUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "SongUITableViewCell.h"
#import "FMDatabaseAdditions.h"
#import "Song.h"
#import "NSString+md5.h"
#import "CellOverlay.h"
#import "NSNotificationCenter+MainThread.h"
#import "JukeboxSingleton.h"

@implementation SongUITableViewCell

@synthesize mySong, trackNumberLabel, songNameScrollView, songNameLabel, artistNameLabel, songDurationLabel, nowPlayingImageView;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{		
		trackNumberLabel = [[UILabel alloc] init];
		trackNumberLabel.frame = CGRectMake(0, 4, 30, 41);
		trackNumberLabel.backgroundColor = [UIColor clearColor];
		trackNumberLabel.textAlignment = UITextAlignmentCenter;
		trackNumberLabel.font = [UIFont boldSystemFontOfSize:22];
		trackNumberLabel.adjustsFontSizeToFitWidth = YES;
		trackNumberLabel.minimumFontSize = 16;
		[self.contentView addSubview:trackNumberLabel];
		
		nowPlayingImageView = [[UIImageView alloc] initWithImage:self.nowPlayingImageBlack];
		nowPlayingImageView.center = trackNumberLabel.center;
		nowPlayingImageView.hidden = YES;
		[self.contentView addSubview:nowPlayingImageView];
		
		songNameScrollView = [[UIScrollView alloc] init];
		songNameScrollView.frame = CGRectMake(35, 0, 235, 50);
		songNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		songNameScrollView.showsVerticalScrollIndicator = NO;
		songNameScrollView.showsHorizontalScrollIndicator = NO;
		songNameScrollView.userInteractionEnabled = NO;
		songNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:songNameScrollView];
		
		songNameLabel = [[UILabel alloc] init];
		songNameLabel.backgroundColor = [UIColor clearColor];
		songNameLabel.textAlignment = UITextAlignmentLeft;
		songNameLabel.font = [UIFont systemFontOfSize:20];
		[songNameScrollView addSubview:songNameLabel];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = UITextAlignmentLeft;
		artistNameLabel.font = [UIFont systemFontOfSize:13];
		artistNameLabel.textColor = [UIColor colorWithWhite:.4 alpha:1];
		[songNameScrollView addSubview:artistNameLabel];
		
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
	}
	
	return self;
}


- (void)layoutSubviews 
{
    [super layoutSubviews];

	// Automatically set the width based on the width of the text
	self.songNameLabel.frame = CGRectMake(0, 0, 235, 37);
	CGSize expectedLabelSize = [self.songNameLabel.text sizeWithFont:self.songNameLabel.font constrainedToSize:CGSizeMake(1000,60) lineBreakMode:self.songNameLabel.lineBreakMode]; 
	CGRect newFrame = self.songNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	self.songNameLabel.frame = newFrame;
	
	self.artistNameLabel.frame = CGRectMake(0, 33, 235, 15);
	expectedLabelSize = [self.artistNameLabel.text sizeWithFont:self.artistNameLabel.font constrainedToSize:CGSizeMake(1000,60) lineBreakMode:self.artistNameLabel.lineBreakMode]; 
	newFrame = self.artistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	self.artistNameLabel.frame = newFrame;
	
	//self.songDurationLabel.frame = CGRectMake(270, 0, 45, 41);
}

#pragma mark - Overlay

- (void)downloadAction
{
	[self.mySong addToCacheQueueDbQueue];
	
	self.overlayView.downloadButton.alpha = .3;
	self.overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}

- (void)queueAction
{
	[self.mySong addToCurrentPlaylistDbQueue];
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	
	[self hideOverlay];
}

- (void)showOverlay
{
	[super showOverlay];
	
	if (self.isOverlayShowing)
	{
		if (self.mySong.isFullyCached)
		{
			self.overlayView.downloadButton.alpha = .3;
			self.overlayView.downloadButton.enabled = NO;
		}
	}
}

#pragma mark - Scrolling

- (void)scrollLabels
{
	CGFloat scrollWidth = self.songNameLabel.frame.size.width > self.artistNameLabel.frame.size.width ? self.songNameLabel.frame.size.width : self.artistNameLabel.frame.size.width;
	if (scrollWidth > self.songNameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:self.songNameLabel.frame.size.width/150.];
		self.songNameScrollView.contentOffset = CGPointMake(scrollWidth - self.songNameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	CGFloat scrollWidth = self.songNameLabel.frame.size.width > self.artistNameLabel.frame.size.width ? self.songNameLabel.frame.size.width : self.artistNameLabel.frame.size.width;
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:scrollWidth/150.];
	self.songNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
