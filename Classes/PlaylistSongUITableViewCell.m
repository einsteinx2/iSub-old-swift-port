//
//  PlaylistSongUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "PlaylistSongUITableViewCell.h"
#import "MusicSingleton.h"
#import "CellOverlay.h"

@implementation PlaylistSongUITableViewCell

@synthesize coverArtView, numberLabel, nameScrollView, songNameLabel, artistNameLabel, mySong;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{		
		coverArtView = [[AsynchronousImageView alloc] init];
		coverArtView.isLarge = NO;
		[self.contentView addSubview:coverArtView];
		
		numberLabel = [[UILabel alloc] init];
		numberLabel.backgroundColor = [UIColor clearColor];
		numberLabel.textAlignment = UITextAlignmentCenter;
		numberLabel.font = [UIFont boldSystemFontOfSize:30];
		numberLabel.adjustsFontSizeToFitWidth = YES;
		numberLabel.minimumFontSize = 12;
		[self.contentView addSubview:numberLabel];
		
		nameScrollView = [[UIScrollView alloc] init];
		nameScrollView.frame = CGRectMake(105, 0, 205, 60);
		nameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		nameScrollView.showsVerticalScrollIndicator = NO;
		nameScrollView.showsHorizontalScrollIndicator = NO;
		nameScrollView.userInteractionEnabled = NO;
		nameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:nameScrollView];
		
		songNameLabel = [[UILabel alloc] init];
		songNameLabel.backgroundColor = [UIColor clearColor];
		songNameLabel.textAlignment = UITextAlignmentLeft; // default
		songNameLabel.font = [UIFont boldSystemFontOfSize:20];
		[nameScrollView addSubview:songNameLabel];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = UITextAlignmentLeft; // default
		artistNameLabel.font = [UIFont systemFontOfSize:15];
		[nameScrollView addSubview:artistNameLabel];
	}
	
	return self;
}

- (void)dealloc
{
	coverArtView.delegate = nil;
	
}

- (void)layoutSubviews
{
    [super layoutSubviews];
	
	self.coverArtView.frame = CGRectMake(0, 0, 60, 60);
	self.numberLabel.frame = CGRectMake(62, 0, 40, 60);
	
	// Automatically set the width based on the width of the text
	self.songNameLabel.frame = CGRectMake(0, 0, 205, 40);
	CGSize expectedLabelSize = [self.songNameLabel.text sizeWithFont:self.songNameLabel.font constrainedToSize:CGSizeMake(1000,35) lineBreakMode:self.songNameLabel.lineBreakMode]; 
	CGRect newFrame = self.songNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	self.songNameLabel.frame = newFrame;
	
	self.artistNameLabel.frame = CGRectMake(0, 37, 205, 20);
	expectedLabelSize = [self.artistNameLabel.text sizeWithFont:self.artistNameLabel.font constrainedToSize:CGSizeMake(1000,35) lineBreakMode:self.artistNameLabel.lineBreakMode]; 
	newFrame = self.artistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	self.artistNameLabel.frame = newFrame;
}

#pragma mark - Overlay

/*- (void)toggleDelete
{
	[[viewObjectsS.listOfPlaylistSongs objectAtIndexSafe:indexPath.row] addToCacheQueue];
	
	overlayView.downloadButton.alpha = .3;
	overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}*/

- (void)showOverlay
{
	[super showOverlay];
	
	self.overlayView.downloadButton.alpha = (float)!viewObjectsS.isOfflineMode;
	self.overlayView.downloadButton.enabled = !viewObjectsS.isOfflineMode;
	
	if ((self.mySong.isFullyCached && !viewObjectsS.isOfflineMode) || self.mySong.isVideo)
	{
		self.overlayView.downloadButton.alpha = .3;
		self.overlayView.downloadButton.enabled = NO;
	}
}

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

#pragma mark - Scrolling

- (void)scrollLabels
{
	CGFloat scrollWidth = self.songNameLabel.frame.size.width > self.artistNameLabel.frame.size.width ? self.songNameLabel.frame.size.width : self.artistNameLabel.frame.size.width;
	if (scrollWidth > self.nameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:scrollWidth/150.];
		self.nameScrollView.contentOffset = CGPointMake(scrollWidth - self.nameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	CGFloat scrollWidth = self.songNameLabel.frame.size.width > self.artistNameLabel.frame.size.width ? self.songNameLabel.frame.size.width : self.artistNameLabel.frame.size.width;
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:scrollWidth/150.];
	self.nameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
