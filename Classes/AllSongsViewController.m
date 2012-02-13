//
//  AllSongsViewController.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright Ben Baron 2010. All rights reserved.
//


#import "AllSongsViewController.h"
#import "SearchOverlayViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "AllSongsUITableViewCell.h"
#import "AsynchronousImageViewCached.h"
#import "Index.h"
#import "Album.h"
#import "Song.h"
#import "FMDatabaseAdditions.h"
#import "NSString+md5.h"
#import "LoadingScreen.h"
#import "RootViewController.h"
#import "TBXML.h"
#import "CustomUITableView.h"
#import "CustomUIAlertView.h"
#import "GTMNSString+HTML.h"
#import "SavedSettings.h"
#import "SUSAllSongsDAO.h"
#import "SUSAllSongsLoader.h"
#import "FlurryAnalytics.h"
#import "EGORefreshTableHeaderView.h"
#import "PlaylistSingleton.h"

@interface AllSongsViewController (Private)
- (void)hideLoadingScreen;
@end

@implementation AllSongsViewController

@synthesize headerView, sectionInfo, dataModel, loadingScreen;

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	
	if ([SavedSettings sharedInstance].isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

#pragma mark - View Controller Lifecycle

- (void)createDataModel
{
	dataModel.delegate = nil;
	self.dataModel = [[[SUSAllSongsDAO alloc] init] autorelease];
	dataModel.delegate = self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicSingleton sharedInstance];
	databaseControls = [DatabaseSingleton sharedInstance];
	settings = [SavedSettings sharedInstance];
	
	self.title = @"Songs";
	//self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];

	// Set defaults
	isSearching = NO;
	letUserSelectRow = YES;	
	isProcessingArtists = YES;
	
	[self createDataModel];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createDataModel) name:ISMSNotification_ServerSwitched object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(doneSearching_Clicked:) name:@"endSearch" object:searchOverlayView];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadingFinishedNotification) name:ISMSNotification_AllSongsLoadingFinished object:nil];

	// Add the table fade
	/*UIImageView *fadeTop = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-top.png"]];
	fadeTop.frame =CGRectMake(0, -10, self.tableView.bounds.size.width, 10);
	fadeTop.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.tableView addSubview:fadeTop];
	[fadeTop release];*/
	
	// Add the pull to refresh view
	refreshHeaderView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, 320.0f, self.tableView.bounds.size.height)];
	refreshHeaderView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:237.0/255.0 alpha:1.0];
	[self.tableView addSubview:refreshHeaderView];
	[refreshHeaderView release];
	
	UIImageView *fadeBottom = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]] autorelease];
	fadeBottom.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
	fadeBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.tableView.tableFooterView = fadeBottom;
}

- (void)viewWillAppear:(BOOL)animated 
{
	[super viewWillAppear:animated];
	
	// Don't run this while the table is updating
	if ([SUSAllSongsLoader isLoading])
	{
		[self showLoadingScreen];
	}
	else
	{
		if(musicControls.showPlayerIcon)
		{
			self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
		}
		else
		{
			self.navigationItem.rightBarButtonItem = nil;
		}
		
		// Check if the data has been loaded
		if (dataModel.isDataLoaded)
		{
			[self addCount];
		}
		else
		{
			self.tableView.tableHeaderView = nil;
			if ([[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@isAllSongsLoading", settings.urlString]] isEqualToString:@"YES"])
			{
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Resume Load?" message:@"If you've reloaded the albums tab since this load started you should choose 'Restart Load'.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Restart Load", @"Resume Load", nil];
				alert.tag = 1;
				[alert show];
				[alert release];
			}
			else
			{
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Load?" message:@"This could take a while if you have a big collection.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.\n\nNote: If you've added new artists, you should reload the Folders first." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
				alert.tag = 1;
				[alert show];
				[alert release];
			}
		}
	}
	
	[self.tableView reloadData];
	
	[FlurryAnalytics logEvent:@"AllSongsTab"];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	[self hideLoadingScreen];
}

- (void)addCount
{
	// Build the search and reload view
	headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 90)] autorelease];
	headerView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];
	
	reloadButton = [UIButton buttonWithType:UIButtonTypeCustom];
	reloadButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	reloadButton.frame = CGRectMake(0, 0, 320, 40);
	//[reloadButton addTarget:self action:@selector(reloadAction:) forControlEvents:UIControlEventTouchUpInside];
	[headerView addSubview:reloadButton];
	
	countLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, 320, 30)];
	countLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	countLabel.backgroundColor = [UIColor clearColor];
	countLabel.textColor = [UIColor colorWithRed:156.0/255.0 green:161.0/255.0 blue:168.0/255.0 alpha:1];
	countLabel.textAlignment = UITextAlignmentCenter;
	countLabel.font = [UIFont boldSystemFontOfSize:30];
	[headerView addSubview:countLabel];
	[countLabel release];

	searchBar = [[UISearchBar  alloc] initWithFrame:CGRectMake(0, 50, 320, 40)];
	searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	searchBar.delegate = self;
	searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	searchBar.placeholder = @"Song name";
	[headerView addSubview:searchBar];
	[searchBar release];
	
	reloadTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 36, 320, 12)];
	reloadTimeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	reloadTimeLabel.backgroundColor = [UIColor clearColor];
	reloadTimeLabel.textColor = [UIColor colorWithRed:176.0/255.0 green:181.0/255.0 blue:188.0/255.0 alpha:1];
	reloadTimeLabel.textAlignment = UITextAlignmentCenter;
	reloadTimeLabel.font = [UIFont systemFontOfSize:11];
	[headerView addSubview:reloadTimeLabel];
	[reloadTimeLabel release];
	
	countLabel.text = [NSString stringWithFormat:@"%i Songs", dataModel.count];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateStyle:NSDateFormatterMediumStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	reloadTimeLabel.text = [NSString stringWithFormat:@"last reload: %@", [formatter stringFromDate:[defaults objectForKey:[NSString stringWithFormat:@"%@songsReloadTime", settings.urlString]]]];
	[formatter release];
	
	self.tableView.tableHeaderView = headerView;
	[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload
{
	// Release anything that can be recreated in viewDidLoad or on demand.
	// e.g. self.myOutlet = nil;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"endSearch" object:searchOverlayView];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_ServerSwitched object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_AllSongsLoadingFinished object:nil];
}

- (void)dealloc 
{
	dataModel.delegate = nil;
	[dataModel release]; dataModel = nil;
	[searchBar release]; searchBar = nil;
	[searchOverlayView release]; searchOverlayView = nil;
	[url release]; url = nil;
    [super dealloc];
}

#pragma mark - LoaderDelegate methods

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error
{
	[self.tableView reloadData];
	[self createDataModel];
    [self hideLoadingScreen];
}

- (void)loadingFinished:(SUSLoader*)theLoader
{
	// Don't do anything, handled by the notification
}

- (void)loadingFinishedNotification
{
	[self.tableView reloadData];
	[self createDataModel];
	[self addCount];
    [self hideLoadingScreen];
}

#pragma mark - Loading Display Handling

- (void)registerForLoadingNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLoadingScreen:) name:ISMSNotification_AllSongsLoadingArtists object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLoadingScreen:) name:ISMSNotification_AllSongsLoadingAlbums object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLoadingScreen:) name:ISMSNotification_AllSongsArtistName object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLoadingScreen:) name:ISMSNotification_AllSongsAlbumName object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLoadingScreen:) name:ISMSNotification_AllSongsSongName object:nil];
}

- (void)unregisterForLoadingNotifications
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_AllSongsLoadingArtists object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_AllSongsLoadingAlbums object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_AllSongsArtistName object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_AllSongsAlbumName object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_AllSongsSongName object:nil];
}

- (void)updateLoadingScreen:(NSNotification *)notification
{
	NSString *name = nil;
	if ([notification.object isKindOfClass:[NSString class]])
	{
		name = [NSString stringWithString:(NSString *)notification.object];
	}

	if ([notification.name isEqualToString:ISMSNotification_AllSongsLoadingArtists])
	{
		isProcessingArtists = YES;
		loadingScreen.loadingTitle1.text = @"Processing Artist:";
		loadingScreen.loadingTitle2.text = @"Processing Album:";
	}
	else if ([notification.name isEqualToString:ISMSNotification_AllSongsLoadingAlbums])
	{
		isProcessingArtists = NO;
		loadingScreen.loadingTitle1.text = @"Processing Album:";
		loadingScreen.loadingTitle2.text = @"Processing Song:";
	}
	else if ([notification.name isEqualToString:ISMSNotification_AllSongsArtistName])
	{
		isProcessingArtists = YES;
		loadingScreen.loadingTitle1.text = @"Processing Artist:";
		loadingScreen.loadingTitle2.text = @"Processing Album:";
		loadingScreen.loadingMessage1.text = name;
	}
	else if ([notification.name isEqualToString:ISMSNotification_AllSongsAlbumName])
	{
		if (isProcessingArtists)
			loadingScreen.loadingMessage2.text = name;
		else
			loadingScreen.loadingMessage1.text = name;
	}
	else if ([notification.name isEqualToString:ISMSNotification_AllSongsSongName])
	{
		isProcessingArtists = NO;
		loadingScreen.loadingTitle1.text = @"Processing Album:";
		loadingScreen.loadingTitle2.text = @"Processing Song:";
		loadingScreen.loadingMessage2.text = name;
	}
}

- (void)showLoadingScreen
{
	self.loadingScreen = [[[LoadingScreen alloc] initOnView:self.view withMessage:[NSArray arrayWithObjects:@"Processing Artist:", @"", @"Processing Album:", @"", nil] blockInput:YES mainWindow:NO] autorelease];
	self.tableView.scrollEnabled = NO;
	self.tableView.allowsSelection = NO;
	self.navigationItem.leftBarButtonItem = nil;
	self.navigationItem.rightBarButtonItem = nil;
	
	[self registerForLoadingNotifications];
}

- (void)hideLoadingScreen
{
	[self unregisterForLoadingNotifications];
	
	self.tableView.scrollEnabled = YES;
	self.tableView.allowsSelection = YES;
	
	// Hide the loading screen
	[loadingScreen hide];
	self.loadingScreen = nil;
}

#pragma mark - Button handling methods

- (void)reloadAction:(id)sender
{
	if (!viewObjects.isArtistsLoading)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Reload?" message:@"This could take a while if you have a big collection.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.\n\nNote: If you've added new artists or albums, you should reload the Folders and Albums tabs first." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
		alert.tag = 1;
		[alert show];
		[alert release];
	}
	else
	{
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Please Wait" message:@"You cannot reload the Songs tab while the Folders or Albums tabs are loading" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
		[alert release];
	}
}

- (void)settingsAction:(id)sender 
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

#pragma mark - UIAlertView delegate

- (void)alertView:(CustomUIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView.tag == 1)
	{
		if (buttonIndex == 1)
		{
			[self showLoadingScreen];//:[NSArray arrayWithObjects:@"Processing Artist:", @"", @"Processing Album:", @"", nil]];
			
			[dataModel restartLoad];
			self.tableView.tableHeaderView = nil;
			[self.tableView reloadData];
		}
		else if (buttonIndex == 2)
		{
			[self showLoadingScreen];//:[NSArray arrayWithObjects:@"Processing Album:", @"", @"Processing Song:", @"", nil]];
			
			[dataModel startLoad];
			self.tableView.tableHeaderView = nil;
			[self.tableView reloadData];
		}	
		
		[self dataSourceDidFinishLoadingNewData];
	}
}

#pragma mark - UISearchBar delegate

- (void)searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar 
{	
	[self.tableView.tableHeaderView retain];
	
	[self.tableView setContentOffset:CGPointMake(0, 50) animated:YES];
	
	if ([theSearchBar.text length] == 0)
	{
		//Add the overlay view.
		if(searchOverlayView == nil)
			searchOverlayView = [[SearchOverlayViewController alloc] initWithNibName:@"SearchOverlayViewController" bundle:[NSBundle mainBundle]];
		//CGFloat y = self.tableView.contentOffset.y - searchBar.frame.origin.y + searchBar.frame.size.height;
		CGFloat width = self.view.frame.size.width;
		CGFloat height = self.view.frame.size.height;
		CGRect frame = CGRectMake(0, 40, width, height);
		searchOverlayView.view.frame = frame;
		[self.view.superview addSubview:searchOverlayView.view];
		
		letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
	}
	
	// Remove the index bar
	isSearching = YES;
	[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
	
	//Add the done button.
	self.navigationItem.leftBarButtonItem = nil;
	self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneSearching_Clicked:)] autorelease];
}

- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText
{
	if([searchText length] > 0) 
	{
		[searchOverlayView.view removeFromSuperview];
		isSearching = YES;
		letUserSelectRow = YES;
		self.tableView.scrollEnabled = YES;
		[dataModel searchForSongName:searchText];
	}
	else 
	{
		[self.tableView setContentOffset:CGPointMake(0, 50) animated:YES];
		
		//Add the overlay view.
		if(searchOverlayView == nil)
			searchOverlayView = [[SearchOverlayViewController alloc] initWithNibName:@"SearchOverlayViewController" bundle:[NSBundle mainBundle]];
		CGFloat width = self.view.frame.size.width;
		CGFloat height = self.view.frame.size.height;
		CGRect frame = CGRectMake(0, 40, width, height);
		searchOverlayView.view.frame = frame;
		[self.view.superview addSubview:searchOverlayView.view];
		
		isSearching = NO;
		letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
		[databaseControls.allSongsDb synchronizedExecuteUpdate:@"DROP TABLE allSongsSearch"];
	}
	
	[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)theSearchBar 
{	
	[searchBar resignFirstResponder];
}

- (void) doneSearching_Clicked:(id)sender 
{
	self.tableView.tableHeaderView = nil;
	[self addCount];
	
	searchBar.text = @"";
	[searchBar resignFirstResponder];
	
	isSearching = NO;
	letUserSelectRow = YES;
	self.navigationItem.leftBarButtonItem = nil;
	//self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];
	self.tableView.scrollEnabled = YES;
	
	[searchOverlayView.view removeFromSuperview];
	[searchOverlayView release];
	searchOverlayView = nil;
	
	[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
	
	[self.tableView setContentOffset:CGPointMake(0, 0) animated:YES];
}

#pragma mark - UITableView delegate

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section 
{
	if(isSearching)
		return @"";
	
	if ([dataModel.index count] == 0)
		return @"";
	
	NSString *title = @"";
	if ([dataModel.index count] > section)
		title = [(Index *)[dataModel.index objectAtIndex:section] name];
	
	return title;
}

// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView 
{
	if(isSearching)
	{
		return nil;
	}
	else
	{
		NSMutableArray *titles = [NSMutableArray arrayWithCapacity:0];
		[titles addObject:@"{search}"];
		for (Index *item in dataModel.index)
		{
			[titles addObject:item.name];
		}
		
		return titles;
	}
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index 
{
	if(isSearching)
		return -1;
	
	if (index == 0) 
	{
		[tableView scrollRectToVisible:CGRectMake(0, 50, 320, 40) animated:NO];
		return -1;
	}
	
	return index - 1;
}

- (NSIndexPath *)tableView :(UITableView *)theTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if(letUserSelectRow)
		return indexPath;
	else
		return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	if (isSearching)
	{
		return 1;
	}
	else
	{
		NSUInteger count = [[dataModel index] count];
		return count;
	}
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (isSearching)
	{
		return dataModel.searchCount;
	}
	else 
	{
		if ([dataModel.index count] > section)
			return [(Index *)[dataModel.index objectAtIndex:section] count];
		return 0;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *CellIdentifier = @"Cell";
	AllSongsUITableViewCell *cell = [[[AllSongsUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
	cell.indexPath = indexPath;
	
	Song *aSong = nil;
	if(isSearching)
	{
		aSong = [dataModel songForPositionInSearch:(indexPath.row + 1)];
	}
	else
	{
		NSUInteger sectionStartIndex = [(Index *)[dataModel.index objectAtIndex:indexPath.section] position];
		aSong = [dataModel songForPosition:(sectionStartIndex + indexPath.row + 1)];
	}
	
	cell.md5 = [aSong.path md5];
	cell.isSearching = isSearching;
	
	[cell.coverArtView loadImageFromCoverArtId:aSong.coverArtId];
	
	cell.backgroundView = [[[UIView alloc] init] autorelease];
	if(indexPath.row % 2 == 0)
	{
		if (aSong.isFullyCached)
			cell.backgroundView.backgroundColor = [viewObjects currentLightColor];
		else
			cell.backgroundView.backgroundColor = viewObjects.lightNormal;
	}
	else
	{
		if (aSong.isFullyCached)
			cell.backgroundView.backgroundColor = [viewObjects currentDarkColor];
		else
			cell.backgroundView.backgroundColor = viewObjects.darkNormal;
	}
	
	[cell.songNameLabel setText:aSong.title];
	if (aSong.album)
		[cell.artistNameLabel setText:[NSString stringWithFormat:@"%@ - %@", aSong.artist, aSong.album]];
	else
		[cell.artistNameLabel setText:aSong.artist];
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (viewObjects.isCellEnabled)
	{
		PlaylistSingleton *currentPlaylist = [PlaylistSingleton sharedInstance];
		
		// Clear the current playlist
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
			[databaseControls resetJukeboxPlaylist];
		else
			[databaseControls resetCurrentPlaylistDb];
		
		// Add selected song to the playlist
		Song *aSong = nil;
		if(isSearching)
		{
			aSong = [dataModel songForPositionInSearch:(indexPath.row + 1)];
		}
		else
		{
			NSUInteger sectionStartIndex = [(Index *)[dataModel.index objectAtIndex:indexPath.section] position];
			aSong = [dataModel songForPosition:(sectionStartIndex + indexPath.row + 1)];
		}
		
		[aSong addToCurrentPlaylist];
		
		// If jukebox mode, send song id to server
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
		{
			[musicControls jukeboxStop];
			[musicControls jukeboxClearPlaylist];
			[musicControls jukeboxAddSong:aSong.songId];
		}
		
		// Set player defaults
		currentPlaylist.isShuffle = NO;
		
		// Start the song
		[musicControls playSongAtPosition:0];
		
		// Show the player
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
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

#pragma mark -
#pragma mark Pull to refresh methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{	
	if (scrollView.isDragging) 
	{
		if (refreshHeaderView.state == EGOOPullRefreshPulling && scrollView.contentOffset.y > -65.0f && scrollView.contentOffset.y < 0.0f && !_reloading) 
		{
			[refreshHeaderView setState:EGOOPullRefreshNormal];
		} 
		else if (refreshHeaderView.state == EGOOPullRefreshNormal && scrollView.contentOffset.y < -65.0f && !_reloading) 
		{
			[refreshHeaderView setState:EGOOPullRefreshPulling];
		}
	}
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	if (scrollView.contentOffset.y <= - 65.0f && !_reloading) 
	{
		_reloading = YES;
		[self reloadAction:nil];
		[refreshHeaderView setState:EGOOPullRefreshLoading];
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.2];
		self.tableView.contentInset = UIEdgeInsetsMake(60.0f, 0.0f, 0.0f, 0.0f);
		[UIView commitAnimations];
	}
}

- (void)dataSourceDidFinishLoadingNewData
{
	_reloading = NO;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	[self.tableView setContentInset:UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f)];
	[UIView commitAnimations];
	
	[refreshHeaderView setState:EGOOPullRefreshNormal];
}

@end

