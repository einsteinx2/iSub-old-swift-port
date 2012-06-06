//
//  SearchSongUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SearchSongUITableViewCell.h"
#import "AsynchronousImageView.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "Song.h"
#import "FMDatabaseAdditions.h"
#import "NSString+md5.h"
#import "CellOverlay.h"

@implementation SearchSongUITableViewCell

@synthesize mySong, row, coverArtView, songNameScrollView, songNameLabel, artistNameLabel;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
	{
		coverArtView = [[AsynchronousImageView alloc] init];
		coverArtView.isLarge = NO;
		[self.contentView addSubview:coverArtView];
		
		songNameScrollView = [[UIScrollView alloc] init];
		songNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		songNameScrollView.showsVerticalScrollIndicator = NO;
		songNameScrollView.showsHorizontalScrollIndicator = NO;
		songNameScrollView.userInteractionEnabled = NO;
		songNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:songNameScrollView];
		
		songNameLabel = [[UILabel alloc] init];
		songNameLabel.backgroundColor = [UIColor clearColor];
		songNameLabel.textAlignment = UITextAlignmentLeft; // default
		songNameLabel.font = [UIFont boldSystemFontOfSize:20];
		[self.songNameScrollView addSubview:songNameLabel];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = UITextAlignmentLeft; // default
		artistNameLabel.font = [UIFont systemFontOfSize:15];
		[self.songNameScrollView addSubview:artistNameLabel];
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
	self.songNameScrollView.frame = CGRectMake(65, 0, 250, 60);
	
	// Automatically set the width based on the width of the text
	self.songNameLabel.frame = CGRectMake(0, 0, 250, 35);
	CGSize expectedLabelSize = [self.songNameLabel.text sizeWithFont:self.songNameLabel.font constrainedToSize:CGSizeMake(1000,35) lineBreakMode:self.songNameLabel.lineBreakMode]; 
	CGRect newFrame = self.songNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	self.songNameLabel.frame = newFrame;
	
	self.artistNameLabel.frame = CGRectMake(0, 35, 250, 20);
	expectedLabelSize = [self.artistNameLabel.text sizeWithFont:self.artistNameLabel.font constrainedToSize:CGSizeMake(1000,35) lineBreakMode:self.artistNameLabel.lineBreakMode]; 
	newFrame = self.artistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	self.artistNameLabel.frame = newFrame;
}

- (Song *)mySong
{
	@synchronized(self)
	{
		return mySong;
	}
}

- (void)setMySong:(Song *)aSong
{
	@synchronized(self)
	{
		mySong = [aSong copy];
		
		self.coverArtView.coverArtId = mySong.coverArtId;
		
		self.backgroundView = [[UIView alloc] init];
		if(row % 2 == 0)
		{
			if (mySong.isFullyCached)
				self.backgroundView.backgroundColor = [viewObjectsS currentLightColor];
			else
				self.backgroundView.backgroundColor = viewObjectsS.lightNormal;
		}
		else
		{
			if (mySong.isFullyCached)
				self.backgroundView.backgroundColor = [viewObjectsS currentDarkColor];
			else
				self.backgroundView.backgroundColor = viewObjectsS.darkNormal;
		}
		
		[self.songNameLabel setText:aSong.title];
		if (aSong.album)
			[self.artistNameLabel setText:[NSString stringWithFormat:@"%@ - %@", aSong.artist, aSong.album]];
		else
			[self.artistNameLabel setText:aSong.artist];
	}
}

#pragma mark - Overlay

- (void)showOverlay
{
	[super showOverlay];
	
	self.overlayView.downloadButton.alpha = (float)!viewObjectsS.isOfflineMode;
	self.overlayView.downloadButton.enabled = !viewObjectsS.isOfflineMode;
	
	if (self.mySong.isFullyCached && !viewObjectsS.isOfflineMode)
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
	
	[self hideOverlay];
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
		[UIView setAnimationDuration:scrollWidth/150.];
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
