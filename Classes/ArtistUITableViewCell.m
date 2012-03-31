//
//  ArtistUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 5/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ArtistUITableViewCell.h"
#import "DatabaseSingleton.h"
#import "Artist.h"
#import "CellOverlay.h"

@implementation ArtistUITableViewCell

@synthesize artistNameScrollView, artistNameLabel, myArtist;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
	if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{		
		artistNameScrollView = [[UIScrollView alloc] init];
		artistNameScrollView.frame = CGRectMake(5, 0, 320, 44);
		artistNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		artistNameScrollView.showsVerticalScrollIndicator = NO;
		artistNameScrollView.showsHorizontalScrollIndicator = NO;
		artistNameScrollView.userInteractionEnabled = NO;
		artistNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:artistNameScrollView];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = UITextAlignmentLeft; // default
		artistNameLabel.font = [UIFont boldSystemFontOfSize:20];
		[self.artistNameScrollView addSubview:artistNameLabel];
	}
	
	return self;
}

- (void)layoutSubviews 
{	
    [super layoutSubviews];
	
	// Automatically set the width based on the width of the text
	artistNameLabel.frame = CGRectMake(0, 0, 280, 44);
	CGSize expectedLabelSize = [artistNameLabel.text sizeWithFont:artistNameLabel.font constrainedToSize:CGSizeMake(1000,44) lineBreakMode:artistNameLabel.lineBreakMode];
	//DLog(@"%@: size: %@", artistNameLabel.text, NSStringFromCGSize(expectedLabelSize));
	
	if (expectedLabelSize.width > 280)
	{
		CGRect newFrame = artistNameLabel.frame;
		newFrame.size.width = expectedLabelSize.width;
		artistNameLabel.frame = newFrame;
	}
}

- (void)dealloc
{
	[artistNameScrollView release]; artistNameScrollView = nil;
	[artistNameLabel release]; artistNameLabel = nil;
	[myArtist release]; myArtist = nil;
	[super dealloc];
}

#pragma mark - Overlay

- (void)downloadAction
{
	[databaseS downloadAllSongs:myArtist.artistId artist:myArtist];
	
	self.overlayView.downloadButton.alpha = .3;
	self.overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}

- (void)queueAction
{
	[databaseS queueAllSongs:myArtist.artistId artist:myArtist];
	[self hideOverlay];
}

#pragma mark - Scrolling

- (void)scrollLabels
{
	if (artistNameLabel.frame.size.width > artistNameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:artistNameLabel.frame.size.width/(float)150];
		artistNameScrollView.contentOffset = CGPointMake(artistNameLabel.frame.size.width - artistNameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:artistNameLabel.frame.size.width/150.];
	artistNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}


@end
