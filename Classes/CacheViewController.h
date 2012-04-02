//
//  CacheViewController.h
//  iSub
//
//  Created by Ben Baron on 6/1/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@interface CacheViewController : UITableViewController 
{
	
	BOOL isNoSongsScreenShowing;
	UIImageView *noSongsScreen;
	
	UIView *headerView;
	UIView *headerView2;
	UISegmentedControl *segmentedControl;
	UILabel *songsCountLabel;
	UIButton *deleteSongsButton;
	UILabel *deleteSongsLabel;
	UILabel *spacerLabel;
	UILabel *editSongsLabel;
	UIButton *editSongsButton;
	BOOL isSaveEditShowing;
	
	UIImageView *playAllImage;
	UILabel *playAllLabel;
	UIButton *playAllButton;
	UILabel *spacerLabel2;
	UIImageView *shuffleImage;
	UILabel *shuffleLabel;
	UIButton *shuffleButton;
	
	//UIProgressView *queueDownloadProgressView;
	unsigned long long int queueDownloadProgress;
	NSTimer *updateTimer;
	
	NSMutableArray *listOfArtists;
	NSMutableArray *listOfArtistsSections;
	NSArray *sectionInfo;
	NSUInteger rowCounter;
		
	UIButton *jukeboxInputBlocker;
	
	BOOL showIndex;
}

@property (retain) NSMutableArray *listOfArtists;
@property (retain) NSMutableArray *listOfArtistsSections;
@property (retain) NSArray *sectionInfo;

@property (retain) UILabel *cacheSizeLabel;

//@property (retain) UIProgressView *queueDownloadProgressView;

- (void)updateCacheSizeLabel;
- (void)editSongsAction:(id)sender;

- (void)playAllPlaySong;
- (void)reloadTable;
- (void)updateQueueDownloadProgress;

@end
