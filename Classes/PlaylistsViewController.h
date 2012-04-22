//
//  PlaylistsViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "BBSimpleConnectionQueue.h"
#import "SUSLoaderDelegate.h"

@class BBSimpleConnectionQueue, SUSServerPlaylistsDAO;

@interface PlaylistsViewController : UITableViewController <BBSimpleConnectionQueueDelegate, SUSLoaderDelegate>
{	
	UIView *headerView;
	UISegmentedControl *segmentedControl;
	UIImageView *noPlaylistsScreen;
	BOOL isNoPlaylistsScreenShowing;
	
	UILabel *savePlaylistLabel;
	UILabel *playlistCountLabel;
	UIButton *savePlaylistButton;
	UILabel *deleteSongsLabel;
	UILabel *spacerLabel;
	UILabel *editPlaylistLabel;
	UIButton *editPlaylistButton;
	BOOL isPlaylistSaveEditShowing;
					
	BBSimpleConnectionQueue *connectionQueue;
	
	BOOL savePlaylistLocal;
	
	NSMutableData *receivedData;
	NSURLConnection *connection;
	NSMutableURLRequest *request;
	
	//NSMutableData *receivedData;
}

@property (strong) NSMutableURLRequest *request;
@property (strong) SUSServerPlaylistsDAO *serverPlaylistsDataModel;
@property NSUInteger currentPlaylistCount;

@property (strong) UITextField *playlistNameTextField;

- (void)showDeleteButton;
- (void)hideDeleteButton;

- (void)segmentAction:(id)sender;
- (void)updateCurrentPlaylistCount;

- (void)parseData;
- (void)cancelLoad;

@end
