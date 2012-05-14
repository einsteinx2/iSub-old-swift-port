//
//  PlaylistsUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "LocalPlaylistsUITableViewCell.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "NSString+md5.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueueAdditions.h"
#import "Song.h"
#import "CellOverlay.h"
#import "SavedSettings.h"
#import "NSNotificationCenter+MainThread.h"

@implementation LocalPlaylistsUITableViewCell

@synthesize md5, playlistCountLabel, playlistNameScrollView, playlistNameLabel;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
	{
		playlistCountLabel = [[UILabel alloc] init];
		playlistCountLabel.backgroundColor = [UIColor clearColor];
		playlistCountLabel.textAlignment = UITextAlignmentLeft; // default
		playlistCountLabel.font = [UIFont systemFontOfSize:16];
		playlistCountLabel.textColor = [UIColor colorWithWhite:.45 alpha:1];
		[self.contentView addSubview:playlistCountLabel];
		
		playlistNameScrollView = [[UIScrollView alloc] init];
		playlistNameScrollView.frame = CGRectMake(5, 0, 310, 44);
		playlistNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		playlistNameScrollView.showsVerticalScrollIndicator = NO;
		playlistNameScrollView.showsHorizontalScrollIndicator = NO;
		playlistNameScrollView.userInteractionEnabled = NO;
		playlistNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:playlistNameScrollView];
		
		playlistNameLabel = [[UILabel alloc] init];
		playlistNameLabel.backgroundColor = [UIColor clearColor];
		playlistNameLabel.textAlignment = UITextAlignmentLeft; // default
		playlistNameLabel.font = [UIFont boldSystemFontOfSize:20];
		[playlistNameScrollView addSubview:playlistNameLabel];
    }
    return self;
}


- (void)layoutSubviews 
{ 
    [super layoutSubviews];
	
	//self.deleteToggleImage.frame = CGRectMake(4.0, 18.5, 23.0, 23.0);
	self.playlistCountLabel.frame = CGRectMake(5, 35, 320, 20);
	
	// Automatically set the width based on the width of the text
	self.playlistNameLabel.frame = CGRectMake(0, 0, 290, 44);
	CGSize expectedLabelSize = [self.playlistNameLabel.text sizeWithFont:self.playlistNameLabel.font constrainedToSize:CGSizeMake(1000,44) lineBreakMode:self.playlistNameLabel.lineBreakMode]; 
	CGRect newFrame = self.playlistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	self.playlistNameLabel.frame = newFrame;
}

#pragma mark - Overlay

- (void)downloadAllSongs
{
	int count = [databaseS.localPlaylistsDbQueue intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM playlist%@", self.md5]];
	for (int i = 0; i < count; i++)
	{
		[[Song songFromDbRow:i inTable:[NSString stringWithFormat:@"playlist%@", self.md5] inDatabaseQueue:databaseS.localPlaylistsDbQueue] addToCacheQueueDbQueue];
	}
	
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
	if (settingsS.isJukeboxEnabled)
	{
		/*[databaseS.localPlaylistsDb executeUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:@"%@/currentPlaylist.db", databaseS.databaseFolderPath], @"currentPlaylistDb"];
		 if ([databaseS.localPlaylistsDb hadError]) { DLog(@"Err attaching the currentPlaylistDb %d: %@", [databaseS.localPlaylistsDb lastErrorCode], [databaseS.localPlaylistsDb lastErrorMessage]); }
		 [databaseS.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO currentPlaylist SELECT * FROM playlist%@", self.md5]];
		 [databaseS.localPlaylistsDb executeUpdate:@"DETACH DATABASE currentPlaylistDb"];*/
	}
	else
	{
		[databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
		{
			[db executeUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseS.databaseFolderPath, [settingsS.urlString md5]], @"currentPlaylistDb"];
			if ([db hadError]) { DLog(@"Err attaching the currentPlaylistDb %d: %@", [db lastErrorCode], [db lastErrorMessage]); }
			[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO currentPlaylist SELECT * FROM playlist%@", md5]];
			if ([db hadError]) { DLog(@"Err performing query %d: %@", [db lastErrorCode], [db lastErrorMessage]); }
			[db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
		}];
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	}
	
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
	if (self.playlistNameLabel.frame.size.width > self.playlistNameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:self.playlistNameLabel.frame.size.width/150.];
		self.playlistNameScrollView.contentOffset = CGPointMake(self.playlistNameLabel.frame.size.width - self.playlistNameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:self.playlistNameLabel.frame.size.width/150.];
	self.playlistNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
