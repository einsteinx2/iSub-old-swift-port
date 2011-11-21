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
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString-md5.h"
#import "LoadingScreen.h"
#import "RootViewController.h"
#import "TBXML.h"
#import "CustomUITableView.h"
#import "CustomUIAlertView.h"
#import "GTMNSString+HTML.h"
#import "SavedSettings.h"
#import "SUSAllSongsDAO.h"
#import "SUSAllSongsLoader.h"

@interface AllSongsViewController (Private)
- (void)hideLoadingScreen;
@end

@implementation AllSongsViewController

@synthesize headerView, sectionInfo, dataModel, loadingScreen;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	
	if ([SavedSettings sharedInstance].isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

#pragma mark - View Controller Lifecycle

- (void)createDataModel
{
	self.dataModel = [[[SUSAllSongsDAO alloc] init] autorelease];
}

- (void)viewDidLoad {
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
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(doneSearching_Clicked:) name:@"endSearch" object:searchOverlayView];

	// Add the table fade
	UIImageView *fadeTop = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-top.png"]];
	fadeTop.frame =CGRectMake(0, -10, self.tableView.bounds.size.width, 10);
	fadeTop.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.tableView addSubview:fadeTop];
	[fadeTop release];
	
	UIImageView *fadeBottom = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]] autorelease];
	fadeBottom.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
	fadeBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.tableView.tableFooterView = fadeBottom;
}

-(void)viewWillAppear:(BOOL)animated 
{
	[super viewWillAppear:animated];
	
	// Don't run this while the table is updating
	if (viewObjects.isSongsLoading)
	{
		// TODO: display the loading progress box
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
			//[self addCount];
		}
		else
		{
			if (viewObjects.isAlbumsLoading)
			{
				// TODO: display the loading progress box
			}
			else
			{
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
	}
}

-(void)addCount
{
	// Build the search and reload view
	headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 90)] autorelease];
	headerView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];
	
	reloadButton = [UIButton buttonWithType:UIButtonTypeCustom];
	reloadButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	reloadButton.frame = CGRectMake(0, 0, 320, 40);
	[reloadButton addTarget:self action:@selector(reloadAction:) forControlEvents:UIControlEventTouchUpInside];
	[headerView addSubview:reloadButton];
	
	countLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, 320, 30)];
	countLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	countLabel.backgroundColor = [UIColor clearColor];
	countLabel.textColor = [UIColor colorWithRed:156.0/255.0 green:161.0/255.0 blue:168.0/255.0 alpha:1];
	countLabel.textAlignment = UITextAlignmentCenter;
	countLabel.font = [UIFont boldSystemFontOfSize:30];
	[headerView addSubview:countLabel];
	[countLabel release];
	
	reloadImage = [[UIImageView alloc] initWithFrame:CGRectMake(20, 13, 24, 26)];
	reloadImage.image = [UIImage imageNamed:@"reload-table.png"];
	[headerView addSubview:reloadImage];
	[reloadImage release];
	
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
	
	countLabel.text = [NSString stringWithFormat:@"%i Songs", [databaseControls.allSongsDb intForQuery:@"SELECT COUNT(*) FROM allSongs"]];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateStyle:NSDateFormatterMediumStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	reloadTimeLabel.text = [NSString stringWithFormat:@"last reload: %@", [formatter stringFromDate:[defaults objectForKey:[NSString stringWithFormat:@"%@songsReloadTime", settings.urlString]]]];
	[formatter release];
	
	self.tableView.tableHeaderView = headerView;
	[self.tableView reloadData];
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
	// Release anything that can be recreated in viewDidLoad or on demand.
	// e.g. self.myOutlet = nil;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"endSearch" object:searchOverlayView];
}

- (void)dealloc 
{
	[searchBar release];
	[searchOverlayView release];
	[url release];
    [super dealloc];
}

#pragma mark - LoaderDelegate methods

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error
{
    
}

- (void)loadingFinished:(SUSLoader*)theLoader
{
    [self hideLoadingScreen];
    [self.tableView reloadData];
}

#pragma mark - Loading Display Handling

- (void)registerForLoadingNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLoadingScreen:) name:NOTIF_LOADING_ARTISTS object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLoadingScreen:) name:NOTIF_LOADING_ALBUMS object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLoadingScreen:) name:NOTIF_ARTIST_NAME object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLoadingScreen:) name:NOTIF_ALBUM_NAME object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLoadingScreen:) name:NOTIF_SONG_NAME object:nil];
}

- (void)unregisterForLoadingNotifications
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIF_LOADING_ARTISTS object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIF_LOADING_ALBUMS object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIF_ARTIST_NAME object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIF_ALBUM_NAME object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIF_SONG_NAME object:nil];
}

- (void)updateLoadingScreen:(NSNotification *)notification
{
	NSString *name = nil;
	if ([notification.object isKindOfClass:[NSString class]])
	{
		name = [NSString stringWithString:(NSString *)notification.object];
	}

	if ([notification.name isEqualToString:NOTIF_LOADING_ARTISTS])
	{
		if (!isProcessingArtists)
		{
			isProcessingArtists = YES;
			loadingScreen.loadingTitle1.text = @"Processing Artist:";
			loadingScreen.loadingTitle2.text = @"Processing Album:";
		}
	}
	else if ([notification.name isEqualToString:NOTIF_LOADING_ALBUMS])
	{
		if (isProcessingArtists)
		{
			isProcessingArtists = NO;
			loadingScreen.loadingTitle1.text = @"Processing Album:";
			loadingScreen.loadingTitle2.text = @"Processing Song:";
		}
	}
	else if ([notification.name isEqualToString:NOTIF_ARTIST_NAME])
	{
		loadingScreen.loadingMessage1.text = name;
	}
	else if ([notification.name isEqualToString:NOTIF_ALBUM_NAME])
	{
		if (isProcessingArtists)
			loadingScreen.loadingMessage2.text = name;
		else
			loadingScreen.loadingMessage1.text = name;
	}
	else if ([notification.name isEqualToString:NOTIF_SONG_NAME])
	{
		if (!isProcessingArtists)
			loadingScreen.loadingMessage2.text = name;
	}
}
 
 
- (void)hideLoadingScreen
{
	// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	//NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	self.tableView.scrollEnabled = YES;
	[(CustomUITableView*)self.tableView setBlockInput:NO];
	
	// Hide the loading screen
	[loadingScreen hide];
	self.loadingScreen = nil;
	
	//[autoreleasePool release];
}

#pragma mark - Button handling methods

- (void) reloadAction:(id)sender
{
	//if (!appDelegate.isArtistsLoading && !appDelegate.isAlbumsLoading && [[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@isAllAlbumsLoading", appDelegate.defaultUrl]] isEqualToString:@"NO"])
	if (!viewObjects.isArtistsLoading && !viewObjects.isAlbumsLoading)
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

#pragma mark - UIAlertView delegate

- (void)alertView:(CustomUIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView.tag == 1)
	{
		if (buttonIndex == 1)
		{
			self.loadingScreen = [[LoadingScreen alloc] initOnView:self.view 
													   withMessage:[NSArray arrayWithObjects:@"Processing Artist:", @"", @"Processing Album:", @"", nil] blockInput:YES mainWindow:NO];
			self.tableView.scrollEnabled = NO;
			[(CustomUITableView*)self.tableView setBlockInput:YES];
			self.navigationItem.leftBarButtonItem = nil;
			self.navigationItem.rightBarButtonItem = nil;
			
			[self registerForLoadingNotifications];
			[dataModel restartLoad];
		}
		else if (buttonIndex == 2)
		{
			self.loadingScreen = [[LoadingScreen alloc] initOnView:self.view 
													   withMessage:[NSArray arrayWithObjects:@"Processing Album:", @"", @"Processing Song:", @"", nil] blockInput:YES mainWindow:NO];
			self.tableView.scrollEnabled = NO;
			[(CustomUITableView*)self.tableView setBlockInput:YES];
			self.navigationItem.leftBarButtonItem = nil;
			self.navigationItem.rightBarButtonItem = nil;
			
			[self registerForLoadingNotifications];
			[dataModel startLoad];
		}	
	}
}

#pragma mark - UISearchBar delegate

- (void) searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar 
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
	[self.tableView reloadData];
	
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
		[databaseControls.allSongsDb executeUpdate:@"DROP TABLE allSongsSearch"];
	}
	
	[self.tableView reloadData];
}

- (void) searchBarSearchButtonClicked:(UISearchBar *)theSearchBar 
{	
	[dataModel searchForSongName:theSearchBar.text];
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
	
	[self.tableView reloadData];
	
	[self.tableView setContentOffset:CGPointMake(0, 0) animated:YES];
}

#pragma mark - UITableView delegate

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
		return [(Index *)[dataModel.index objectAtIndex:section] count];
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
		aSong = [dataModel songForPosition:(sectionStartIndex + indexPath.row)];
	}
	
	cell.md5 = [NSString md5:aSong.path];
	cell.isSearching = isSearching;
	
	[cell.coverArtView loadImageFromCoverArtId:aSong.coverArtId];
	
	cell.backgroundView = [[[UIView alloc] init] autorelease];
	if(indexPath.row % 2 == 0)
	{
		if ([databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ? and finished = 'YES'", cell.md5] != nil)
			cell.backgroundView.backgroundColor = [viewObjects currentLightColor];
		else
			cell.backgroundView.backgroundColor = viewObjects.lightNormal;
	}
	else
	{
		if ([databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ? and finished = 'YES'", cell.md5] != nil)
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
			aSong = [dataModel songForPosition:(sectionStartIndex + indexPath.row)];
		}
		
		[aSong addToPlaylistQueue];
		
		// If jukebox mode, send song id to server
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
		{
			[musicControls jukeboxStop];
			[musicControls jukeboxClearPlaylist];
			[musicControls jukeboxAddSong:aSong.songId];
		}
		
		// Set player defaults
		musicControls.isShuffle = NO;
		
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

@end

