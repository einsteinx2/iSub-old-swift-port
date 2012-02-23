//
//  CurrentPlaylistViewController.h
//  iSub
//
//  Created by Ben Baron on 4/9/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@interface CurrentPlaylistViewController : UITableViewController 
{
	
	UIView *headerView;
	UILabel *savePlaylistLabel;
	UILabel *deleteSongsLabel;
	UILabel *playlistCountLabel;
	UIButton *savePlaylistButton;
	UILabel *editPlaylistLabel;
	
	UITextField *playlistNameTextField;
	
	//NSTimer *songHighlightTimer;
		
	NSUInteger currentPlaylistCount;
}

- (void) selectRow;

- (void) showDeleteButton;
- (void) hideDeleteButton;

@end
