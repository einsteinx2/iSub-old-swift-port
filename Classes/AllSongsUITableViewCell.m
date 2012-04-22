//
//  AllAlbumsUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "AllSongsUITableViewCell.h"
#import "AsynchronousImageView.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "Song.h"
#import "FMDatabaseAdditions.h"
#import "CellOverlay.h"


@implementation AllSongsUITableViewCell

@synthesize md5, coverArtView, songNameScrollView, songNameLabel, artistNameLabel;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{	
		self.isSearching = NO;
		self.isOverlayShowing = NO;
		
		coverArtView = [[AsynchronousImageView alloc] init];
		coverArtView.isLarge = NO;
		[self.contentView addSubview:coverArtView];
		
		songNameScrollView = [[UIScrollView alloc] init];
		songNameScrollView.frame = CGRectMake(65, 0, 255, 60);
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
		[songNameScrollView addSubview:songNameLabel];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = UITextAlignmentLeft; // default
		artistNameLabel.font = [UIFont systemFontOfSize:15];
		[songNameScrollView addSubview:artistNameLabel];
	}
	
	return self;
}

- (void)layoutSubviews 
{
    [super layoutSubviews];
	
	coverArtView.frame = CGRectMake(0, 0, 60, 60);
	
	// Automatically set the width based on the width of the text
	songNameLabel.frame = CGRectMake(0, 0, 225, 35);
	CGSize expectedLabelSize = [songNameLabel.text sizeWithFont:songNameLabel.font constrainedToSize:CGSizeMake(1000,35) lineBreakMode:songNameLabel.lineBreakMode]; 
	CGRect newFrame = songNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	songNameLabel.frame = newFrame;
	
	artistNameLabel.frame = CGRectMake(0, 35, 225, 20);
	expectedLabelSize = [artistNameLabel.text sizeWithFont:artistNameLabel.font constrainedToSize:CGSizeMake(1000,35) lineBreakMode:artistNameLabel.lineBreakMode]; 
	newFrame = artistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	artistNameLabel.frame = newFrame;
}

- (void)dealloc
{
	coverArtView.delegate = nil;
	
	
}

#pragma mark - Overlay

- (void)showOverlay
{
	[super showOverlay];
	
	if (self.isOverlayShowing)
	{
		if ([[databaseS.songCacheDb stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", md5] isEqualToString:@"YES"]) 
		{
			self.overlayView.downloadButton.alpha = .3;
			self.overlayView.downloadButton.enabled = NO;
		}
		else 
		{
			self.overlayView.downloadButton.alpha = .8;
			[self.overlayView.downloadButton addTarget:self action:@selector(downloadAction) forControlEvents:UIControlEventTouchUpInside];
			self.overlayView.downloadButton.enabled = YES;
		}
	}
}

- (void)downloadAction
{
	if (self.isSearching) 
	{
		Song *aSong = [Song songFromDbRow:self.indexPath.row inTable:@"allSongsSearch" inDatabase:databaseS.allSongsDb];
		[aSong addToCacheQueue];
	}
	else 
	{
		Song *aSong = [Song songFromDbRow:self.indexPath.row inTable:@"allSongs" inDatabase:databaseS.allSongsDb];
		[aSong addToCacheQueue];
	}
	
	self.overlayView.downloadButton.alpha = .3;
	self.overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}

- (void)queueAction
{	
	if (self.isSearching) 
	{
		Song *aSong = [Song songFromDbRow:self.indexPath.row inTable:@"allSongsSearch" inDatabase:databaseS.allSongsDb];
		[databaseS queueSong:aSong];
	}
	else 
	{
		Song *aSong = [Song songFromDbRow:self.indexPath.row inTable:@"allSongs" inDatabase:databaseS.allSongsDb];
		[databaseS queueSong:aSong];
	}
	
	[self hideOverlay];
}

#pragma mark - Scrolling

- (void)scrollLabels
{	
	CGFloat scrollWidth = songNameLabel.frame.size.width > artistNameLabel.frame.size.width ? songNameLabel.frame.size.width : artistNameLabel.frame.size.width;
	if (scrollWidth > songNameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:scrollWidth/150.];
		songNameScrollView.contentOffset = CGPointMake(scrollWidth - songNameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	CGFloat scrollWidth = songNameLabel.frame.size.width > artistNameLabel.frame.size.width ? songNameLabel.frame.size.width : artistNameLabel.frame.size.width;
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:scrollWidth/150.];
	songNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
