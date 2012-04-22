//
//  AllAlbumsViewController.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "AllAlbumsViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "AlbumViewController.h"
#import "AllAlbumsUITableViewCell.h"
#import "AllSongsUITableViewCell.h"
#import "Index.h"
#import "Artist.h"
#import "Album.h"
#import "FMDatabaseAdditions.h"
#import "NSString+md5.h"
#import "LoadingScreen.h"
#import "FoldersViewController.h"
#import "SA_OAuthTwitterEngine.h"
#import "CustomUITableView.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
#import "SUSAllAlbumsDAO.h"
#import "FlurryAnalytics.h"
#import "EGORefreshTableHeaderView.h"
#import "SUSAllSongsLoader.h"
#import "SUSAllSongsDAO.h"
#import "NSArray+Additions.h"
#import "UIViewController+PushViewControllerCustom.h"

@implementation AllAlbumsViewController

@synthesize headerView, sectionInfo, dataModel, allSongsDataModel, loadingScreen;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if (settingsS.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)createDataModel
{
	self.dataModel = [[SUSAllAlbumsDAO alloc] init];
	allSongsDataModel.delegate = nil;
	self.allSongsDataModel = [[SUSAllSongsDAO alloc] initWithDelegate:self];
}

- (void)viewDidLoad 
{
	//DLog(@"allAlbums viewDidLoad");
    [super viewDidLoad];
	
	self.title = @"Albums";
	//self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];
	
	//Set defaults
	letUserSelectRow = YES;	
	isSearching = NO;
	
	[self createDataModel];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createDataModel) name:ISMSNotification_ServerSwitched object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadingFinishedNotification) name:ISMSNotification_AllSongsLoadingFinished object:nil];
	
	/*// Add the table fade
	UIImageView *fadeTop = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-top.png"]];
	fadeTop.frame =CGRectMake(0, -10, self.tableView.bounds.size.width, 10);
	fadeTop.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.tableView addSubview:fadeTop];
	[fadeTop release];*/
	
	// Add the pull to refresh view
	refreshHeaderView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, 320.0f, self.tableView.bounds.size.height)];
	refreshHeaderView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:237.0/255.0 alpha:1.0];
	[self.tableView addSubview:refreshHeaderView];
	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
	//else
	//{
		UIImageView *fadeBottom = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]];
		fadeBottom.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
		fadeBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.tableView.tableFooterView = fadeBottom;
	//}
}


-(void)addCount
{
	//Build the search and reload view
	headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 90)];
	headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	headerView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];
	
	reloadButton = [UIButton buttonWithType:UIButtonTypeCustom];
	reloadButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	reloadButton.frame = CGRectMake(0, 0, 320, 40);
	[headerView addSubview:reloadButton];
	
	countLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, 320, 30)];
	countLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	countLabel.backgroundColor = [UIColor clearColor];
	countLabel.textColor = [UIColor colorWithRed:156.0/255.0 green:161.0/255.0 blue:168.0/255.0 alpha:1];
	countLabel.textAlignment = UITextAlignmentCenter;
	countLabel.font = [UIFont boldSystemFontOfSize:30];
	[headerView addSubview:countLabel];
	
	searchBar = [[UISearchBar  alloc] initWithFrame:CGRectMake(0, 50, 320, 40)];
	searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	searchBar.delegate = self;
	searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	searchBar.placeholder = @"Album name";
	[headerView addSubview:searchBar];
	
	reloadTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 36, 320, 12)];
	reloadTimeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	reloadTimeLabel.backgroundColor = [UIColor clearColor];
	reloadTimeLabel.textColor = [UIColor colorWithRed:176.0/255.0 green:181.0/255.0 blue:188.0/255.0 alpha:1];
	reloadTimeLabel.textAlignment = UITextAlignmentCenter;
	reloadTimeLabel.font = [UIFont systemFontOfSize:11];
	[headerView addSubview:reloadTimeLabel];
	
	countLabel.text = [NSString stringWithFormat:@"%i Albums", dataModel.count];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateStyle:NSDateFormatterMediumStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	reloadTimeLabel.text = [NSString stringWithFormat:@"last reload: %@", [formatter stringFromDate:[defaults objectForKey:[NSString stringWithFormat:@"%@songsReloadTime", settingsS.urlString]]]];
	
	self.tableView.tableHeaderView = headerView;
	
	[self.tableView reloadData];
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
		if(musicS.showPlayerIcon)
		{
			self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)];
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

			if ([[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@isAllSongsLoading", settingsS.urlString]] isEqualToString:@"YES"])
			{
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Resume Load?" message:@"If you've reloaded the albums tab since this load started you should choose 'Restart Load'.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Restart Load", @"Resume Load", nil];
				alert.tag = 1;
				[alert show];
			}
			else
			{
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Load?" message:@"This could take a while if you have a big collection.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.\n\nNote: If you've added new artists, you should reload the Folders first." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
				alert.tag = 1;
				[alert show];
			}
		}
	}
	
	[self.tableView reloadData];
	
	[FlurryAnalytics logEvent:@"AllAlbumsTab"];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[self hideLoadingScreen];
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_AllSongsLoadingFinished object:nil];
	 searchBar = nil;
	 url = nil;
}


#pragma mark -
#pragma mark Button handling methods

- (void)reloadAction:(id)sender
{
	if (![SUSAllSongsLoader isLoading])
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Reload?" message:@"This could take a while if you have a big collection.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.\n\nNote: If you've added new artists, you should reload the Folders tab first." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
		alert.tag = 1;
		[alert show];
	}
	else
	{
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Please Wait" message:@"You cannot reload the Albums tab while the Folders or Songs tabs are loading" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
		[self dataSourceDidFinishLoadingNewData];
	}	
}

- (void)alertView:(CustomUIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView.tag == 1)
	{
		if (buttonIndex == 1)
		{
			[self showLoadingScreen];//:[NSArray arrayWithObjects:@"Processing Artist:", @"", @"Processing Album:", @"", nil]];
			
			[allSongsDataModel restartLoad];
			self.tableView.tableHeaderView = nil;
			[self.tableView reloadData];
		}
		else if (buttonIndex == 2)
		{
			[self showLoadingScreen];//:[NSArray arrayWithObjects:@"Processing Album:", @"", @"Processing Song:", @"", nil]];
			
			[allSongsDataModel startLoad];
			self.tableView.tableHeaderView = nil;
			[self.tableView reloadData];
		}	
		
		[self dataSourceDidFinishLoadingNewData];
	}
}

- (void) settingsAction:(id)sender 
{
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverListViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverListViewController animated:YES];
}


- (IBAction)nowPlayingAction:(id)sender
{
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
}

#pragma mark - Search

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
	
	dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
	dismissButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[dismissButton addTarget:self action:@selector(doneSearching_Clicked:) forControlEvents:UIControlEventTouchUpInside];
	dismissButton.frame = self.view.bounds;
	dismissButton.enabled = NO;
	[searchOverlay addSubview:dismissButton];
	
	UIImageView *fadeBottom = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]];
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
	
	UIImageView *fadeBottom = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]];
	fadeBottom.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
	fadeBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.tableView.tableFooterView = fadeBottom;
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar 
{	
	//self.tableView.tableHeaderView;
	
	[self.tableView setContentOffset:CGPointMake(0, 50) animated:YES];
	
	if ([theSearchBar.text length] == 0)
	{
		[self createSearchOverlay];
		
		letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
	}
	
	// Remove the index bar
	isSearching = YES;
	[self.tableView reloadData];
	
	//Add the done button.
	self.navigationItem.leftBarButtonItem = nil;
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneSearching_Clicked:)];
}


- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText
{
	if([searchText length] > 0) 
	{
		[self hideSearchOverlay];
		
		isSearching = YES;
		letUserSelectRow = YES;
		self.tableView.scrollEnabled = YES;
		[dataModel searchForAlbumName:searchText];
	}
	else 
	{
		[self.tableView setContentOffset:CGPointMake(0, 50) animated:YES];
		
		[self createSearchOverlay];
		
		isSearching = NO;
		letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
		[databaseS.allAlbumsDb executeUpdate:@"DROP TABLE allAlbumsSearch"];
	}
	
	[self.tableView reloadData];
}


- (void)searchBarSearchButtonClicked:(UISearchBar *)theSearchBar 
{
	[searchBar resignFirstResponder];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)theSearchBar
{
	[self hideSearchOverlay];
}

- (void)doneSearching_Clicked:(id)sender 
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
	
	[self hideSearchOverlay];
	
	[self.tableView reloadData];
	
	[self.tableView setContentOffset:CGPointMake(0, 28) animated:YES];
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

#pragma mark - Tableview methods

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section 
{
	if(isSearching)
		return @"";
	
	if ([dataModel.index count] == 0)
		return @"";
	
	NSString *title = [(Index *)[dataModel.index objectAtIndexSafe:section] name];
	
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


- (NSIndexPath *)tableView:(UITableView *)theTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if(letUserSelectRow)
		return indexPath;
	else
		return nil;
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
		return [(Index *)[dataModel.index objectAtIndexSafe:section] count];
	}
}

								   
// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *cellIdentifier = @"AllAlbumsCell";
	AllAlbumsUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell)
	{
		cell = [[AllAlbumsUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}
	cell.accessoryType = UITableViewCellAccessoryNone;
		
	Album *anAlbum = nil;
	if(isSearching)
	{
		anAlbum = [dataModel albumForPositionInSearch:(indexPath.row + 1)];
	}
	else
	{
		NSUInteger sectionStartIndex = [(Index *)[dataModel.index objectAtIndexSafe:indexPath.section] position];
		anAlbum = [dataModel albumForPosition:(sectionStartIndex + indexPath.row + 1)];
	}
	
	cell.myId = anAlbum.albumId;
	cell.myArtist = [Artist artistWithName:anAlbum.artistName andArtistId:anAlbum.artistId];
	
	cell.coverArtView.coverArtId = anAlbum.coverArtId;
	
	cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
		
	[cell.albumNameLabel setText:anAlbum.title];
	[cell.artistNameLabel setText:anAlbum.artistName];
	
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath)
		return;
	
	if (viewObjectsS.isCellEnabled)
	{
		Album *anAlbum = nil;
		if(isSearching)
		{
			anAlbum = [dataModel albumForPositionInSearch:(indexPath.row + 1)];
		}
		else
		{
			NSUInteger sectionStartIndex = [(Index *)[dataModel.index objectAtIndexSafe:indexPath.section] position];
			anAlbum = [dataModel albumForPosition:(sectionStartIndex + indexPath.row + 1)];
		}
		
		AlbumViewController* albumViewController = [[AlbumViewController alloc] initWithArtist:nil orAlbum:anAlbum];
		[self pushViewControllerCustom:albumViewController];
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
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
	else if ([notification.name isEqualToString:ISMSNotification_AllSongsSorting])
	{
		loadingScreen.loadingTitle1.text = @"Sorting";
		loadingScreen.loadingTitle2.text = @"";
		loadingScreen.loadingMessage1.text = name;
		loadingScreen.loadingMessage2.text = @"";
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
	self.loadingScreen = [[LoadingScreen alloc] initOnView:self.view withMessage:[NSArray arrayWithObjects:@"Processing Artist:", @"", @"Processing Album:", @"", nil] blockInput:YES mainWindow:NO];
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

