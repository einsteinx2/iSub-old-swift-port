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
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "ServerListViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "PlaylistsUITableViewCell.h"
#import "CurrentPlaylistSongUITableViewCell.h"
#import "AsynchronousImageViewCached.h"
#import "LocalPlaylistsUITableViewCell.h"
#import "PlaylistSongsViewController.h"
#import "FMDatabaseAdditions.h"
#import "Song.h"
#import "StoreViewController.h"
#import "CustomUIAlertView.h"
#import "TBXML.h"
#import "SavedSettings.h"
#import "NSMutableURLRequest+SUS.h"
#import "OrderedDictionary.h"
#import "SUSServerPlaylistsDAO.h"
#import "SUSServerPlaylist.h"
#import "PlaylistSingleton.h"
#import "AudioEngine.h"
#import "FlurryAnalytics.h"
//
#import "NSString+Additions.h"
#import "NSNotificationCenter+MainThread.h"

@interface PlaylistsViewController (Private)

- (void)addNoPlaylistsScreen;

@end


@implementation PlaylistsViewController

@synthesize request;
@synthesize serverPlaylistsDataModel, currentPlaylistDataModel;

#pragma mark - Rotation

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if ([SavedSettings sharedInstance].isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	if (!IS_IPAD() && isNoPlaylistsScreenShowing)
	{
		if (UIInterfaceOrientationIsPortrait(fromInterfaceOrientation))
		{
			noPlaylistsScreen.transform = CGAffineTransformTranslate(noPlaylistsScreen.transform, 0.0, 23.0);
		}
		else
		{
			noPlaylistsScreen.transform = CGAffineTransformTranslate(noPlaylistsScreen.transform, 0.0, -110.0);
		}
	}
}

#pragma mark - Lifecycle

- (void)viewDidLoad 
{
    [super viewDidLoad];
		
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicSingleton sharedInstance];
	databaseControls = [DatabaseSingleton sharedInstance];
	
	self.serverPlaylistsDataModel = [[[SUSServerPlaylistsDAO alloc] initWithDelegate:self] autorelease];
	self.currentPlaylistDataModel = [PlaylistSingleton sharedInstance];
	
	isNoPlaylistsScreenShowing = NO;
	isPlaylistSaveEditShowing = NO;
	savePlaylistLocal = NO;
	
	receivedData = nil;
	
	viewObjects.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
	goToNextSong = NO;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCurrentPlaylistCount) name:@"updateCurrentPlaylistCount" object:nil];

    self.title = @"Playlists";
	
	if (viewObjects.isOfflineMode)
		self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];
	
	// Setup segmented control in the header view
	headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)] autorelease];
	headerView.backgroundColor = [UIColor colorWithWhite:.3 alpha:1];
	
	if (viewObjects.isOfflineMode)
		segmentedControl = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Current", @"Offline Playlists", nil]];
	else
		segmentedControl = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Current", @"Local", @"Server", nil]];
	
	segmentedControl.frame = CGRectMake(5, 5, 310, 36);
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
	
	connectionQueue = [[BBSimpleConnectionQueue alloc] init];
	connectionQueue.delegate = self;
}


- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewWillAppear:) name:ISMSNotification_StorePurchaseComplete object:nil];
	
	if(musicControls.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	if ([SavedSettings sharedInstance].isPlaylistUnlocked)
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
	
	[FlurryAnalytics logEvent:@"PlaylistsTab"];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"updateCurrentPlaylistCount" object:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_StorePurchaseComplete object:nil];
	
	if (viewObjects.isEditing)
	{
		// Clear the edit stuff if they switch tabs in the middle of editing
		viewObjects.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
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

#pragma mark - Button Handling

- (void) settingsAction:(id)sender 
{
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverListViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverListViewController animated:YES];
	[serverListViewController release];
}


- (IBAction)nowPlayingAction:(id)sender
{
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
	[streamingPlayerViewController release];
}

#pragma mark -


- (void)updateCurrentPlaylistCount
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
			currentPlaylistCount = [databaseControls.currentPlaylistDb synchronizedIntForQuery:@"SELECT COUNT(*) FROM jukeboxCurrentPlaylist"];
		else
			currentPlaylistCount = [databaseControls.currentPlaylistDb synchronizedIntForQuery:@"SELECT COUNT(*) FROM currentPlaylist"];
			
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
		headerView.frame = CGRectMake(0, 0, 320, 95);
		
		int y = 45;
		
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
			if ([databaseControls.localPlaylistsDb synchronizedIntForQuery:@"SELECT COUNT(*) FROM localPlaylists"] == 1)
				savePlaylistLabel.text = [NSString stringWithFormat:@"1 playlist"];
			else 
				savePlaylistLabel.text = [NSString stringWithFormat:@"%i playlists", [databaseControls.localPlaylistsDb synchronizedIntForQuery:@"SELECT COUNT(*) FROM localPlaylists"]];
		}
		else if (segmentedControl.selectedSegmentIndex == 2)
		{
			savePlaylistLabel.frame = CGRectMake(0, y, 227, 50);
			if ([serverPlaylistsDataModel.serverPlaylists count] == 1)
				savePlaylistLabel.text = [NSString stringWithFormat:@"1 playlist"];
			else 
				savePlaylistLabel.text = [NSString stringWithFormat:@"%i playlists", [serverPlaylistsDataModel.serverPlaylists count]];
			
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
			if ([databaseControls.localPlaylistsDb synchronizedIntForQuery:@"SELECT COUNT(*) FROM localPlaylists"] == 1)
				playlistCountLabel.text = [NSString stringWithFormat:@"1 playlist"];
			else 
				playlistCountLabel.text = [NSString stringWithFormat:@"%i playlists", [databaseControls.localPlaylistsDb synchronizedIntForQuery:@"SELECT COUNT(*) FROM localPlaylists"]];
		}
		else if (segmentedControl.selectedSegmentIndex == 2)
		{
			if ([serverPlaylistsDataModel.serverPlaylists count] == 1)
				playlistCountLabel.text = [NSString stringWithFormat:@"1 playlist"];
			else 
				playlistCountLabel.text = [NSString stringWithFormat:@"%i playlists", [serverPlaylistsDataModel.serverPlaylists count]];
			
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
	if ([SavedSettings sharedInstance].isPlaylistUnlocked)
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
	if ([SavedSettings sharedInstance].isPlaylistUnlocked)
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
	
	if (![SavedSettings sharedInstance].isPlaylistUnlocked)
	{
		UIButton *storeLauncher = [UIButton buttonWithType:UIButtonTypeCustom];
		storeLauncher.frame = CGRectMake(0, 0, noPlaylistsScreen.frame.size.width, noPlaylistsScreen.frame.size.height);
		[storeLauncher addTarget:self action:@selector(showStore) forControlEvents:UIControlEventTouchUpInside];
		[noPlaylistsScreen addSubview:storeLauncher];
	}
	
	[self.view addSubview:noPlaylistsScreen];
	
	[noPlaylistsScreen release];
	
	if (!IS_IPAD())
	{
		if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
		{
			//noPlaylistsScreen.transform = CGAffineTransformScale(noPlaylistsScreen.transform, 0.75, 0.75);
			noPlaylistsScreen.transform = CGAffineTransformTranslate(noPlaylistsScreen.transform, 0.0, 23.0);
		}
	}
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
		viewObjects.isLocalPlaylist = YES;
		
		// Get the current playlist count
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
			currentPlaylistCount = [databaseControls.currentPlaylistDb synchronizedIntForQuery:@"SELECT COUNT(*) FROM jukeboxCurrentPlaylist"];
		else
			currentPlaylistCount = [databaseControls.currentPlaylistDb synchronizedIntForQuery:@"SELECT COUNT(*) FROM currentPlaylist"];
		
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
		[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
		
		if (currentPlaylistDataModel.currentIndex >= 0 && currentPlaylistDataModel.currentIndex < currentPlaylistCount)
		{
			[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:currentPlaylistDataModel.currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
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
		
		if ([databaseControls.localPlaylistsDb synchronizedIntForQuery:@"SELECT COUNT(*) FROM localPlaylists"] > 0)
		{
			// Modify the header view to include the save and edit buttons
			[self addSaveEditButtons];
		}
		
		// Reload the table data
		[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
		
		// Remove the no playlists overlay screen if it's showing
		[self removeNoPlaylistsScreen];
		
		// If the list is empty, display the no playlists overlay screen
		if ([databaseControls.localPlaylistsDb synchronizedIntForQuery:@"SELECT COUNT(*) FROM localPlaylists"] == 0)
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
		[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
		
		// Remove the no playlists overlay screen if it's showing
		[self removeNoPlaylistsScreen];
		
		//[viewObjects showLoadingScreen:self.view blockInput:YES mainWindow:NO];
		[viewObjects showLoadingScreenOnMainWindow];
        
        [serverPlaylistsDataModel startLoad];
	}
}


- (void) editPlaylistAction:(id)sender
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		if (self.tableView.editing == NO)
		{
			viewObjects.isEditing = YES;
			[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
			[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(showDeleteButton) name:@"showDeleteButton" object: nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(hideDeleteButton) name:@"hideDeleteButton" object: nil];
			viewObjects.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
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
			[self hideDeleteButton];
			[self.tableView setEditing:NO animated:YES];
			editPlaylistLabel.backgroundColor = [UIColor clearColor];
			editPlaylistLabel.text = @"Edit";
			
			if (goToNextSong)
			{
				goToNextSong = NO;
				currentPlaylistCount = [databaseControls.currentPlaylistDb synchronizedIntForQuery:@"SELECT COUNT(*) FROM currentPlaylist"];
				if (currentPlaylistCount > 0)
				{
					[musicControls nextSong];
				}
				else
				{
                    [[AudioEngine sharedInstance] stop];
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
			
			// Reload the table to correct the numbers
			[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
			if (currentPlaylistDataModel.currentIndex >= 0 && currentPlaylistDataModel.currentIndex < currentPlaylistCount)
			{
				[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:currentPlaylistDataModel.currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
			}
		}
	}
	else if (segmentedControl.selectedSegmentIndex == 1 ||
			 segmentedControl.selectedSegmentIndex == 2)
	{
		if (self.tableView.editing == NO)
		{
			viewObjects.isEditing = YES;
			[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
			[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(showDeleteButton) name:@"showDeleteButton" object: nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(hideDeleteButton) name:@"hideDeleteButton" object: nil];
			viewObjects.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
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
			[self hideDeleteButton];
			[self.tableView setEditing:NO animated:YES];
			editPlaylistLabel.backgroundColor = [UIColor clearColor];
			editPlaylistLabel.text = @"Edit";
			
			// Reload the table to correct the numbers
			[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
		}
	}
}


- (void)showDeleteButton
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		if ([viewObjects.multiDeleteList count] == 0)
		{
			deleteSongsLabel.text = @"Select All";
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
	else if (segmentedControl.selectedSegmentIndex == 1 ||
			 segmentedControl.selectedSegmentIndex == 2)
	{
		if ([viewObjects.multiDeleteList count] == 0)
		{
			deleteSongsLabel.text = @"Select All";
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
	else if (segmentedControl.selectedSegmentIndex == 1 ||
			 segmentedControl.selectedSegmentIndex == 2)
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

- (void)uploadPlaylist:(NSString*)name
{	
	PlaylistSingleton *currentPlaylist = [PlaylistSingleton sharedInstance];
	
	NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(name), @"name", nil];
	
	NSMutableArray *songIds = [NSMutableArray arrayWithCapacity:currentPlaylistCount];
	for (int i = 0; i < currentPlaylistCount; i++)
	{
		@autoreleasepool 
		{
			Song *aSong = nil;
			if ([SavedSettings sharedInstance].isJukeboxEnabled)
			{
				aSong = [Song songFromDbRow:i inTable:@"jukeboxCurrentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
			}
			else
			{
				if (currentPlaylist.isShuffle)
					aSong = [Song songFromDbRow:i inTable:@"shufflePlaylist" inDatabase:databaseControls.currentPlaylistDb];
				else
					aSong = [Song songFromDbRow:i inTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
			}
			
			[songIds addObject:n2N(aSong.songId)];
		}
	}
	[parameters setObject:[NSArray arrayWithArray:songIds] forKey:@"songId"];

	self.request = [NSMutableURLRequest requestWithSUSAction:@"createPlaylist" andParameters:parameters];
	
	connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
		receivedData = [[NSMutableData data] retain];
		
		self.tableView.scrollEnabled = NO;
		[viewObjects showAlbumLoadingScreen:self.view sender:self];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error saving the playlist to the server.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
}

- (void) deleteAction
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		[currentPlaylistDataModel deleteSongs:viewObjects.multiDeleteList];
		
		currentPlaylistCount = currentPlaylistDataModel.count;
		
		// Create indexPaths from multiDeleteList and delete the rows in the table view
		NSMutableArray *indexes = [[NSMutableArray alloc] init];
		for (NSNumber *index in viewObjects.multiDeleteList)
		{
			@autoreleasepool 
			{
				[indexes addObject:[NSIndexPath indexPathForRow:[index integerValue] inSection:0]];
			}
		}
		[self.tableView performSelectorOnMainThread:@selector(deleteRowsAtIndexPaths:withRowAnimation:) withObject:indexes waitUntilDone:YES];
		[indexes release];
		
		[self performSelectorOnMainThread:@selector(editPlaylistAction:) withObject:nil waitUntilDone:YES];
		[self performSelectorOnMainThread:@selector(segmentAction:) withObject:nil waitUntilDone:YES];
	}
	else if (segmentedControl.selectedSegmentIndex == 1)
	{
		// Sort the multiDeleteList to make sure it's accending
		[viewObjects.multiDeleteList sortUsingSelector:@selector(compare:)];
		
		[databaseControls.localPlaylistsDb synchronizedExecuteUpdate:@"DROP TABLE localPlaylistsTemp"];
		[databaseControls.localPlaylistsDb synchronizedExecuteUpdate:@"CREATE TABLE localPlaylistsTemp(playlist TEXT, md5 TEXT)"];
		for (NSNumber *index in [viewObjects.multiDeleteList reverseObjectEnumerator])
		{
			NSInteger rowId = [index integerValue] + 1;
			NSString *md5 = [databaseControls.localPlaylistsDb stringForQuery:[NSString stringWithFormat:@"SELECT md5 FROM localPlaylists WHERE ROWID = %i", rowId]];
			[databaseControls.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"DROP TABLE playlist%@", md5]];
			[databaseControls.localPlaylistsDb synchronizedExecuteUpdate:@"DELETE FROM localPlaylists WHERE md5 = ?", md5];
		}
		[databaseControls.localPlaylistsDb synchronizedExecuteUpdate:@"INSERT INTO localPlaylistsTemp SELECT * FROM localPlaylists"];
		[databaseControls.localPlaylistsDb synchronizedExecuteUpdate:@"DROP TABLE localPlaylists"];
		[databaseControls.localPlaylistsDb synchronizedExecuteUpdate:@"ALTER TABLE localPlaylistsTemp RENAME TO localPlaylists"];
		
		// Create indexPaths from multiDeleteList and delete the rows from the tableView
		NSMutableArray *indexes = [[NSMutableArray alloc] init];
		for (NSNumber *index in viewObjects.multiDeleteList)
		{
			[indexes addObject:[NSIndexPath indexPathForRow:[index integerValue] inSection:0]];
		}
		[self.tableView performSelectorOnMainThread:@selector(deleteRowsAtIndexPaths:withRowAnimation:) withObject:indexes waitUntilDone:YES];
		
		[indexes release];
		
		[self performSelectorOnMainThread:@selector(editPlaylistAction:) withObject:nil waitUntilDone:YES];
		[self performSelectorOnMainThread:@selector(segmentAction:) withObject:nil waitUntilDone:YES];
	}
	
	[viewObjects performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:NO];
	
	[pool release];
}

- (void)savePlaylistAction:(id)sender
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		if (deleteSongsLabel.hidden == YES)
		{
			if (viewObjects.isEditing == NO)
			{
				savePlaylistLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
				playlistCountLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
				
				UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Local or Server?" 
																	  message:@"Would you like to save this playlist to your device or to your Subsonic server?" 
																	 delegate:self 
															cancelButtonTitle:nil
															otherButtonTitles:@"Local", @"Server", nil];
				[myAlertView show];
				[myAlertView release];
			}
		}
		else 
		{
			if ([viewObjects.multiDeleteList count] == 0)
			{
				// Select all the rows
				for (int i = 0; i < currentPlaylistCount; i++)
				{
					[viewObjects.multiDeleteList addObject:[NSNumber numberWithInt:i]];
				}
				[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
				[self showDeleteButton];
			}
			else
			{
				// Delete action
				[viewObjects showLoadingScreenOnMainWindow];
				[self performSelectorInBackground:@selector(deleteAction) withObject:nil];
			}
		}
	}
	else if (segmentedControl.selectedSegmentIndex == 1)
	{
		if (deleteSongsLabel.hidden == NO)
		{
			if ([viewObjects.multiDeleteList count] == 0)
			{
				// Select all the rows
				NSUInteger count = [databaseControls.localPlaylistsDb synchronizedIntForQuery:@"SELECT COUNT(*) FROM localPlaylists"];
				for (int i = 0; i < count; i++)
				{
					[viewObjects.multiDeleteList addObject:[NSNumber numberWithInt:i]];
				}
				[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
				[self showDeleteButton];
			}
			else
			{
				// Delete action
				[viewObjects showLoadingScreenOnMainWindow];
				[self performSelectorInBackground:@selector(deleteAction) withObject:nil];
			}
		}
	}
	else if (segmentedControl.selectedSegmentIndex == 2)
	{
		if (deleteSongsLabel.hidden == NO)
		{
			if ([viewObjects.multiDeleteList count] == 0)
			{
				// Select all the rows
				NSUInteger count = [serverPlaylistsDataModel.serverPlaylists count];
				for (int i = 0; i < count; i++)
				{
					[viewObjects.multiDeleteList addObject:[NSNumber numberWithInt:i]];
				}
				[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
				[self showDeleteButton];
			}
			else
			{
				self.tableView.scrollEnabled = NO;
				[viewObjects showAlbumLoadingScreen:self.view sender:self];
				
				for (NSNumber *index in viewObjects.multiDeleteList)
				{
                    NSString *playlistId = [[serverPlaylistsDataModel.serverPlaylists objectAtIndex:[index intValue]] playlistId];
                    NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(playlistId) forKey:@"id"];
                    DLog(@"parameters: %@", parameters);
                    NSMutableURLRequest *aRequest = [NSMutableURLRequest requestWithSUSAction:@"deletePlaylist" andParameters:parameters];
                    
					connection = [[NSURLConnection alloc] initWithRequest:aRequest delegate:self startImmediately:NO];
					if (connection)
					{
						[connectionQueue registerConnection:connection];
						[connectionQueue startQueue];
					} 
					else 
					{
						DLog(@"There was an error deleting a server playlist, could not create network request");
					}
				}
			}
		}
	}
}

- (void)connectionQueueDidFinish:(id)connectionQueue
{
	[viewObjects hideLoadingScreen];
	self.tableView.scrollEnabled = YES;
	[self editPlaylistAction:nil];
	[self segmentAction:nil];
}

- (void)cancelLoad
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		[connection cancel];
	}
	else
	{
		[connectionQueue clearQueue];
		
		[self connectionQueueDidFinish:connectionQueue];
	}
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	PlaylistSingleton *currentPlaylist = [PlaylistSingleton sharedInstance];
	
	if ([alertView.title isEqualToString:@"Local or Server?"])
	{
		if (buttonIndex == 0)
		{
			savePlaylistLocal = YES;
		}
		else if (buttonIndex == 1)
		{
			savePlaylistLocal = NO;
		}
		else if (buttonIndex == 2)
		{
			return;
		}
		
		UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Playlist Name:" message:@"      \n      " delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
		myAlertView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
		playlistNameTextField = [[UITextField alloc] initWithFrame:CGRectMake(12.0, 47.0, 260.0, 22.0)];
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
    else if([alertView.title isEqualToString:@"Playlist Name:"])
	{
		[playlistNameTextField resignFirstResponder];
		if(buttonIndex == 1)
		{
			if (savePlaylistLocal)
			{
				// Check if the playlist exists, if not create the playlist table and add the entry to localPlaylists table
				if ([databaseControls.localPlaylistsDb synchronizedIntForQuery:@"SELECT COUNT(*) FROM localPlaylists WHERE md5 = ?", [playlistNameTextField.text md5]] == 0)
				{
					[databaseControls.localPlaylistsDb synchronizedExecuteUpdate:@"INSERT INTO localPlaylists (playlist, md5) VALUES (?, ?)", playlistNameTextField.text, [playlistNameTextField.text md5]];
					[databaseControls.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (%@)", [playlistNameTextField.text md5], [Song standardSongColumnSchema]]];
					
					[databaseControls.localPlaylistsDb synchronizedExecuteUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseControls.databaseFolderPath, [[SavedSettings sharedInstance].urlString md5]], @"currentPlaylistDb"];
					if ([databaseControls.localPlaylistsDb hadError]) { DLog(@"Err attaching the currentPlaylistDb %d: %@", [databaseControls.localPlaylistsDb lastErrorCode], [databaseControls.localPlaylistsDb lastErrorMessage]); }
					if (currentPlaylist.isShuffle) {
						[databaseControls.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM shufflePlaylist", [playlistNameTextField.text md5]]];
					}
					else {
						[databaseControls.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM currentPlaylist", [playlistNameTextField.text md5]]];
					}
					[databaseControls.localPlaylistsDb synchronizedExecuteUpdate:@"DETACH DATABASE currentPlaylistDb"];
				}
				else
				{
					// If it exists, ask to overwrite
					UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Overwrite?" message:@"There is already a playlist with this name. Would you like to overwrite it?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
					[myAlertView show];
					[myAlertView release];
				}
			}
			else
			{
				[self uploadPlaylist:playlistNameTextField.text];
			}
		}
	}
	else if([alertView.title isEqualToString:@"Overwrite?"])
	{
		if(buttonIndex == 1)
		{
			// If yes, overwrite the playlist
			[databaseControls.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"DROP TABLE playlist%@", [playlistNameTextField.text md5]]];
			[databaseControls.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (%@)", [playlistNameTextField.text md5], [Song standardSongColumnSchema]]];
			
			[databaseControls.localPlaylistsDb synchronizedExecuteUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseControls.databaseFolderPath, [[SavedSettings sharedInstance].urlString md5]], @"currentPlaylistDb"];
			if ([databaseControls.localPlaylistsDb hadError]) { DLog(@"Err attaching the currentPlaylistDb %d: %@", [databaseControls.localPlaylistsDb lastErrorCode], [databaseControls.localPlaylistsDb lastErrorMessage]); }
			if (currentPlaylist.isShuffle) {
				[databaseControls.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM shufflePlaylist", [playlistNameTextField.text md5]]];
			}
			else {
				[databaseControls.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM currentPlaylist", [playlistNameTextField.text md5]]];
			}
			[databaseControls.localPlaylistsDb synchronizedExecuteUpdate:@"DETACH DATABASE currentPlaylistDb"];
		}
	}
	
	savePlaylistLabel.backgroundColor = [UIColor clearColor];
	playlistCountLabel.backgroundColor = [UIColor clearColor];
}

- (void)selectRow
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
		if (currentPlaylistDataModel.currentIndex >= 0 && currentPlaylistDataModel.currentIndex < currentPlaylistCount)
		{
			[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:currentPlaylistDataModel.currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
		}
	}
}

#pragma mark - SUSLoader Delegate

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error
{
    [viewObjects hideLoadingScreen];
}

- (void)loadingFinished:(SUSLoader *)theLoader
{    
    [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
    
    // If the list is empty, display the no playlists overlay screen
    if ([serverPlaylistsDataModel.serverPlaylists count] == 0 && isNoPlaylistsScreenShowing == NO)
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
    else
    {
        // Modify the header view to include the save and edit buttons
        [self addSaveEditButtons];
    }
    
    // Hide the loading screen
    [viewObjects hideLoadingScreen];
}

#pragma mark - Connection Delegate

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
	if (segmentedControl.selectedSegmentIndex == 0)
		[receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
	if (segmentedControl.selectedSegmentIndex == 0)
		[receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	NSString *message = @"";
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		message = [NSString stringWithFormat:@"There was an error saving the playlist to the server.\n\nError %i: %@", 
				   [error code], 
				   [error localizedDescription]];
	}
	else
	{
		message = [NSString stringWithFormat:@"There was an error loading the playlists.\n\nError %i: %@", 
				   [error code], 
				   [error localizedDescription]];
	}
	
	// Inform the user that the connection failed.
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
	[alert release];
	
	self.tableView.scrollEnabled = YES;
	[viewObjects hideLoadingScreen];
	
	[theConnection release];
	
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		[receivedData release];
	}
	else
	{
		[connectionQueue connectionFinished:theConnection];
	}
}	

- (NSURLRequest *)connection: (NSURLConnection *)inConnection willSendRequest:(NSURLRequest *)inRequest redirectResponse:(NSURLResponse *)inRedirectResponse;
{
    if (inRedirectResponse) 
	{
        NSMutableURLRequest *newRequest = [[request mutableCopy] autorelease];
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
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		[self performSelectorInBackground:@selector(parseData) withObject:nil];
	}
	else
	{
		[connectionQueue connectionFinished:theConnection];
	}
	
	self.tableView.scrollEnabled = YES;
	[theConnection release];
}

static NSString *kName_Error = @"error";

- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil];
	alert.tag = 1;
	[alert show];
	[alert release];
}

- (void)parseData
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Parse the data
	//
	TBXML *tbxml = [[TBXML alloc] initWithXMLData:receivedData];
    TBXMLElement *root = tbxml.rootXMLElement;
    if (root) 
	{
		TBXMLElement *error = [TBXML childElementNamed:kName_Error parentElement:root];
		if (error)
		{
			NSString *code = [TBXML valueOfAttributeNamed:@"code" forElement:error];
			NSString *message = [TBXML valueOfAttributeNamed:@"message" forElement:error];
			[self subsonicErrorCode:code message:message];
		}
	}
    [tbxml release];
	
	[receivedData release];
	
	[viewObjects performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:NO];
	
	[pool release];
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
		return [databaseControls.localPlaylistsDb synchronizedIntForQuery:@"SELECT COUNT(*) FROM localPlaylists"];
	else if (segmentedControl.selectedSegmentIndex == 2)
		return [serverPlaylistsDataModel.serverPlaylists count];
	
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
	PlaylistSingleton *currentPlaylist = [PlaylistSingleton sharedInstance];
	
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		NSInteger fromRow = fromIndexPath.row + 1;
		NSInteger toRow = toIndexPath.row + 1;
		
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
		{
			[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"DROP TABLE jukeboxTemp"];
			NSString *query = [NSString stringWithFormat:@"CREATE TABLE jukeboxTemp (%@)", [Song standardSongColumnSchema]];
			[databaseControls.currentPlaylistDb executeUpdate:query];
			
			if (fromRow < toRow)
			{
				[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID < ?", [NSNumber numberWithInt:fromRow]];
				[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID > ? AND ROWID <= ?", [NSNumber numberWithInt:fromRow], [NSNumber numberWithInt:toRow]];
				[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
				[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID > ?", [NSNumber numberWithInt:toRow]];
				
				[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
				[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"ALTER TABLE jukeboxTemp RENAME TO jukeboxCurrentPlaylist"];
			}
			else
			{
				[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID < ?", [NSNumber numberWithInt:toRow]];
				[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
				[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID >= ? AND ROWID < ?", [NSNumber numberWithInt:toRow], [NSNumber numberWithInt:fromRow]];
				[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID > ?", [NSNumber numberWithInt:fromRow]];
				
				[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
				[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"ALTER TABLE jukeboxTemp RENAME TO jukeboxCurrentPlaylist"];
			}
		}
		else
		{
			if (currentPlaylist.isShuffle)
			{
				[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"DROP TABLE shuffleTemp"];
				NSString *query = [NSString stringWithFormat:@"CREATE TABLE shuffleTemp (%@)", [Song standardSongColumnSchema]];
				[databaseControls.currentPlaylistDb executeUpdate:query];
				
				if (fromRow < toRow)
				{
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID < ?", [NSNumber numberWithInt:fromRow]];
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID > ? AND ROWID <= ?", [NSNumber numberWithInt:fromRow], [NSNumber numberWithInt:toRow]];
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID > ?", [NSNumber numberWithInt:toRow]];
					
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"DROP TABLE shufflePlaylist"];
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"ALTER TABLE shuffleTemp RENAME TO shufflePlaylist"];
				}
				else
				{
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID < ?", [NSNumber numberWithInt:toRow]];
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID >= ? AND ROWID < ?", [NSNumber numberWithInt:toRow], [NSNumber numberWithInt:fromRow]];
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID > ?", [NSNumber numberWithInt:fromRow]];
					
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"DROP TABLE shufflePlaylist"];
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"ALTER TABLE shuffleTemp RENAME TO shufflePlaylist"];
				}
			}
			else
			{
				[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"DROP TABLE currentTemp"];
				NSString *query = [NSString stringWithFormat:@"CREATE TABLE currentTemp (%@)", [Song standardSongColumnSchema]];
				[databaseControls.currentPlaylistDb executeUpdate:query];
				
				if (fromRow < toRow)
				{
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID < ?", [NSNumber numberWithInt:fromRow]];
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID > ? AND ROWID <= ?", [NSNumber numberWithInt:fromRow], [NSNumber numberWithInt:toRow]];
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID > ?", [NSNumber numberWithInt:toRow]];
					
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"DROP TABLE currentPlaylist"];
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"ALTER TABLE currentTemp RENAME TO currentPlaylist"];
				}
				else
				{
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID < ?", [NSNumber numberWithInt:toRow]];
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID >= ? AND ROWID < ?", [NSNumber numberWithInt:toRow], [NSNumber numberWithInt:fromRow]];
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID > ?", [NSNumber numberWithInt:fromRow]];
					
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"DROP TABLE currentPlaylist"];
					[databaseControls.currentPlaylistDb synchronizedExecuteUpdate:@"ALTER TABLE currentTemp RENAME TO currentPlaylist"];
				}
			}
		}
		
		// Fix the multiDeleteList to reflect the new row positions
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
		
		// Correct the value of currentPlaylistPosition
		if (fromIndexPath.row == currentPlaylistDataModel.currentIndex)
		{
			currentPlaylistDataModel.currentIndex = toIndexPath.row;
		}
		else 
		{
			if (fromIndexPath.row < currentPlaylistDataModel.currentIndex && toIndexPath.row >= currentPlaylistDataModel.currentIndex)
			{
				currentPlaylistDataModel.currentIndex = currentPlaylistDataModel.currentIndex - 1;
			}
			else if (fromIndexPath.row > currentPlaylistDataModel.currentIndex && toIndexPath.row <= currentPlaylistDataModel.currentIndex)
			{
				currentPlaylistDataModel.currentIndex = currentPlaylistDataModel.currentIndex + 1;
			}
		}
		
		// Highlight the current playing song
		if (currentPlaylistDataModel.currentIndex >= 0 && currentPlaylistDataModel.currentIndex < currentPlaylistCount)
		{
			[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:currentPlaylistDataModel.currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
		}
		
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
		{
			[musicControls jukeboxReplacePlaylistWithLocal];
		}
		
		if (![SavedSettings sharedInstance].isJukeboxEnabled)
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistOrderChanged];
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

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	PlaylistSingleton *currentPlaylist = [PlaylistSingleton sharedInstance];
	
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
		
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
		{
			aSong = [Song songFromDbRow:indexPath.row inTable:@"jukeboxCurrentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
		}
		else
		{
			if (currentPlaylist.isShuffle)
				aSong = [Song songFromDbRow:indexPath.row inTable:@"shufflePlaylist" inDatabase:databaseControls.currentPlaylistDb];
			else
				aSong = [Song songFromDbRow:indexPath.row inTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
		}
		
		[cell.coverArtView loadImageFromCoverArtId:aSong.coverArtId];
		
		cell.numberLabel.text = [NSString stringWithFormat:@"%i", (indexPath.row + 1)];
		
		cell.songNameLabel.text = aSong.title;
		
		if (aSong.album)
			cell.artistNameLabel.text = [NSString stringWithFormat:@"%@ - %@", aSong.artist, aSong.album];
		else
			cell.artistNameLabel.text = aSong.artist;
		
		cell.backgroundView = [[[UIView alloc] init] autorelease];
		if(indexPath.row % 2 == 0)
		{
			if ([databaseControls.songCacheDb synchronizedStringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ? and finished = 'YES'", [aSong.path md5]] != nil)
				cell.backgroundView.backgroundColor = [viewObjects currentLightColor];
			else
				cell.backgroundView.backgroundColor = viewObjects.lightNormal;
		}
		else
		{
			if ([databaseControls.songCacheDb synchronizedStringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ? and finished = 'YES'", [aSong.path md5]] != nil)
				cell.backgroundView.backgroundColor = [viewObjects currentDarkColor];
			else
				cell.backgroundView.backgroundColor = viewObjects.darkNormal;
		}
		
		return cell;
	}
	else if (segmentedControl.selectedSegmentIndex == 1)
	{
		static NSString *CellIdentifier = @"Cell";
		
		LocalPlaylistsUITableViewCell *cell = [[[LocalPlaylistsUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		cell.indexPath = indexPath;
		
		// Set up the cell...
		cell.deleteToggleImage.hidden = !viewObjects.isEditing;
		if ([viewObjects.multiDeleteList containsObject:[NSNumber numberWithInt:indexPath.row]])
		{
			cell.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
		}
		cell.contentView.backgroundColor = [UIColor clearColor];
		cell.playlistNameLabel.backgroundColor = [UIColor clearColor];
		cell.playlistNameLabel.text = [[databaseControls.localPlaylistsDb synchronizedStringForQuery:@"SELECT playlist FROM localPlaylists WHERE ROWID = ?", [NSNumber numberWithInt:(indexPath.row + 1)]] gtm_stringByUnescapingFromHTML];
		cell.md5 = [databaseControls.localPlaylistsDb synchronizedStringForQuery:@"SELECT md5 FROM localPlaylists WHERE ROWID = ?", [NSNumber numberWithInt:(indexPath.row + 1)]];
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
		
		PlaylistsUITableViewCell *cell = [[[PlaylistsUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		cell.indexPath = indexPath;
        cell.serverPlaylist = [serverPlaylistsDataModel.serverPlaylists objectAtIndex:indexPath.row];
		
		cell.deleteToggleImage.hidden = !viewObjects.isEditing;
		if ([viewObjects.multiDeleteList containsObject:[NSNumber numberWithInt:indexPath.row]])
		{
			cell.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
		}
		
		cell.contentView.backgroundColor = [UIColor clearColor];
		cell.playlistNameLabel.backgroundColor = [UIColor clearColor];
        SUSServerPlaylist *playlist = [serverPlaylistsDataModel.serverPlaylists objectAtIndex:indexPath.row];        
        cell.playlistNameLabel.text = playlist.playlistName;
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
			PlaylistSongsViewController *playlistSongsViewController = [[PlaylistSongsViewController alloc] initWithNibName:@"PlaylistSongsViewController" bundle:nil];
			playlistSongsViewController.md5 = [databaseControls.localPlaylistsDb synchronizedStringForQuery:@"SELECT md5 FROM localPlaylists WHERE ROWID = ?", [NSNumber numberWithInt:(indexPath.row + 1)]];
			[self.navigationController pushViewController:playlistSongsViewController animated:YES];
			[playlistSongsViewController release];
		}		
		else if (segmentedControl.selectedSegmentIndex == 2)
		{
			PlaylistSongsViewController *playlistSongsViewController = [[PlaylistSongsViewController alloc] initWithNibName:@"PlaylistSongsViewController" bundle:nil];
            SUSServerPlaylist *playlist = [serverPlaylistsDataModel.serverPlaylists objectAtIndex:indexPath.row];
			playlistSongsViewController.md5 = [[playlist.playlistName gtm_stringByUnescapingFromHTML] md5];
            playlistSongsViewController.serverPlaylist = playlist;
			[self.navigationController pushViewController:playlistSongsViewController animated:YES];
			[playlistSongsViewController release];		
		}
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}


- (void)dealloc 
{
	[currentPlaylistDataModel release]; currentPlaylistDataModel = nil;
	serverPlaylistsDataModel.delegate = nil;
	[serverPlaylistsDataModel release]; serverPlaylistsDataModel = nil;
	[connectionQueue release]; connectionQueue = nil;
    [super dealloc];
}


@end

