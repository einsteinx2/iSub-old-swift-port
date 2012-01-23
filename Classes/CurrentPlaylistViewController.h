//
//  CurrentPlaylistViewController.h
//  iSub
//
//  Created by Ben Baron on 4/9/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, DatabaseSingleton, SUSCurrentPlaylistDAO;

@interface CurrentPlaylistViewController : UITableViewController 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	
	UIView *headerView;
	UILabel *savePlaylistLabel;
	UILabel *deleteSongsLabel;
	UILabel *playlistCountLabel;
	UIButton *savePlaylistButton;
	UILabel *editPlaylistLabel;
	
	UITextField *playlistNameTextField;
	
	//NSTimer *songHighlightTimer;
	
	BOOL goToNextSong;
	
	NSUInteger currentPlaylistCount;
}

@property (nonatomic, retain) SUSCurrentPlaylistDAO *dataModel;

- (void) selectRow;

- (void) showDeleteButton;
- (void) hideDeleteButton;

@end
