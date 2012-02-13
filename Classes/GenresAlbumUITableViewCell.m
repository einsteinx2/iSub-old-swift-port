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
#import "AsynchronousImageViewCached.h"
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
		coverArtView = [[AsynchronousImageViewCached alloc] init];
		[self.contentView addSubview:coverArtView];
		[coverArtView release];
		
		albumNameScrollView = [[UIScrollView alloc] init];
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

- (void)layoutSubview 
{	
    [super layoutSubviews];
	
	self.contentView.frame = CGRectMake(0, 0, 320, 60);
	albumNameScrollView.frame = CGRectMake(65, 0, 230, 60);
	
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
		if ([ViewObjectsSingleton sharedInstance].isOfflineMode)
		{
			self.overlayView.downloadButton.enabled = NO;
			self.overlayView.downloadButton.hidden = YES;
		}
	}
}

- (void)downloadAction
{
	[[ViewObjectsSingleton sharedInstance] showLoadingScreenOnMainWindow];
	[self performSelectorInBackground:@selector(downloadAllSongs) withObject:nil];
	
	self.overlayView.downloadButton.alpha = .3;
	self.overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}

- (void)downloadAllSongs
{
	@autoreleasepool 
	{
		FMResultSet *result;
		if ([ViewObjectsSingleton sharedInstance].isOfflineMode) 
		{
			result = [[DatabaseSingleton sharedInstance].songCacheDb synchronizedExecuteQuery:[NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND seg%i = ? AND genre = ? ORDER BY seg%i COLLATE NOCASE", segment, (segment + 1)], seg1, albumNameLabel.text, genre];
		}
		else 
		{
			result = [[DatabaseSingleton sharedInstance].genresDb executeQuery:[NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE seg1 = ? AND seg%i = ? AND genre = ? ORDER BY seg%i COLLATE NOCASE", segment, (segment + 1)], seg1, albumNameLabel.text, genre];
		}
		
		while ([result next])
		{
			if ([result stringForColumnIndex:0] != nil)
				[[Song songFromGenreDb:[NSString stringWithString:[result stringForColumnIndex:0]]] addToCacheQueue];
		}
		
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
		if ([ViewObjectsSingleton sharedInstance].isOfflineMode) 
		{
			result = [[DatabaseSingleton sharedInstance].songCacheDb synchronizedExecuteQuery:[NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND seg%i = ? AND genre = ? ORDER BY seg%i COLLATE NOCASE", segment, (segment + 1)], seg1, albumNameLabel.text, genre];
		}
		else 
		{
			result = [[DatabaseSingleton sharedInstance].genresDb executeQuery:[NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE seg1 = ? AND seg%i = ? AND genre = ? ORDER BY seg%i COLLATE NOCASE", segment, (segment + 1)], seg1, albumNameLabel.text, genre];
		}
		
		while ([result next])
		{
			if ([result stringForColumnIndex:0] != nil)
				[[Song songFromGenreDb:[NSString stringWithString:[result stringForColumnIndex:0]]] addToCurrentPlaylist];
		}
		
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
