//
//  AlbumUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "GenresAlbumUITableViewCell.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "AsynchronousImageView.h"
#import "FMDatabaseAdditions.h"
#import "CellOverlay.h"
#import "Song.h"


@implementation GenresAlbumUITableViewCell

@synthesize segment, seg1, genre, coverArtView, albumNameScrollView, albumNameLabel;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{		
		coverArtView = [[AsynchronousImageView alloc] init];
		coverArtView.isLarge = NO;
		[self.contentView addSubview:coverArtView];
		[coverArtView release];
		
		albumNameScrollView = [[UIScrollView alloc] init];
		albumNameScrollView.frame = CGRectMake(65, 0, 230, 60);
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
	[genre release]; genre = nil;
    [super dealloc];
}

#pragma mark - Overlay

- (void)showOverlay
{
	[super showOverlay];
	if (self.isOverlayShowing)
	{		
		if (viewObjectsS.isOfflineMode)
		{
			self.overlayView.downloadButton.enabled = NO;
			self.overlayView.downloadButton.hidden = YES;
		}
	}
}

- (void)downloadAllSongs
{
	FMResultSet *result;
	if (viewObjectsS.isOfflineMode) 
	{
		result = [databaseS.songCacheDb executeQuery:[NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND seg%i = ? AND genre = ? ORDER BY seg%i COLLATE NOCASE", segment, (segment + 1)], seg1, albumNameLabel.text, genre];
	}
	else 
	{
		result = [databaseS.genresDb executeQuery:[NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE seg1 = ? AND seg%i = ? AND genre = ? ORDER BY seg%i COLLATE NOCASE", segment, (segment + 1)], seg1, albumNameLabel.text, genre];
	}
	
	while ([result next])
	{
		if ([result stringForColumnIndex:0] != nil)
			[[Song songFromGenreDb:[NSString stringWithString:[result stringForColumnIndex:0]]] addToCacheQueue];
	}
	[result close];
	
	// Hide the loading screen
	[viewObjectsS hideLoadingScreen];
}

- (void)downloadAction
{
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	[self performSelector:@selector(downloadAllSongs) withObject:nil afterDelay:0.05];
	
	self.overlayView.downloadButton.alpha = .3;
	self.overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}

- (void)queueAllSongs
{
	FMResultSet *result;
	if (viewObjectsS.isOfflineMode) 
	{
		result = [databaseS.songCacheDb executeQuery:[NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND seg%i = ? AND genre = ? ORDER BY seg%i COLLATE NOCASE", segment, (segment + 1)], seg1, albumNameLabel.text, genre];
	}
	else 
	{
		result = [databaseS.genresDb executeQuery:[NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE seg1 = ? AND seg%i = ? AND genre = ? ORDER BY seg%i COLLATE NOCASE", segment, (segment + 1)], seg1, albumNameLabel.text, genre];
	}
	
	while ([result next])
	{
		if ([result stringForColumnIndex:0] != nil)
			[[Song songFromGenreDb:[NSString stringWithString:[result stringForColumnIndex:0]]] addToCurrentPlaylist];
	}
	[result close];
	
	[viewObjectsS hideLoadingScreen];
}

- (void)queueAction
{
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	[self performSelector:@selector(queueAllSongs) withObject:nil afterDelay:0.05];
	[self hideOverlay];
}

#pragma mark - Scrolling

- (void)scrollLabels
{
	if (albumNameLabel.frame.size.width > albumNameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:albumNameLabel.frame.size.width/(float)150];
		albumNameScrollView.contentOffset = CGPointMake(albumNameLabel.frame.size.width - albumNameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:albumNameLabel.frame.size.width/(float)150];
	albumNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
