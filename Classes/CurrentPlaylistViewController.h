//
//  CurrentPlaylistViewController.h
//  iSub
//
//  Created by Ben Baron on 4/9/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class iSubAppDelegate, ViewObjectsSingleton, MusicControlsSingleton, DatabaseControlsSingleton;

@interface CurrentPlaylistViewController : UITableViewController 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicControlsSingleton *musicControls;
	DatabaseControlsSingleton *databaseControls;
	
	UIView *headerView;
	UILabel *savePlaylistLabel;
	UILabel *deleteSongsLabel;
	UILabel *playlistCountLabel;
	UIButton *savePlaylistButton;
	UILabel *editPlaylistLabel;
	
	UITextField *playlistNameTextField;
	
	//NSTimer *songHighlightTimer;
	
	BOOL goToNextSong;
}

- (void) selectRow;

- (void) showDeleteButton;
- (void) hideDeleteButton;

@end
