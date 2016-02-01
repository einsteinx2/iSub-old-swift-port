//
//  CacheViewController.m
//  iSub
//
//  Created by Ben Baron on 6/1/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "iSub-Swift.h"
#import "CacheViewController.h"
#import "CacheAlbumViewController.h"
#import "ServerListViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "UIViewController+PushViewControllerCustom.h"

// TODO: Finish cleanup

@interface CacheViewController() <ItemUITableViewCellDelegate>
{
    UIView *_headerView2;
    UISegmentedControl *_segmentedControl;
    UILabel *_songsCountLabel;
    UIButton *_deleteSongsButton;
    UILabel *_deleteSongsLabel;
    UILabel *_editSongsLabel;
    UIButton *_editSongsButton;
    UIImageView *_playAllImage;
    UILabel *_playAllLabel;
    UIButton *_playAllButton;
    UIImageView *_shuffleImage;
    UILabel *_shuffleLabel;
    UIButton *_shuffleButton;
    UIImageView *_noSongsScreen;
    UIButton *_jukeboxInputBlocker;
    NSMutableArray *_listOfArtists;
    NSMutableArray *_listOfArtistsSections;
    NSArray *_sectionInfo;
    UILabel *_cacheSizeLabel;
    
    BOOL _saveEditShowing;
    BOOL _noSongsScreenShowing;
    BOOL _showIndex;

    NSUInteger _cacheQueueCount;
    
    NSMutableArray *_multiDeleteList;
}
@end

@implementation CacheViewController

#pragma mark - Rotation handling

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	if (!IS_IPAD() && _noSongsScreenShowing)
	{
        [UIView animateWithDuration:duration animations:^{
            CGFloat ty = UIInterfaceOrientationIsPortrait(toInterfaceOrientation) ? -23.0f : 110.0;
            _noSongsScreen.transform = CGAffineTransformTranslate(_noSongsScreen.transform, 0.0, ty);
        }];
	}
}

#pragma mark - View lifecycle

- (void)viewDidLoad 
{
	[super viewDidLoad];
	
	_multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		
    self.title = settingsS.isOfflineMode ? @"Artists" : @"Cache";
}

- (void)viewWillAppear:(BOOL)animated 
{	
	[super viewWillAppear:animated];
		
	[self _registerForNotifications];
	
	[self _reloadTable];
	
    if (!settingsS.isOfflineMode)
    {
        [self _startUpdatingProgress];
    }
	
	[Flurry logEvent:@"CacheTab"];
	
	// Reload the data in case it changed
	if (settingsS.isCacheUnlocked)
	{
		self.tableView.tableHeaderView.hidden = NO;
		[self a_segment:nil];
	}
	else
	{
		self.tableView.tableHeaderView.hidden = YES;
		[self _addNoSongsScreen];
	}
	
	self.tableView.scrollEnabled = YES;
	[_jukeboxInputBlocker removeFromSuperview];
	_jukeboxInputBlocker = nil;
	if (settingsS.isJukeboxEnabled)
	{
		self.tableView.scrollEnabled = NO;
		
		_jukeboxInputBlocker = [UIButton buttonWithType:UIButtonTypeCustom];
		_jukeboxInputBlocker.frame = CGRectMake(0, 0, 1004, 1004);
		[self.view addSubview:_jukeboxInputBlocker];
		
		UIView *colorView = [[UIView alloc] initWithFrame:_jukeboxInputBlocker.frame];
		colorView.backgroundColor = [UIColor blackColor];
		colorView.alpha = 0.5;
		[_jukeboxInputBlocker addSubview:colorView];
	}    
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	// Must do this here as well or the no songs overlay will be off sometimes
	if (settingsS.isCacheUnlocked)
	{
		self.tableView.tableHeaderView.hidden = NO;
		
		[self a_segment:nil];
	}
	else
	{
		self.tableView.tableHeaderView.hidden = YES;
		[self _addNoSongsScreen];
	}
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
		
	[self _unregisterForNotifications];
    
    [self _unregisterForDeleteButtonNotifications];
    
    [self _stopUpdatingProgress];
}

- (void)didReceiveMemoryWarning 
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{
    [self _unregisterForNotifications];
    [self _unregisterForDeleteButtonNotifications];
    [self _stopUpdatingProgress];
}

#pragma mark - CustomUITableViewController Overrides -

- (UIView *)setupHeaderView
{
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    headerView.backgroundColor = [UIColor colorWithWhite:.3 alpha:1];
    _segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Cached", @"Downloading"]];
    [_segmentedControl addTarget:self action:@selector(a_segment:) forControlEvents:UIControlEventValueChanged];
    
    _segmentedControl.frame = CGRectMake(5, 5, 310, 36);
    _segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _segmentedControl.tintColor = ISMSHeaderColor;
    _segmentedControl.selectedSegmentIndex = 0;
    if (settingsS.isOfflineMode)
    {
        _segmentedControl.hidden = YES;
    }
    [headerView addSubview:_segmentedControl];
    
    if (settingsS.isOfflineMode)
    {
        headerView.frame = CGRectMake(0, 0, 320, 50);
        headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        _headerView2 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
        _headerView2.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _headerView2.backgroundColor = viewObjectsS.darkNormal;
        [headerView addSubview:_headerView2];
        
        _playAllLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 160, 50)];
        _playAllLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
        _playAllLabel.backgroundColor = [UIColor clearColor];
        _playAllLabel.textColor = ISMSHeaderButtonColor;
        _playAllLabel.textAlignment = NSTextAlignmentCenter;
        _playAllLabel.font = ISMSRegularFont(24);
        _playAllLabel.text = @"Play All";
        [_headerView2 addSubview:_playAllLabel];
        
        _playAllButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _playAllButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
        _playAllButton.frame = CGRectMake(0, 0, 160, 40);
        [_playAllButton addTarget:self action:@selector(a_playAll:) forControlEvents:UIControlEventTouchUpInside];
        [_headerView2 addSubview:_playAllButton];
        
        _shuffleLabel = [[UILabel alloc] initWithFrame:CGRectMake(160, 0, 160, 50)];
        _shuffleLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth;
        _shuffleLabel.backgroundColor = [UIColor clearColor];
        _shuffleLabel.textColor = ISMSHeaderButtonColor;
        _shuffleLabel.textAlignment = NSTextAlignmentCenter;
        _shuffleLabel.font = ISMSRegularFont(24);
        _shuffleLabel.text = @"Shuffle";
        [_headerView2 addSubview:_shuffleLabel];
        
        _shuffleButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _shuffleButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth;
        _shuffleButton.frame = CGRectMake(160, 0, 160, 40);
        [_shuffleButton addTarget:self action:@selector(a_shuffle:) forControlEvents:UIControlEventTouchUpInside];
        [_headerView2 addSubview:_shuffleButton];
    }
    
    return headerView;
}

- (void)customizeTableView:(UITableView *)tableView
{
    tableView.separatorColor = [UIColor clearColor];
}

#pragma mark - Notifications -

- (void)_registerForNotifications
{
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    
    [defaultCenter addObserver:self selector:@selector(_songDownloaded:)
                          name:ISMSNotification_StreamHandlerSongDownloaded object:nil];
    [defaultCenter addObserver:self selector:@selector(_songDownloaded:)
                          name:ISMSNotification_CacheQueueSongDownloaded object:nil];
    
    [defaultCenter addObserver:self selector:@selector(_songDeleted:)
                          name:ISMSNotification_CachedSongDeleted object:nil];
    
    [defaultCenter addObserver:self selector:@selector(_reachabilityChanged:)
                          name:EX2ReachabilityNotification_ReachabilityChanged object: nil];
    
    [defaultCenter addObserver:self selector:@selector(viewWillAppear:)
                          name:ISMSNotification_StorePurchaseComplete object:nil];
}

- (void)_unregisterForNotifications
{
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    
    [defaultCenter removeObserver:self name:ISMSNotification_StreamHandlerSongDownloaded object:nil];
    [defaultCenter removeObserver:self name:ISMSNotification_CacheQueueSongDownloaded object:nil];
    [defaultCenter removeObserver:self name:ISMSNotification_CachedSongDeleted object:nil];
    [defaultCenter removeObserver:self name:EX2ReachabilityNotification_ReachabilityChanged object:nil];
    [defaultCenter removeObserver:self name:ISMSNotification_StorePurchaseComplete object:nil];
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

- (void)_songDownloaded:(NSNotification *)notification
{
    [self _reloadTable];
}

- (void)_songDeleted:(NSNotification *)notification
{
    [self _reloadTable];
}

- (void)_reachabilityChanged:(NSNotification *)notification
{
    [self a_segment:nil];
}

- (void)_showDeleteButton:(NSNotification *)notification
{
    [self _showDeleteButton];
}

- (void)_hideDeleteButton:(NSNotification *)notification
{
    [self _hideDeleteButton];
}

- (void)_storePurchaseComplete:(NSNotification *)notification
{
    // TODO: Don't call this method, have the logic in another method
    [self viewWillAppear:NO];
}

#pragma mark - Actions -

- (void)a_segment:(id)sender
{
    if (_segmentedControl.selectedSegmentIndex == 0)
    {
        if (self.tableView.editing)
        {
            [self a_editSongs:nil];
        }
        
        [self _reloadTable];
        
        if (_listOfArtists.count == 0)
        {
            [self _removeSaveEditButtons];
            
            [self _addNoSongsScreen];
            [self _addNoSongsScreen];
        }
        else
        {
            [self _removeNoSongsScreen];
            
            if (settingsS.isOfflineMode == NO)
            {
                [self _addSaveEditButtons];
            }
        }
    }
    else if (_segmentedControl.selectedSegmentIndex == 1)
    {
        if (self.tableView.editing)
        {
            [self a_editSongs:nil];
        }
        
        [self _reloadTable];
        
        if (_cacheQueueCount > 0)
        {
            [self _removeNoSongsScreen];
            [self _addSaveEditButtons];
        }
    }
    
    [self.tableView reloadData];
}

- (void)a_showStore:(id)sender
{
//	StoreViewController *store = [[StoreViewController alloc] init];
//	[self pushViewControllerCustom:store];
}

- (void)a_playAll:(id)sender
{	
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	[self performSelector:@selector(_loadPlayAllPlaylist:) withObject:@NO afterDelay:0.05];
}

- (void)a_shuffle:(id)sender
{
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	[self performSelector:@selector(_loadPlayAllPlaylist:) withObject:@YES afterDelay:0.05];
}

- (void)a_editSongs:(id)sender
{
	if (_segmentedControl.selectedSegmentIndex == 0)
	{
		if (!self.tableView.editing)
		{
            [self _registerForDeleteButtonNotifications];

			_multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			[self.tableView setEditing:YES animated:YES];
			_editSongsLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
			_editSongsLabel.text = @"Done";
			[self _showDeleteButton];
			
            [self showDeleteToggles];
		}
		else 
		{
            [self _unregisterForDeleteButtonNotifications];
            
			_multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			[self.tableView setEditing:NO animated:YES];
			[self _hideDeleteButton];
			_editSongsLabel.backgroundColor = [UIColor clearColor];
			_editSongsLabel.text = @"Edit";
			
			// Reload the table
			[self.tableView reloadData];
            
            [self hideDeleteToggles];
		}
	}
	else if (_segmentedControl.selectedSegmentIndex == 1)
	{
		if (!self.tableView.editing)
		{
            [self _registerForDeleteButtonNotifications];

			_multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			[self.tableView setEditing:YES animated:YES];
			_editSongsLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
			_editSongsLabel.text = @"Done";
			[self _showDeleteButton];
			
			[self showDeleteToggles];
		}
		else 
		{
            [self _unregisterForDeleteButtonNotifications];
            
			_multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			[self.tableView setEditing:NO animated:YES];
			[self _hideDeleteButton];
			_editSongsLabel.backgroundColor = [UIColor clearColor];
			_editSongsLabel.text = @"Edit";
			
			// Reload the table
			[self _reloadTable];
		}
	}
}

- (void)a_deleteSongs:(id)sender
{
	if (self.tableView.editing)
	{
		if ([_deleteSongsLabel.text isEqualToString:@"Select All"])
		{
			if (_segmentedControl.selectedSegmentIndex == 0)
			{
				// Select all the rows
				for (NSArray *section in _listOfArtistsSections)
				{
					for (NSString *folderName in section)
					{
						[_multiDeleteList addObject:folderName];
					}
				}
			}
			else
			{
				// Select all the rows
				[databaseS.cacheQueueDbQueue inDatabase:^(FMDatabase *db)
				{
					FMResultSet *result = [db executeQuery:@"SELECT md5 FROM cacheQueueList"];
					while ([result next])
					{
						@autoreleasepool 
						{
							NSString *md5 = [result stringForColumnIndex:0];
							if (md5) [_multiDeleteList addObject:md5];
						}
					}
				}];
			}
			
			[self.tableView reloadData];
			[self _showDeleteButton];
		}
		else
		{
			[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Deleting"];
			if (_segmentedControl.selectedSegmentIndex == 0)
				[self performSelector:@selector(_deleteCachedSongs) withObject:nil afterDelay:0.05];
			else
				[self performSelector:@selector(_deleteQueuedSongs) withObject:nil afterDelay:0.05];
		}
	}
}

#pragma mark - Private -

#pragma mark UI

- (void)_startUpdatingProgress
{
    [self _stopUpdatingProgress];
    
    [self _updateCacheSizeLabel];
    [self _updateQueueDownloadProgress];
    
    [self performSelector:@selector(_startUpdatingProgress) withObject:nil afterDelay:1.5];
}

- (void)_stopUpdatingProgress
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_startUpdatingProgress) object:nil];
}

- (void)_updateCacheSizeLabel
{
    if (_segmentedControl.selectedSegmentIndex == 0)
    {
        if (cacheS.cacheSize <= 0)
            _cacheSizeLabel.text = @"";
        else
            _cacheSizeLabel.text = [NSString formatFileSize:cacheS.cacheSize];
    }
}

- (void)_updateQueueDownloadProgress
{
    if (_segmentedControl.selectedSegmentIndex == 1 && cacheQueueManagerS.isQueueDownloading)
    {
        [self _reloadTable];
    }
}

- (void)_removeSaveEditButtons
{
    if (_saveEditShowing == YES)
    {
        _saveEditShowing = NO;
        [_songsCountLabel removeFromSuperview];
        _songsCountLabel = nil;
        [_deleteSongsButton removeFromSuperview];
        _deleteSongsButton = nil;
        [_editSongsLabel removeFromSuperview];
        _editSongsLabel = nil;
        [_editSongsButton removeFromSuperview];
        _editSongsButton = nil;
        [_deleteSongsLabel removeFromSuperview];
        _deleteSongsLabel = nil;
        [_cacheSizeLabel removeFromSuperview];
        _cacheSizeLabel = nil;
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_updateCacheSizeLabel) object:nil];
        [_headerView2 removeFromSuperview];
        _headerView2 = nil;
        
        UIView *headerView = self.tableView.tableHeaderView;
        headerView.frame = CGRectMake(0, 0, 320, 44);
        self.tableView.tableHeaderView = headerView;
    }
}

- (void)_addSaveEditButtons
{
    [self _removeSaveEditButtons];
    
    if (_saveEditShowing == NO)
    {
        // Modify the header view to include the save and edit buttons
        _saveEditShowing = YES;
        int y = 43;
        
        UIView *headerView = self.tableView.tableHeaderView;
        
        headerView.frame = CGRectMake(0, 0, 320, y + 100);
        if (_segmentedControl.selectedSegmentIndex == 1)
            headerView.frame = CGRectMake(0, 0, 320, y + 50);
        
        _songsCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, y, 160, 34)];
        _songsCountLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
        _songsCountLabel.backgroundColor = [UIColor clearColor];
        _songsCountLabel.textColor = [UIColor whiteColor];
        _songsCountLabel.textAlignment = NSTextAlignmentCenter;
        _songsCountLabel.font = ISMSBoldFont(22);
        if (_segmentedControl.selectedSegmentIndex == 0)
        {
            NSUInteger cachedSongsCount = [databaseS.songCacheDbQueue intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE finished = 'YES' AND md5 != ''"];
            if ([databaseS.songCacheDbQueue intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE finished = 'YES' AND md5 != ''"] == 1)
                _songsCountLabel.text = [NSString stringWithFormat:@"1 Song"];
            else
                _songsCountLabel.text = [NSString stringWithFormat:@"%lu Songs", (unsigned long)cachedSongsCount];
        }
        else if (_segmentedControl.selectedSegmentIndex == 1)
        {
            if (_cacheQueueCount == 1)
                _songsCountLabel.text = [NSString stringWithFormat:@"1 Song"];
            else
                _songsCountLabel.text = [NSString stringWithFormat:@"%lu Songs", (unsigned long)_cacheQueueCount];
        }
        [headerView addSubview:_songsCountLabel];
        
        _cacheSizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, y + 33, 160, 14)];
        _cacheSizeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
        _cacheSizeLabel.backgroundColor = [UIColor clearColor];
        _cacheSizeLabel.textColor = [UIColor whiteColor];
        _cacheSizeLabel.textAlignment = NSTextAlignmentCenter;
        _cacheSizeLabel.font = ISMSBoldFont(12);
        if (_segmentedControl.selectedSegmentIndex == 0)
        {
            if (cacheS.cacheSize <= 0)
                _cacheSizeLabel.text = @"";
            else
                _cacheSizeLabel.text = [NSString formatFileSize:cacheS.cacheSize];
        }
        else if (_segmentedControl.selectedSegmentIndex == 1)
        {
            /*unsigned long long combinedSize = 0;
             FMResultSet *result = [databaseS.cacheQueueDb executeQuery:@"SELECT size FROM cacheQueue"];
             while ([result next])
             {
             combinedSize += [result longLongIntForColumnIndex:0];
             }
             [result close];
             cacheSizeLabel.text = [NSString formatFileSize:combinedSize];*/
            
            _cacheSizeLabel.text = @"";
        }
        [headerView addSubview:_cacheSizeLabel];
        [self _updateCacheSizeLabel];
        
        _deleteSongsButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _deleteSongsButton.frame = CGRectMake(0, y, 160, 50);
        _deleteSongsButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
        [_deleteSongsButton addTarget:self action:@selector(a_deleteSongs:) forControlEvents:UIControlEventTouchUpInside];
        [headerView addSubview:_deleteSongsButton];
        
        _editSongsLabel = [[UILabel alloc] initWithFrame:CGRectMake(160, y, 160, 50)];
        _editSongsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
        _editSongsLabel.backgroundColor = [UIColor clearColor];
        _editSongsLabel.textColor = [UIColor whiteColor];
        _editSongsLabel.textAlignment = NSTextAlignmentCenter;
        _editSongsLabel.font = ISMSBoldFont(22);
        _editSongsLabel.text = @"Edit";
        [headerView addSubview:_editSongsLabel];
        
        _editSongsButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _editSongsButton.frame = CGRectMake(160, y, 160, 40);
        _editSongsButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
        [_editSongsButton addTarget:self action:@selector(a_editSongs:) forControlEvents:UIControlEventTouchUpInside];
        [headerView addSubview:_editSongsButton];
        
        _deleteSongsLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, y, 160, 50)];
        _deleteSongsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
        _deleteSongsLabel.backgroundColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:.5];
        _deleteSongsLabel.textColor = [UIColor whiteColor];
        _deleteSongsLabel.textAlignment = NSTextAlignmentCenter;
        _deleteSongsLabel.font = ISMSBoldFont(22);
        _deleteSongsLabel.adjustsFontSizeToFitWidth = YES;
        _deleteSongsLabel.minimumScaleFactor = 12.0 / _deleteSongsLabel.font.pointSize;
        _deleteSongsLabel.text = @"Delete # Songs";
        _deleteSongsLabel.hidden = YES;
        [headerView addSubview:_deleteSongsLabel];
        
        _headerView2 = nil;
        if (_segmentedControl.selectedSegmentIndex == 0)
        {
            _headerView2 = [[UIView alloc] initWithFrame:CGRectMake(0, y + 52, 320, 50)];
            _headerView2.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            _headerView2.backgroundColor = viewObjectsS.darkNormal;
            [headerView addSubview:_headerView2];
            
            _playAllLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 160, 50)];
            _playAllLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
            _playAllLabel.backgroundColor = [UIColor clearColor];
            _playAllLabel.textColor = ISMSHeaderButtonColor;
            _playAllLabel.textAlignment = NSTextAlignmentCenter;
            _playAllLabel.font = ISMSRegularFont(24);
            _playAllLabel.text = @"Play All";
            [_headerView2 addSubview:_playAllLabel];
            
            _playAllButton = [UIButton buttonWithType:UIButtonTypeCustom];
            _playAllButton.frame = CGRectMake(0, 0, 160, 40);
            _playAllButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
            [_playAllButton addTarget:self action:@selector(a_playAll:) forControlEvents:UIControlEventTouchUpInside];
            [_headerView2 addSubview:_playAllButton];
            
            _shuffleLabel = [[UILabel alloc] initWithFrame:CGRectMake(160, 0, 160, 50)];
            _shuffleLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth;
            _shuffleLabel.backgroundColor = [UIColor clearColor];
            _shuffleLabel.textColor = ISMSHeaderButtonColor;
            _shuffleLabel.textAlignment = NSTextAlignmentCenter;
            _shuffleLabel.font = ISMSRegularFont(24);
            _shuffleLabel.text = @"Shuffle";
            [_headerView2 addSubview:_shuffleLabel];
            
            _shuffleButton = [UIButton buttonWithType:UIButtonTypeCustom];
            _shuffleButton.frame = CGRectMake(160, 0, 160, 40);
            _shuffleButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth;
            [_shuffleButton addTarget:self action:@selector(a_shuffle:) forControlEvents:UIControlEventTouchUpInside];
            [_headerView2 addSubview:_shuffleButton];
        }
        
        self.tableView.tableHeaderView = headerView;
    }
}

- (void)_removeNoSongsScreen
{
    if (_noSongsScreenShowing == YES)
    {
        [_noSongsScreen removeFromSuperview];
        _noSongsScreenShowing = NO;
    }
}

- (void)_addNoSongsScreen
{
    [self _removeNoSongsScreen];
    
    if (_noSongsScreenShowing == NO)
    {
        _noSongsScreenShowing = YES;
        _noSongsScreen = [[UIImageView alloc] init];
        _noSongsScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
        _noSongsScreen.frame = CGRectMake(40, 100, 240, 180);
        _noSongsScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
        _noSongsScreen.image = [UIImage imageNamed:@"loading-screen-image"];
        _noSongsScreen.alpha = .80;
        _noSongsScreen.userInteractionEnabled = YES;
        
        UILabel *textLabel = [[UILabel alloc] init];
        textLabel.backgroundColor = [UIColor clearColor];
        textLabel.textColor = [UIColor whiteColor];
        textLabel.font = ISMSBoldFont(30);
        textLabel.textAlignment = NSTextAlignmentCenter;
        textLabel.numberOfLines = 0;
        if (settingsS.isCacheUnlocked)
        {
            if (_segmentedControl.selectedSegmentIndex == 0)
                [textLabel setText:@"No Cached\nSongs"];
            else if (_segmentedControl.selectedSegmentIndex == 1)
                [textLabel setText:@"No Queued\nSongs"];
            
            textLabel.frame = CGRectMake(20, 20, 200, 140);
        }
        else
        {
            textLabel.text = @"Caching\nLocked";
            textLabel.frame = CGRectMake(20, 0, 200, 100);
        }
        [_noSongsScreen addSubview:textLabel];
        
        if (settingsS.isCacheUnlocked == NO)
        {
            UILabel *textLabel2 = [[UILabel alloc] init];
            textLabel2.backgroundColor = [UIColor clearColor];
            textLabel2.textColor = [UIColor whiteColor];
            textLabel2.font = ISMSBoldFont(14);
            textLabel2.textAlignment = NSTextAlignmentCenter;
            textLabel2.numberOfLines = 0;
            textLabel2.text = @"Tap to purchase the ability to cache songs for better streaming performance and offline playback";
            textLabel2.frame = CGRectMake(20, 90, 200, 70);
            [_noSongsScreen addSubview:textLabel2];
            
            UIButton *storeLauncher = [UIButton buttonWithType:UIButtonTypeCustom];
            storeLauncher.frame = CGRectMake(0, 0, _noSongsScreen.frame.size.width, _noSongsScreen.frame.size.height);
            [storeLauncher addTarget:self action:@selector(a_showStore:) forControlEvents:UIControlEventTouchUpInside];
            [_noSongsScreen addSubview:storeLauncher];
        }
        
        [self.view addSubview:_noSongsScreen];
        
        
        if (!IS_IPAD())
        {
            if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
            {
                _noSongsScreen.transform = CGAffineTransformTranslate(_noSongsScreen.transform, 0.0, 23.0);
            }
        }
    }
}

- (void)_showDeleteButton
{
    if ([_multiDeleteList count] == 0)
    {
        _deleteSongsLabel.text = @"Select All";
    }
    else if ([_multiDeleteList count] == 1)
    {
        if (_segmentedControl.selectedSegmentIndex == 0)
            _deleteSongsLabel.text = @"Delete 1 Folder  ";
        else
            _deleteSongsLabel.text = @"Delete 1 Song  ";
    }
    else
    {
        if (_segmentedControl.selectedSegmentIndex == 0)
            _deleteSongsLabel.text = [NSString stringWithFormat:@"Delete %lu Folders", (unsigned long)[_multiDeleteList count]];
        else
            _deleteSongsLabel.text = [NSString stringWithFormat:@"Delete %lu Songs", (unsigned long)[_multiDeleteList count]];
    }
    
    _songsCountLabel.hidden = YES;
    _cacheSizeLabel.hidden = YES;
    _deleteSongsLabel.hidden = NO;
}

- (void)_hideDeleteButton
{
    if (!self.tableView.editing)
    {
        _songsCountLabel.hidden = NO;
        _cacheSizeLabel.hidden = NO;
        _deleteSongsLabel.hidden = YES;
        return;
    }
    
    if ([_multiDeleteList count] == 0)
    {
        _deleteSongsLabel.text = @"Select All";
    }
    else if ([_multiDeleteList count] == 1)
    {
        
        if (_segmentedControl.selectedSegmentIndex == 0)
            _deleteSongsLabel.text = @"Delete 1 Folder  ";
        else
            _deleteSongsLabel.text = @"Delete 1 Song  ";
    }
    else
    {
        if (_segmentedControl.selectedSegmentIndex == 0)
            _deleteSongsLabel.text = [NSString stringWithFormat:@"Delete %lu Folders", (unsigned long)[_multiDeleteList count]];
        else
            _deleteSongsLabel.text = [NSString stringWithFormat:@"Delete %lu Songs", (unsigned long)[_multiDeleteList count]];
    }
}

#pragma mark Other

- (void)_loadPlayAllPlaylist:(NSNumber *)shouldShuffle
{
    playlistS.isShuffle = NO;
    
    BOOL isShuffle = [shouldShuffle boolValue];
    
    if (settingsS.isJukeboxEnabled)
    {
        [databaseS resetJukeboxPlaylist];
        [jukeboxS jukeboxClearRemotePlaylist];
    }
    else
    {
        [databaseS resetCurrentPlaylistDb];
    }
    
    NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
    [databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db)
     {
         FMResultSet *result = [db executeQuery:@"SELECT md5 FROM cachedSongsLayout ORDER BY seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8, seg9 COLLATE NOCASE"];
         while ([result next])
         {
             @autoreleasepool
             {
                 NSString *md5 = [result stringForColumnIndex:0];
                 if (md5) [songMd5s addObject:md5];
             }
         }
         [result close];
     }];
    
    for (NSString *md5 in songMd5s)
    {
        @autoreleasepool
        {
            ISMSSong *aSong = [ISMSSong songFromCacheDbQueue:md5];
            [aSong addToCurrentPlaylistDbQueue];
        }
    }
    
    if (isShuffle)
    {
        playlistS.isShuffle = YES;
        [databaseS shufflePlaylist];
    }
    else
    {
        playlistS.isShuffle = NO;
    }
    
    if (settingsS.isJukeboxEnabled)
        [jukeboxS jukeboxPlaySongAtPosition:@0];
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
    
    [viewObjectsS hideLoadingScreen];
    [musicS playSongAtPosition:0];
    [self showPlayer];
}

- (void)_reloadTable
{
    if (_segmentedControl.selectedSegmentIndex == 0)
    {
        // Create the artist list
        _listOfArtists = [NSMutableArray arrayWithCapacity:1];
        _listOfArtistsSections = [NSMutableArray arrayWithCapacity:28];
        
        // Fix for slow load problem (EDIT: Looks like it didn't actually work :(
        [databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db)
         {
             [db executeUpdate:@"DROP TABLE IF EXISTS cachedSongsArtistList"];
             [db executeUpdate:@"CREATE TEMP TABLE cachedSongsArtistList (artist TEXT UNIQUE)"];
             [db executeUpdate:@"INSERT OR IGNORE INTO cachedSongsArtistList SELECT seg1 FROM cachedSongsLayout"];
             
             FMResultSet *result = [db executeQuery:@"SELECT artist FROM cachedSongsArtistList ORDER BY artist COLLATE NOCASE"];
             while ([result next])
             {
                 @autoreleasepool
                 {
                     // Cover up for blank insert problem
                     NSString *artist = [result stringForColumnIndex:0];
                     if (artist.length > 0)
                         [_listOfArtists addObject:[artist copy]];
                 }
             }
             [result close];
             
             [_listOfArtists sortUsingSelector:@selector(caseInsensitiveCompareWithoutIndefiniteArticles:)];
             
             // Create the section index
             [db executeUpdate:@"DROP TABLE IF EXISTS cachedSongsArtistIndex"];
             [db executeUpdate:@"CREATE TEMP TABLE cachedSongsArtistIndex (artist TEXT)"];
             for (NSString *artist in _listOfArtists)
             {
                 [db executeUpdate:@"INSERT INTO cachedSongsArtistIndex (artist) VALUES (?)", [artist stringWithoutIndefiniteArticle], nil];
             }
         }];
        
        _sectionInfo = [databaseS sectionInfoFromTable:@"cachedSongsArtistIndex" inDatabaseQueue:databaseS.songCacheDbQueue withColumn:@"artist"];
        _showIndex = YES;
        if ([_sectionInfo count] < 5)
            _showIndex = NO;
        
        // Sort into sections
        if ([_sectionInfo count] > 0)
        {
            int lastIndex = 0;
            for (int i = 0; i < [_sectionInfo count] - 1; i++)
            {
                @autoreleasepool {
                    int index = [[[_sectionInfo objectAtIndexSafe:i+1] objectAtIndexSafe:1] intValue];
                    NSMutableArray *section = [NSMutableArray arrayWithCapacity:0];
                    for (int i = lastIndex; i < index; i++)
                    {
                        [section addObject:[_listOfArtists objectAtIndexSafe:i]];
                    }
                    [_listOfArtistsSections addObject:section];
                    lastIndex = index;
                }
            }
            NSMutableArray *section = [NSMutableArray arrayWithCapacity:0];
            for (int i = lastIndex; i < [_listOfArtists count]; i++)
            {
                [section addObject:[_listOfArtists objectAtIndexSafe:i]];
            }
            [_listOfArtistsSections addObject:section];
        }
        
        NSUInteger cachedSongsCount = [databaseS.songCacheDbQueue intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE finished = 'YES' AND md5 != ''"];
        if (cachedSongsCount == 0)
        {
            [self _removeSaveEditButtons];
            [self _addNoSongsScreen];
            [self _addNoSongsScreen];
        }
        else
        {
            if (_saveEditShowing)
            {
                if (cachedSongsCount == 1)
                    _songsCountLabel.text = [NSString stringWithFormat:@"1 Song"];
                else
                    _songsCountLabel.text = [NSString stringWithFormat:@"%lu Songs", (unsigned long)cachedSongsCount];
            }
            else if (settingsS.isOfflineMode == NO)
            {
                [self _addSaveEditButtons];
            }
            
            [self _removeNoSongsScreen];
        }
    }
    else
    {
        [databaseS.cacheQueueDbQueue inDatabase:^(FMDatabase *db)
         {
             [db executeUpdate:@"DROP TABLE IF EXISTS cacheQueueList"];
             [db executeUpdate:@"CREATE TEMP TABLE cacheQueueList (md5 TEXT)"];
             [db executeUpdate:@"INSERT INTO cacheQueueList SELECT md5 FROM cacheQueue"];
             
             if (self.tableView.editing)
             {
                 NSArray *multiDeleteList = [NSArray arrayWithArray:_multiDeleteList];
                 for (NSString *md5 in multiDeleteList)
                 {
                     NSString *dbMd5 = [db stringForQuery:@"SELECT md5 FROM cacheQueueList WHERE md5 = ?", md5];
                     if (!dbMd5)
                         [_multiDeleteList removeObject:md5];
                 }
             }
         }];
        
        _cacheQueueCount = [databaseS.cacheQueueDbQueue intForQuery:@"SELECT COUNT(*) FROM cacheQueueList"];
        if (_cacheQueueCount == 0)
        {
            [self _removeSaveEditButtons];	
            [self _addNoSongsScreen];
            [self _addNoSongsScreen];
        }
        else
        {
            if (_saveEditShowing)
            {
                if (_cacheQueueCount == 1)
                    _songsCountLabel.text = [NSString stringWithFormat:@"1 Song"];
                else 
                    _songsCountLabel.text = [NSString stringWithFormat:@"%lu Songs", (unsigned long)_cacheQueueCount];
            }
            else
            {
                [self _addSaveEditButtons];
            }
            
            if (_noSongsScreenShowing)
                [self _removeNoSongsScreen];
        }
    }
    
    [self.tableView reloadData];
}

- (void)_deleteCachedSongs
{
    [self _unregisterForNotifications];
    
    NSMutableArray *songMd5s = [[NSMutableArray alloc] initWithCapacity:0];
    for (NSString *folderName in _multiDeleteList)
    {
        [databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db)
         {
             FMResultSet *result = [db executeQuery:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? ", folderName];
             
             while ([result next])
             {
                 @autoreleasepool
                 {
                     NSString *md5 = [result stringForColumnIndex:0];
                     if (md5) [songMd5s addObject:md5];
                 }
             }
             [result close];
         }];
    }
    
    for (NSString *md5 in songMd5s)
    {
        @autoreleasepool
        {
            [ISMSSong removeSongFromCacheDbQueueByMD5:md5];
            NSLog(@"removing song: %@", md5);
        }
    }
    
    [self a_segment:nil];
    
    [cacheS findCacheSize];
    
    [viewObjectsS hideLoadingScreen];
    
    if (!cacheQueueManagerS.isQueueDownloading)
        [cacheQueueManagerS startDownloadQueue];
    
    [self _registerForNotifications];
}

- (void)_deleteQueuedSongs
{
    [self _unregisterForNotifications];
    
    // Sort the multiDeleteList to make sure it's accending
    [_multiDeleteList sortUsingSelector:@selector(compare:)];
    
    // Delete each song from the database
    for (NSString *md5 in _multiDeleteList)
    {
        if (cacheQueueManagerS.isQueueDownloading)
        {
            // Check if we're deleting the song that's currently caching. If so, stop the download.
            if (cacheQueueManagerS.currentQueuedSong)
            {
                if ([[cacheQueueManagerS.currentQueuedSong.path md5] isEqualToString:md5])
                {
                    [cacheQueueManagerS stopDownloadQueue];
                }
            }
        }
        
        // Delete the row from the cacheQueue
        [databaseS.cacheQueueDbQueue inDatabase:^(FMDatabase *db)
         {
             [db executeUpdate:@"DELETE FROM cacheQueue WHERE md5 = ?", md5];
         }];
    }
    
    // Reload the table
    [self a_editSongs:nil];
    
    if (!cacheQueueManagerS.isQueueDownloading)
        [cacheQueueManagerS startDownloadQueue];
    
    [viewObjectsS hideLoadingScreen];
    
    [self _registerForNotifications];
}

#pragma mark - Table View Delegate -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	if (_segmentedControl.selectedSegmentIndex == 0 && settingsS.isCacheUnlocked)
	{
		return [_sectionInfo count];
	}
	
	return 1;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
	if (_segmentedControl.selectedSegmentIndex == 0 && settingsS.isCacheUnlocked && _showIndex)
	{
		NSMutableArray *indexes = [[NSMutableArray alloc] init];
		for (int i = 0; i < [_sectionInfo count]; i++)
		{
			[indexes addObject:[[_sectionInfo objectAtIndexSafe:i] objectAtIndexSafe:0]];
		}
		return indexes;
	}
		
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	
	if (_segmentedControl.selectedSegmentIndex == 0 && settingsS.isCacheUnlocked)
	{
		return [[_sectionInfo objectAtIndexSafe:section] objectAtIndexSafe:0];
	}
	
	return @"";
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index 
{
	if (_segmentedControl.selectedSegmentIndex == 0)
	{
		if (index == 0) 
		{
			[tableView scrollRectToVisible:CGRectMake(0, 90, 320, 40) animated:NO];
			return -1;
		}
		
		return index;
	}
	
	return -1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return ISMSNormalize(_segmentedControl.selectedSegmentIndex == 0 ? ISMSSongCellHeight : (ISMSAlbumCellHeight + ISMSCellHeaderHeight));
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	if (settingsS.isCacheUnlocked)
	{
		if (_segmentedControl.selectedSegmentIndex == 0)
		{
			return [[_listOfArtistsSections objectAtIndexSafe:section] count];
		}
		else if (_segmentedControl.selectedSegmentIndex == 1)
		{
			return _cacheQueueCount;
		}
	}
	
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{    
	if (_segmentedControl.selectedSegmentIndex == 0)
	{
		static NSString *cellIdentifier = @"CacheArtistCell";
		ItemUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[ItemUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                     reuseIdentifier:cellIdentifier];
            cell.delegate = self;
            cell.showDeleteButton = YES;
		}
        cell.indexPath = indexPath;
        
		NSString *name = [[_listOfArtistsSections objectAtIndexSafe:indexPath.section] objectAtIndexSafe:indexPath.row];
		
        cell.markedForDelete = [_multiDeleteList containsObject:name];
        
		if (_showIndex)
			cell.indexShowing = YES;
		
        cell.title = name;
		
		cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
		
		return cell;
	}
	else
	{
		static NSString *cellIdentifier = @"CacheQueueCell";
		ItemUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[ItemUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                     reuseIdentifier:cellIdentifier];
            cell.delegate = self;
            cell.showDeleteButton = YES;
		}
		cell.indexPath = indexPath;

		__block ISMSSong *aSong;
		__block NSDate *cached;
		
		[databaseS.cacheQueueDbQueue inDatabase:^(FMDatabase *db)
		{
			FMResultSet *result = [db executeQuery:@"SELECT * FROM cacheQueue JOIN cacheQueueList USING(md5) WHERE cacheQueueList.ROWID = ?", @(indexPath.row + 1)];
			aSong = [ISMSSong songFromDbResult:result];
			cached = [NSDate dateWithTimeIntervalSince1970:[result doubleForColumn:@"cachedDate"]];
			//cell.md5 = [result stringForColumn:@"md5"];
			[result close];
		}];
		
        cell.associatedObject = aSong;
        
        cell.markedForDelete = [_multiDeleteList containsObject:aSong.path.md5];

		cell.coverArtId = aSong.coverArtId;
		
        NSString *headerTitle = nil;
		if (indexPath.row == 0)
		{
			if ([aSong isEqualToSong:cacheQueueManagerS.currentQueuedSong] && cacheQueueManagerS.isQueueDownloading)
			{
				headerTitle = [NSString stringWithFormat:@"Added %@ - Progress: %@", [NSString relativeTime:cached], [NSString formatFileSize:cacheQueueManagerS.currentQueuedSong.localFileSize]];
			}
			else if (appDelegateS.isWifi || settingsS.isManualCachingOnWWANEnabled)
			{
				headerTitle = [NSString stringWithFormat:@"Added %@ - Progress: Waiting...", [NSString relativeTime:cached]];
			}
			else
			{
				headerTitle = [NSString stringWithFormat:@"Added %@ - Progress: Need Wifi", [NSString relativeTime:cached]];
			}
		}
		else
		{
			headerTitle = [NSString stringWithFormat:@"Added %@ - Progress: Waiting...", [NSString relativeTime:cached]];
		}
        cell.headerTitle = headerTitle;
		
        cell.title = aSong.title;
        cell.subTitle = aSong.albumName ? [NSString stringWithFormat:@"%@ - %@", aSong.artistName, aSong.albumName] : aSong.artistName;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		
		return cell;
	}
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return UITableViewCellEditingStyleNone;
}

static NSInteger trackSort(id obj1, id obj2, void *context)
{
	NSUInteger track1 = [(NSNumber*)[(NSArray*)obj1 objectAtIndexSafe:1] intValue];
	NSUInteger track2 = [(NSNumber*)[(NSArray*)obj2 objectAtIndexSafe:1] intValue];
	if (track1 < track2)
		return NSOrderedAscending;
	else if (track1 == track2)
		return NSOrderedSame;
	else
		return NSOrderedDescending;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath)
		return;
	
    if (_segmentedControl.selectedSegmentIndex == 0)
	{
		if (viewObjectsS.isCellEnabled)
		{
			NSString *name = nil;
			if ([_listOfArtistsSections count] > indexPath.section)
				if ([[_listOfArtistsSections objectAtIndexSafe:indexPath.section] count] > indexPath.row)
					name = [[_listOfArtistsSections objectAtIndexSafe:indexPath.section] objectAtIndexSafe:indexPath.row];
			
			CacheAlbumViewController *cacheAlbumViewController = [[CacheAlbumViewController alloc] initWithNibName:@"CacheAlbumViewController" bundle:nil];
			cacheAlbumViewController.title = name;
			cacheAlbumViewController.listOfAlbums = [NSMutableArray arrayWithCapacity:1];
			cacheAlbumViewController.listOfSongs = [NSMutableArray arrayWithCapacity:1];
			
			[databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db)
			{
				FMResultSet *result = [db executeQuery:@"SELECT md5, segs, seg2, track FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? GROUP BY seg2 ORDER BY seg2 COLLATE NOCASE", name];
				while ([result next])
				{
					@autoreleasepool 
					{
						NSUInteger numOfSegments = [result intForColumnIndex:1];
						
						NSString *md5 = [result stringForColumn:@"md5"];
						NSString *seg2 = [result stringForColumn:@"seg2"];
						
						if (numOfSegments > 2)
						{
							if (md5 && seg2)
								[cacheAlbumViewController.listOfAlbums addObject:@[md5, seg2]];
						}
						else
						{
							if (md5)
							{
								[cacheAlbumViewController.listOfSongs addObject:@[md5, @([result intForColumn:@"track"])]];
								
								BOOL multipleSameTrackNumbers = NO;
								NSMutableArray *trackNumbers = [NSMutableArray arrayWithCapacity:[cacheAlbumViewController.listOfSongs count]];
								for (NSArray *song in cacheAlbumViewController.listOfSongs)
								{
									NSNumber *track = [song objectAtIndexSafe:1];
									
									if ([trackNumbers containsObject:track])
									{
										multipleSameTrackNumbers = YES;
										break;
									}
									
									[trackNumbers addObject:track];
								}
								
								// Sort by track number
								if (!multipleSameTrackNumbers)
									[cacheAlbumViewController.listOfSongs sortUsingFunction:trackSort context:NULL];
							}
						}
					}
					
					if (!cacheAlbumViewController.segments)
					{
						NSArray *segments = @[name];
						cacheAlbumViewController.segments = segments;				
					}
				}
				[result close];
			}];
			
			[self pushViewControllerCustom:cacheAlbumViewController];
		}
		else
		{
			[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
		}
	}
}

#pragma mark - ItemUITableViewCell Delegate -

- (void)tableCellDownloadButtonPressed:(ItemUITableViewCell *)cell
{
    
}

- (void)tableCellDeleteButtonPressed:(ItemUITableViewCell *)cell
{
    if (_segmentedControl.selectedSegmentIndex == 0)
    {
        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Deleting"];
        [self performSelector:@selector(deleteAllSongsForArtistName:) withObject:cell.title afterDelay:0.05];
    }
    else if (_segmentedControl.selectedSegmentIndex == 1)
    {
        [(ISMSSong *)cell.associatedObject removeFromCacheQueueDbQueue];
    }
    
    [cell.overlayView disableDownloadButton];
}

- (void)deleteAllSongsForArtistName:(NSString *)name
{
    NSMutableArray *songMd5s = [[NSMutableArray alloc] initWithCapacity:50];
    [databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db)
     {
         FMResultSet *result = [db executeQuery:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? ", name];
         while ([result next])
         {
             @autoreleasepool
             {
                 NSString *md5 = [result stringForColumnIndex:0];
                 if (md5) [songMd5s addObject:md5];
             }
         }
         [result close];
     }];
    
    for (NSString *md5 in songMd5s)
    {
        @autoreleasepool
        {
            [ISMSSong removeSongFromCacheDbQueueByMD5:md5];
        }
    }
    
    [cacheS findCacheSize];
    
    // Reload the cached songs table
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CachedSongDeleted];
    
    if (!cacheQueueManagerS.isQueueDownloading)
        [cacheQueueManagerS startDownloadQueue];
    
    // Hide the loading screen	
    [viewObjectsS hideLoadingScreen];
}

- (void)tableCellQueueButtonPressed:(ItemUITableViewCell *)cell
{
    if (_segmentedControl.selectedSegmentIndex == 0)
    {
        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
        [self performSelector:@selector(queueAllSongsForArtistName:) withObject:cell.title afterDelay:0.05];
    }
    else if (_segmentedControl.selectedSegmentIndex == 1)
    {
        [(ISMSSong *)cell.associatedObject addToCurrentPlaylistDbQueue];
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
    }
}

- (void)queueAllSongsForArtistName:(NSString *)name
{
    NSMutableArray *songMd5s = [[NSMutableArray alloc] initWithCapacity:50];
    [databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db)
     {
         FMResultSet *result = [db executeQuery:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? ORDER BY seg2 COLLATE NOCASE", name];
         while ([result next])
         {
             @autoreleasepool
             {
                 NSString *md5 = [result stringForColumnIndex:0];
                 if (md5) [songMd5s addObject:md5];
             }
         }
         [result close];
     }];
    
    for (NSString *md5 in songMd5s)
    {
        @autoreleasepool
        {
            ISMSSong *aSong = [ISMSSong songFromCacheDbQueue:md5];
            [aSong addToCurrentPlaylistDbQueue];
        }
    }
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
    
    [viewObjectsS hideLoadingScreen];
}

- (void)tableCellDeleteToggled:(ItemUITableViewCell *)cell markedForDelete:(BOOL)markedForDelete
{
    if (_segmentedControl.selectedSegmentIndex == 0)
    {
        NSObject *object = cell.title;
        if (markedForDelete)
        {
            if (object) [_multiDeleteList addObject:object];
        }
        else
        {
            if (object) [_multiDeleteList removeObject:object];
        }
    }
    else
    {
        ISMSSong *song = cell.associatedObject;
        NSString *object = song.path.md5;
        if (markedForDelete)
        {
            if (object) [_multiDeleteList addObject:object];
        }
        else
        {
            if (object) [_multiDeleteList removeObject:object];
        }
    }
}

@end

