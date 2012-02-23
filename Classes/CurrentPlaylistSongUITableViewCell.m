//
//  PlaylistSongUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CurrentPlaylistSongUITableViewCell.h"
#import "AsynchronousImageViewCached.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "FMDatabaseAdditions.h"
#import "Song.h"
#import "CellOverlay.h"
#import "PlaylistSingleton.h"
#import "NSNotificationCenter+MainThread.h"

@implementation CurrentPlaylistSongUITableViewCell

@synthesize coverArtView, numberLabel, nameScrollView, songNameLabel, artistNameLabel;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{		
		coverArtView = [[AsynchronousImageViewCached alloc] init];
		[self.contentView addSubview:coverArtView];
		[coverArtView release];
		
		numberLabel = [[UILabel alloc] init];
		numberLabel.backgroundColor = [UIColor clearColor];
		numberLabel.textAlignment = UITextAlignmentCenter;
		numberLabel.font = [UIFont boldSystemFontOfSize:30];
		numberLabel.adjustsFontSizeToFitWidth = YES;
		numberLabel.minimumFontSize = 12;
		[self.contentView addSubview:numberLabel];
		[numberLabel release];		
				
		nameScrollView = [[UIScrollView alloc] init];
		nameScrollView.frame = CGRectMake(105, 0, 210, 60);
		nameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		nameScrollView.showsVerticalScrollIndicator = NO;
		nameScrollView.showsHorizontalScrollIndicator = NO;
		nameScrollView.userInteractionEnabled = NO;
		nameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:nameScrollView];
		[nameScrollView release];
		
		songNameLabel = [[UILabel alloc] init];
		songNameLabel.backgroundColor = [UIColor clearColor];
		songNameLabel.textAlignment = UITextAlignmentLeft; // default
		songNameLabel.font = [UIFont boldSystemFontOfSize:20];
		[nameScrollView addSubview:songNameLabel];
		[songNameLabel release];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = UITextAlignmentLeft; // default
		artistNameLabel.font = [UIFont systemFontOfSize:15];
		[nameScrollView addSubview:artistNameLabel];
		[artistNameLabel release];
	}
	
	return self;
}

- (void)layoutSubviews 
{
    [super layoutSubviews];
	
	self.deleteToggleImage.frame = CGRectMake(4.0, 18.5, 23.0, 23.0);
	coverArtView.frame = CGRectMake(0, 0, 60, 60);
	numberLabel.frame = CGRectMake(62, 0, 40, 60);
	
	// Automatically set the width based on the width of the text
	songNameLabel.frame = CGRectMake(0, 0, 190, 40);
	CGSize expectedLabelSize = [songNameLabel.text sizeWithFont:songNameLabel.font constrainedToSize:CGSizeMake(1000,35) lineBreakMode:songNameLabel.lineBreakMode]; 
	CGRect newFrame = songNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	songNameLabel.frame = newFrame;
	
	artistNameLabel.frame = CGRectMake(0, 37, 190, 20);
	expectedLabelSize = [artistNameLabel.text sizeWithFont:artistNameLabel.font constrainedToSize:CGSizeMake(1000,35) lineBreakMode:artistNameLabel.lineBreakMode]; 
	newFrame = artistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	artistNameLabel.frame = newFrame;
}

#pragma mark - Overlay

- (void)downloadAction
{
	PlaylistSingleton *currentPlaylist = [PlaylistSingleton sharedInstance];
	
	if (currentPlaylist.isShuffle) 
		[[Song songFromDbRow:self.indexPath.row inTable:@"shufflePlaylist" inDatabase:[DatabaseSingleton sharedInstance].currentPlaylistDb] addToCacheQueue];
	else 
		[[Song songFromDbRow:self.indexPath.row inTable:@"currentPlaylist" inDatabase:[DatabaseSingleton sharedInstance].currentPlaylistDb] addToCacheQueue];
	
	self.overlayView.downloadButton.alpha = .3;
	self.overlayView.downloadButton.enabled = NO;

	[self hideOverlay];
}

- (void)queueAction
{
	PlaylistSingleton *currentPlaylist = [PlaylistSingleton sharedInstance];
	
	//DLog(@"queueAction");
	if (currentPlaylist.isShuffle)
	{
		Song *aSong = [Song songFromDbRow:self.indexPath.row inTable:@"shufflePlaylist" inDatabase:[DatabaseSingleton sharedInstance].currentPlaylistDb];
		[[DatabaseSingleton sharedInstance] queueSong:aSong];
	}
	else
	{
		Song *aSong = [Song songFromDbRow:self.indexPath.row inTable:@"currentPlaylist" inDatabase:[DatabaseSingleton sharedInstance].currentPlaylistDb];
		[[DatabaseSingleton sharedInstance] queueSong:aSong];
	}
	
	[self hideOverlay];
	[NSNotificationCenter postNotificationToMainThreadWithName:@"updateCurrentPlaylistCount"];
	[(UITableView*)self.superview reloadData];
}

#pragma mark - Scrolling

- (void)scrollLabels
{
	CGFloat scrollWidth = songNameLabel.frame.size.width > artistNameLabel.frame.size.width ? songNameLabel.frame.size.width : artistNameLabel.frame.size.width;
	if (scrollWidth > nameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:scrollWidth/150.];
		nameScrollView.contentOffset = CGPointMake(scrollWidth - nameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	CGFloat scrollWidth = songNameLabel.frame.size.width > artistNameLabel.frame.size.width ? songNameLabel.frame.size.width : artistNameLabel.frame.size.width;
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:scrollWidth/150.];
	nameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
