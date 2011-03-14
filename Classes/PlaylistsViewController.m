//
//  PlaylistsViewController.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "PlaylistsViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicControlsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "AudioStreamer.h"
#import "ServerListViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "PlaylistsXMLParser.h"
#import "PlaylistsUITableViewCell.h"
#import "CurrentPlaylistSongUITableViewCell.h"
#import "AsynchronousImageViewCached.h"
#import "LocalPlaylistsUITableViewCell.h"
#import "PlaylistSongsViewController.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString-md5.h"
#import "Song.h"
#import "ASIHTTPRequest.h"
#import "StoreViewController.h"
#import "CustomUIAlertView.h"

@interface PlaylistsViewController (Private)

- (void)addNoPlaylistsScreen;

@end


@implementation PlaylistsViewController

@synthesize listOfSongs;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if ([[[iSubAppDelegate sharedInstance].settingsDictionary objectForKey:@"lockRotationSetting"] isEqualToString:@"YES"] 
		&& inOrientation != UIDeviceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	//NSLog(@"Playlist viewDidLoad");
	
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicControlsSingleton sharedInstance];
	databaseControls = [DatabaseControlsSingleton sharedInstance];
	
	isNoPlaylistsScreenShowing = NO;
	isPlaylistSaveEditShowing = NO;
	
	viewObjects.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
	//viewObjects.multiDeleteList = nil; viewObjects.multiDeleteList = [[NSMutableArray alloc] init];
	goToNextSong = NO;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:@"initSongInfo" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:@"reloadPlaylist" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCurrentPlaylistCount) name:@"updateCurrentPlaylistCount" object:nil];

    self.title = @"Playlists";
	
	if (viewObjects.isOfflineMode)
		self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];
	
	// Setup segmented control in the header view
	headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 40)] autorelease];
	headerView.backgroundColor = [UIColor colorWithWhite:.3 alpha:1];
	
	if (viewObjects.isOfflineMode)
		segmentedControl = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Current", @"Offline Playlists", nil]];
	else
		segmentedControl = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Current", @"Local", @"Server", nil]];
	
	segmentedControl.frame = CGRectMake(5, 2, 310, 36);
	segmentedControl.selectedSegmentIndex = 0;
	segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
	segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	segmentedControl.tintColor = [UIColor colorWithWhite:.57 alpha:1];
	[segmentedControl addTarget:self action:@selector(segmentAction:) forControlEvents:UIControlEventValueChanged];
	[headerView addSubview:segmentedControl];
	
	self.tableView.tableHeaderView = headerView;
	
	// Add the table fade
	/*UIImageView *fadeTop = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-top.png"]];
	fadeTop.frame =CGRectMake(0, -10, self.tableView.bounds.size.width, 10);
	fadeTop.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.tableView addSubview:fadeTop];
	[fadeTop release];*/
	
	UIImageView *fadeBottom = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]] autorelease];
	fadeBottom.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
	fadeBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.tableView.tableFooterView = fadeBottom;
}


- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
	
	if(musicControls.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	if (viewObjects.isPlaylistUnlocked)
	{
		// Reload the data in case it changed
		self.tableView.tableHeaderView.hidden = NO;
		[self segmentAction:nil];
	}
	else
	{
		self.tableView.tableHeaderView.hidden = YES;
		[self addNoPlaylistsScreen];
	}
}


- (void)updateCurrentPlaylistCount
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		if (viewObjects.isJukebox)
			currentPlaylistCount = [databaseControls.currentPlaylistDb intForQuery:@"SELECT COUNT(*) FROM jukeboxCurrentPlaylist"];
		else
			currentPlaylistCount = [databaseControls.currentPlaylistDb intForQuery:@"SELECT COUNT(*) FROM currentPlaylist"];
			
		if (currentPlaylistCount == 1)
			playlistCountLabel.text = [NSString stringWithFormat:@"1 song"];
		else 
			playlistCountLabel.text = [NSString stringWithFormat:@"%i songs", currentPlaylistCount];
	}
}


- (void) removeEditControls
{
	// Clear the edit stuff if they switch tabs in the middle of editing
	if (viewObjects.isEditing)
	{
		viewObjects.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		//viewObjects.multiDeleteList = nil; viewObjects.multiDeleteList = [[NSMutableArray alloc] init];
		viewObjects.isEditing = NO;
		self.tableView.editing = NO;
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"showDeleteButton" object:nil];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideDeleteButton" object:nil];
	}
}


- (void) removeSaveEditButtons
{
	// Remove the save and edit buttons if showing
	if (isPlaylistSaveEditShowing == YES)
	{
		headerView.frame = CGRectMake(0, 0, 320, 44);
		[savePlaylistLabel removeFromSuperview];
		[playlistCountLabel removeFromSuperview];
		[savePlaylistButton removeFromSuperview];
		[spacerLabel removeFromSuperview];
		[editPlaylistLabel removeFromSuperview];
		[editPlaylistButton removeFromSuperview];
		[deleteSongsLabel removeFromSuperview];
		isPlaylistSaveEditShowing = NO;
		self.tableView.tableHeaderView = headerView;
	}
}


- (void) addSaveEditButtons
{
	if (isPlaylistSaveEditShowing == NO)
	{
		// Modify the header view to include the save and edit buttons
		isPlaylistSaveEditShowing = YES;
		headerView.frame = CGRectMake(0, 0, 320, 90);
		
		int y;
		//if (IS_IPAD())
		//	y = 44;
		//else
			y = 40;
		
		savePlaylistLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, y, 227, 34)];
		savePlaylistLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		savePlaylistLabel.backgroundColor = [UIColor clearColor];
		savePlaylistLabel.textColor = [UIColor whiteColor];
		savePlaylistLabel.textAlignment = UITextAlignmentCenter;
		savePlaylistLabel.font = [UIFont boldSystemFontOfSize:22];
		if (segmentedControl.selectedSegmentIndex == 0)
		{
			savePlaylistLabel.text = @"Save Playlist";
		}
		else if (segmentedControl.selectedSegmentIndex == 1)
		{
			savePlaylistLabel.frame = CGRectMake(0, y, 227, 50);
			if ([databaseControls.localPlaylistsDb intForQuery:@"SELECT COUNT(*) FROM localPlaylists"] == 1)
				savePlaylistLabel.text = [NSString stringWithFormat:@"1 playlist"];
			else 
				savePlaylistLabel.text = [NSString stringWithFormat:@"%i playlists", [databaseControls.localPlaylistsDb intForQuery:@"SELECT COUNT(*) FROM localPlaylists"]];
		}
		[headerView addSubview:savePlaylistLabel];
		[savePlaylistLabel release];
		
		playlistCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, y + 33, 227, 14)];
		playlistCountLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		playlistCountLabel.backgroundColor = [UIColor clearColor];
		playlistCountLabel.textColor = [UIColor whiteColor];
		playlistCountLabel.textAlignment = UITextAlignmentCenter;
		playlistCountLabel.font = [UIFont boldSystemFontOfSize:12];
		if (segmentedControl.selectedSegmentIndex == 0)
		{
			if (currentPlaylistCount == 1)
				playlistCountLabel.text = [NSString stringWithFormat:@"1 song"];
			else 
				playlistCountLabel.text = [NSString stringWithFormat:@"%i songs", currentPlaylistCount];
		}
		[headerView addSubview:playlistCountLabel];
		[playlistCountLabel release];
		
		savePlaylistButton = [UIButton buttonWithType:UIButtonTypeCustom];
		savePlaylistButton.frame = CGRectMake(0, y, 230, 40);
		savePlaylistButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		[savePlaylistButton addTarget:self action:@selector(savePlaylistAction:) forControlEvents:UIControlEventTouchUpInside];
		[headerView addSubview:savePlaylistButton];
		
		spacerLabel = [[UILabel alloc] initWithFrame:CGRectMake(226, y, 6, 50)];
		spacerLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		spacerLabel.backgroundColor = [UIColor clearColor];
		spacerLabel.textColor = [UIColor whiteColor];
		spacerLabel.font = [UIFont systemFontOfSize:40];
		spacerLabel.text = @"|";
		[headerView addSubview:spacerLabel];
		[spacerLabel release];	
		
		editPlaylistLabel = [[UILabel alloc] initWithFrame:CGRectMake(234, y, 86, 50)];
		editPlaylistLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
		editPlaylistLabel.backgroundColor = [UIColor clearColor];
		editPlaylistLabel.textColor = [UIColor whiteColor];
		editPlaylistLabel.textAlignment = UITextAlignmentCenter;
		editPlaylistLabel.font = [UIFont boldSystemFontOfSize:22];
		editPlaylistLabel.text = @"Edit";
		[headerView addSubview:editPlaylistLabel];
		[editPlaylistLabel release];
		
		editPlaylistButton = [UIButton buttonWithType:UIButtonTypeCustom];
		editPlaylistButton.frame = CGRectMake(234, y, 86, 40);
		editPlaylistButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
		[editPlaylistButton addTarget:self action:@selector(editPlaylistAction:) forControlEvents:UIControlEventTouchUpInside];
		[headerView addSubview:editPlaylistButton];	
		
		deleteSongsLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, y, 227, 50)];
		deleteSongsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		deleteSongsLabel.backgroundColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:.5];
		deleteSongsLabel.textColor = [UIColor whiteColor];
		deleteSongsLabel.textAlignment = UITextAlignmentCenter;
		deleteSongsLabel.font = [UIFont boldSystemFontOfSize:22];
		deleteSongsLabel.adjustsFontSizeToFitWidth = YES;
		deleteSongsLabel.minimumFontSize = 12;
		if (segmentedControl.selectedSegmentIndex == 0)
		{
			deleteSongsLabel.text = @"Remove # Songs";
		}
		else if (segmentedControl.selectedSegmentIndex == 1)
		{
			deleteSongsLabel.text = @"Remove # Playlists";
		}
		deleteSongsLabel.hidden = YES;
		[headerView addSubview:deleteSongsLabel];
		[deleteSongsLabel release];
		
		self.tableView.tableHeaderView = headerView;
	}
	else
	{
		if (segmentedControl.selectedSegmentIndex == 0)
		{
			if (currentPlaylistCount == 1)
				playlistCountLabel.text = [NSString stringWithFormat:@"1 song"];
			else 
				playlistCountLabel.text = [NSString stringWithFormat:@"%i songs", currentPlaylistCount];
		}
		else if (segmentedControl.selectedSegmentIndex == 1)
		{
			if ([databaseControls.localPlaylistsDb intForQuery:@"SELECT COUNT(*) FROM localPlaylists"] == 1)
				playlistCountLabel.text = [NSString stringWithFormat:@"1 playlist"];
			else 
				playlistCountLabel.text = [NSString stringWithFormat:@"%i playlists", [databaseControls.localPlaylistsDb intForQuery:@"SELECT COUNT(*) FROM localPlaylists"]];
		}
	}
}


- (void) removeNoPlaylistsScreen
{
	// Remove the no playlists overlay screen if it's showing
	if (isNoPlaylistsScreenShowing)
	{
		[noPlaylistsScreen removeFromSuperview];
		isNoPlaylistsScreenShowing = NO;
	}
}


- (void) addNoPlaylistsScreen
{
	[self removeNoPlaylistsScreen];
	
	isNoPlaylistsScreenShowing = YES;
	noPlaylistsScreen = [[UIImageView alloc] init];
	noPlaylistsScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
	noPlaylistsScreen.frame = CGRectMake(40, 100, 240, 180);
	noPlaylistsScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
	noPlaylistsScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
	noPlaylistsScreen.alpha = .80;
	noPlaylistsScreen.userInteractionEnabled = YES;
	
	UILabel *textLabel = [[UILabel alloc] init];
	textLabel.backgroundColor = [UIColor clearColor];
	textLabel.textColor = [UIColor whiteColor];
	textLabel.font = [UIFont boldSystemFontOfSize:32];
	textLabel.textAlignment = UITextAlignmentCenter;
	textLabel.numberOfLines = 0;
	if (viewObjects.isPlaylistUnlocked)
	{
		if (segmentedControl.selectedSegmentIndex == 0)
		{
			textLabel.text = @"No Songs\nQueued";
			textLabel.frame = CGRectMake(20, 0, 200, 100);
		}
		else if (segmentedControl.selectedSegmentIndex == 1)
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
	[noPlaylistsScreen addSubview:textLabel];
	[textLabel release];
	
	UILabel *textLabel2 = [[UILabel alloc] init];
	textLabel2.backgroundColor = [UIColor clearColor];
	textLabel2.textColor = [UIColor whiteColor];
	textLabel2.font = [UIFont boldSystemFontOfSize:14];
	textLabel2.textAlignment = UITextAlignmentCenter;
	textLabel2.numberOfLines = 0;
	if (viewObjects.isPlaylistUnlocked)
	{
		if (segmentedControl.selectedSegmentIndex == 0)
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
	[noPlaylistsScreen addSubview:textLabel2];
	[textLabel2 release];
	
	if (!viewObjects.isPlaylistUnlocked)
	{
		UIButton *storeLauncher = [UIButton buttonWithType:UIButtonTypeCustom];
		storeLauncher.frame = CGRectMake(0, 0, noPlaylistsScreen.frame.size.width, noPlaylistsScreen.frame.size.height);
		[storeLauncher addTarget:self action:@selector(showStore) forControlEvents:UIControlEventTouchUpInside];
		[noPlaylistsScreen addSubview:storeLauncher];
	}
	
	[self.view addSubview:noPlaylistsScreen];
	
	[noPlaylistsScreen release];
}

- (void)showStore
{
	StoreViewController *store = [[StoreViewController alloc] init];
	[self.navigationController pushViewController:store animated:YES];
	[store release];
}


- (void)segmentAction:(id)sender
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		// Get the current playlist count
		if (viewObjects.isJukebox)
			currentPlaylistCount = [databaseControls.currentPlaylistDb intForQuery:@"SELECT COUNT(*) FROM jukeboxCurrentPlaylist"];
		else
			currentPlaylistCount = [databaseControls.currentPlaylistDb intForQuery:@"SELECT COUNT(*) FROM currentPlaylist"];
		
		// Clear the edit stuff if they switch tabs in the middle of editing
		[self removeEditControls];
		
		// Remove the save and edit buttons if showing
		[self removeSaveEditButtons];
		
		if (currentPlaylistCount > 0)
		{
			// Modify the header view to include the save and edit buttons
			[self addSaveEditButtons];
		}
		
		// Reload the table data
		[self.tableView reloadData];
		
		if (currentPlaylistCount > 0 && musicControls.currentPlaylistPosition >= 0)
		{
			/*if (appDelegate.streamer)
			 {
			 // Highlight the current playing song
			 [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:appDelegate.currentPlaylistPosition inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
			 }*/
			
			@try 
			{
				[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:musicControls.currentPlaylistPosition inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
			}
			@catch (NSException *exception) 
			{
				//NSLog(@"main: Caught %@: %@", [exception name], [exception reason]);
			}
		}
		
		// Remove the no playlists overlay screen if it's showing
		[self removeNoPlaylistsScreen];
		
		// If the list is empty, display the no playlists overlay screen
		if (currentPlaylistCount == 0)
		{
			[self addNoPlaylistsScreen];
		}
		
		// If the list is empty remove the Save/Edit bar
		if (currentPlaylistCount == 0)
		{
			[self removeSaveEditButtons];
		}
	}
	else if(segmentedControl.selectedSegmentIndex == 1)
	{
		viewObjects.isLocalPlaylist = YES;
		
		// Clear the edit stuff if they switch tabs in the middle of editing
		[self removeEditControls];
		
		// Remove the save and edit buttons if showing
		[self removeSaveEditButtons];
		
		if ([databaseControls.localPlaylistsDb intForQuery:@"SELECT COUNT(*) FROM localPlaylists"] > 0)
		{
			// Modify the header view to include the save and edit buttons
			[self addSaveEditButtons];
		}
		
		// Reload the table data
		[self.tableView reloadData];
		
		// Remove the no playlists overlay screen if it's showing
		[self removeNoPlaylistsScreen];
		
		// If the list is empty, display the no playlists overlay screen
		if ([databaseControls.localPlaylistsDb intForQuery:@"SELECT COUNT(*) FROM localPlaylists"] == 0)
		{
			[self addNoPlaylistsScreen];
		}
	}
	else if(segmentedControl.selectedSegmentIndex == 2)
	{
		viewObjects.isLocalPlaylist = NO;
		
		// Clear the edit stuff if they switch tabs in the middle of editing
		[self removeEditControls];
		
		// Remove the save and edit buttons if showing
		[self removeSaveEditButtons];

		// Reload the table data
		[self.tableView reloadData];
		
		// Remove the no playlists overlay screen if it's showing
		[self removeNoPlaylistsScreen];
		
		[viewObjects showLoadingScreen:self.view blockInput:YES mainWindow:NO];
		[self performSelectorInBackground:@selector(loadRemotePlaylists) withObject:nil];
	}
}


- (void) editPlaylistAction:(id)sender
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		if (self.tableView.editing == NO)
		{
			viewObjects.isEditing = YES;
			[self.tableView reloadData];
			[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(showDeleteButton) name:@"showDeleteButton" object: nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(hideDeleteButton) name:@"hideDeleteButton" object: nil];
			viewObjects.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			//viewObjects.multiDeleteList = nil; viewObjects.multiDeleteList = [[NSMutableArray alloc] init];
			[self.tableView setEditing:YES animated:YES];
			editPlaylistLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
			editPlaylistLabel.text = @"Done";
			[self showDeleteButton];
			
			[NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(showDeleteToggle) userInfo:nil repeats:NO];
		}
		else 
		{
			viewObjects.isEditing = NO;
			[[NSNotificationCenter defaultCenter] removeObserver:self name:@"showDeleteButton" object:nil];
			[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideDeleteButton" object:nil];
			viewObjects.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			//viewObjects.multiDeleteList = nil; viewObjects.multiDeleteList = [[NSMutableArray alloc] init];
			[self hideDeleteButton];
			[self.tableView setEditing:NO animated:YES];
			editPlaylistLabel.backgroundColor = [UIColor clearColor];
			editPlaylistLabel.text = @"Edit";
			
			if (goToNextSong)
			{
				goToNextSong = NO;
				if (musicControls.streamer)
				{
					currentPlaylistCount = [databaseControls.currentPlaylistDb intForQuery:@"SELECT COUNT(*) FROM currentPlaylist"];
					if (currentPlaylistCount > 0)
					{
						[musicControls nextSong];
					}
					else
					{
						[musicControls destroyStreamer];
						self.navigationItem.rightBarButtonItem = nil;
						
						if (isPlaylistSaveEditShowing == YES)
						{
							if (IS_IPAD())
							{
								headerView.frame = CGRectMake(0, 0, 320, 48);
							}
							else 
							{
								headerView.frame = CGRectMake(0, 0, 320, 40);
							}
							[savePlaylistLabel removeFromSuperview];
							[playlistCountLabel removeFromSuperview];
							[savePlaylistButton removeFromSuperview];
							[spacerLabel removeFromSuperview];
							[editPlaylistLabel removeFromSuperview];
							[editPlaylistButton removeFromSuperview];
							[deleteSongsLabel removeFromSuperview];
							isPlaylistSaveEditShowing = NO;
							self.tableView.tableHeaderView = headerView;
						}
					}
				}
			}
			
			// Reload the table to correct the numbers
			[self.tableView reloadData];
			if (musicControls.streamer)
			{
				@try 
				{
					[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:musicControls.currentPlaylistPosition inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
				}
				@catch (NSException *exception) 
				{
					//NSLog(@"main: Caught %@: %@", [exception name], [exception reason]);
				}
			}
		}
	}
	else if (segmentedControl.selectedSegmentIndex == 1)
	{
		if (self.tableView.editing == NO)
		{
			viewObjects.isEditing = YES;
			[self.tableView reloadData];
			[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(showDeleteButton) name:@"showDeleteButton" object: nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(hideDeleteButton) name:@"hideDeleteButton" object: nil];
			viewObjects.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			//viewObjects.multiDeleteList = nil; viewObjects.multiDeleteList = [[NSMutableArray alloc] init];
			[self.tableView setEditing:YES animated:YES];
			editPlaylistLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
			editPlaylistLabel.text = @"Done";
			[self showDeleteButton];
			
			[NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(showDeleteToggle) userInfo:nil repeats:NO];
		}
		else 
		{
			viewObjects.isEditing = NO;
			[[NSNotificationCenter defaultCenter] removeObserver:self name:@"showDeleteButton" object:nil];
			[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideDeleteButton" object:nil];
			viewObjects.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			//viewObjects.multiDeleteList = nil; viewObjects.multiDeleteList = [[NSMutableArray alloc] init];
			[self hideDeleteButton];
			[self.tableView setEditing:NO animated:YES];
			editPlaylistLabel.backgroundColor = [UIColor clearColor];
			editPlaylistLabel.text = @"Edit";
			
			// Reload the table to correct the numbers
			[self.tableView reloadData];
		}
	}
}


- (void) showDeleteButton
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		if ([viewObjects.multiDeleteList count] == 0)
		{
			deleteSongsLabel.text = @"Clear Playlist";
		}
		else if ([viewObjects.multiDeleteList count] == 1)
		{
			deleteSongsLabel.text = @"Remove 1 Song  ";
		}
		else
		{
			deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %i Songs", [viewObjects.multiDeleteList count]];
		}
	}
	else if (segmentedControl.selectedSegmentIndex == 1)
	{
		if ([viewObjects.multiDeleteList count] == 0)
		{
			deleteSongsLabel.text = @"Clear Playlists";
		}
		else if ([viewObjects.multiDeleteList count] == 1)
		{
			deleteSongsLabel.text = @"Remove 1 Playlist";
		}
		else
		{
			deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %i Playlists", [viewObjects.multiDeleteList count]];
		}
	}
	
	savePlaylistLabel.hidden = YES;
	playlistCountLabel.hidden = YES;
	deleteSongsLabel.hidden = NO;
}

		
- (void) hideDeleteButton
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		if ([viewObjects.multiDeleteList count] == 0)
		{
			if (viewObjects.isEditing == NO)
			{
				savePlaylistLabel.hidden = NO;
				playlistCountLabel.hidden = NO;
				deleteSongsLabel.hidden = YES;
			}
			else
			{
				deleteSongsLabel.text = @"Clear Playlist";
			}
		}
		else if ([viewObjects.multiDeleteList count] == 1)
		{
			deleteSongsLabel.text = @"Remove 1 Song  ";
		}
		else 
		{
			deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %i Songs", [viewObjects.multiDeleteList count]];
		}
	}
	else if (segmentedControl.selectedSegmentIndex == 1)
	{
		if ([viewObjects.multiDeleteList count] == 0)
		{
			if (viewObjects.isEditing == NO)
			{
				savePlaylistLabel.hidden = NO;
				playlistCountLabel.hidden = NO;
				deleteSongsLabel.hidden = YES;
			}
			else
			{
				deleteSongsLabel.text = @"Clear Playlists";
			}
		}
		else if ([viewObjects.multiDeleteList count] == 1)
		{
			deleteSongsLabel.text = @"Remove 1 Playlist";
		}
		else 
		{
			deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %i Playlists", [viewObjects.multiDeleteList count]];
		}
	}
}


- (void) showDeleteToggle
{
	// Show the delete toggle for already visible cells
	for (id cell in self.tableView.visibleCells) 
	{
		[[cell deleteToggleImage] setHidden:NO];
	}
}


- (void) savePlaylistAction:(id)sender
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		if (deleteSongsLabel.hidden == YES)
		{
			if (viewObjects.isEditing == NO)
			{
				savePlaylistLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
				playlistCountLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
				
				UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Playlist Name:" message:@"      \n      " delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
				myAlertView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
				playlistNameTextField = [[UITextField alloc] initWithFrame:CGRectMake(12.0, 47.0, 260.0, 22.0)];
				//playlistNameTextField.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin;
				[playlistNameTextField setBackgroundColor:[UIColor whiteColor]];
				[myAlertView addSubview:playlistNameTextField];
				if ([[[[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."] objectAtIndex:0] isEqualToString:@"3"])
				{
					CGAffineTransform myTransform = CGAffineTransformMakeTranslation(0.0, 100.0);
					[myAlertView setTransform:myTransform];
				}
				[myAlertView show];
				[myAlertView release];
				[playlistNameTextField becomeFirstResponder];
			}
		}
		else 
		{
			if ([deleteSongsLabel.text isEqualToString:@"Clear Playlist"])
			{
				if (viewObjects.isJukebox)
				{
					[databaseControls resetJukeboxPlaylist];
					[musicControls jukeboxClearPlaylist];
				}
				else
				{
					[musicControls destroyStreamer];
					[databaseControls resetCurrentPlaylistDb];
				}
				
				[self editPlaylistAction:nil];
				[self segmentAction:nil];
				
				musicControls.currentPlaylistPosition = 0;
			}
			else
			{
				//
				// Delete action
				//
				
				// Sort the multiDeleteList to make sure it's accending
				[viewObjects.multiDeleteList sortUsingSelector:@selector(compare:)];
				//NSLog(@"multiDeleteList: %@", viewObjects.multiDeleteList);
				
				if (viewObjects.isJukebox)
				{
					[databaseControls.currentPlaylistDb executeUpdate:@"DROP TABLE jukeboxTemp"];
					[databaseControls.currentPlaylistDb executeUpdate:@"CREATE TABLE jukeboxTemp(title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
					
					for (NSNumber *index in [viewObjects.multiDeleteList reverseObjectEnumerator])
					{
						NSInteger rowId = [index integerValue] + 1;
						[databaseControls.currentPlaylistDb executeUpdate:[NSString stringWithFormat:@"DELETE FROM jukeboxCurrentPlaylist WHERE ROWID = %i", rowId]];
					}
					
					[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist"];
					[databaseControls.currentPlaylistDb executeUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
					[databaseControls.currentPlaylistDb executeUpdate:@"ALTER TABLE jukeboxTemp RENAME TO jukeboxCurrentPlaylist"];
				}
				else
				{
					if (musicControls.isShuffle)
					{
						[databaseControls.currentPlaylistDb executeUpdate:@"DROP TABLE shuffleTemp"];
						[databaseControls.currentPlaylistDb executeUpdate:@"CREATE TABLE shuffleTemp(title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
						
						for (NSNumber *index in [viewObjects.multiDeleteList reverseObjectEnumerator])
						{
							NSInteger rowId = [index integerValue] + 1;
							[databaseControls.currentPlaylistDb executeUpdate:[NSString stringWithFormat:@"DELETE FROM shufflePlaylist WHERE ROWID = %i", rowId]];
						}
						
						[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist"];
						[databaseControls.currentPlaylistDb executeUpdate:@"DROP TABLE shufflePlaylist"];
						[databaseControls.currentPlaylistDb executeUpdate:@"ALTER TABLE shuffleTemp RENAME TO shufflePlaylist"];
					}
					else
					{
						[databaseControls.currentPlaylistDb executeUpdate:@"DROP TABLE currentTemp"];
						[databaseControls.currentPlaylistDb executeUpdate:@"CREATE TABLE currentTemp(title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
						
						for (NSNumber *index in [viewObjects.multiDeleteList reverseObjectEnumerator])
						{
							NSInteger rowId = [index integerValue] + 1;
							[databaseControls.currentPlaylistDb executeUpdate:[NSString stringWithFormat:@"DELETE FROM currentPlaylist WHERE ROWID = %i", rowId]];
						}
						
						[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist"];
						[databaseControls.currentPlaylistDb executeUpdate:@"DROP TABLE currentPlaylist"];
						[databaseControls.currentPlaylistDb executeUpdate:@"ALTER TABLE currentTemp RENAME TO currentPlaylist"];
					}
				}
				
				// Correct the value of currentPlaylistPosition
				// If the current song was deleted make sure to set goToNextSong so the next song will play
				if ([viewObjects.multiDeleteList containsObject:[NSNumber numberWithInt:musicControls.currentPlaylistPosition]])
				{
					goToNextSong = YES;
				}
				
				// Find out how many songs were deleted before the current position to determine the new position
				NSInteger numberBefore = 0;
				for (NSNumber *index in viewObjects.multiDeleteList)
				{
					if ([index integerValue] <= musicControls.currentPlaylistPosition)
					{
						numberBefore = numberBefore + 1;
					}
				}
				musicControls.currentPlaylistPosition = musicControls.currentPlaylistPosition - numberBefore;
				
				// Recaculate the table count
				if (viewObjects.isJukebox)
					currentPlaylistCount = [databaseControls.currentPlaylistDb intForQuery:@"SELECT COUNT(*) FROM jukeboxCurrentPlaylist"];
				else
					currentPlaylistCount = [databaseControls.currentPlaylistDb intForQuery:@"SELECT COUNT(*) FROM currentPlaylist"];
				
				// Create indexPaths from multiDeleteList and delete the rows in the table view
				NSMutableArray *indexes = [[NSMutableArray alloc] init];
				for (NSNumber *index in viewObjects.multiDeleteList)
				{
					[indexes addObject:[NSIndexPath indexPathForRow:[index integerValue] inSection:0]];
				}
				[self.tableView deleteRowsAtIndexPaths:indexes withRowAnimation:YES];
				
				[indexes release];
				
				if (viewObjects.isJukebox)
				{
					[musicControls jukeboxReplacePlaylistWithLocal];
				}
				
				[self editPlaylistAction:nil];
				[self segmentAction:nil];
			}
		}
	}
	else if (segmentedControl.selectedSegmentIndex == 1)
	{
		if (deleteSongsLabel.hidden == NO)
		{
			if ([deleteSongsLabel.text isEqualToString:@"Clear Playlists"])
			{
				[databaseControls resetLocalPlaylistsDb];
				[self editPlaylistAction:nil];
				[self segmentAction:nil];
			}
			else
			{
				//
				// Delete action
				//
				
				// Sort the multiDeleteList to make sure it's accending
				[viewObjects.multiDeleteList sortUsingSelector:@selector(compare:)];
				//NSLog(@"multiDeleteList: %@", viewObjects.multiDeleteList);
				
				[databaseControls.localPlaylistsDb executeUpdate:@"DROP TABLE localPlaylistsTemp"];
				[databaseControls.localPlaylistsDb executeUpdate:@"CREATE TABLE localPlaylistsTemp(playlist TEXT, md5 TEXT)"];
				for (NSNumber *index in [viewObjects.multiDeleteList reverseObjectEnumerator])
				{
					NSInteger rowId = [index integerValue] + 1;
					NSString *md5 = [databaseControls.localPlaylistsDb stringForQuery:[NSString stringWithFormat:@"SELECT md5 FROM localPlaylists WHERE ROWID = %i", rowId]];
					[databaseControls.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"DROP TABLE playlist%@", md5]];
					[databaseControls.localPlaylistsDb executeUpdate:@"DELETE FROM localPlaylists WHERE md5 = ?", md5];
				}
				[databaseControls.localPlaylistsDb executeUpdate:@"INSERT INTO localPlaylistsTemp SELECT * FROM localPlaylists"];
				[databaseControls.localPlaylistsDb executeUpdate:@"DROP TABLE localPlaylists"];
				[databaseControls.localPlaylistsDb executeUpdate:@"ALTER TABLE localPlaylistsTemp RENAME TO localPlaylists"];
				
				// Create indexPaths from multiDeleteList and delete the rows from the tableView
				NSMutableArray *indexes = [[NSMutableArray alloc] init];
				for (NSNumber *index in viewObjects.multiDeleteList)
				{
					[indexes addObject:[NSIndexPath indexPathForRow:[index integerValue] inSection:0]];
				}
				[self.tableView deleteRowsAtIndexPaths:indexes withRowAnimation:YES];
				
				[indexes release];
				
				[self editPlaylistAction:nil];
				[self segmentAction:nil];
			}
		}
	}
}


- (void)alertView:(CustomUIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if([alertView.title isEqualToString:@"Playlist Name:"])
	{
		[playlistNameTextField resignFirstResponder];
		if(buttonIndex == 1)
		{
			// Check if the playlist exists, if not create the playlist table and add the entry to localPlaylists table
			if ([databaseControls.localPlaylistsDb intForQuery:@"SELECT COUNT(*) FROM localPlaylists WHERE md5 = ?", [NSString md5:playlistNameTextField.text]] == 0)
			{
				[databaseControls.localPlaylistsDb executeUpdate:@"INSERT INTO localPlaylists (playlist, md5) VALUES (?, ?)", playlistNameTextField.text, [NSString md5:playlistNameTextField.text]];
				[databaseControls.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)", [NSString md5:playlistNameTextField.text]]];
				
				[databaseControls.localPlaylistsDb executeUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseControls.databaseFolderPath, [NSString md5:appDelegate.defaultUrl]], @"currentPlaylistDb"];
				if ([databaseControls.localPlaylistsDb hadError]) { NSLog(@"Err attaching the currentPlaylistDb %d: %@", [databaseControls.localPlaylistsDb lastErrorCode], [databaseControls.localPlaylistsDb lastErrorMessage]); }
				if (musicControls.isShuffle) {
					[databaseControls.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM shufflePlaylist", [NSString md5:playlistNameTextField.text]]];
				}
				else {
					[databaseControls.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM currentPlaylist", [NSString md5:playlistNameTextField.text]]];
				}
				[databaseControls.localPlaylistsDb executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
			}
			else
			{
				// If it exists, ask to overwrite
				CustomUIAlertView *myAlertView = [[CustomUIAlertView alloc] initWithTitle:@"Overwrite?" message:@"There is already a playlist with this name. Would you like to overwrite it?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
				[myAlertView show];
				[myAlertView release];
			}
		}
	}
	else if([alertView.title isEqualToString:@"Overwrite?"])
	{
		if(buttonIndex == 1)
		{
			// If yes, overwrite the playlist
			[databaseControls.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"DROP TABLE playlist%@", [NSString md5:playlistNameTextField.text]]];
			[databaseControls.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)", [NSString md5:playlistNameTextField.text]]];
			
			[databaseControls.localPlaylistsDb executeUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseControls.databaseFolderPath, [NSString md5:appDelegate.defaultUrl]], @"currentPlaylistDb"];
			if ([databaseControls.localPlaylistsDb hadError]) { NSLog(@"Err attaching the currentPlaylistDb %d: %@", [databaseControls.localPlaylistsDb lastErrorCode], [databaseControls.localPlaylistsDb lastErrorMessage]); }
			if (musicControls.isShuffle) {
				[databaseControls.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM shufflePlaylist", [NSString md5:playlistNameTextField.text]]];
			}
			else {
				[databaseControls.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM currentPlaylist", [NSString md5:playlistNameTextField.text]]];
			}
			[databaseControls.localPlaylistsDb executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
		}
	}
	
	savePlaylistLabel.backgroundColor = [UIColor clearColor];
	playlistCountLabel.backgroundColor = [UIColor clearColor];
}


- (void)loadRemotePlaylists
{
	//NSLog(@"loadRemotePlaylists listOfPlaylists count: %i", [viewObjects.listOfPlaylists count]);
	
	// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	// Grab the list of playlists from the server
	ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:[appDelegate getBaseUrl:@"getPlaylists.view"]]];
	[request startSynchronous];
	if ([request error])
	{
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error grabbing the playlist from the server." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
	else
	{
		NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:[request responseData]];
		PlaylistsXMLParser *parser = [[PlaylistsXMLParser alloc] initXMLParser];
		[xmlParser setDelegate:parser];
		[xmlParser parse];
		
		[xmlParser release];
		[parser release];
	}
	
	[self performSelectorOnMainThread:@selector(loadRemotePlaylists2) withObject:nil waitUntilDone:NO];
	
	[autoreleasePool release];
}	


- (void)loadRemotePlaylists2
{
	[self.tableView reloadData];

	// If the list is empty, display the no playlists overlay screen
	if ([viewObjects.listOfPlaylists count] == 0 && isNoPlaylistsScreenShowing == NO)
	{
		isNoPlaylistsScreenShowing = YES;
		noPlaylistsScreen = [[UIImageView alloc] init];
		noPlaylistsScreen.frame = CGRectMake(40, 100, 240, 180);
		noPlaylistsScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
		noPlaylistsScreen.alpha = .80;
		
		UILabel *textLabel = [[UILabel alloc] init];
		textLabel.backgroundColor = [UIColor clearColor];
		textLabel.textColor = [UIColor whiteColor];
		textLabel.font = [UIFont boldSystemFontOfSize:32];
		textLabel.textAlignment = UITextAlignmentCenter;
		textLabel.numberOfLines = 0;
		[textLabel setText:@"No Playlists\nFound"];
		textLabel.frame = CGRectMake(20, 20, 200, 140);
		[noPlaylistsScreen addSubview:textLabel];
		[textLabel release];
		
		[self.view addSubview:noPlaylistsScreen];
		
		[noPlaylistsScreen release];
	}
	
	// Hide the loading screen
	[viewObjects hideLoadingScreen];
}



- (void)selectRow
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		[self.tableView reloadData];
		if (musicControls.currentPlaylistPosition >= 0)
		{
			@try 
			{
				[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:musicControls.currentPlaylistPosition inSection:0] animated:YES scrollPosition:UITableViewScrollPositionMiddle];
			}
			@catch (NSException *exception) 
			{
				//NSLog(@"main: Caught %@: %@", [exception name], [exception reason]);
			}
		}
	}
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	if (viewObjects.isEditing)
	{
		// Clear the edit stuff if they switch tabs in the middle of editing
		viewObjects.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		//viewObjects.multiDeleteList = nil; viewObjects.multiDeleteList = [[NSMutableArray alloc] init];
		viewObjects.isEditing = NO;
		self.tableView.editing = NO;
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"showDeleteButton" object:nil];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideDeleteButton" object:nil];
	}
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void) settingsAction:(id)sender 
{
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverListViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverListViewController animated:YES];
	[serverListViewController release];
}


- (IBAction)nowPlayingAction:(id)sender
{
	musicControls.isNewSong = NO;
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
	[streamingPlayerViewController release];
}


#pragma mark Table view methods

// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView 
{
	if (segmentedControl.selectedSegmentIndex == 0 && currentPlaylistCount > 0)
	{
		if (viewObjects.isEditing == NO)
		{
			NSMutableArray *searchIndexes = [[[NSMutableArray alloc] init] autorelease];
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
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		if (index == 0)
		{
			[tableView scrollRectToVisible:CGRectMake(0, 0, 320, 40) animated:NO];
		}
		else if (index == 19)
		{
			NSInteger row = currentPlaylistCount - 1;
			[tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
		}
		else 
		{
			NSInteger row = currentPlaylistCount / 20 * index;
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
	if (segmentedControl.selectedSegmentIndex == 0)
		return currentPlaylistCount;
	else if (segmentedControl.selectedSegmentIndex == 1)
		return [databaseControls.localPlaylistsDb intForQuery:@"SELECT COUNT(*) FROM localPlaylists"];
	else if (segmentedControl.selectedSegmentIndex == 2)
		return [viewObjects.listOfPlaylists count];
	
	return 0;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (segmentedControl.selectedSegmentIndex == 0)
		return YES;
	else if (segmentedControl.selectedSegmentIndex == 1)
		return YES;
	else if (segmentedControl.selectedSegmentIndex == 2)
		return NO;
	
	return NO;
}

// Set the editing style, set to none for no delete minus sign (overriding with own custom multi-delete boxes)
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return UITableViewCellEditingStyleNone;
}


// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath 
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		NSInteger fromRow = fromIndexPath.row + 1;
		NSInteger toRow = toIndexPath.row + 1;
		
		if (viewObjects.isJukebox)
		{
			[databaseControls.currentPlaylistDb executeUpdate:@"DROP TABLE jukeboxTemp"];
			[databaseControls.currentPlaylistDb executeUpdate:@"CREATE TABLE jukeboxTemp(title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
			
			if (fromRow < toRow)
			{
				[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID < ?", [NSNumber numberWithInt:fromRow]];
				[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID > ? AND ROWID <= ?", [NSNumber numberWithInt:fromRow], [NSNumber numberWithInt:toRow]];
				[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
				[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID > ?", [NSNumber numberWithInt:toRow]];
				
				[databaseControls.currentPlaylistDb executeUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
				[databaseControls.currentPlaylistDb executeUpdate:@"ALTER TABLE jukeboxTemp RENAME TO jukeboxCurrentPlaylist"];
			}
			else
			{
				[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID < ?", [NSNumber numberWithInt:toRow]];
				[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
				[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID >= ? AND ROWID < ?", [NSNumber numberWithInt:toRow], [NSNumber numberWithInt:fromRow]];
				[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID > ?", [NSNumber numberWithInt:fromRow]];
				
				[databaseControls.currentPlaylistDb executeUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
				[databaseControls.currentPlaylistDb executeUpdate:@"ALTER TABLE jukeboxTemp RENAME TO jukeboxCurrentPlaylist"];
			}
		}
		else
		{
			if (musicControls.isShuffle)
			{
				[databaseControls.currentPlaylistDb executeUpdate:@"DROP TABLE shuffleTemp"];
				[databaseControls.currentPlaylistDb executeUpdate:@"CREATE TABLE shuffleTemp(title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
				
				if (fromRow < toRow)
				{
					[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID < ?", [NSNumber numberWithInt:fromRow]];
					[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID > ? AND ROWID <= ?", [NSNumber numberWithInt:fromRow], [NSNumber numberWithInt:toRow]];
					[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
					[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID > ?", [NSNumber numberWithInt:toRow]];
					
					[databaseControls.currentPlaylistDb executeUpdate:@"DROP TABLE shufflePlaylist"];
					[databaseControls.currentPlaylistDb executeUpdate:@"ALTER TABLE shuffleTemp RENAME TO shufflePlaylist"];
				}
				else
				{
					[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID < ?", [NSNumber numberWithInt:toRow]];
					[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
					[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID >= ? AND ROWID < ?", [NSNumber numberWithInt:toRow], [NSNumber numberWithInt:fromRow]];
					[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID > ?", [NSNumber numberWithInt:fromRow]];
					
					[databaseControls.currentPlaylistDb executeUpdate:@"DROP TABLE shufflePlaylist"];
					[databaseControls.currentPlaylistDb executeUpdate:@"ALTER TABLE shuffleTemp RENAME TO shufflePlaylist"];
				}
			}
			else
			{
				[databaseControls.currentPlaylistDb executeUpdate:@"DROP TABLE currentTemp"];
				[databaseControls.currentPlaylistDb executeUpdate:@"CREATE TABLE currentTemp(title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
				
				if (fromRow < toRow)
				{
					[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID < ?", [NSNumber numberWithInt:fromRow]];
					[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID > ? AND ROWID <= ?", [NSNumber numberWithInt:fromRow], [NSNumber numberWithInt:toRow]];
					[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
					[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID > ?", [NSNumber numberWithInt:toRow]];
					
					[databaseControls.currentPlaylistDb executeUpdate:@"DROP TABLE currentPlaylist"];
					[databaseControls.currentPlaylistDb executeUpdate:@"ALTER TABLE currentTemp RENAME TO currentPlaylist"];
				}
				else
				{
					[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID < ?", [NSNumber numberWithInt:toRow]];
					[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
					[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID >= ? AND ROWID < ?", [NSNumber numberWithInt:toRow], [NSNumber numberWithInt:fromRow]];
					[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID > ?", [NSNumber numberWithInt:fromRow]];
					
					[databaseControls.currentPlaylistDb executeUpdate:@"DROP TABLE currentPlaylist"];
					[databaseControls.currentPlaylistDb executeUpdate:@"ALTER TABLE currentTemp RENAME TO currentPlaylist"];
				}
			}
		}
		
		// Fix the multiDeleteList to reflect the new row positions
		//NSLog(@"multiDeleteList: %@", viewObjects.multiDeleteList);
		if ([viewObjects.multiDeleteList count] > 0)
		{
			NSMutableArray *tempMultiDeleteList = [[NSMutableArray alloc] init];
			int newPosition;
			for (NSNumber *position in viewObjects.multiDeleteList)
			{
				if (fromIndexPath.row > toIndexPath.row)
				{
					if ([position intValue] >= toIndexPath.row && [position intValue] <= fromIndexPath.row)
					{
						if ([position intValue] == fromIndexPath.row)
						{
							[tempMultiDeleteList addObject:[NSNumber numberWithInt:toIndexPath.row]];
						}
						else 
						{
							newPosition = [position intValue] + 1;
							[tempMultiDeleteList addObject:[NSNumber numberWithInt:newPosition]];
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
							[tempMultiDeleteList addObject:[NSNumber numberWithInt:toIndexPath.row]];
						}
						else 
						{
							newPosition = [position intValue] - 1;
							[tempMultiDeleteList addObject:[NSNumber numberWithInt:newPosition]];
						}
					}
					else
					{
						[tempMultiDeleteList addObject:position];
					}
				}
			}
			viewObjects.multiDeleteList = [NSMutableArray arrayWithArray:tempMultiDeleteList];
			[tempMultiDeleteList release];
		}
		//NSLog(@"multiDeleteList: %@", viewObjects.multiDeleteList);
		
		// Correct the value of currentPlaylistPosition
		if (fromIndexPath.row == musicControls.currentPlaylistPosition)
		{
			musicControls.currentPlaylistPosition = toIndexPath.row;
		}
		else 
		{
			if (fromIndexPath.row < musicControls.currentPlaylistPosition && toIndexPath.row >= musicControls.currentPlaylistPosition)
			{
				musicControls.currentPlaylistPosition = musicControls.currentPlaylistPosition - 1;
			}
			else if (fromIndexPath.row > musicControls.currentPlaylistPosition && toIndexPath.row <= musicControls.currentPlaylistPosition)
			{
				musicControls.currentPlaylistPosition = musicControls.currentPlaylistPosition + 1;
			}
		}
		
		// Highlight the current playing song
		@try 
		{
			[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:musicControls.currentPlaylistPosition inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
		}
		@catch (NSException *exception) 
		{
			//NSLog(@"main: Caught %@: %@", [exception name], [exception reason]);
		}
		
		if (viewObjects.isJukebox)
		{
			[musicControls jukeboxReplacePlaylistWithLocal];
		}
	}
}


// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (segmentedControl.selectedSegmentIndex == 0)
		return YES;
	else if (segmentedControl.selectedSegmentIndex == 1)
		return NO; //this will be changed to YES and will be fully editable
	else if (segmentedControl.selectedSegmentIndex == 2)
		return NO;
	
	return NO;
}


/*// Customize the height of individual rows to make the album rows taller to accomidate the album art.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (segmentedControl.selectedSegmentIndex == 0)
		return 60.0;
	else if (segmentedControl.selectedSegmentIndex == 1)
		return 60.0;
	else
		return 43.0;
}*/


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		static NSString *CellIdentifier = @"Cell";
		CurrentPlaylistSongUITableViewCell *cell = [[[CurrentPlaylistSongUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		cell.indexPath = indexPath;
		
		cell.deleteToggleImage.hidden = !viewObjects.isEditing;
		if ([viewObjects.multiDeleteList containsObject:[NSNumber numberWithInt:indexPath.row]])
		{
			cell.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
		}
		
		Song *aSong;
		
		if (viewObjects.isJukebox)
		{
			aSong = [databaseControls songFromDbRow:indexPath.row inTable:@"jukeboxCurrentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
		}
		else
		{
			if (musicControls.isShuffle)
				aSong = [databaseControls songFromDbRow:indexPath.row inTable:@"shufflePlaylist" inDatabase:databaseControls.currentPlaylistDb];
			else
				aSong = [databaseControls songFromDbRow:indexPath.row inTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
		}
		
		if (aSong.coverArtId)
		{
			if ([databaseControls.coverArtCacheDb60 intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [NSString md5:aSong.coverArtId]] == 1)
			{
				// If the image is already in the cache dictionary, load it
				cell.coverArtView.image = [UIImage imageWithData:[databaseControls.coverArtCacheDb60 dataForQuery:@"SELECT data FROM coverArtCache WHERE id = ?", [NSString md5:aSong.coverArtId]]];
			}
			else 
			{			
				// If not, grab it from the url and cache it
				NSString *imgUrlString;
				if (appDelegate.isHighRez)
				{
					imgUrlString = [NSString stringWithFormat:@"%@%@&size=120", [appDelegate getBaseUrl:@"getCoverArt.view"], aSong.coverArtId];
				}
				else
				{
					imgUrlString = [NSString stringWithFormat:@"%@%@&size=60", [appDelegate getBaseUrl:@"getCoverArt.view"], aSong.coverArtId];
				}
				[cell.coverArtView loadImageFromURLString:imgUrlString coverArtId:aSong.coverArtId];
			}
		}
		else
		{
			cell.coverArtView.image = [UIImage imageNamed:@"default-album-art-small.png"];
		}
		
		cell.numberLabel.text = [NSString stringWithFormat:@"%i", (indexPath.row + 1)];
		
		cell.songNameLabel.text = aSong.title;
		
		if (aSong.album)
			cell.artistNameLabel.text = [NSString stringWithFormat:@"%@ - %@", aSong.artist, aSong.album];
		else
			cell.artistNameLabel.text = aSong.artist;
		
		cell.backgroundView = [[[UIView alloc] init] autorelease];
		if(indexPath.row % 2 == 0)
		{
			if ([databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ? and finished = 'YES'", [NSString md5:aSong.path]] != nil)
				cell.backgroundView.backgroundColor = [viewObjects currentLightColor];
			else
				cell.backgroundView.backgroundColor = viewObjects.lightNormal;
		}
		else
		{
			if ([databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ? and finished = 'YES'", [NSString md5:aSong.path]] != nil)
				cell.backgroundView.backgroundColor = [viewObjects currentDarkColor];
			else
				cell.backgroundView.backgroundColor = viewObjects.darkNormal;
		}
		
		return cell;
	}
	else if (segmentedControl.selectedSegmentIndex == 1)
	{
		static NSString *CellIdentifier = @"Cell";
		
		LocalPlaylistsUITableViewCell *cell = [[[LocalPlaylistsUITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
		cell.indexPath = indexPath;
		
		// Set up the cell...
		cell.deleteToggleImage.hidden = !viewObjects.isEditing;
		if ([viewObjects.multiDeleteList containsObject:[NSNumber numberWithInt:indexPath.row]])
		{
			cell.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
		}
		cell.contentView.backgroundColor = [UIColor clearColor];
		cell.playlistNameLabel.backgroundColor = [UIColor clearColor];
		cell.playlistNameLabel.text = [databaseControls.localPlaylistsDb stringForQuery:@"SELECT playlist FROM localPlaylists WHERE ROWID = ?", [NSNumber numberWithInt:(indexPath.row + 1)]];
		cell.md5 = [databaseControls.localPlaylistsDb stringForQuery:@"SELECT md5 FROM localPlaylists WHERE ROWID = ?", [NSNumber numberWithInt:(indexPath.row + 1)]];
		NSUInteger songCount = [databaseControls.localPlaylistsDb intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM playlist%@", cell.md5]];
		if (songCount == 1)
		{
			cell.playlistCountLabel.text = @"1 song";
		}
		else
		{
			cell.playlistCountLabel.text = [NSString stringWithFormat:@"%i songs", songCount];
		}
		cell.backgroundView = [[[UIView alloc] init] autorelease];
		if(indexPath.row % 2 == 0)
			cell.backgroundView.backgroundColor = viewObjects.lightNormal;
		else
			cell.backgroundView.backgroundColor = viewObjects.darkNormal;				
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		
		return cell;
	}
	else if (segmentedControl.selectedSegmentIndex == 2)
	{
		static NSString *CellIdentifier = @"Cell";
		
		PlaylistsUITableViewCell *cell = [[[PlaylistsUITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
		cell.indexPath = indexPath;
		
		// Set up the cell...
		cell.contentView.backgroundColor = [UIColor clearColor];
		cell.playlistNameLabel.backgroundColor = [UIColor clearColor];
		cell.playlistNameLabel.text = [[viewObjects.listOfPlaylists objectAtIndex:indexPath.row] objectAtIndex:1];
		cell.backgroundView = [[[UIView alloc] init] autorelease];
		if(indexPath.row % 2 == 0)
			cell.backgroundView.backgroundColor = [UIColor whiteColor];
		else
			cell.backgroundView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];			
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		
		return cell;		
	}
	
	return nil;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (viewObjects.isCellEnabled)
	{
		if (segmentedControl.selectedSegmentIndex == 0)
		{
			[musicControls playSongAtPosition:indexPath.row];
			
			musicControls.isNewSong = YES;
			
			if (IS_IPAD())
			{
				[[NSNotificationCenter defaultCenter] postNotificationName:@"showPlayer" object:nil];
			}
			else
			{
				iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
				streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
				[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
				[streamingPlayerViewController release];
			}
		}
		else if (segmentedControl.selectedSegmentIndex == 1)
		{
			//appDelegate.localPlaylist = [[NSString md5:[appDelegate.listOfLocalPlaylists objectAtIndex:indexPath.row]] retain];
			PlaylistSongsViewController *playlistSongsViewController = [[PlaylistSongsViewController alloc] initWithNibName:@"PlaylistSongsViewController" bundle:nil];
			playlistSongsViewController.md5 = [databaseControls.localPlaylistsDb stringForQuery:@"SELECT md5 FROM localPlaylists WHERE ROWID = ?", [NSNumber numberWithInt:(indexPath.row + 1)]];
			[self.navigationController pushViewController:playlistSongsViewController animated:YES];
			[playlistSongsViewController release];
		}		
		else if (segmentedControl.selectedSegmentIndex == 2)
		{
			viewObjects.subsonicPlaylist = [viewObjects.listOfPlaylists objectAtIndex:indexPath.row];
			PlaylistSongsViewController *playlistSongsViewController = [[PlaylistSongsViewController alloc] initWithNibName:@"PlaylistSongsViewController" bundle:nil];
			playlistSongsViewController.md5 = [NSString md5:[viewObjects.subsonicPlaylist objectAtIndex:0]];
			[self.navigationController pushViewController:playlistSongsViewController animated:YES];
			[playlistSongsViewController release];		
		}
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}


- (void)dealloc {
    [super dealloc];
}


@end

