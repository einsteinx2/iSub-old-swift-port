//
//  AllAlbumsUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "AllAlbumsUITableViewCell.h"
#import "AsynchronousImageView.h"
#import "DatabaseSingleton.h"
#import "Album.h"
#import "CellOverlay.h"

@implementation AllAlbumsUITableViewCell

@synthesize myId, myArtist, coverArtView, albumNameScrollView, albumNameLabel, artistNameLabel;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{
		coverArtView = [[AsynchronousImageView alloc] init];
		coverArtView.isLarge = NO;
		[self.contentView addSubview:coverArtView];
		
		albumNameScrollView = [[UIScrollView alloc] init];
		albumNameScrollView.frame = CGRectMake(65, 0, 250, 60);
		albumNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		albumNameScrollView.showsVerticalScrollIndicator = NO;
		albumNameScrollView.showsHorizontalScrollIndicator = NO;
		albumNameScrollView.userInteractionEnabled = NO;
		albumNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:albumNameScrollView];
		
		albumNameLabel = [[UILabel alloc] init];
		albumNameLabel.backgroundColor = [UIColor clearColor];
		albumNameLabel.textAlignment = UITextAlignmentLeft; // default
		albumNameLabel.font = [UIFont boldSystemFontOfSize:20];
		[albumNameScrollView addSubview:albumNameLabel];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = UITextAlignmentLeft; // default
		artistNameLabel.font = [UIFont systemFontOfSize:15];
		[albumNameScrollView addSubview:artistNameLabel];
	}
	
	return self;
}

- (void)layoutSubviews 
{
    [super layoutSubviews];
	
	coverArtView.frame = CGRectMake(0, 0, 60, 60);
	
	// Automatically set the width based on the width of the text
	albumNameLabel.frame = CGRectMake(0, 0, 230, 35);
	CGSize expectedLabelSize = [albumNameLabel.text sizeWithFont:albumNameLabel.font constrainedToSize:CGSizeMake(1000,35) lineBreakMode:albumNameLabel.lineBreakMode]; 
	CGRect newFrame = albumNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	albumNameLabel.frame = newFrame;
	
	artistNameLabel.frame = CGRectMake(0, 35, 230, 20);
	expectedLabelSize = [artistNameLabel.text sizeWithFont:artistNameLabel.font constrainedToSize:CGSizeMake(1000,35) lineBreakMode:artistNameLabel.lineBreakMode]; 
	newFrame = artistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	artistNameLabel.frame = newFrame;
}

- (void)dealloc
{
	coverArtView.delegate = nil;
	/*[coverArtView release]; coverArtView = nil;
	[albumNameScrollView release]; albumNameScrollView = nil;
	[albumNameLabel release]; albumNameLabel = nil;
	[artistNameLabel release]; artistNameLabel = nil;
	
	[myId release]; myId = nil;
	[myArtist release]; myArtist = nil;
	
    [super dealloc];*/
}

#pragma mark - Overlay

- (void)downloadAction
{
	[databaseS downloadAllSongs:myId artist:myArtist];
	
	self.overlayView.downloadButton.alpha = .3;
	self.overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}

- (void)queueAction
{
	[databaseS queueAllSongs:myId artist:myArtist];
	[self hideOverlay];
}

#pragma mark - Scrolling

- (void)scrollLabels
{
	CGFloat scrollWidth = albumNameLabel.frame.size.width > artistNameLabel.frame.size.width ? albumNameLabel.frame.size.width : artistNameLabel.frame.size.width;
	if (scrollWidth > albumNameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:albumNameLabel.frame.size.width/150.];
		albumNameScrollView.contentOffset = CGPointMake(scrollWidth - albumNameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	CGFloat scrollWidth = albumNameLabel.frame.size.width > artistNameLabel.frame.size.width ? albumNameLabel.frame.size.width : artistNameLabel.frame.size.width;
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:scrollWidth/150.];
	albumNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
