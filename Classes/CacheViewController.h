//
//  CacheViewController.h
//  iSub
//
//  Created by Ben Baron on 6/1/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class iSubAppDelegate, ViewObjectsSingleton, MusicControlsSingleton, DatabaseControlsSingleton;

@interface CacheViewController : UITableViewController 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicControlsSingleton *musicControls;
	DatabaseControlsSingleton *databaseControls;
	
	BOOL isNoSongsScreenShowing;
	UIImageView *noSongsScreen;
	
	UIView *headerView;
	UIView *headerView2;
	UISegmentedControl *segmentedControl;
	UILabel *songsCountLabel;
	UILabel *cacheSizeLabel;
	UIButton *deleteSongsButton;
	UILabel *deleteSongsLabel;
	UILabel *spacerLabel;
	UILabel *editSongsLabel;
	UIButton *editSongsButton;
	BOOL isSaveEditShowing;
	
	//UIProgressView *queueDownloadProgressView;
	unsigned long long int queueDownloadProgress;
	NSTimer *updateTimer;
	
	NSMutableArray *listOfArtists;
	NSArray *sectionInfo;
	
	BOOL firstLoad;
	
	UIButton *jukeboxInputBlocker;
}

@property (nonatomic, retain) NSMutableArray *listOfArtists;
@property (nonatomic, retain) NSArray *sectionInfo;

//@property (nonatomic, retain) UIProgressView *queueDownloadProgressView;

- (void) editSongsAction:(id)sender;

@end
