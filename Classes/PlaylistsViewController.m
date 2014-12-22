//
//  PlaylistsViewController.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "iSub-Swift.h"
#import "PlaylistsViewController.h"
#import "ServerListViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "PlaylistSongsViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"

@interface PlaylistsViewController() <EX2SimpleConnectionQueueDelegate, ISMSLoaderDelegate, CustomUITableViewCellDelegate>
{
    SUSServerPlaylistsDAO *_serverPlaylistsDataModel;
    
    UIView *_headerView;
    UISegmentedControl *_segmentedControl;
    UIImageView *_noPlaylistsScreen;
    UILabel *_savePlaylistLabel;
    UILabel *_playlistCountLabel;
    UIButton *_savePlaylistButton;
    UILabel *_deleteSongsLabel;
    UILabel *_editPlaylistLabel;
    UIButton *_editPlaylistButton;
    
    EX2SimpleConnectionQueue *_connectionQueue;
    NSURLConnection *_connection;
    NSMutableURLRequest *_request;
    NSMutableData *_receivedData;
    
    BOOL _noPlaylistsScreenShowing;
    BOOL _playlistSaveEditShowing;
    BOOL _savePlaylistLocal;
    
    NSUInteger _currentPlaylistCount;
    
    SUSURLConnection *_cellConnection;
    
    void (^_cellSuccessBlock)(NSData *data, NSDictionary *userInfo);
}
@end


@implementation PlaylistsViewController

#pragma mark - Rotation -

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	if (!IS_IPAD() && _noPlaylistsScreenShowing)
	{
        [UIView animateWithDuration:duration animations:^{
            if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
            {
                _noPlaylistsScreen.transform = CGAffineTransformTranslate(_noPlaylistsScreen.transform, 0.0, -23.0);
            }
            else
            {
                _noPlaylistsScreen.transform = CGAffineTransformTranslate(_noPlaylistsScreen.transform, 0.0, 110.0);
            }
        }];
	}
}

#pragma mark - Lifecycle

- (void)viewDidLoad 
{
    [super viewDidLoad];
		
	_serverPlaylistsDataModel = [[SUSServerPlaylistsDAO alloc] initWithDelegate:self];
	
	_noPlaylistsScreenShowing = NO;
	_playlistSaveEditShowing = NO;
	_savePlaylistLocal = NO;
	
	_receivedData = nil;
	
	viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
	
    self.title = @"Playlists";
	
	// Setup segmented control in the header view
	_headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
	_headerView.backgroundColor = [UIColor colorWithWhite:.3 alpha:1];
	
    NSArray *items = settingsS.isOfflineMode ? @[@"Current", @"Offline Playlists"] : @[@"Current", @"Local", @"Server"];
    _segmentedControl = [[UISegmentedControl alloc] initWithItems:items];
	_segmentedControl.frame = CGRectMake(5, 5, 310, 36);
	_segmentedControl.selectedSegmentIndex = 0;
	_segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _segmentedControl.tintColor = ISMSHeaderColor;
	[_segmentedControl addTarget:self action:@selector(a_segment:) forControlEvents:UIControlEventValueChanged];
	[_headerView addSubview:_segmentedControl];
	
	self.tableView.tableHeaderView = _headerView;
		
	_connectionQueue = [[EX2SimpleConnectionQueue alloc] init];
	_connectionQueue.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
			
	if (settingsS.isPlaylistUnlocked)
	{
		// Reload the data in case it changed
		self.tableView.tableHeaderView.hidden = NO;
		[self a_segment:nil];
	}
	else
	{
		self.tableView.tableHeaderView.hidden = YES;
		//[self performSelector:@selector(addNoPlaylistsScreen) withObject:nil afterDelay:0.1];
		[self _addNoPlaylistsScreen];
	}
	
	[Flurry logEvent:@"PlaylistsTab"];

	[self _registerForNotifications];
	
	if (settingsS.isJukeboxEnabled)
		[jukeboxS jukeboxGetInfo];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	[self _unregisterForNotifications];
	
	if (self.tableView.editing)
	{
		// Clear the edit stuff if they switch tabs in the middle of editing
		viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		self.tableView.editing = NO;
        [self _unregisterForDeleteButtonNotifications];
	}
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _serverPlaylistsDataModel.delegate = nil;
    _connectionQueue = nil;
}

#pragma mark - Notifications -

- (void)_registerForNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_bassInitialized:)
                                                 name:ISMSNotification_BassInitialized object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_bassFreed:)
                                                 name:ISMSNotification_BassFreed object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_currentPlaylistIndexChanged:)
                                                 name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_currentPlaylistShuffleToggled:)
                                                 name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_currentPlaylistSongsQueued:)
                                                 name:ISMSNotification_CurrentPlaylistSongsQueued object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_storePurchaseComplete:)
                                                 name:ISMSNotification_StorePurchaseComplete object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_jukeboxSongInfo:)
                                                 name:ISMSNotification_JukeboxSongInfo object:nil];
}

- (void)_unregisterForNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_BassInitialized object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_BassFreed object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_StorePurchaseComplete object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistSongsQueued object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_JukeboxSongInfo object:nil];
}

- (void)_registerForDeleteButtonNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_showDeleteButton:)
                                                 name:ISMSNotification_ShowDeleteButton object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_hideDeleteButton:)
                                                 name:ISMSNotification_HideDeleteButton object:nil];
}

- (void)_unregisterForDeleteButtonNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_ShowDeleteButton object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_HideDeleteButton object:nil];
}

- (void)_bassInitialized:(NSNotification *)notification
{
    [self _selectRow];
}

- (void)_bassFreed:(NSNotification *)notification
{
    [self _selectRow];
}

- (void)_currentPlaylistIndexChanged:(NSNotification *)notification
{
    [self _selectRow];
}

- (void)_currentPlaylistShuffleToggled:(NSNotification *)notification
{
    [self _selectRow];
}

- (void)_currentPlaylistSongsQueued:(NSNotification *)notification
{
    [self _updateCurrentPlaylistCount];
    [self.tableView reloadData];
}

- (void)_storePurchaseComplete:(NSNotification *)notification
{
    [self viewWillAppear:NO];
}

- (void)_jukeboxSongInfo:(NSNotification *)notification
{
    [self _updateCurrentPlaylistCount];
    [self.tableView reloadData];
    [self _selectRow];
}

- (void)_showDeleteButton:(NSNotification *)notification
{
    [self _showDeleteButton];
}

- (void)_hideDeleteButton:(NSNotification *)notification
{
    [self _hideDeleteButton];
}

#pragma mark - Private -

#pragma mark UI

- (void)_updateCurrentPlaylistCount
{
	if (_segmentedControl.selectedSegmentIndex == 0)
	{
		_currentPlaylistCount = [playlistS count];

		if (_currentPlaylistCount == 1)
			_playlistCountLabel.text = [NSString stringWithFormat:@"1 song"];
		else 
			_playlistCountLabel.text = [NSString stringWithFormat:@"%lu songs", (unsigned long)_currentPlaylistCount];
	}
}

- (void)_removeEditControls
{
	// Clear the edit stuff if they switch tabs in the middle of editing
	if (self.tableView.editing)
	{
		viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		self.tableView.editing = NO;
        [self _unregisterForDeleteButtonNotifications];
	}
}

- (void)_removeSaveEditButtons
{
	// Remove the save and edit buttons if showing
	if (_playlistSaveEditShowing)
	{
		_headerView.frame = CGRectMake(0, 0, 320, 44);
		[_savePlaylistLabel removeFromSuperview];
		[_playlistCountLabel removeFromSuperview];
		[_savePlaylistButton removeFromSuperview];
		[_editPlaylistLabel removeFromSuperview];
		[_editPlaylistButton removeFromSuperview];
		[_deleteSongsLabel removeFromSuperview];
		_playlistSaveEditShowing = NO;
		self.tableView.tableHeaderView = _headerView;
	}
}

- (void)_addSaveEditButtons
{
	if (!_playlistSaveEditShowing)
	{
		// Modify the header view to include the save and edit buttons
		_playlistSaveEditShowing = YES;
		_headerView.frame = CGRectMake(0, 0, 320, 95);
		
		int y = 45;
		
		_savePlaylistLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, y, 227, 34)];
		_savePlaylistLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		_savePlaylistLabel.backgroundColor = [UIColor clearColor];
		_savePlaylistLabel.textColor = [UIColor whiteColor];
		_savePlaylistLabel.textAlignment = NSTextAlignmentCenter;
		_savePlaylistLabel.font = ISMSBoldFont(22);
		if (_segmentedControl.selectedSegmentIndex == 0)
		{
			_savePlaylistLabel.text = @"Save Playlist";
		}
		else if (_segmentedControl.selectedSegmentIndex == 1)
		{
			_savePlaylistLabel.frame = CGRectMake(0, y, 227, 50);
			NSUInteger localPlaylistsCount = [databaseS.localPlaylistsDbQueue intForQuery:@"SELECT COUNT(*) FROM localPlaylists"];
			if (localPlaylistsCount == 1)
				_savePlaylistLabel.text = [NSString stringWithFormat:@"1 playlist"];
			else 
				_savePlaylistLabel.text = [NSString stringWithFormat:@"%lu playlists", (unsigned long)localPlaylistsCount];
		}
		else if (_segmentedControl.selectedSegmentIndex == 2)
		{
			_savePlaylistLabel.frame = CGRectMake(0, y, 227, 50);
			NSUInteger serverPlaylistsCount = [_serverPlaylistsDataModel.serverPlaylists count];
			if (serverPlaylistsCount == 1)
				_savePlaylistLabel.text = [NSString stringWithFormat:@"1 playlist"];
			else 
				_savePlaylistLabel.text = [NSString stringWithFormat:@"%lu playlists", (unsigned long)serverPlaylistsCount];
			
		}
		[_headerView addSubview:_savePlaylistLabel];
		
		_playlistCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, y + 33, 227, 14)];
		_playlistCountLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		_playlistCountLabel.backgroundColor = [UIColor clearColor];
		_playlistCountLabel.textColor = [UIColor whiteColor];
		_playlistCountLabel.textAlignment = NSTextAlignmentCenter;
		_playlistCountLabel.font = ISMSBoldFont(12);
		if (_segmentedControl.selectedSegmentIndex == 0)
		{
			if (_currentPlaylistCount == 1)
				_playlistCountLabel.text = [NSString stringWithFormat:@"1 song"];
			else 
				_playlistCountLabel.text = [NSString stringWithFormat:@"%lu songs", (unsigned long)_currentPlaylistCount];
		}
		[_headerView addSubview:_playlistCountLabel];
		
		_savePlaylistButton = [UIButton buttonWithType:UIButtonTypeCustom];
		_savePlaylistButton.frame = CGRectMake(0, y, 232, 40);
		_savePlaylistButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
        [_savePlaylistButton addTarget:self action:@selector(a_savePlaylist:) forControlEvents:UIControlEventTouchUpInside];
		[_headerView addSubview:_savePlaylistButton];
		
		_editPlaylistLabel = [[UILabel alloc] initWithFrame:CGRectMake(232, y, 88, 50)];
		_editPlaylistLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
		_editPlaylistLabel.backgroundColor = [UIColor clearColor];
		_editPlaylistLabel.textColor = [UIColor whiteColor];
		_editPlaylistLabel.textAlignment = NSTextAlignmentCenter;
		_editPlaylistLabel.font = ISMSBoldFont(22);
		_editPlaylistLabel.text = @"Edit";
		[_headerView addSubview:_editPlaylistLabel];
		
		_editPlaylistButton = [UIButton buttonWithType:UIButtonTypeCustom];
		_editPlaylistButton.frame = CGRectMake(232, y, 88, 40);
		_editPlaylistButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
		[_editPlaylistButton addTarget:self action:@selector(a_editPlaylist:) forControlEvents:UIControlEventTouchUpInside];
		[_headerView addSubview:_editPlaylistButton];	
		
		_deleteSongsLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, y, 232, 50)];
		_deleteSongsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		_deleteSongsLabel.backgroundColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:.5];
		_deleteSongsLabel.textColor = [UIColor whiteColor];
		_deleteSongsLabel.textAlignment = NSTextAlignmentCenter;
		_deleteSongsLabel.font = ISMSBoldFont(22);
		_deleteSongsLabel.adjustsFontSizeToFitWidth = YES;
		_deleteSongsLabel.minimumScaleFactor = 12.0 / _deleteSongsLabel.font.pointSize;
		if (_segmentedControl.selectedSegmentIndex == 0)
		{
			_deleteSongsLabel.text = @"Remove # Songs";
		}
		else if (_segmentedControl.selectedSegmentIndex == 1)
		{
			_deleteSongsLabel.text = @"Remove # Playlists";
		}
		_deleteSongsLabel.hidden = YES;
		[_headerView addSubview:_deleteSongsLabel];
		
		self.tableView.tableHeaderView = _headerView;
	}
	else
	{
		if (_segmentedControl.selectedSegmentIndex == 0)
		{
			if (_currentPlaylistCount == 1)
				_playlistCountLabel.text = [NSString stringWithFormat:@"1 song"];
			else 
				_playlistCountLabel.text = [NSString stringWithFormat:@"%lu songs", (unsigned long)_currentPlaylistCount];
		}
		else if (_segmentedControl.selectedSegmentIndex == 1)
		{
			NSUInteger localPlaylistsCount = [databaseS.localPlaylistsDbQueue intForQuery:@"SELECT COUNT(*) FROM localPlaylists"];
			if (localPlaylistsCount == 1)
				_playlistCountLabel.text = [NSString stringWithFormat:@"1 playlist"];
			else 
				_playlistCountLabel.text = [NSString stringWithFormat:@"%lu playlists", (unsigned long)localPlaylistsCount];
		}
		else if (_segmentedControl.selectedSegmentIndex == 2)
		{
			NSUInteger serverPlaylistsCount = [_serverPlaylistsDataModel.serverPlaylists count];
			if (serverPlaylistsCount == 1)
				_playlistCountLabel.text = [NSString stringWithFormat:@"1 playlist"];
			else 
				_playlistCountLabel.text = [NSString stringWithFormat:@"%lu playlists", (unsigned long)serverPlaylistsCount];
			
		}
	}
}

- (void)_removeNoPlaylistsScreen
{
	// Remove the no playlists overlay screen if it's showing
	if (_noPlaylistsScreenShowing)
	{
		[_noPlaylistsScreen removeFromSuperview];
		_noPlaylistsScreenShowing = NO;
	}
}

- (void)_addNoPlaylistsScreen
{
	[self _removeNoPlaylistsScreen];
	
	_noPlaylistsScreenShowing = YES;
	_noPlaylistsScreen = [[UIImageView alloc] init];
	_noPlaylistsScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
	_noPlaylistsScreen.frame = CGRectMake(40, 100, 240, 180);
	_noPlaylistsScreen.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height / 2);
	_noPlaylistsScreen.image = [UIImage imageNamed:@"loading-screen-image"];
	_noPlaylistsScreen.alpha = .80;
	_noPlaylistsScreen.userInteractionEnabled = YES;
	
	UILabel *textLabel = [[UILabel alloc] init];
	textLabel.backgroundColor = [UIColor clearColor];
	textLabel.textColor = [UIColor whiteColor];
	textLabel.font = ISMSBoldFont(30);
	textLabel.textAlignment = NSTextAlignmentCenter;
	textLabel.numberOfLines = 0;
	if (settingsS.isPlaylistUnlocked)
	{
		if (_segmentedControl.selectedSegmentIndex == 0)
		{
			textLabel.text = @"No Songs\nQueued";
			textLabel.frame = CGRectMake(20, 0, 200, 100);
		}
		else if (_segmentedControl.selectedSegmentIndex == 1 || _segmentedControl.selectedSegmentIndex == 2)
		{
			textLabel.text = @"No Playlists\nFound";
			textLabel.frame = CGRectMake(20, 20, 200, 140);
		}
	}
	else
	{
		textLabel.text = @"Playlists\nLocked";
		textLabel.frame = CGRectMake(20, 0, 200, 100);
	}
	[_noPlaylistsScreen addSubview:textLabel];
	
	UILabel *textLabel2 = [[UILabel alloc] init];
	textLabel2.backgroundColor = [UIColor clearColor];
	textLabel2.textColor = [UIColor whiteColor];
	textLabel2.font = ISMSBoldFont(14);
	textLabel2.textAlignment = NSTextAlignmentCenter;
	textLabel2.numberOfLines = 0;
	if (settingsS.isPlaylistUnlocked)
	{
		if (_segmentedControl.selectedSegmentIndex == 0)
		{
			
			textLabel2.text = @"Swipe to the right on any song, album, or artist to bring up the Queue button";
			textLabel2.frame = CGRectMake(20, 100, 200, 60);
		}
	}
	else
	{
		textLabel2.text = @"Tap to purchase the ability to view, create, and manage playlists";
		textLabel2.frame = CGRectMake(20, 100, 200, 60);
	}
	[_noPlaylistsScreen addSubview:textLabel2];
	
	if (!settingsS.isPlaylistUnlocked)
	{
		UIButton *storeLauncher = [UIButton buttonWithType:UIButtonTypeCustom];
		storeLauncher.frame = CGRectMake(0, 0, _noPlaylistsScreen.frame.size.width, _noPlaylistsScreen.frame.size.height);
		[storeLauncher addTarget:self action:@selector(_showStore) forControlEvents:UIControlEventTouchUpInside];
		[_noPlaylistsScreen addSubview:storeLauncher];
	}
	
	[self.view addSubview:_noPlaylistsScreen];
	
	if (!IS_IPAD())
	{
		if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
		{
			//noPlaylistsScreen.transform = CGAffineTransformScale(noPlaylistsScreen.transform, 0.75, 0.75);
			_noPlaylistsScreen.transform = CGAffineTransformTranslate(_noPlaylistsScreen.transform, 0.0, 23.0);
		}
	}
}

- (void)_showStore
{
//	StoreViewController *store = [[StoreViewController alloc] init];
//	[self pushViewControllerCustom:store];
}

- (void)_showDeleteButton
{
    if (_segmentedControl.selectedSegmentIndex == 0)
    {
        if ([viewObjectsS.multiDeleteList count] == 0)
        {
            _deleteSongsLabel.text = @"Select All";
        }
        else if ([viewObjectsS.multiDeleteList count] == 1)
        {
            _deleteSongsLabel.text = @"Remove 1 Song  ";
        }
        else
        {
            _deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %lu Songs", (unsigned long)[viewObjectsS.multiDeleteList count]];
        }
    }
    else if (_segmentedControl.selectedSegmentIndex == 1 ||
             _segmentedControl.selectedSegmentIndex == 2)
    {
        if ([viewObjectsS.multiDeleteList count] == 0)
        {
            _deleteSongsLabel.text = @"Select All";
        }
        else if ([viewObjectsS.multiDeleteList count] == 1)
        {
            _deleteSongsLabel.text = @"Remove 1 Playlist";
        }
        else
        {
            _deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %lu Playlists", (unsigned long)[viewObjectsS.multiDeleteList count]];
        }
    }
    
    _savePlaylistLabel.hidden = YES;
    _playlistCountLabel.hidden = YES;
    _deleteSongsLabel.hidden = NO;
}

- (void)_hideDeleteButton
{
    if (_segmentedControl.selectedSegmentIndex == 0)
    {
        if ([viewObjectsS.multiDeleteList count] == 0)
        {
            if (!self.tableView.editing)
            {
                _savePlaylistLabel.hidden = NO;
                _playlistCountLabel.hidden = NO;
                _deleteSongsLabel.hidden = YES;
            }
            else
            {
                _deleteSongsLabel.text = @"Clear Playlist";
            }
        }
        else if ([viewObjectsS.multiDeleteList count] == 1)
        {
            _deleteSongsLabel.text = @"Remove 1 Song  ";
        }
        else
        {
            _deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %lu Songs", (unsigned long)[viewObjectsS.multiDeleteList count]];
        }
    }
    else if (_segmentedControl.selectedSegmentIndex == 1 ||
             _segmentedControl.selectedSegmentIndex == 2)
    {
        if ([viewObjectsS.multiDeleteList count] == 0)
        {
            if (!self.tableView.editing)
            {
                _savePlaylistLabel.hidden = NO;
                _playlistCountLabel.hidden = NO;
                _deleteSongsLabel.hidden = YES;
            }
            else
            {
                _deleteSongsLabel.text = @"Clear Playlists";
            }
        }
        else if ([viewObjectsS.multiDeleteList count] == 1)
        {
            _deleteSongsLabel.text = @"Remove 1 Playlist";
        }
        else 
        {
            _deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %lu Playlists", (unsigned long)[viewObjectsS.multiDeleteList count]];
        }
    }
}

- (void)_selectRow
{
    if (_segmentedControl.selectedSegmentIndex == 0)
    {
        [self.tableView reloadData];
        if (playlistS.currentIndex >= 0 && playlistS.currentIndex < _currentPlaylistCount)
        {
            [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:playlistS.currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
        }
    }
}

- (void)_showSavePlaylistTextBoxAlert
{
    UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Playlist Name:" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
    myAlertView.alertViewStyle = UIAlertViewStylePlainTextInput;
    [myAlertView show];
}

#pragma mark Other

- (void)_uploadPlaylist:(NSString*)name
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(name), @"name", nil];
    
    NSMutableArray *songIds = [NSMutableArray arrayWithCapacity:_currentPlaylistCount];
    NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
    NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
    NSString *table = playlistS.isShuffle ? shufTable : currTable;
    
    [databaseS.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
     {
         for (int i = 0; i < _currentPlaylistCount; i++)
         {
             @autoreleasepool
             {
                 ISMSSong *aSong = [ISMSSong songFromDbRow:i inTable:table inDatabase:db];
                 [songIds addObject:n2N(aSong.songId)];
             }
         }
     }];
    [parameters setObject:[NSArray arrayWithArray:songIds] forKey:@"songId"];
    
    _request = [NSMutableURLRequest requestWithSUSAction:@"createPlaylist" parameters:parameters];
    
    _connection = [[NSURLConnection alloc] initWithRequest:_request delegate:self];
    if (_connection)
    {
        _receivedData = [NSMutableData data];
        
        self.tableView.scrollEnabled = NO;
        [viewObjectsS showAlbumLoadingScreen:self.view sender:self];
    }
    else
    {
        // Inform the user that the connection failed.
        CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error saving the playlist to the server.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    }
}

#pragma mark - Actions -

- (void)a_segment:(id)sender
{
	if (_segmentedControl.selectedSegmentIndex == 0)
	{		
		// Get the current playlist count
        [self _updateCurrentPlaylistCount];

		// Clear the edit stuff if they switch tabs in the middle of editing
		[self _removeEditControls];
		
		// Remove the save and edit buttons if showing
		[self _removeSaveEditButtons];
		
		if (_currentPlaylistCount > 0)
		{
			// Modify the header view to include the save and edit buttons
			[self _addSaveEditButtons];
		}
		
		// Reload the table data
		[self.tableView reloadData];
		
		// TODO: do this for iPad as well, different minScrollRow values
		NSUInteger minScrollRow = 5;
		if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
			minScrollRow = 2;
		
		UITableViewScrollPosition scrollPosition = UITableViewScrollPositionNone;
		if (playlistS.currentIndex > minScrollRow)
			scrollPosition = UITableViewScrollPositionMiddle;
		
		if (playlistS.currentIndex >= 0 && playlistS.currentIndex < _currentPlaylistCount)
		{
			[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:playlistS.currentIndex inSection:0] animated:NO scrollPosition:scrollPosition];
		}
		
		// Remove the no playlists overlay screen if it's showing
		[self _removeNoPlaylistsScreen];
		
		// If the list is empty, display the no playlists overlay screen
		if (_currentPlaylistCount == 0)
		{
			[self _addNoPlaylistsScreen];
		}
		
		// If the list is empty remove the Save/Edit bar
		if (_currentPlaylistCount == 0)
		{
			[self _removeSaveEditButtons];
		}
	}
	else if(_segmentedControl.selectedSegmentIndex == 1)
	{
		// Clear the edit stuff if they switch tabs in the middle of editing
		[self _removeEditControls];
		
		// Remove the save and edit buttons if showing
		[self _removeSaveEditButtons];
		
		NSUInteger localPlaylistsCount = [databaseS.localPlaylistsDbQueue intForQuery:@"SELECT COUNT(*) FROM localPlaylists"];
		
		if (localPlaylistsCount > 0)
		{
			// Modify the header view to include the save and edit buttons
			[self _addSaveEditButtons];
		}
		
		// Reload the table data
		[self.tableView reloadData];
		
		// Remove the no playlists overlay screen if it's showing
		[self _removeNoPlaylistsScreen];
		
		// If the list is empty, display the no playlists overlay screen
		if (localPlaylistsCount == 0)
		{
			[self _addNoPlaylistsScreen];
		}
	}
	else if(_segmentedControl.selectedSegmentIndex == 2)
	{
		// Clear the edit stuff if they switch tabs in the middle of editing
		[self _removeEditControls];
		
		// Remove the save and edit buttons if showing
		[self _removeSaveEditButtons];

		// Reload the table data
		[self.tableView reloadData];
		
		// Remove the no playlists overlay screen if it's showing
		[self _removeNoPlaylistsScreen];
		
        [viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
        [_serverPlaylistsDataModel startLoad];
	}
}

- (void)a_editPlaylist:(id)sender
{
	if (_segmentedControl.selectedSegmentIndex == 0)
	{
		if (!self.tableView.editing)
		{
			[self.tableView reloadData];
            [self _registerForDeleteButtonNotifications];
			viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			[self.tableView setEditing:YES animated:YES];
			_editPlaylistLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
			_editPlaylistLabel.text = @"Done";
			[self _showDeleteButton];
			
			[self showDeleteToggles];
		}
		else 
		{
            [self _unregisterForDeleteButtonNotifications];
			viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			[self.tableView setEditing:NO animated:YES];
			[self _hideDeleteButton];
			_editPlaylistLabel.backgroundColor = [UIColor clearColor];
			_editPlaylistLabel.text = @"Edit";
			
			// Reload the table to correct the numbers
			[self.tableView reloadData];
			if (playlistS.currentIndex >= 0 && playlistS.currentIndex < _currentPlaylistCount)
			{
				[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:playlistS.currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
			}
            [self hideDeleteToggles];
		}
	}
	else if (_segmentedControl.selectedSegmentIndex == 1 ||
			 _segmentedControl.selectedSegmentIndex == 2)
	{
		if (!self.tableView.editing)
		{
			[self.tableView reloadData];
            [self _registerForDeleteButtonNotifications];
			viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			[self.tableView setEditing:YES animated:YES];
			_editPlaylistLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
			_editPlaylistLabel.text = @"Done";
			[self _showDeleteButton];
			
			[self showDeleteToggles];
		}
		else 
		{
            [self _unregisterForDeleteButtonNotifications];
			viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			[self.tableView setEditing:NO animated:YES];
			[self _hideDeleteButton];
			_editPlaylistLabel.backgroundColor = [UIColor clearColor];
			_editPlaylistLabel.text = @"Edit";
			
			// Reload the table to correct the numbers
			[self.tableView reloadData];
            
            [self hideDeleteToggles];
		}
	}
}

- (void)a_delete:(id)sender
{
	[self _unregisterForNotifications];
	
	if (_segmentedControl.selectedSegmentIndex == 0)
	{
		[playlistS deleteSongs:viewObjectsS.multiDeleteList];
		[self _updateCurrentPlaylistCount];
		
		[self.tableView reloadData];
		
		[self a_editPlaylist:nil];
		[self a_segment:nil];
	}
	else if (_segmentedControl.selectedSegmentIndex == 1)
	{
		// Sort the multiDeleteList to make sure it's accending
		[viewObjectsS.multiDeleteList sortUsingSelector:@selector(compare:)];
		
		[databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
		{
			[db executeUpdate:@"DROP TABLE localPlaylistsTemp"];
			[db executeUpdate:@"CREATE TABLE localPlaylistsTemp(playlist TEXT, md5 TEXT)"];
			for (NSNumber *index in [viewObjectsS.multiDeleteList reverseObjectEnumerator])
			{
				@autoreleasepool 
				{
					NSInteger rowId = [index integerValue] + 1;
					NSString *md5 = [db stringForQuery:[NSString stringWithFormat:@"SELECT md5 FROM localPlaylists WHERE ROWID = %li", (long)rowId]];
					[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE playlist%@", md5]];
					[db executeUpdate:@"DELETE FROM localPlaylists WHERE md5 = ?", md5];
				}
			}
			[db executeUpdate:@"INSERT INTO localPlaylistsTemp SELECT * FROM localPlaylists"];
			[db executeUpdate:@"DROP TABLE localPlaylists"];
			[db executeUpdate:@"ALTER TABLE localPlaylistsTemp RENAME TO localPlaylists"];
		}];
		
		[self.tableView reloadData];
		
		[self a_editPlaylist:nil];
		[self a_segment:nil];
	}
	
	[viewObjectsS hideLoadingScreen];
	
	[self _registerForNotifications];	
}

- (void)a_savePlaylist:(id)sender
{
	if (_segmentedControl.selectedSegmentIndex == 0)
	{
		if (_deleteSongsLabel.hidden == YES)
		{
			if (!self.tableView.editing)
			{
				if (settingsS.isOfflineMode)
				{
					[self _showSavePlaylistTextBoxAlert];
				}
				else
				{
					_savePlaylistLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
					_playlistCountLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
					
					UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Local or Server?" 
																		  message:@"Would you like to save this playlist to your device or to your Subsonic server?" 
																		 delegate:self 
																cancelButtonTitle:nil
																otherButtonTitles:@"Local", @"Server", nil];
					[myAlertView show];
				}
			}
		}
		else 
		{
			if ([viewObjectsS.multiDeleteList count] == 0)
			{
				// Select all the rows
				for (int i = 0; i < _currentPlaylistCount; i++)
				{
					[viewObjectsS.multiDeleteList addObject:@(i)];
				}
				[self.tableView reloadData];
				[self _showDeleteButton];
			}
			else
			{
				// Delete action
				[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Deleting"];
				[self performSelector:@selector(a_delete:) withObject:nil afterDelay:0.05];
			}
		}
	}
	else if (_segmentedControl.selectedSegmentIndex == 1)
	{
		if (_deleteSongsLabel.hidden == NO)
		{
			if ([viewObjectsS.multiDeleteList count] == 0)
			{
				// Select all the rows
				NSUInteger count = [databaseS.localPlaylistsDbQueue intForQuery:@"SELECT COUNT(*) FROM localPlaylists"];
				for (int i = 0; i < count; i++)
				{
					[viewObjectsS.multiDeleteList addObject:@(i)];
				}
				[self.tableView reloadData];
				[self _showDeleteButton];
			}
			else
			{
				// Delete action
				[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Deleting"];
				[self performSelector:@selector(a_delete:) withObject:nil afterDelay:0.05];
			}
		}
	}
	else if (_segmentedControl.selectedSegmentIndex == 2)
	{
		if (_deleteSongsLabel.hidden == NO)
		{
			if ([viewObjectsS.multiDeleteList count] == 0)
			{
				// Select all the rows
				NSUInteger count = [_serverPlaylistsDataModel.serverPlaylists count];
				for (int i = 0; i < count; i++)
				{
					[viewObjectsS.multiDeleteList addObject:@(i)];
				}
				[self.tableView reloadData];
				[self _showDeleteButton];
			}
			else
			{
				self.tableView.scrollEnabled = NO;
				[viewObjectsS showAlbumLoadingScreen:self.view sender:self];
				
				for (NSNumber *index in viewObjectsS.multiDeleteList)
				{
                    NSString *playlistId = [[_serverPlaylistsDataModel.serverPlaylists objectAtIndexSafe:[index intValue]] playlistId];
                    NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(playlistId) forKey:@"id"];
                    DLog(@"parameters: %@", parameters);
                    NSMutableURLRequest *aRequest = [NSMutableURLRequest requestWithSUSAction:@"deletePlaylist" parameters:parameters];
                    
					_connection = [[NSURLConnection alloc] initWithRequest:aRequest delegate:self startImmediately:NO];
					if (_connection)
					{
						[_connectionQueue registerConnection:_connection];
						[_connectionQueue startQueue];
					} 
					else 
					{
					//DLog(@"There was an error deleting a server playlist, could not create network request");
					}
				}
			}
		}
	}
}

- (void)cancelLoad
{
	if (_segmentedControl.selectedSegmentIndex == 0)
	{
		[_connection cancel];
	}
	else
	{
		if (_connectionQueue.isRunning)
		{
			[_connectionQueue clearQueue];
			
			[self connectionQueueDidFinish:_connectionQueue];
		}
		else
		{
			[_serverPlaylistsDataModel cancelLoad];
			[viewObjectsS hideLoadingScreen];
		}
	}
}

#pragma mark - UIAlertView Delegate -

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ([alertView.title isEqualToString:@"Local or Server?"])
    {
        if (buttonIndex == 0)
        {
            _savePlaylistLocal = YES;
        }
        else if (buttonIndex == 1)
        {
            _savePlaylistLocal = NO;
        }
        else if (buttonIndex == 2)
        {
            return;
        }
        
        [self _showSavePlaylistTextBoxAlert];
    }
    else if([alertView.title isEqualToString:@"Playlist Name:"])
    {
        NSString *text = [alertView textFieldAtIndex:0].text;
        if(buttonIndex == 1)
        {
            if (_savePlaylistLocal || settingsS.isOfflineMode)
            {
                // Check if the playlist exists, if not create the playlist table and add the entry to localPlaylists table
                NSString *test = [databaseS.localPlaylistsDbQueue stringForQuery:@"SELECT md5 FROM localPlaylists WHERE md5 = ?", [text md5]];
                if (!test)
                {
                    NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", [settingsS.urlString md5]];
                    NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
                    NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
                    NSString *table = playlistS.isShuffle ? shufTable : currTable;
                    
                    [databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
                     {
                         [db executeUpdate:@"INSERT INTO localPlaylists (playlist, md5) VALUES (?, ?)", text, [text md5]];
                         [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (%@)", [text md5], [ISMSSong standardSongColumnSchema]]];
                         
                         [db executeUpdate:@"ATTACH DATABASE ? AS ?", [databaseS.databaseFolderPath stringByAppendingPathComponent:databaseName], @"currentPlaylist"];
                         //[db executeUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseS.databaseFolderPath, [settingsS.urlString md5]], @"currentPlaylistDb"];
                         if ([db hadError]) { DLog(@"Err attaching the currentPlaylistDb %d: %@", [db lastErrorCode], [db lastErrorMessage]); }
                         
                         [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM %@", [text md5], table]];
                         [db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
                     }];
                }
                else
                {
                    // If it exists, ask to overwrite
                    UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Overwrite?" message:@"There is already a playlist with this name. Would you like to overwrite it?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
                    [myAlertView ex2SetCustomObject:text forKey:@"name"];
                    [myAlertView show];
                }
            }
            else
            {
                NSString *tableName = [NSString stringWithFormat:@"splaylist%@", [text md5]];
                if ([databaseS.localPlaylistsDbQueue tableExists:tableName])
                {
                    // If it exists, ask to overwrite
                    UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Overwrite?" message:@"There is already a playlist with this name. Would you like to overwrite it?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
                    [myAlertView ex2SetCustomObject:text forKey:@"name"];
                    [myAlertView show];
                }
                else
                {
                    [self _uploadPlaylist:text];
                }
            }
        }
    }
    else if([alertView.title isEqualToString:@"Overwrite?"])
    {
        NSString *text = [alertView ex2CustomObjectForKey:@"name"];
        if(buttonIndex == 1)
        {
            if (_savePlaylistLocal || settingsS.isOfflineMode)
            {
                NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", [settingsS.urlString md5]];
                NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
                NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
                NSString *table = playlistS.isShuffle ? shufTable : currTable;
                
                [databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
                 {
                     // If yes, overwrite the playlist
                     [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE playlist%@", [text md5]]];
                     [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (%@)", [text md5], [ISMSSong standardSongColumnSchema]]];
                     
                     [db executeUpdate:@"ATTACH DATABASE ? AS ?", [databaseS.databaseFolderPath stringByAppendingPathComponent:databaseName], @"currentPlaylistDb"];
                     if ([db hadError]) { DLog(@"Err attaching the currentPlaylistDb %d: %@", [db lastErrorCode], [db lastErrorMessage]); }
                     
                     [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM %@", [text md5], table]];
                     [db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
                 }];				
            }
            else
            {
                [databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
                 {
                     [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE splaylist%@", [text md5]]];
                 }];
                
                [self _uploadPlaylist:text];
            }
        }
    }
    
    _savePlaylistLabel.backgroundColor = [UIColor clearColor];
    _playlistCountLabel.backgroundColor = [UIColor clearColor];
}

#pragma mark - ISMSLoader Delegate -

- (void)loadingFailed:(ISMSLoader *)theLoader withError:(NSError *)error
{
    [viewObjectsS hideLoadingScreen];
}

- (void)loadingFinished:(ISMSLoader *)theLoader
{    
    [self.tableView reloadData];
    
    // If the list is empty, display the no playlists overlay screen
    if ([_serverPlaylistsDataModel.serverPlaylists count] == 0 && _noPlaylistsScreenShowing == NO)
    {
		[self _addNoPlaylistsScreen];
    }
    else
    {
        // Modify the header view to include the save and edit buttons
        [self _addSaveEditButtons];
    }
    
    // Hide the loading screen
    [viewObjectsS hideLoadingScreen];
}

#pragma mark - EX2SimpleConnectionQueue Delegate -

- (void)connectionQueueDidFinish:(id)connectionQueue
{
    [viewObjectsS hideLoadingScreen];
    self.tableView.scrollEnabled = YES;
    [self a_editPlaylist:nil];
    [self a_segment:nil];
}

#pragma mark - Connection Delegate -

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	if (_segmentedControl.selectedSegmentIndex == 0)
		[_receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
	if (_segmentedControl.selectedSegmentIndex == 0)
		[_receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	NSString *message = @"";
	if (_segmentedControl.selectedSegmentIndex == 0)
	{
		message = [NSString stringWithFormat:@"There was an error saving the playlist to the server.\n\nError %li: %@", 
				   (long)[error code],
				   [error localizedDescription]];
	}
	else
	{
		message = [NSString stringWithFormat:@"There was an error loading the playlists.\n\nError %li: %@",
				   (long)[error code],
				   [error localizedDescription]];
	}
	
	// Inform the user that the connection failed.
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	
	self.tableView.scrollEnabled = YES;
	[viewObjectsS hideLoadingScreen];
	
	
	if (_segmentedControl.selectedSegmentIndex == 0)
	{
	}
	else
	{
		[_connectionQueue connectionFinished:theConnection];
	}
}	

- (NSURLRequest *)connection: (NSURLConnection *)inConnection willSendRequest:(NSURLRequest *)inRequest redirectResponse:(NSURLResponse *)inRedirectResponse;
{
    if (inRedirectResponse) 
	{
        NSMutableURLRequest *newRequest = [_request mutableCopy];
        [newRequest setURL:[inRequest URL]];
        return newRequest;
    } 
	else 
	{
        return inRequest;
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	if (_segmentedControl.selectedSegmentIndex == 0)
	{
		[self _parseData];
	}
	else
	{
		[_connectionQueue connectionFinished:theConnection];
	}
	
	self.tableView.scrollEnabled = YES;
}

static NSString *kName_Error = @"error";

- (void)_subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil];
	alert.tag = 1;
	[alert show];
}

- (void)_parseData
{
    // Parse the data
    //
    RXMLElement *root = [[RXMLElement alloc] initFromXMLData:_receivedData];
    if (![root isValid])
    {
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
        [self _subsonicErrorCode:nil message:error.description];
    }
    else
    {
        RXMLElement *error = [root child:@"error"];
        if ([error isValid])
        {
            NSString *code = [error attribute:@"code"];
            NSString *message = [error attribute:@"message"];
            [self _subsonicErrorCode:code message:message];
        }
    }
	
	[viewObjectsS hideLoadingScreen];
}

#pragma mark - Table View Delegate -

// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView 
{
	if (_segmentedControl.selectedSegmentIndex == 0 && _currentPlaylistCount > 0)
	{
		if (!self.tableView.editing)
		{
			NSMutableArray *searchIndexes = [[NSMutableArray alloc] init];
			for (int x = 0; x < 20; x++)
			{
				[searchIndexes addObject:@"●"];
			}
			return searchIndexes;
		}
		else
		{
			return nil;
		}
	}
	else 
	{
		return nil;
	}

}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index 
{
	if (_segmentedControl.selectedSegmentIndex == 0)
	{
		if (index == 0)
		{
			[tableView scrollRectToVisible:CGRectMake(0, 0, 320, 40) animated:NO];
		}
		else if (index == 19)
		{
			NSInteger row = _currentPlaylistCount - 1;
			[tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
		}
		else 
		{
			NSInteger row = _currentPlaylistCount / 20 * index;
			[tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
			return -1;		
		}
	}
	
	return index - 1;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{	
	if (_segmentedControl.selectedSegmentIndex == 0)
		return _currentPlaylistCount;
	else if (_segmentedControl.selectedSegmentIndex == 1)
		return [databaseS.localPlaylistsDbQueue intForQuery:@"SELECT COUNT(*) FROM localPlaylists"];
	else if (_segmentedControl.selectedSegmentIndex == 2)
		return _serverPlaylistsDataModel.serverPlaylists.count;
	
	return 0;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return YES;
}

// Set the editing style, set to none for no delete minus sign (overriding with own custom multi-delete boxes)
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return UITableViewCellEditingStyleNone;
}


// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath 
{
	if (_segmentedControl.selectedSegmentIndex == 0)
	{
		NSInteger fromRow = fromIndexPath.row + 1;
		NSInteger toRow = toIndexPath.row + 1;
		
		[databaseS.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
		{
			NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
			NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
			NSString *table = playlistS.isShuffle ? shufTable : currTable;
			
		//DLog(@"table: %@", table);
			
			[db executeUpdate:@"DROP TABLE moveTemp"];
			NSString *query = [NSString stringWithFormat:@"CREATE TABLE moveTemp (%@)", [ISMSSong standardSongColumnSchema]];
			[db executeUpdate:query];
			
			if (fromRow < toRow)
			{
				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID < ?", table], @(fromRow)];
				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID > ? AND ROWID <= ?", table], @(fromRow), @(toRow)];
				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID = ?", table], @(fromRow)];
				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID > ?", table], @(toRow)];
				
				[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE %@", table]];
				[db executeUpdate:[NSString stringWithFormat:@"ALTER TABLE moveTemp RENAME TO %@", table]];
			}
			else
			{
				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID < ?", table], @(toRow)];
				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID = ?", table], @(fromRow)];
				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID >= ? AND ROWID < ?", table], @(toRow), @(fromRow)];
				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID > ?", table], @(fromRow)];
				
				[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE %@", table]];
				[db executeUpdate:[NSString stringWithFormat:@"ALTER TABLE moveTemp RENAME TO %@", table]];
			}
		}];
		
		if (settingsS.isJukeboxEnabled)
		{
			[jukeboxS jukeboxReplacePlaylistWithLocal];
		}
				
		// Fix the multiDeleteList to reflect the new row positions
		if ([viewObjectsS.multiDeleteList count] > 0)
		{
			NSMutableArray *tempMultiDeleteList = [[NSMutableArray alloc] init];
			int newPosition;
			for (NSNumber *position in viewObjectsS.multiDeleteList)
			{
				if (fromIndexPath.row > toIndexPath.row)
				{
					if ([position intValue] >= toIndexPath.row && [position intValue] <= fromIndexPath.row)
					{
						if ([position intValue] == fromIndexPath.row)
						{
							[tempMultiDeleteList addObject:@(toIndexPath.row)];
						}
						else 
						{
							newPosition = [position intValue] + 1;
							[tempMultiDeleteList addObject:@(newPosition)];
						}
					}
					else
					{
						[tempMultiDeleteList addObject:position];
					}
				}
				else
				{
					if ([position intValue] <= toIndexPath.row && [position intValue] >= fromIndexPath.row)
					{
						if ([position intValue] == fromIndexPath.row)
						{
							[tempMultiDeleteList addObject:@(toIndexPath.row)];
						}
						else 
						{
							newPosition = [position intValue] - 1;
							[tempMultiDeleteList addObject:@(newPosition)];
						}
					}
					else
					{
						[tempMultiDeleteList addObject:position];
					}
				}
			}
			viewObjectsS.multiDeleteList = [NSMutableArray arrayWithArray:tempMultiDeleteList];
		}
		
		// Correct the value of currentPlaylistPosition
		if (fromIndexPath.row == playlistS.currentIndex)
		{
			playlistS.currentIndex = toIndexPath.row;
		}
		else 
		{
			if (fromIndexPath.row < playlistS.currentIndex && toIndexPath.row >= playlistS.currentIndex)
			{
				playlistS.currentIndex = playlistS.currentIndex - 1;
			}
			else if (fromIndexPath.row > playlistS.currentIndex && toIndexPath.row <= playlistS.currentIndex)
			{
				playlistS.currentIndex = playlistS.currentIndex + 1;
			}
		}
		
		// Highlight the current playing song
		if (playlistS.currentIndex >= 0 && playlistS.currentIndex < _currentPlaylistCount)
		{
			[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:playlistS.currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
		}
		
		if (!settingsS.isJukeboxEnabled)
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistOrderChanged];
	}
}


// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (_segmentedControl.selectedSegmentIndex == 0)
		return YES;
	else if (_segmentedControl.selectedSegmentIndex == 1)
		return NO; //this will be changed to YES and will be fully editable
	else if (_segmentedControl.selectedSegmentIndex == 2)
		return NO;
	
	return NO;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (_segmentedControl.selectedSegmentIndex == 0)
	{
		static NSString *cellIdentifier = @"CurrentPlaylistSongCell";
		CustomUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[CustomUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            cell.delegate = self;
            cell.alwaysShowCoverArt = YES;
            cell.alwaysShowSubtitle = YES;
		}
		cell.indexPath = indexPath;
		
        cell.markedForDelete = [viewObjectsS.multiDeleteList containsObject:@(indexPath.row)];
		
		ISMSSong *aSong = [playlistS songForIndex:indexPath.row];
		
        cell.associatedObject = aSong;
		cell.coverArtId = aSong.coverArtId;
		
		if (indexPath.row == playlistS.currentIndex && (audioEngineS.player.isStarted || (settingsS.isJukeboxEnabled && jukeboxS.jukeboxIsPlaying)))
		{
			cell.playing = YES;
			//cell.numberLabel.hidden = YES;
		}
		else 
		{
			cell.playing = NO;
			//cell.numberLabel.hidden = NO;
			//cell.numberLabel.text = [NSString stringWithFormat:@"%li", (long)(indexPath.row + 1)];
		}
		
		cell.title = aSong.title;
        cell.subTitle = aSong.album ? [NSString stringWithFormat:@"%@ - %@", aSong.artist, aSong.album] : aSong.artist;
		
        if (aSong.isFullyCached)
        {
            cell.backgroundView = [[UIView alloc] init];
            cell.backgroundView.backgroundColor = [viewObjectsS currentLightColor];
        }
        else
        {
            cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
        }
		
		return cell;
	}
	else if (_segmentedControl.selectedSegmentIndex == 1)
	{
		static NSString *cellIdentifier = @"LocalPlaylistsCell";
		CustomUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[CustomUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            cell.delegate = self;
		}
		cell.indexPath = indexPath;
        
        NSString *md5 = [databaseS.localPlaylistsDbQueue stringForQuery:@"SELECT md5 FROM localPlaylists WHERE ROWID = ?", @(indexPath.row + 1)];
        cell.associatedObject = md5;
		
        cell.markedForDelete = [viewObjectsS.multiDeleteList containsObject:@(indexPath.row)];
        
        cell.title = [databaseS.localPlaylistsDbQueue stringForQuery:@"SELECT playlist FROM localPlaylists WHERE ROWID = ?", @(indexPath.row + 1)];
        
        NSUInteger count = [databaseS.localPlaylistsDbQueue intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM playlist%@", md5]];

        cell.subTitle = count == 1 ? @"1 song" : [NSString stringWithFormat:@"%li songs", (long)count];

		cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		
		return cell;
	}
	else if (_segmentedControl.selectedSegmentIndex == 2)
	{
		static NSString *cellIdentifier = @"PlaylistsCell";
		CustomUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[CustomUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.delegate = self;
		}
		cell.indexPath = indexPath;
        SUSServerPlaylist *playlist = [_serverPlaylistsDataModel.serverPlaylists objectAtIndexSafe:indexPath.row];
        cell.associatedObject = playlist;
		
        cell.markedForDelete = [viewObjectsS.multiDeleteList containsObject:@(indexPath.row)];
		
        cell.title = playlist.playlistName;
        
        if (!_cellSuccessBlock)
        {
            __weak PlaylistsViewController *weakSelf = self;
            NSData *receivedData = _receivedData;
            _cellSuccessBlock = ^(NSData *data, NSDictionary *userInfo) {
                SUSServerPlaylist *serverPlaylist = userInfo[@"serverPlaylist"];
                BOOL isDownload = [userInfo[@"isDownload"] boolValue];
                
                // Parse the data
                //
                RXMLElement *root = [[RXMLElement alloc] initFromXMLData:receivedData];
                if (![root isValid])
                {
                    //NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
                    // TODO: handle this error
                }
                else
                {
                    RXMLElement *error = [root child:@"error"];
                    if ([error isValid])
                    {
                        //NSString *code = [error attribute:@"code"];
                        //NSString *message = [error attribute:@"message"];
                        // TODO: handle this error
                    }
                    else
                    {
                        // TODO: Handle !isValid case
                        if ([[root child:@"playlist"] isValid])
                        {
                            NSString *md5 = [serverPlaylist.playlistName md5];
                            [databaseS removeServerPlaylistTable:md5];
                            [databaseS createServerPlaylistTable:md5];
                            
                            [root iterate:@"playlist.entry" usingBlock:^(RXMLElement *e) {
                                ISMSSong *aSong = [[ISMSSong alloc] initWithRXMLElement:e];
                                [aSong insertIntoServerPlaylistWithPlaylistId:md5];
                                if (isDownload)
                                {
                                    [aSong addToCacheQueueDbQueue];
                                }
                                else
                                {
                                    [aSong addToCurrentPlaylistDbQueue];
                                }
                            }];
                        }
                    }
                }
                
                // Hide the loading screen
                [viewObjectsS hideLoadingScreen];
                
                if (!isDownload)
                    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
                
                if (weakSelf)
                {
                    __strong PlaylistsViewController *strongSelf = weakSelf;
                    strongSelf->_cellConnection = nil;
                }
            };
        }
		
		return cell;
	}
	
	return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath)
		return;
	
	if (viewObjectsS.isCellEnabled)
	{
		if (_segmentedControl.selectedSegmentIndex == 0)
		{
            ISMSSong *playedSong = [musicS playSongAtPosition:indexPath.row];
            if (!playedSong.isVideo)
                [self showPlayer];
		}
		else if (_segmentedControl.selectedSegmentIndex == 1)
		{
			PlaylistSongsViewController *playlistSongsViewController = [[PlaylistSongsViewController alloc] initWithNibName:@"PlaylistSongsViewController" bundle:nil];
            playlistSongsViewController.localPlaylist = YES;
			playlistSongsViewController.md5 = [databaseS.localPlaylistsDbQueue stringForQuery:@"SELECT md5 FROM localPlaylists WHERE ROWID = ?", @(indexPath.row + 1)];
			[self pushViewControllerCustom:playlistSongsViewController];
		}
		else if (_segmentedControl.selectedSegmentIndex == 2)
		{
			PlaylistSongsViewController *playlistSongsViewController = [[PlaylistSongsViewController alloc] initWithNibName:@"PlaylistSongsViewController" bundle:nil];
            SUSServerPlaylist *playlist = [_serverPlaylistsDataModel.serverPlaylists objectAtIndexSafe:indexPath.row];
			playlistSongsViewController.md5 = [playlist.playlistName md5];
            playlistSongsViewController.serverPlaylist = playlist;
			[self pushViewControllerCustom:playlistSongsViewController];
		}
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

#pragma mark - CustomUITableViewCell Delegate -

- (void)tableCellDownloadButtonPressed:(CustomUITableViewCell *)cell
{
    id associatedObject = cell.associatedObject;
    if ([associatedObject isKindOfClass:[ISMSSong class]])
    {
        [(ISMSSong *)cell.associatedObject addToCacheQueueDbQueue];
    }
    else if ([associatedObject isKindOfClass:[NSString class]])
    {
        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
        [self performSelector:@selector(downloadAllSongsForLocalPlaylistMd5:) withObject:associatedObject afterDelay:0.05];
        
        [cell.overlayView disableDownloadButton];
    }
    else if ([associatedObject isKindOfClass:[SUSServerPlaylist class]])
    {
        [viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
        
        SUSServerPlaylist *serverPlaylist = (SUSServerPlaylist *)cell.associatedObject;
        NSDictionary *parameters = @{ @"id": n2N(serverPlaylist.playlistId) };
        NSDictionary *userInfo = @{ @"serverPlaylist": serverPlaylist, @"isDownload": @YES };
        
        _cellConnection = [[SUSURLConnection alloc] initWithAction:@"getPlaylist"
                                                        parameters:parameters
                                                          userInfo:userInfo
                                                           success:_cellSuccessBlock
                                                           failure:^(NSError *error) {
                                                               // TODO: Prompt the user
                                                               [viewObjectsS hideLoadingScreen];
                                                               _cellConnection = nil;
                                                           }];
        
        [cell.overlayView disableDownloadButton];
    }
}

- (void)downloadAllSongsForLocalPlaylistMd5:(NSString *)md5
{
    int count = [databaseS.localPlaylistsDbQueue intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM playlist%@", md5]];
    for (int i = 0; i < count; i++)
    {
        ISMSSong *song = [ISMSSong songFromDbRow:i inTable:[NSString stringWithFormat:@"playlist%@", md5] inDatabaseQueue:databaseS.localPlaylistsDbQueue];
        [song addToCacheQueueDbQueue];
    }
    
    // Hide the loading screen
    [viewObjectsS hideLoadingScreen];
}

- (void)tableCellQueueButtonPressed:(CustomUITableViewCell *)cell
{
    id associatedObject = cell.associatedObject;
    if ([associatedObject isKindOfClass:[ISMSSong class]])
    {
        [(ISMSSong *)cell.associatedObject addToCurrentPlaylistDbQueue];
    }
    else if ([associatedObject isKindOfClass:[NSString class]])
    {
        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
        [self performSelector:@selector(queueAllSongsForLocalPlaylistMd5:) withObject:associatedObject afterDelay:0.05];
    }
    else if ([associatedObject isKindOfClass:[SUSServerPlaylist class]])
    {
        [viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
        
        SUSServerPlaylist *serverPlaylist = (SUSServerPlaylist *)cell.associatedObject;
        NSDictionary *parameters = @{ @"id": n2N(serverPlaylist.playlistId) };
        NSDictionary *userInfo = @{ @"serverPlaylist": serverPlaylist, @"isDownload": @NO };
        
        _cellConnection = [[SUSURLConnection alloc] initWithAction:@"getPlaylist"
                                                        parameters:parameters
                                                          userInfo:userInfo
                                                           success:_cellSuccessBlock
                                                           failure:^(NSError *error) {
            // TODO: Prompt the user
            [viewObjectsS hideLoadingScreen];
            _cellConnection = nil;
        }];
    }
}

- (void)queueAllSongsForLocalPlaylistMd5:(NSString *)md5
{
    int count = [databaseS.localPlaylistsDbQueue intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM playlist%@", md5]];
    for (int i = 0; i < count; i++)
    {
        @autoreleasepool
        {
            ISMSSong *song = [ISMSSong songFromDbRow:i inTable:[NSString stringWithFormat:@"playlist%@", md5] inDatabaseQueue:databaseS.localPlaylistsDbQueue];
            [song addToCurrentPlaylistDbQueue];
        }
    }
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
    
    [viewObjectsS hideLoadingScreen];
}

- (void)tableCellDeleteToggled:(CustomUITableViewCell *)cell markedForDelete:(BOOL)markedForDelete
{
    NSObject *object = @(cell.indexPath.row);
    if (markedForDelete)
    {
        [viewObjectsS.multiDeleteList addObject:object];
    }
    else
    {
        [viewObjectsS.multiDeleteList removeObject:object];
    }
}

@end

