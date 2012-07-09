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
#import "FMDatabaseQueueAdditions.h"

#import "CellOverlay.h"
#import "Song.h"
#import "CacheSingleton.h"
#import "ISMSCacheQueueManager.h"

@implementation CacheAlbumUITableViewCell

@synthesize segments, coverArtView, albumNameScrollView, albumNameLabel;

#pragma mark - Overlay

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{	
		coverArtView = [[UIImageView alloc] init];
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
	}
	
	return self;
}

- (void)layoutSubviews 
{
    [super layoutSubviews];

	// Automatically set the width based on the width of the text
	self.albumNameLabel.frame = CGRectMake(0, 0, 230, 60);
	CGSize expectedLabelSize = [self.albumNameLabel.text sizeWithFont:self.albumNameLabel.font constrainedToSize:CGSizeMake(1000,60) lineBreakMode:self.albumNameLabel.lineBreakMode]; 
	CGRect frame = self.albumNameLabel.frame;
	frame.size.width = expectedLabelSize.width;
	self.albumNameLabel.frame = frame;
	
	self.coverArtView.frame = CGRectMake(0, 0, 60, 60);
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
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Deleting"];
	[self performSelector:@selector(deleteAllSongs) withObject:nil afterDelay:0.05];
	
	self.overlayView.downloadButton.alpha = .3;
	self.overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}

- (void)deleteAllSongs
{
	NSMutableArray *newSegments = [NSMutableArray arrayWithArray:segments];
	[newSegments addObject:self.albumNameLabel.text];
	
	NSUInteger segment = [newSegments count];

	NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? ", segment+1];
	for (int i = 2; i <= segment; i++)
	{
		[query appendFormat:@" AND seg%i = ? ", i];
	}
	[query appendFormat:@"ORDER BY seg%i COLLATE NOCASE", segment+1, segment+1];
	//DLog(@"query: %@", query);
	NSMutableArray *songMd5s = [[NSMutableArray alloc] initWithCapacity:0];
	[databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:query withArgumentsInArray:newSegments];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSString *md5 = [result stringForColumnIndex:0];
				if (md5) [songMd5s addObject:md5];
			}
		}
		[result close];
	}];
	
	//DLog(@"songMd5s: %@", songMd5s);
	for (NSString *md5 in songMd5s)
	{
		@autoreleasepool 
		{
			[Song removeSongFromCacheDbQueueByMD5:md5];
		}
	}
	
	[cacheS findCacheSize];
		
	// Reload the cached songs table
	[NSNotificationCenter postNotificationToMainThreadWithName:@"cachedSongDeleted"];
	
	if (!cacheQueueManagerS.isQueueDownloading)
		[cacheQueueManagerS startDownloadQueue];
	
	// Hide the loading screen
	[viewObjectsS hideLoadingScreen];
}

- (void)queueAction
{
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	[self performSelector:@selector(queueAllSongs) withObject:nil afterDelay:0.05];
	[self hideOverlay];
}

- (void)queueAllSongs
{
	NSMutableArray *newSegments = [NSMutableArray arrayWithArray:segments];
	[newSegments addObject:self.albumNameLabel.text];
	
	NSUInteger segment = [newSegments count];
	
	NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? ", segment+1];
	for (int i = 2; i <= segment; i++)
	{
		[query appendFormat:@" AND seg%i = ? ", i];
	}
	[query appendFormat:@"ORDER BY seg%i COLLATE NOCASE", segment+1, segment+1];
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:20];
	[databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:query withArgumentsInArray:newSegments];
		while ([result next])
		{
			NSString *md5 = [result stringForColumnIndex:0];
			if (md5) [songMd5s addObject:md5];
		}
		[result close];
	}];
	
	for (NSString *md5 in songMd5s)
	{
		@autoreleasepool 
		{
			Song *aSong = [Song songFromCacheDbQueue:md5];
			[aSong addToCurrentPlaylistDbQueue];
		}
	}
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	
	// Hide the loading screen
	[viewObjectsS hideLoadingScreen];
}

#pragma mark - Scrolling

- (void)scrollLabels
{
	if (self.albumNameLabel.frame.size.width > self.albumNameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:self.albumNameLabel.frame.size.width/150.];
		self.albumNameScrollView.contentOffset = CGPointMake(self.albumNameLabel.frame.size.width - self.albumNameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:self.albumNameLabel.frame.size.width/150.];
	self.albumNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
