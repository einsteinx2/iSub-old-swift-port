//
//  AllAlbumsViewController.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "AllAlbumsViewController.h"
#import "SearchOverlayViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "AlbumViewController.h"
#import "AllAlbumsUITableViewCell.h"
#import "AsynchronousImageViewCached.h"
#import "Index.h"
#import "Artist.h"
#import "Album.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString+md5.h"
#import "LoadingScreen.h"
#import "RootViewController.h"

#import "SA_OAuthTwitterEngine.h"

#import "CustomUITableView.h"
#import "CustomUIAlertView.h"

#import "SavedSettings.h"
#import "SUSAllAlbumsDAO.h"
#import "FlurryAnalytics.h"

@implementation AllAlbumsViewController

@synthesize headerView, sectionInfo, dataModel;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	
	if ([SavedSettings sharedInstance].isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)createDataModel
{
	self.dataModel = [[[SUSAllAlbumsDAO alloc] init] autorelease];
}

- (void)viewDidLoad 
{
	//DLog(@"allAlbums viewDidLoad");
    [super viewDidLoad];
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicSingleton sharedInstance];
	databaseControls = [DatabaseSingleton sharedInstance];
	
	self.title = @"Albums";
	//self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];
	
	//Set defaults
	viewObjects.isSearchingAllAlbums = NO;
	letUserSelectRow = YES;	
	isSearching = NO;
	
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


-(void)addCount
{
	//Build the search and reload view
	headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 90)] autorelease];
	headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
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
	searchBar.placeholder = @"Album name";
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
	
	countLabel.text = [NSString stringWithFormat:@"%i Albums", dataModel.count];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateStyle:NSDateFormatterMediumStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	reloadTimeLabel.text = [NSString stringWithFormat:@"last reload: %@", [formatter stringFromDate:[defaults objectForKey:[NSString stringWithFormat:@"%@songsReloadTime", [SavedSettings sharedInstance].urlString]]]];
	[formatter release];
	
	self.tableView.tableHeaderView = headerView;
	
	[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
}

- (void) updateMessage
{
	[viewObjects.allAlbumsLoadingScreen setAllMessagesText:[NSArray arrayWithObjects:@"Sorting Table", @"", @"", @"", nil]];
}


- (void) hideLoadingScreen
{
	// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	self.tableView.scrollEnabled = YES;
	[(CustomUITableView*)self.tableView setBlockInput:NO];
	[viewObjects.allAlbumsLoadingScreen hide];
	viewObjects.allAlbumsLoadingScreen = nil;
	
	[autoreleasePool release];
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
			[self addCount];
		}
		else
		{
			if (viewObjects.isAlbumsLoading)
			{
				// TODO: display the loading progress box
			}
			else
			{
				SavedSettings *settings = [SavedSettings sharedInstance];
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
	
	/*// Don't run this while the table is updating
	if (!viewObjects.isAlbumsLoading)
	{
		if(musicControls.showPlayerIcon)
		{
			self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
		}
		else
		{
			self.navigationItem.rightBarButtonItem = nil;
		}
		
		// If the database hasn't been created or the device was shutoff during the process then create it, otherwise show the header
		if ([databaseControls.allAlbumsDb tableExists:@"allAlbums"] == NO || [[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@isAllAlbumsLoading", appDelegate.defaultUrl]] isEqualToString:@"YES"])
		{
			if([[SavedSettings sharedInstance] getTopLevelFolders] == nil)
			{
				CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"You must load the Folders tab first" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
				alert.tag = 4;
				[alert show];
				[alert release];
			}
			else if (viewObjects.isSongsLoading)
			{
				CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Please Wait" message:@"You cannot reload the Albums tab while the Songs tab is loading" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
				[alert show];
				[alert release];
			}
			else
			{
				if ([[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@isAllAlbumsLoading", appDelegate.defaultUrl]] isEqualToString:@"YES"])
				{
					UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Resume Load?" message:@"If you've reloaded the Folders tab since this load started you should choose 'Restart Load'.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Restart Load", @"Resume Load", nil];
					[alert show];
					[alert release];
				}
				else
				{
					UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Load?" message:@"This could take a while if you have a big collection.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.\n\nNote: If you've added new artists, you should reload the Folders tab first." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
					[alert show];
					[alert release];
				}
			}
		}
	}
	else
	{
		[viewObjects.allAlbumsLoadingScreen.view removeFromSuperview];
		[self.view addSubview:viewObjects.allAlbumsLoadingScreen.view];
	}*/
	
	[FlurryAnalytics logEvent:@"AllAlbumsTab"];
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"endSearch" object:searchOverlayView];
}

- (void)viewDidUnload {
	// Release anything that can be recreated in viewDidLoad or on demand.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc {
	[searchBar release];
	[searchOverlayView release];
	[url release];
    [super dealloc];
}


#pragma mark -
#pragma mark Button handling methods


- (void) doneSearching_Clicked:(id)sender 
{
	self.tableView.tableHeaderView = nil;
	[self addCount];
	
	searchBar.text = @"";
	[searchBar resignFirstResponder];
	
	isSearching = NO;
	letUserSelectRow = YES;
	viewObjects.isSearchingAllAlbums = NO;
	self.navigationItem.leftBarButtonItem = nil;
	//self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];
	self.tableView.scrollEnabled = YES;
	
	[searchOverlayView.view removeFromSuperview];
	[searchOverlayView release];
	searchOverlayView = nil;
	
	[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
	
	[self.tableView setContentOffset:CGPointMake(0, 28) animated:YES];
}


- (void) reloadAction:(id)sender
{
	//if (!appDelegate.isArtistsLoading && !appDelegate.isSongsLoading && [[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@isAllSongsLoading", appDelegate.defaultUrl]] isEqualToString:@"NO"])
	if (!viewObjects.isArtistsLoading && !viewObjects.isSongsLoading)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Reload?" message:@"This could take a while if you have a big collection.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.\n\nNote: If you've added new artists, you should reload the Folders tab first." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
		[alert show];
		[alert release];
	}
	else
	{
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Please Wait" message:@"You cannot reload the Albums tab while the Folders or Songs tabs are loading" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
		[alert release];
	}	
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1)
	{
		[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE resumeLoad"];
		viewObjects.allAlbumsLoadingProgress = 0;
		viewObjects.allAlbumsLoadingScreen = [[LoadingScreen alloc] initOnView:self.view withMessage:[NSArray arrayWithObjects:@"Processing Artist:", @"", @"Total Albums:", @"", nil] blockInput:YES mainWindow:NO];
		self.tableView.scrollEnabled = NO;
		//DLog(@"self.tableView: %@", self.tableView);
		[(CustomUITableView*)self.tableView setBlockInput:YES];
		self.navigationItem.leftBarButtonItem = nil;
		self.navigationItem.rightBarButtonItem = nil;
		[self performSelectorInBackground:@selector(loadData) withObject:nil];
	}
	else if (buttonIndex == 2)
	{
		viewObjects.allAlbumsLoadingProgress = [databaseControls.allAlbumsDb intForQuery:@"SELECT COUNT(*) FROM allAlbumsTemp"];
		viewObjects.allAlbumsLoadingScreen = [[LoadingScreen alloc] initOnView:self.view withMessage:[NSArray arrayWithObjects:@"Processing Artist:", @"", @"Total Albums:", @"", nil] blockInput:YES mainWindow:NO];
		self.tableView.scrollEnabled = NO;
		//DLog(@"self.tableView: %@", self.tableView);
		[(CustomUITableView*)self.tableView setBlockInput:YES];
		self.navigationItem.leftBarButtonItem = nil;
		self.navigationItem.rightBarButtonItem = nil;
		[self performSelectorInBackground:@selector(loadData) withObject:nil];
	}
	//DLog(@"loading screen bounds: %@", NSStringFromCGRect(viewObjects.allAlbumsLoadingScreen.view.bounds));
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


#pragma mark -
#pragma mark Tableview methods

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section 
{
	if(isSearching)
		return @"";
	
	if ([dataModel.index count] == 0)
		return @"";
	
	NSString *title = [(Index *)[dataModel.index objectAtIndex:section] name];
	
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
		viewObjects.isSearchingAllAlbums = YES;
		letUserSelectRow = YES;
		self.tableView.scrollEnabled = YES;
		[self searchTableView];
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
		
		viewObjects.isSearchingAllAlbums = NO;
		letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
		[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE allAlbumsSearch"];
	}
	
	[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
}


- (void) searchBarSearchButtonClicked:(UISearchBar *)theSearchBar 
{
	[self searchTableView];
	[searchBar resignFirstResponder];
}

- (void) searchTableView 
{
	// Inialize the search DB
	[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE allAlbumsSearch"];
	[databaseControls.allAlbumsDb executeUpdate:@"CREATE TABLE allAlbumsSearch(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];	
		
	// Perform the search
	[databaseControls.allAlbumsDb executeUpdate:@"INSERT INTO allAlbumsSearch SELECT * FROM allAlbums WHERE title MATCH ? LIMIT 100", searchBar.text];
	if ([databaseControls.allAlbumsDb hadError]) {
		DLog(@"Err %d: %@", [databaseControls.allAlbumsDb lastErrorCode], [databaseControls.allAlbumsDb lastErrorMessage]);
	}
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


// Customize the number of rows in the table view.
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

								   
// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *CellIdentifier = @"Cell";
	AllAlbumsUITableViewCell *cell = [[[AllAlbumsUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
	
	Album *anAlbum = nil;
	if(isSearching)
	{
		anAlbum = [dataModel albumForPositionInSearch:(indexPath.row + 1)];
	}
	else
	{
		NSUInteger sectionStartIndex = [(Index *)[dataModel.index objectAtIndex:indexPath.section] position];
		anAlbum = [dataModel albumForPosition:(sectionStartIndex + indexPath.row + 1)];
	}
	
	cell.myId = anAlbum.albumId;
	cell.myArtist = [Artist artistWithName:anAlbum.artistName andArtistId:anAlbum.artistId];
	
	[cell.coverArtView loadImageFromCoverArtId:anAlbum.coverArtId];
	
	cell.backgroundView = [[ViewObjectsSingleton sharedInstance] createCellBackground:indexPath.row];
		
	[cell.albumNameLabel setText:anAlbum.title];
	[cell.artistNameLabel setText:anAlbum.artistName];
	
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (viewObjects.isCellEnabled)
	{
		Album *anAlbum = nil;
		if(isSearching)
		{
			anAlbum = [dataModel albumForPositionInSearch:(indexPath.row + 1)];
		}
		else
		{
			NSUInteger sectionStartIndex = [(Index *)[dataModel.index objectAtIndex:indexPath.section] position];
			anAlbum = [dataModel albumForPosition:(sectionStartIndex + indexPath.row + 1)];
		}
		
		AlbumViewController* albumViewController = [[AlbumViewController alloc] initWithArtist:nil orAlbum:anAlbum];
		[self.navigationController pushViewController:albumViewController animated:YES];
		[albumViewController release];
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

@end

