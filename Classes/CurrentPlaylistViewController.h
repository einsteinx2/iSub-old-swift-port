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
		
	//NSTimer *songHighlightTimer;
			
	BOOL savePlaylistLocal;
	
	NSMutableData *receivedData;
	NSURLConnection *connection;
	NSMutableURLRequest *request;
}

@property (retain) NSMutableURLRequest *request;

@property (retain) UITextField *playlistNameTextField;

@property NSUInteger currentPlaylistCount;

- (void) selectRow;

- (void) showDeleteButton;
- (void) hideDeleteButton;

@end
