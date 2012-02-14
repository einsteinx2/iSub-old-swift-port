//
//  ArtistUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 5/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CacheArtistUITableViewCell.h"
#import "ViewObjectsSingleton.h"
#import "DatabaseSingleton.h"
#import "FMDatabaseAdditions.h"
#import "CellOverlay.h"
#import "Song.h"


@implementation CacheArtistUITableViewCell

@synthesize artistNameScrollView, artistNameLabel;

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
		[artistNameScrollView release];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = UITextAlignmentLeft; // default
		artistNameLabel.font = [UIFont boldSystemFontOfSize:20];
		[artistNameScrollView addSubview:artistNameLabel];
		[artistNameLabel release];
	}
	
	return self;
}

- (void)layoutSubviews 
{	
    [super layoutSubviews];

	// Automatically set the width based on the width of the text
	artistNameLabel.frame = CGRectMake(0, 0, 290, 44);
	CGSize expectedLabelSize = [artistNameLabel.text sizeWithFont:artistNameLabel.font constrainedToSize:CGSizeMake(1000,44) lineBreakMode:artistNameLabel.lineBreakMode]; 
	CGRect newFrame = artistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	artistNameLabel.frame = newFrame;
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
	// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	FMResultSet *result;
	result = [[DatabaseSingleton sharedInstance].songCacheDb executeQuery:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ?", artistNameLabel.text];
	
	while ([result next])
	{
		if ([result stringForColumnIndex:0] != nil)
			[Song removeSongFromCacheDbByMD5:[NSString stringWithString:[result stringForColumnIndex:0]]];
	}
	
	// Reload the cached songs table
	[[NSNotificationCenter defaultCenter] postNotificationName:@"cachedSongDeleted" object:nil];
	
	// Hide the loading screen	
	[[ViewObjectsSingleton sharedInstance] performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:YES];
	
	[autoreleasePool release];
}

- (void)queueAction
{
	[super queueAction];
	
	[[ViewObjectsSingleton sharedInstance] showLoadingScreenOnMainWindow];
	[self performSelectorInBackground:@selector(queueAllSongs) withObject:nil];
	[self hideOverlay];
}

- (void)queueAllSongs
{
	// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	FMResultSet *result;
	
	result = [[DatabaseSingleton sharedInstance].songCacheDb executeQuery:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? ORDER BY seg2 COLLATE NOCASE", artistNameLabel.text];
	
	while ([result next])
	{
		if ([result stringForColumnIndex:0] != nil)
			[[Song songFromCacheDb:[NSString stringWithString:[result stringForColumnIndex:0]]] addToCurrentPlaylist];
	}
	
	[result close];
	
	[[ViewObjectsSingleton sharedInstance] performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:YES];
	
	[autoreleasePool release];
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
	[UIView setAnimationDuration:artistNameLabel.frame.size.width/(float)150];
	artistNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
