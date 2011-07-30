//
//  RootViewController.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "RootViewController.h"
#import "SearchOverlayViewController.h"
#import "iSubAppDelegate.h"
#import "MusicControlsSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "XMLParser.h"
#import "AlbumViewController.h"
#import "Artist.h"
#import "LoadingScreen.h"
#import "ArtistUITableViewCell.h"
#import "NSString-md5.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

#import "ASIAuthenticationDialog.h"
#import "ASIFormDataRequest.h"
#import "ASIHTTPRequest.h"
#import "ASIInputStream.h"
#import "ASINetworkQueue.h"
#import "ASINSStringAdditions.h"

#import "ViewObjectsSingleton.h"

#import "UIView-tools.h"
#import "CustomUIAlertView.h"

#import "EGORefreshTableHeaderView.h"

#import <QuartzCore/QuartzCore.h>

#import "FolderDropdownControl.h"

#import "SUSIndexesLoader.h"
#import "DefaultSettings.h"

@interface RootViewController (Private)

- (void)dataSourceDidFinishLoadingNewData;
- (void)addCount;

@end

@implementation RootViewController

@synthesize searchBar, headerView;
@synthesize indexes, folders, foldersSearch;
@synthesize isSearching;
@synthesize dropdown;

@synthesize reloading=_reloading;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if ([[[iSubAppDelegate sharedInstance].settingsDictionary objectForKey:@"lockRotationSetting"] isEqualToString:@"YES"] 
		&& inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.1];
	
	[searchOverlayView.view addY:40.0];
 
	[UIView commitAnimations];
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicControlsSingleton sharedInstance];
	settings = [DefaultSettings sharedInstance];

	self.title = @"Folders";
	
	//Initialize the copy array for searching.
	self.indexes = [settings getTopLevelIndexes];
	self.folders = [settings getTopLevelFolders];
	foldersSearch = [[NSMutableArray alloc] init];
		
	//Set defaults
	isSearching = NO;
	didBeginSearching = NO;
	letUserSelectRow = YES;	
	isCountShowing = NO;
	searchY = 80;
	dropdown = nil;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadArtistList) name:@"reloadArtistList" object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(doneSearching_Clicked:) name:@"endSearch" object:searchOverlayView];
	
	// Add the pull to refresh view
	refreshHeaderView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, 320.0f, self.tableView.bounds.size.height)];
	refreshHeaderView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:237.0/255.0 alpha:1.0];
	[self.tableView addSubview:refreshHeaderView];
	[refreshHeaderView release];
	
	UIImageView *fadeBottom = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]] autorelease];
	fadeBottom.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
	fadeBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.tableView.tableFooterView = fadeBottom;
	
	NSString *key = [NSString stringWithFormat:@"folderDropdownCache%@", [settings.urlString md5]];
	NSData *archivedData = [appDelegate.settingsDictionary objectForKey:key];
	NSDictionary *folderNames = [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
		
	if (folderNames == nil || [folderNames count] == 2)
		[self.tableView setContentOffset:CGPointMake(0, 86) animated:NO];
	else
		[self.tableView setContentOffset:CGPointMake(0, 50) animated:NO];
}

- (void)reloadArtistList
{
	[self.tableView reloadData];
	[self addCount];
	
	//[dropdown updateFolders];
}


-(void)addCount
{
	//float parentWidth = self.view.bounds.size.width;
	
	isCountShowing = YES;
	
	headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 126)] autorelease];
	headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	headerView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];
	
	countLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, 320, 30)];
	countLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	countLabel.backgroundColor = [UIColor clearColor];
	countLabel.textColor = [UIColor colorWithRed:156.0/255.0 green:161.0/255.0 blue:168.0/255.0 alpha:1];
	countLabel.textAlignment = UITextAlignmentCenter;
	countLabel.font = [UIFont boldSystemFontOfSize:30];
	[headerView addSubview:countLabel];
	[countLabel release];
	
	reloadTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 36, 320, 12)];
	reloadTimeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	reloadTimeLabel.backgroundColor = [UIColor clearColor];
	reloadTimeLabel.textColor = [UIColor colorWithRed:176.0/255.0 green:181.0/255.0 blue:188.0/255.0 alpha:1];
	reloadTimeLabel.textAlignment = UITextAlignmentCenter;
	reloadTimeLabel.font = [UIFont systemFontOfSize:11];
	[headerView addSubview:reloadTimeLabel];
	[reloadTimeLabel release];	
	
	searchBar = [[UISearchBar  alloc] initWithFrame:CGRectMake(0, 86, 320, 40)];
	searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	searchBar.delegate = self;
	searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	searchBar.placeholder = @"Folder name";
	[headerView addSubview:searchBar];
	[searchBar release];
	
	self.dropdown = [[FolderDropdownControl alloc] initWithFrame:CGRectMake(50, 53, 220, 30)];
	dropdown.delegate = self;
	dropdown.tableView = self.tableView;
	dropdown.viewsToMove = [NSArray arrayWithObjects:searchBar, nil];
	
	dropdown.folders = [NSDictionary dictionaryWithObject:@"All Folders" forKey:@"-1"];
	NSString *key = [NSString stringWithFormat:@"folderDropdownCache%@", [settings.urlString md5]];
	if ([appDelegate.settingsDictionary objectForKey:key])
		dropdown.folders = [NSKeyedUnarchiver unarchiveObjectWithData:[appDelegate.settingsDictionary objectForKey:key]];
	
	NSInteger selectedFolderId = -1;
	key = [NSString stringWithFormat:@"selectedMusicFolderId%@", [settings.urlString md5]];
	if ([appDelegate.settingsDictionary objectForKey:key])
		selectedFolderId = [[appDelegate.settingsDictionary objectForKey:key] intValue];
	
	[dropdown selectFolderWithId:selectedFolderId];
	[headerView addSubview:dropdown];
	[dropdown release];
	
	NSInteger count = 0;
	for (NSArray *array in folders)
	{
		count = count + [array count];
	}
	countLabel.text = [NSString stringWithFormat:@"%i Folders", count];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateStyle:NSDateFormatterMediumStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	reloadTimeLabel.text = [NSString stringWithFormat:@"last reload: %@", [formatter stringFromDate:[defaults objectForKey:[NSString stringWithFormat:@"%@artistsReloadTime", settings.urlString]]]];
	[formatter release];
	
	self.tableView.tableHeaderView = headerView;
}


-(void)loadData:(NSString*)folderId 
{
	viewObjects.isArtistsLoading = YES;
	
	allArtistsLoadingScreen = [[LoadingScreen alloc] initOnView:self.view.superview withMessage:[NSArray arrayWithObjects:@"Processing Folders", @"", @"", @"", nil] blockInput:YES mainWindow:NO];
	
	SUSIndexesLoader *loader = [[SUSIndexesLoader alloc] initWithDelegate:self];
	loader.folderId = folderId;
	[loader startLoad];
}

- (void)loadingFailed:(Loader*)loader
{
	[loader release];
	
	viewObjects.isArtistsLoading = NO;
	
	// Hide the loading screen
	[allArtistsLoadingScreen hide]; [allArtistsLoadingScreen release];
	
	[self dataSourceDidFinishLoadingNewData];
	
	// Inform the user that the connection failed.
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error loading the artist list.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
	[alert release];
}

- (void)loadingFinished:(Loader*)loader
{
	self.folders = [NSArray arrayWithArray:[[loader results] objectForKey:@"folders"]];
	self.indexes = [NSArray arrayWithArray:[[loader results] objectForKey:@"indexes"]];
	[loader release];
	
	[self addCount];
	
	[self.tableView reloadData];
	self.tableView.backgroundColor = [UIColor clearColor];
	
	viewObjects.isArtistsLoading = NO;
	
	// Hide the loading screen
	[allArtistsLoadingScreen hide]; [allArtistsLoadingScreen release];
	
	[self dataSourceDidFinishLoadingNewData];
}

-(void)viewWillAppear:(BOOL)animated 
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
	
	if (!viewObjects.isAlbumsLoading && !viewObjects.isSongsLoading && !viewObjects.isArtistsLoading)
	{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		if(folders == nil || [[appDelegate.settingsDictionary objectForKey:@"autoReloadArtistsSetting"] isEqualToString:@"YES"])
		{
			if([defaults objectForKey:[NSString stringWithFormat:@"%@topLevelFolders", settings.urlString]] == nil || 
			   [[appDelegate.settingsDictionary objectForKey:@"autoReloadArtistsSetting"] isEqualToString:@"YES"])
			{
				NSString *key = [NSString stringWithFormat:@"selectedMusicFolderId%@", [settings.urlString md5]];
				NSString *currentFolderId = [appDelegate.settingsDictionary objectForKey:key];
				[self loadData:currentFolderId];
			}
			else 
			{
				self.folders = [NSKeyedUnarchiver unarchiveObjectWithData:[defaults objectForKey:[NSString stringWithFormat:@"%@topLevelFolders", settings.urlString]]];
				self.indexes = [NSKeyedUnarchiver unarchiveObjectWithData:[defaults objectForKey:[NSString stringWithFormat:@"%@topLevelIndexes", settings.urlString]]];
				
				// TODO: Rewrite the gracefull transition of listOfArtists
				
				// Handle the change to the listOfArtists structure gracefully
				if ([folders count] > 0)
				{
					if ([[folders objectAtIndex:0] count] > 0)
					{
						if ([[[folders objectAtIndex:0] objectAtIndex:0] isKindOfClass:[NSArray class]])
						{
							NSString *key = [NSString stringWithFormat:@"selectedMusicFolderId%@", [settings.urlString md5]];
							NSString *currentFolderId = [appDelegate.settingsDictionary objectForKey:key];
							[self loadData:currentFolderId];
						}
						else
						{
							[self addCount];
							[self.tableView reloadData];
						}
					}
					else
					{
						[self addCount];
						[self.tableView reloadData];
					}
				}
				else
				{
					[self addCount];
					[self.tableView reloadData];
				}
			}
		}
		else 
		{
			if (!isCountShowing)
				[self addCount];
		}
	}
	
	if (!viewObjects.isArtistsLoading)
	{
		if (!isCountShowing)
			[self addCount];
	}
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


- (void)dealloc {
	[searchBar release];
	[searchOverlayView release];
	[foldersSearch release];
	[dropdown release];
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
	
	letUserSelectRow = YES;
	isSearching = NO;
	didBeginSearching = NO;
	self.navigationItem.leftBarButtonItem = nil;
	self.tableView.scrollEnabled = YES;
	
	[searchOverlayView.view removeFromSuperview];
	[searchOverlayView release];
	searchOverlayView = nil;
	
	[self.tableView reloadData];
	
	[self.tableView setContentOffset:CGPointMake(0, 86) animated:YES];
}

- (void) reloadAction:(id)sender
{
	if (!viewObjects.isAlbumsLoading && !viewObjects.isSongsLoading)
	{
		NSString *key = [NSString stringWithFormat:@"selectedMusicFolderId%@", [settings.urlString md5]];
		NSString *currentFolderId = [appDelegate.settingsDictionary objectForKey:key];
		[self loadData:currentFolderId];
	}
	else
	{
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Please Wait" message:@"You cannot reload the Artists tab while the Albums or Songs tabs are loading" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
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
	musicControls.isNewSong = NO;
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
	[streamingPlayerViewController release];
}


#pragma mark -
#pragma mark SearchBar


- (void) searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar 
{
	[self.tableView.tableHeaderView retain];

	[dropdown closeDropdownFast];
	[self.tableView setContentOffset:CGPointMake(0, 86) animated:YES];
	//[self.tableView setContentOffset:CGPointMake(0, 50) animated:NO];
	
	if ([theSearchBar.text length] == 0)
	{
		//Add the overlay view.
		if(searchOverlayView == nil)
			searchOverlayView = [[SearchOverlayViewController alloc] initWithNibName:@"SearchOverlayViewController" bundle:[NSBundle mainBundle]];
		//CGFloat y = self.tableView.contentOffset.y - searchBar.frame.origin.y + searchBar.frame.size.height;
		CGFloat width = self.view.frame.size.width;
		CGFloat height = self.view.frame.size.height;
		//CGRect frame = CGRectMake(0, y, width, height);
		CGRect frame = CGRectMake(0, 40, width, height);
		searchOverlayView.view.frame = frame;
		[self.view.superview addSubview:searchOverlayView.view];
		
		letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
	}
	
	// Remove the index bar
	didBeginSearching = YES;
	[self.tableView reloadData];
	
	//Add the done button.
	self.navigationItem.leftBarButtonItem = nil;
	self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneSearching_Clicked:)] autorelease];
}


- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText
{
	//Remove all objects first.
	[foldersSearch removeAllObjects];
	
	if([searchText length] > 0) 
	{
		[searchOverlayView.view removeFromSuperview];
		isSearching = YES;
		letUserSelectRow = YES;
		self.tableView.scrollEnabled = YES;
		[self searchTableView];
	}
	else 
	{
		[self.tableView setContentOffset:CGPointMake(0, 86) animated:YES];
		
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
	}
	
	[self.tableView reloadData];
}

- (void) searchBarSearchButtonClicked:(UISearchBar *)theSearchBar 
{
	[self searchTableView];
	[searchBar resignFirstResponder];
}

- (void) searchTableView 
{
	NSString *searchText = searchBar.text;
	NSMutableArray *searchArray = [[NSMutableArray alloc] init];
	
	for (NSArray *array in folders)
	{
		[searchArray addObjectsFromArray:array];
	}
	
	for (Artist *anArtist in searchArray)
	{
		NSRange titleResultsRange = [anArtist.name rangeOfString:searchText options:NSCaseInsensitiveSearch];
		
		if (titleResultsRange.length > 0)
			[foldersSearch addObject:anArtist];
	}
	
	[searchArray release];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	if (isSearching)
		return 1;
	else
		return [folders count];
}


#pragma mark TableView

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (isSearching)
	{
		return [foldersSearch count];
	}
	else 
	{
		return [[folders objectAtIndex:section] count];
	}
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *CellIdentifier = @"Cell";
	ArtistUITableViewCell *cell = [[[ArtistUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
	
	Artist *anArtist;
	if(isSearching)
	{
		//anArtist = [[foldersSearch objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
		anArtist = [foldersSearch objectAtIndex:indexPath.row];
	}
	else
	{
		anArtist = [[folders objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
	}
	cell.myArtist = anArtist;
	
	[cell.artistNameLabel setText:anArtist.name];
	cell.backgroundView = [viewObjects createCellBackground:indexPath.row];
	
	return cell;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	
	if(isSearching || didBeginSearching)
		return @"";
	
	return [indexes objectAtIndex:section];
}


// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView 
{
	if(isSearching || didBeginSearching)
		return nil;
	else
	{
		NSMutableArray *searchIndexes = [[[NSMutableArray alloc] init] autorelease];
		[searchIndexes addObject:@"{search}"];
		[searchIndexes addObjectsFromArray:indexes];
		
		return searchIndexes;
	}
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index 
{
	if(isSearching || didBeginSearching)
		return -1;
	
	if (index == 0) 
	{
		//[tableView scrollRectToVisible:CGRectMake(0, 50, 320, searchY) animated:NO];
		
		NSString *key = [NSString stringWithFormat:@"folderDropdownCache%@", [settings.urlString md5]];
		NSData *archivedData = [appDelegate.settingsDictionary objectForKey:key];
		NSDictionary *folderNames = [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
				
		if (folderNames == nil || [folderNames count] == 2)
			//[tableView scrollRectToVisible:CGRectMake(0, 87, 320, searchY) animated:NO];
			[self.tableView setContentOffset:CGPointMake(0, 86) animated:NO];
		else
			//[tableView scrollRectToVisible:CGRectMake(0, 50, 320, searchY) animated:NO];
			[self.tableView setContentOffset:CGPointMake(0, 50) animated:NO];
		
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (viewObjects.isCellEnabled)
	{
		Artist *anArtist;
		if(isSearching)
		{
			anArtist = [foldersSearch objectAtIndex:indexPath.row];
		}
		else 
		{	
			anArtist = [[folders objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
		}
		AlbumViewController* albumViewController = [[AlbumViewController alloc] initWithArtist:anArtist orAlbum:nil];
				
		[self.navigationController pushViewController:albumViewController animated:YES];
		[albumViewController release];
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
		//[self reloadAction:nil];
		NSString *key = [NSString stringWithFormat:@"selectedMusicFolderId%@", [settings.urlString md5]];
		NSString *currentFolderId = [appDelegate.settingsDictionary objectForKey:key];
		[self loadData:currentFolderId];
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

