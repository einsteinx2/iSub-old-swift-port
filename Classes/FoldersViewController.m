//
//  RootViewController.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "FoldersViewController.h"
#import "iSubAppDelegate.h"
#import "MusicSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "AlbumViewController.h"
#import "Artist.h"
#import "LoadingScreen.h"
#import "ArtistUITableViewCell.h"
#import "NSString+md5.h"
#import "FMDatabaseAdditions.h"
#import "ViewObjectsSingleton.h"
#import "UIView+Tools.h"
#import "CustomUIAlertView.h"
#import "EGORefreshTableHeaderView.h"
#import <QuartzCore/QuartzCore.h>
#import "FolderDropdownControl.h"
#import "SUSRootFoldersDAO.h"
#import "SavedSettings.h"
#import "FlurryAnalytics.h"
#import "SUSAllSongsLoader.h"
#import "SeparaterView.h"
#import "NSArray+Additions.h"
#import "UIViewController+PushViewController.h"

@interface FoldersViewController (Private)

- (void)dataSourceDidFinishLoadingNewData;
- (void)addCount;
-(void)loadData:(NSNumber *)folderId;

@end

@implementation FoldersViewController

@synthesize searchBar, headerView;
//@synthesize indexes, folders, foldersSearch;
@synthesize isSearching;
@synthesize dropdown;

@synthesize reloading=_reloading;

@synthesize dataModel;

#pragma mark - Rotation

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if (settingsS.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

#pragma mark - Lifecycle

- (void)createDataModel
{
	self.dataModel = [[[SUSRootFoldersDAO alloc] initWithDelegate:self] autorelease];
	dataModel.selectedFolderId = [settingsS rootFoldersSelectedFolderId];
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	[self createDataModel];
	
	self.title = @"Folders";
		
	//Set defaults
	isSearching = NO;
	letUserSelectRow = YES;	
	isCountShowing = NO;
	searchY = 80;
	dropdown = nil;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverSwitched) name:ISMSNotification_ServerSwitched object:nil];
		
	// Add the pull to refresh view
	refreshHeaderView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, 320.0f, self.tableView.bounds.size.height)];
	refreshHeaderView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:237.0/255.0 alpha:1.0];
	[self.tableView addSubview:refreshHeaderView];
	[refreshHeaderView release];
	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
	else
	{		
		if (dropdown.folders == nil || [dropdown.folders count] == 2)
			[self.tableView setContentOffset:CGPointMake(0, 86) animated:NO];
		else
			[self.tableView setContentOffset:CGPointMake(0, 50) animated:NO];
	}	
		UIImageView *fadeBottom = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]] autorelease];
		fadeBottom.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
		fadeBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.tableView.tableFooterView = fadeBottom;
	 //}
	
	if ([dataModel isRootFolderIdCached])
		[self addCount];
}

-(void)viewWillAppear:(BOOL)animated 
{
	[super viewWillAppear:animated];
	
	if(musicS.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	if (![SUSAllSongsLoader isLoading] && !viewObjectsS.isArtistsLoading)
	{
		if (![dataModel isRootFolderIdCached])
		{
			[self loadData:[settingsS rootFoldersSelectedFolderId]];
		}
	}
	
	[FlurryAnalytics logEvent:@"FoldersTab"];
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}


- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_ServerSwitched object:nil];

	dataModel.delegate = nil;
	[dataModel release]; dataModel = nil;
	[searchBar release]; searchBar = nil;
	[dropdown release]; dropdown = nil;
    [super dealloc];
}

#pragma mark - Loading

- (void)updateCount
{
	if ([dataModel count] == 1)
		countLabel.text = [NSString stringWithFormat:@"%i Folder", [dataModel count]];
	else
		countLabel.text = [NSString stringWithFormat:@"%i Folders", [dataModel count]];
	
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateStyle:NSDateFormatterMediumStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	reloadTimeLabel.text = [NSString stringWithFormat:@"last reload: %@", [formatter stringFromDate:[settingsS rootFoldersReloadTime]]];
	[formatter release];
	
}

-(void)addCount
{	
	isCountShowing = YES;
	
	headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 126)] autorelease];
	headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	headerView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];
	
	CGRect sepFrame = CGRectMake(0, 0, headerView.bounds.size.width, 2);
	SeparaterView *sepView = [[SeparaterView alloc] initWithFrame:sepFrame];
	[headerView addSubview:sepView];
	[sepView release];
	
	blockerButton = [UIButton buttonWithType:UIButtonTypeCustom];
	blockerButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	blockerButton.frame = headerView.frame;
	[headerView addSubview:blockerButton];
	
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
	NSDictionary *dropdownFolders = [SUSRootFoldersDAO folderDropdownFolders];
	if (dropdownFolders != nil)
	{
		dropdown.folders = dropdownFolders;
	}
	else
	{
		dropdown.folders = [NSDictionary dictionaryWithObject:@"All Folders" forKey:[NSNumber numberWithInt:-1]];
	}
	[dropdown selectFolderWithId:[dataModel selectedFolderId]];
	
	[headerView addSubview:dropdown];
	[dropdown release];
	
	[self updateCount];
	
	self.tableView.tableHeaderView = headerView;
}

-(void)loadData:(NSNumber *)folderId 
{
	[dropdown updateFolders];
	
	viewObjectsS.isArtistsLoading = YES;
	
	allArtistsLoadingScreen = [[LoadingScreen alloc] initOnView:self.view.superview withMessage:[NSArray arrayWithObjects:@"Processing Folders", @"", @"", @"", nil]  blockInput:YES mainWindow:NO];
	
	dataModel.selectedFolderId = folderId;
	[dataModel startLoad];
}

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error
{	
	viewObjectsS.isArtistsLoading = NO;
	
	// Hide the loading screen
	[allArtistsLoadingScreen hide]; 
	[allArtistsLoadingScreen release]; allArtistsLoadingScreen = nil;
	
	[self dataSourceDidFinishLoadingNewData];
	
	// Inform the user that the connection failed.
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error loading the artist list.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	[alert release];
}

- (void)loadingFinished:(SUSLoader*)theLoader
{	
    //DLog(@"loadingFinished called");
	if (isCountShowing)
		[self updateCount];
	else
		[self addCount];		
	
	[self.tableView reloadData];
	self.tableView.backgroundColor = [UIColor clearColor];
	
	viewObjectsS.isArtistsLoading = NO;
	
	// Hide the loading screen
	[allArtistsLoadingScreen hide]; 
	[allArtistsLoadingScreen release]; allArtistsLoadingScreen = nil;
	
	[self dataSourceDidFinishLoadingNewData];
}

#pragma mark - Folder Dropdown Delegate

- (void)folderDropdownMoveViewsY:(float)y
{
	//[self.tableView beginUpdates];
	self.tableView.tableHeaderView.height += y;
	searchBar.y += y;
	blockerButton.frame = self.tableView.tableHeaderView.frame;
	
	/*for (UIView *subView in self.tableView.subviews)
	{
		if (subView != self.tableView.tableHeaderView && subView != refreshHeaderView)
			subView.y += y;
	}*/
	
	/*for (UITableViewCell *cell in self.tableView.visibleCells)
	{
		cell.y += y;
	}*/	
	//[self.tableView endUpdates];
	
	self.tableView.tableHeaderView = self.tableView.tableHeaderView;
}

- (void)folderDropdownViewsFinishedMoving
{
	//self.tableView.tableHeaderView = self.tableView.tableHeaderView;
	/*[self.tableView setNeedsLayout];
	[self.tableView reloadData];*/
}

- (void)folderDropdownSelectFolder:(NSNumber *)folderId
{
	// Save the default
	settingsS.rootFoldersSelectedFolderId = folderId;
	
	// Reload the data
	dataModel.selectedFolderId = folderId;
	isSearching = NO;
	if ([dataModel isRootFolderIdCached])
	{
		[self.tableView reloadData];
		[self updateCount];
	}
	else
	{
		[self loadData:folderId];
	}
}

- (void)serverSwitched
{
	[self createDataModel];
	[self folderDropdownSelectFolder:[NSNumber numberWithInteger:-1]];
}

#pragma mark - Button handling methods

- (void) reloadAction:(id)sender
{
	if (![SUSAllSongsLoader isLoading])
	{
		[self loadData:[settingsS rootFoldersSelectedFolderId]];
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
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
	[streamingPlayerViewController release];
}


#pragma mark -
#pragma mark SearchBar

- (void)createSearchOverlay
{
	searchOverlay = [[UIView alloc] init];
	//searchOverlay.frame = CGRectMake(0, 74, 480, 480);
	searchOverlay.frame = CGRectMake(0, 0, 480, 480);
	searchOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	searchOverlay.backgroundColor = [UIColor colorWithWhite:0 alpha:.80];
	searchOverlay.alpha = 0.0;
	//[self.view.superview addSubview:searchOverlay];
	//[self.tableView.tableFooterView addSubview:searchOverlay];
	self.tableView.tableFooterView = searchOverlay;//self.tableView.tableFooterView;
	[searchOverlay release];
	
	dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
	dismissButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[dismissButton addTarget:self action:@selector(doneSearching_Clicked:) forControlEvents:UIControlEventTouchUpInside];
	dismissButton.frame = self.view.bounds;
	dismissButton.enabled = NO;
	[searchOverlay addSubview:dismissButton];
	
	UIImageView *fadeBottom = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]] autorelease];
	fadeBottom.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
	fadeBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[searchOverlay addSubview:fadeBottom];
	
	// Animate the search overlay on screen
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
	searchOverlay.alpha = 1;
	dismissButton.enabled = YES;
	[UIView commitAnimations];
}

- (void)hideSearchOverlay
{
	if (searchOverlay)
	{
		// Animate the search overlay off screen
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.3];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(removeSearchOverlay)];
		searchOverlay.alpha = 0;
		dismissButton.enabled = NO;
		[UIView commitAnimations];
	}
}

- (void)removeSearchOverlay
{
	[searchOverlay removeFromSuperview];
	searchOverlay = nil;
	
	UIImageView *fadeBottom = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]] autorelease];
	fadeBottom.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
	fadeBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.tableView.tableFooterView = fadeBottom;
}

- (void) searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar 
{
	if (isSearching)
		return;
	
	// Remove the index bar
	isSearching = YES;
	[dataModel clearSearchTable];
	[self.tableView reloadData];
	
	[self.tableView.tableHeaderView retain];

	[dropdown closeDropdownFast];
	[self.tableView setContentOffset:CGPointMake(0, 86) animated:YES];
	
	if ([theSearchBar.text length] == 0)
	{
		[self createSearchOverlay];
				
		letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
	}
	
	//Add the done button.
	self.navigationItem.leftBarButtonItem = nil;
	self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneSearching_Clicked:)] autorelease];
}


- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText
{
	if([searchText length] > 0) 
	{				
		[self hideSearchOverlay];
		
		letUserSelectRow = YES;
		self.tableView.scrollEnabled = YES;
		
		[dataModel searchForFolderName:searchBar.text];
		
		[self.tableView reloadData];
	}
	else 
	{		
		[self createSearchOverlay];
				
		letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
		
		[dataModel clearSearchTable];
		
		[self.tableView reloadData];
		
		[self.tableView setContentOffset:CGPointMake(0, 86) animated:NO];
	}
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)theSearchBar 
{
	//[self searchTableView];
	[searchBar resignFirstResponder];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)theSearchBar
{
	[self hideSearchOverlay];
}

- (void)doneSearching_Clicked:(id)sender 
{
	[self updateCount];
	
	searchBar.text = @"";
	[searchBar resignFirstResponder];
	
	letUserSelectRow = YES;
	isSearching = NO;
	self.navigationItem.leftBarButtonItem = nil;
	self.tableView.scrollEnabled = YES;
	
	[self hideSearchOverlay];
	
	[dataModel clearSearchTable];
	
	[self.tableView reloadData];
	
	[self.tableView setContentOffset:CGPointMake(0, 86) animated:YES];
}

#pragma mark TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{	
	if (isSearching)
	{
		return 1;
	}
	else
	{
		NSUInteger count = [[dataModel indexNames] count];
		return count;
	}
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (isSearching)
	{
		NSUInteger count = dataModel.searchCount;
		return count;
	}
	else 
	{
		if ([[dataModel indexCounts] count] > section)
		{
			NSUInteger count = [[[dataModel indexCounts] objectAtIndexSafe:section] intValue];
			return count;
		}
		
		return 0;
	}
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{	
	static NSString *cellIdentifier = @"ArtistCell";
	ArtistUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell)
	{
		cell = [[ArtistUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}

	Artist *anArtist = nil;
	if(isSearching)
	{
		anArtist = [dataModel artistForPositionInSearch:(indexPath.row + 1)];
	}
	else
	{
		if ([[dataModel indexPositions] count] > indexPath.section)
		{
			//DLog(@"indexPositions: %@", [dataModel indexPositions]);
			NSUInteger sectionStartIndex = [[[dataModel indexPositions] objectAtIndexSafe:indexPath.section] intValue];
			anArtist = [dataModel artistForPosition:(sectionStartIndex + indexPath.row)];
		}
	}
	cell.myArtist = anArtist;
	
	[cell.artistNameLabel setText:anArtist.name];
	cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
		
	return cell;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	
	if(isSearching)
		return @"";
	
	if ([[dataModel indexNames] count] == 0)
		return @"";
	
	NSString *title = [[dataModel indexNames] objectAtIndexSafe:section];

	return title;
}


// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView 
{
	if(isSearching)
		return nil;
	
	NSMutableArray *titles = [NSMutableArray arrayWithCapacity:0];
	[titles addObject:@"{search}"];
	[titles addObjectsFromArray:[dataModel indexNames]];
		
	return titles;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index 
{
	if(isSearching)
		return -1;
	
	if (index == 0) 
	{
		if (dropdown.folders == nil || [dropdown.folders count] == 2)
			[self.tableView setContentOffset:CGPointMake(0, 86) animated:NO];
		else
			[self.tableView setContentOffset:CGPointMake(0, 50) animated:NO];
		
		return -1;
	}
	
	return index - 1;
}


- (NSIndexPath *)tableView :(UITableView *)theTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	DLog(@"will indexPath.row: %i", indexPath.row);
	if(letUserSelectRow)
		return indexPath;
	else
		return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath)
		return;
	
	if (viewObjectsS.isCellEnabled)
	{
		DLog(@"did indexPath.row: %i", indexPath.row);
		Artist *anArtist = nil;
		if(isSearching)
		{
			anArtist = [dataModel artistForPositionInSearch:(indexPath.row + 1)];
		}
		else 
		{	
			if ([[dataModel indexPositions] count] > indexPath.section)
			{
				NSUInteger sectionStartIndex = [[[dataModel indexPositions] objectAtIndexSafe:indexPath.section] intValue];
				anArtist = [dataModel artistForPosition:(sectionStartIndex + indexPath.row)];
			}
		}
		AlbumViewController* albumViewController = [[AlbumViewController alloc] initWithArtist:anArtist orAlbum:nil];
		[self pushViewController:albumViewController];
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
		[self loadData:[settingsS rootFoldersSelectedFolderId]];
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

