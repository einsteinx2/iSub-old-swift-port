//
//  ArtistUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 5/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "GenresGenreUITableViewCell.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "FMDatabase.h"
#import "CellOverlay.h"
#import "Song.h"
#import "FMDatabase+Synchronized.h"

@implementation GenresGenreUITableViewCell

@synthesize genreNameScrollView, genreNameLabel;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
	if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{
		genreNameScrollView = [[UIScrollView alloc] init];
		genreNameScrollView.frame = CGRectMake(5, 0, 300, 44);
		genreNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		genreNameScrollView.showsVerticalScrollIndicator = NO;
		genreNameScrollView.showsHorizontalScrollIndicator = NO;
		genreNameScrollView.userInteractionEnabled = NO;
		genreNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:genreNameScrollView];
		[genreNameScrollView release];
		
		genreNameLabel = [[UILabel alloc] init];
		genreNameLabel.backgroundColor = [UIColor clearColor];
		genreNameLabel.textAlignment = UITextAlignmentLeft; // default
		genreNameLabel.font = [UIFont boldSystemFontOfSize:20];
		[genreNameScrollView addSubview:genreNameLabel];
		[genreNameLabel release];
	}
	
	return self;
}

- (void)layoutSubviews 
{	
    [super layoutSubviews];
		
	// Automatically set the width based on the width of the text
	genreNameLabel.frame = CGRectMake(0, 0, 270, 44);
	CGSize expectedLabelSize = [genreNameLabel.text sizeWithFont:genreNameLabel.font constrainedToSize:CGSizeMake(1000,44) lineBreakMode:genreNameLabel.lineBreakMode]; 
	CGRect newFrame = genreNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	genreNameLabel.frame = newFrame;
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
			result = [[DatabaseSingleton sharedInstance].songCacheDb synchronizedQuery:[NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE"], genreNameLabel.text];
		}
		else 
		{
			result = [[DatabaseSingleton sharedInstance].genresDb executeQuery:[NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE"], genreNameLabel.text];
		}
		
		while ([result next])
		{
			if ([result stringForColumnIndex:0] != nil)
				[[Song songFromGenreDb:[NSString stringWithString:[result stringForColumnIndex:0]]] addToCacheQueue];
		}
		[result release];
		
		if ([MusicSingleton sharedInstance].isQueueListDownloading == NO)
		{
			[[MusicSingleton sharedInstance] performSelectorOnMainThread:@selector(downloadNextQueuedSong) withObject:nil waitUntilDone:NO];
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
			result = [[DatabaseSingleton sharedInstance].songCacheDb synchronizedQuery:[NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE"], genreNameLabel.text];
		}
		else 
		{
			result = [[DatabaseSingleton sharedInstance].genresDb executeQuery:[NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE"], genreNameLabel.text];
		}
		
		while ([result next])
		{
			//DLog(@"adding %@", [result stringForColumnIndex:0]);
			if ([result stringForColumnIndex:0] != nil)
				[[Song songFromGenreDb:[NSString stringWithString:[result stringForColumnIndex:0]]] addToPlaylistQueue];
		}
		[result release];
		
		[[ViewObjectsSingleton sharedInstance] performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:YES];
	}
}

#pragma mark - Scrolling

- (void)scrollLabels
{
	if (genreNameLabel.frame.size.width > genreNameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:genreNameLabel.frame.size.width/(float)150];
		genreNameScrollView.contentOffset = CGPointMake(genreNameLabel.frame.size.width - genreNameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:genreNameLabel.frame.size.width/(float)150];
	genreNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
