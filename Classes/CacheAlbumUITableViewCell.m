//
//  AlbumUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CacheAlbumUITableViewCell.h"
#import "ViewObjectsSingleton.h"
#import "DatabaseSingleton.h"
#import "FMDatabaseAdditions.h"

#import "CellOverlay.h"
#import "Song.h"

@implementation CacheAlbumUITableViewCell

@synthesize segment, seg1, coverArtView, albumNameScrollView, albumNameLabel;

#pragma mark - Overlay

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{	
		coverArtView = [[UIImageView alloc] init];
		[self.contentView addSubview:coverArtView];
		[coverArtView release];
		
		albumNameScrollView = [[UIScrollView alloc] init];
		albumNameScrollView.frame = CGRectMake(65, 0, 250, 60);
		albumNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		albumNameScrollView.showsVerticalScrollIndicator = NO;
		albumNameScrollView.showsHorizontalScrollIndicator = NO;
		albumNameScrollView.userInteractionEnabled = NO;
		albumNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:albumNameScrollView];
		[albumNameScrollView release];
		
		albumNameLabel = [[UILabel alloc] init];
		albumNameLabel.backgroundColor = [UIColor clearColor];
		albumNameLabel.textAlignment = UITextAlignmentLeft; // default
		albumNameLabel.font = [UIFont boldSystemFontOfSize:20];
		[albumNameScrollView addSubview:albumNameLabel];
		[albumNameLabel release];
	}
	
	return self;
}

- (void)layoutSubviews 
{
    [super layoutSubviews];

	// Automatically set the width based on the width of the text
	albumNameLabel.frame = CGRectMake(0, 0, 230, 60);
	CGSize expectedLabelSize = [albumNameLabel.text sizeWithFont:albumNameLabel.font constrainedToSize:CGSizeMake(1000,60) lineBreakMode:albumNameLabel.lineBreakMode]; 
	CGRect newFrame = albumNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	albumNameLabel.frame = newFrame;
	
	coverArtView.frame = CGRectMake(0, 0, 60, 60);
}

- (void)dealloc 
{
	[seg1 release]; seg1 = nil;

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
	[[ViewObjectsSingleton sharedInstance] showLoadingScreenOnMainWindow];
	[self performSelectorInBackground:@selector(deleteAllSongs) withObject:nil];
	
	self.overlayView.downloadButton.alpha = .3;
	self.overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}

- (void)deleteAllSongs
{
	@autoreleasepool 
	{
		FMResultSet *result;
		result = [[DatabaseSingleton sharedInstance].songCacheDb executeQuery:[NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND seg%i = ? ORDER BY seg%i COLLATE NOCASE", segment, (segment + 1)], seg1, albumNameLabel.text];
		
		while ([result next])
		{
			if ([result stringForColumnIndex:0] != nil)
				[Song removeSongFromCacheDbByMD5:[NSString stringWithString:[result stringForColumnIndex:0]]];
		}
		
		// Reload the cached songs table
		[[NSNotificationCenter defaultCenter] postNotificationName:@"cachedSongDeleted" object:nil];
		
		// Hide the loading screen
		[[ViewObjectsSingleton sharedInstance] performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:YES];
	}
}

- (void)queueAction
{
	[[ViewObjectsSingleton sharedInstance] showLoadingScreenOnMainWindow];
	[self performSelectorInBackground:@selector(queueAllSongs) withObject:nil];
	[self hideOverlay];
}

- (void)queueAllSongs
{
	@autoreleasepool
	{
		FMResultSet *result;
		result = [[DatabaseSingleton sharedInstance].songCacheDb executeQuery:[NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND seg%i = ? ORDER BY seg%i COLLATE NOCASE", segment, (segment + 1)], seg1, albumNameLabel.text];
		
		while ([result next])
		{
			if ([result stringForColumnIndex:0] != nil)
				[[Song songFromCacheDb:[NSString stringWithString:[result stringForColumnIndex:0]]] addToCurrentPlaylist];
		}
		
		// Hide the loading screen
		[[ViewObjectsSingleton sharedInstance] performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:YES];
	}
}

#pragma mark - Scrolling

- (void)scrollLabels
{
	if (albumNameLabel.frame.size.width > albumNameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:albumNameLabel.frame.size.width/150.];
		albumNameScrollView.contentOffset = CGPointMake(albumNameLabel.frame.size.width - albumNameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:albumNameLabel.frame.size.width/150.];
	albumNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
