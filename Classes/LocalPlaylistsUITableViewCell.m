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
#import "Song.h"
#import "CellOverlay.h"
#import "SavedSettings.h"

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
		[playlistCountLabel release];
		
		playlistNameScrollView = [[UIScrollView alloc] init];
		playlistNameScrollView.frame = CGRectMake(5, 0, 310, 44);
		playlistNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		playlistNameScrollView.showsVerticalScrollIndicator = NO;
		playlistNameScrollView.showsHorizontalScrollIndicator = NO;
		playlistNameScrollView.userInteractionEnabled = NO;
		playlistNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:playlistNameScrollView];
		[playlistNameScrollView release];
		
		playlistNameLabel = [[UILabel alloc] init];
		playlistNameLabel.backgroundColor = [UIColor clearColor];
		playlistNameLabel.textAlignment = UITextAlignmentLeft; // default
		playlistNameLabel.font = [UIFont boldSystemFontOfSize:20];
		[playlistNameScrollView addSubview:playlistNameLabel];
		[playlistNameLabel release];
    }
    return self;
}

- (void)layoutSubviews 
{
    [super layoutSubviews];
	
	self.deleteToggleImage.frame = CGRectMake(4.0, 18.5, 23.0, 23.0);
	playlistCountLabel.frame = CGRectMake(5, 35, 320, 20);
	
	// Automatically set the width based on the width of the text
	playlistNameLabel.frame = CGRectMake(0, 0, 290, 44);
	CGSize expectedLabelSize = [playlistNameLabel.text sizeWithFont:playlistNameLabel.font constrainedToSize:CGSizeMake(1000,44) lineBreakMode:playlistNameLabel.lineBreakMode]; 
	CGRect newFrame = playlistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	playlistNameLabel.frame = newFrame;
}

- (void)dealloc 
{
	[md5 release]; md5 = nil;
	
	[super dealloc];
}

#pragma mark - Overlay

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
		int count = [[DatabaseSingleton sharedInstance].localPlaylistsDb intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM playlist%@", md5]];
		for (int i = 0; i < count; i++)
		{
			[[Song songFromDbRow:i inTable:[NSString stringWithFormat:@"playlist%@", md5] inDatabase:[DatabaseSingleton sharedInstance].localPlaylistsDb] addToCacheQueue];
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
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
		{
			/*[databaseControls.localPlaylistsDb executeUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:@"%@/currentPlaylist.db", databaseControls.databaseFolderPath], @"currentPlaylistDb"];
			 if ([databaseControls.localPlaylistsDb hadError]) { DLog(@"Err attaching the currentPlaylistDb %d: %@", [databaseControls.localPlaylistsDb lastErrorCode], [databaseControls.localPlaylistsDb lastErrorMessage]); }
			 [databaseControls.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO currentPlaylist SELECT * FROM playlist%@", self.md5]];
			 [databaseControls.localPlaylistsDb executeUpdate:@"DETACH DATABASE currentPlaylistDb"];*/
		}
		else
		{
			DatabaseSingleton *databaseControls = [DatabaseSingleton sharedInstance];
			[databaseControls.localPlaylistsDb executeUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseControls.databaseFolderPath, [[SavedSettings sharedInstance].urlString md5]], @"currentPlaylistDb"];
			if ([databaseControls.localPlaylistsDb hadError]) { DLog(@"Err attaching the currentPlaylistDb %d: %@", [databaseControls.localPlaylistsDb lastErrorCode], [databaseControls.localPlaylistsDb lastErrorMessage]); }
			[databaseControls.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO currentPlaylist SELECT * FROM playlist%@", md5]];
			if ([databaseControls.localPlaylistsDb hadError]) { DLog(@"Err performing query %d: %@", [databaseControls.localPlaylistsDb lastErrorCode], [databaseControls.localPlaylistsDb lastErrorMessage]); }
			[databaseControls.localPlaylistsDb executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
		}
		
		[[ViewObjectsSingleton sharedInstance] performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:YES];
	}
}

#pragma mark - Scrolling

- (void)scrollLabels
{
	if (playlistNameLabel.frame.size.width > playlistNameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:playlistNameLabel.frame.size.width/150.];
		playlistNameScrollView.contentOffset = CGPointMake(playlistNameLabel.frame.size.width - playlistNameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:playlistNameLabel.frame.size.width/150.];
	playlistNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
