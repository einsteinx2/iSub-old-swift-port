//
//  iPadMainMenu.m
//  iSub
//
//  Created by bbaron on 10/21/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "iPadMainMenu.h"
#import "NewHomeViewController.h"
#import "RootViewController.h"
#import "AllAlbumsViewController.h"
#import "AllSongsViewController.h"
#import "PlaylistsViewController.h"
#import "PlayingViewController.h"
#import "BookmarksViewController.h"
#import "GenresViewController.h"
#import "CacheViewController.h"
#import "ChatViewController.h"
#import "iSubAppDelegate.h"
#import "MGSplitViewController.h"
#import "InitialDetailViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ViewObjectsSingleton.h"
#import "SavedSettings.h"

@implementation iPadMainMenu

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad 
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
	
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	
	[self loadTable];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showPlayer) name:@"showPlayer" object:nil];
}

- (void)centerCells:(UIInterfaceOrientation)orientation
{
	float totalCellHeight = 93.5 * [rowNames count];
	if (UIInterfaceOrientationIsLandscape(orientation))
	{
		self.tableView.tableHeaderView = nil;
	}
	else
	{
		float height = (1004.0 - totalCellHeight) / 2.0;
		CGRect frame = CGRectMake(0, 0, 200, height);
		UIView *header = [[[UIView alloc] initWithFrame:frame] autorelease];
		self.tableView.tableHeaderView = header;
	}
}

- (void)loadTable
{
	self.tableView.scrollEnabled = NO;
	
	if ([SavedSettings sharedInstance].isSongsTabEnabled)
	{
		self.tableView.scrollEnabled = YES;
		rowNames = [[NSArray alloc] initWithObjects:@"Home", @"Player", @"Folders", @"Playlists", @"Playing", @"Bookmarks", @"Cache", @"Chat", @"Genres", @"Albums", @"Songs", nil];
	}
	else
	{
		rowNames = [[NSArray alloc] initWithObjects:@"Home", @"Player", @"Folders", @"Playlists", @"Playing", @"Bookmarks", @"Cache", @"Chat", nil];
	}
	
	[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
	
	//[self centerCells:[UIDevice currentDevice].orientation];
	[self centerCells:self.interfaceOrientation];
}

- (void)showPlayer
{
	[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0] animated:YES scrollPosition:UITableViewScrollPositionMiddle];
	[self tableView:self.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];
}

- (void)showSettings
{
	if ([ViewObjectsSingleton sharedInstance].isSettingsShowing == NO)
	{
		[ViewObjectsSingleton sharedInstance].isSettingsShowing = YES;
		[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
		[self tableView:self.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
		[appDelegate.homeNavigationController popToRootViewControllerAnimated:NO];
		[(NewHomeViewController*)appDelegate.homeNavigationController.topViewController settings];
	}
}

/*
- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
}
*/

- (void)viewDidAppear:(BOOL)animated 
{
    [super viewDidAppear:animated];
	
	[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionTop];
	[self tableView:self.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
}

/*
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}
*/


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Override to allow orientations other than the default portrait orientation.
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[self centerCells:toInterfaceOrientation];
}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
    // Return the number of rows in the section.
    return [rowNames count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		//UIView *v = [[[UIView alloc] init] autorelease];
		//v.backgroundColor = [UIColor clearColor];
		UIImageView *v = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ipad-menu-selected-background.png"]] autorelease];
		cell.selectedBackgroundView = v;
    }
    
    // Configure the cell...
	//DLog(@"row %i: %@", indexPath.row, [rowNames objectAtIndex:indexPath.row]);
	cell.textLabel.text = [rowNames objectAtIndex:indexPath.row];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:36];
	cell.textLabel.textColor = [UIColor whiteColor];
	cell.textLabel.textAlignment = UITextAlignmentRight;
    
    return cell;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/


/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{	
	appDelegate.splitView.detailViewController.view.hidden = YES;
	if (indexPath.row == 0)
	{
		// Home tab
		if (appDelegate.homeNavigationController == nil)
		{
			NewHomeViewController *homeViewController = [[NewHomeViewController alloc] initWithNibName:@"NewHomeViewController~iPad" bundle:nil];
			appDelegate.homeNavigationController = [[UINavigationController alloc] initWithRootViewController:homeViewController];
			[appDelegate.homeNavigationController viewDidLoad];
		}
		appDelegate.splitView.detailViewController = appDelegate.homeNavigationController;
	}
	else if (indexPath.row == 1)
	{
		// Player tab
		if (appDelegate.playerNavigationController == nil)
		{
			iPhoneStreamingPlayerViewController *playerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController~iPad" bundle:nil];
			appDelegate.playerNavigationController = [[UINavigationController alloc] initWithRootViewController:playerViewController];
			[appDelegate.playerNavigationController viewDidLoad];
		}
		appDelegate.splitView.detailViewController = appDelegate.playerNavigationController;
	}
	else if (indexPath.row == 2)
	{
		// Artists tab
		if (appDelegate.artistsNavigationController == nil)
		{
			RootViewController *artistsViewController = [[RootViewController alloc] initWithNibName:@"RootViewController" bundle:nil];
			appDelegate.artistsNavigationController = [[UINavigationController alloc] initWithRootViewController:artistsViewController];
			[appDelegate.artistsNavigationController viewDidLoad];
		}
		appDelegate.splitView.detailViewController = appDelegate.artistsNavigationController;
	}
	else if (indexPath.row == 3)
	{
		// Playlists tab
		if (appDelegate.playlistsNavigationController == nil)
		{
			PlaylistsViewController *playlistsViewController = [[PlaylistsViewController alloc] initWithNibName:@"PlaylistsViewController" bundle:nil];
			appDelegate.playlistsNavigationController = [[UINavigationController alloc] initWithRootViewController:playlistsViewController];
			[appDelegate.playlistsNavigationController viewDidLoad];
		}
		appDelegate.splitView.detailViewController = appDelegate.playlistsNavigationController;
	}
	else if (indexPath.row == 4)
	{
		// Playing tab
		if (appDelegate.playingNavigationController == nil)
		{
			PlayingViewController *playingViewController = [[PlayingViewController alloc] initWithNibName:@"PlayingViewController" bundle:nil];
			appDelegate.playingNavigationController = [[UINavigationController alloc] initWithRootViewController:playingViewController];
			[appDelegate.playingNavigationController viewDidLoad];
		}
		appDelegate.splitView.detailViewController = appDelegate.playingNavigationController;
	}
	else if (indexPath.row == 5)
	{
		// Bookmarks tab
		if (appDelegate.bookmarksNavigationController == nil)
		{
			BookmarksViewController *bookmarksViewController = [[BookmarksViewController alloc] initWithNibName:@"BookmarksViewController" bundle:nil];
			appDelegate.bookmarksNavigationController = [[UINavigationController alloc] initWithRootViewController:bookmarksViewController];
			[appDelegate.bookmarksNavigationController viewDidLoad];
		}
		appDelegate.splitView.detailViewController = appDelegate.bookmarksNavigationController;
	}
	else if (indexPath.row == 6)
	{
		// Cache tab
		if (appDelegate.cacheNavigationController == nil)
		{
			CacheViewController *cacheViewController = [[CacheViewController alloc] initWithNibName:@"CacheViewController" bundle:nil];
			appDelegate.cacheNavigationController = [[UINavigationController alloc] initWithRootViewController:cacheViewController];
			[appDelegate.cacheNavigationController viewDidLoad];
		}
		appDelegate.splitView.detailViewController = appDelegate.cacheNavigationController;
	}
	else if (indexPath.row == 7)
	{
		// Chat tab
		if (appDelegate.chatNavigationController == nil)
		{
			ChatViewController *chatViewController = [[ChatViewController alloc] initWithNibName:@"ChatViewController" bundle:nil];
			appDelegate.chatNavigationController = [[UINavigationController alloc] initWithRootViewController:chatViewController];
			[appDelegate.chatNavigationController viewDidLoad];
		}
		appDelegate.splitView.detailViewController = appDelegate.chatNavigationController;
	}
	else if (indexPath.row == 8)
	{
		// Genre tab
		if (appDelegate.genresNavigationController == nil)
		{
			GenresViewController *genresViewController = [[GenresViewController alloc] initWithNibName:@"GenresViewController" bundle:nil];
			appDelegate.genresNavigationController = [[UINavigationController alloc] initWithRootViewController:genresViewController];
			[appDelegate.genresNavigationController viewDidLoad];
		}
		appDelegate.splitView.detailViewController = appDelegate.genresNavigationController;
	}
	else if (indexPath.row == 9)
	{
		// Albums tab
		if (appDelegate.allAlbumsNavigationController == nil)
		{
			AllAlbumsViewController *allAlbumsViewController = [[AllAlbumsViewController alloc] initWithNibName:@"AllAlbumsViewController" bundle:nil];
			appDelegate.allAlbumsNavigationController = [[UINavigationController alloc] initWithRootViewController:allAlbumsViewController];
			[appDelegate.allAlbumsNavigationController viewDidLoad];
		}
		appDelegate.splitView.detailViewController = appDelegate.allAlbumsNavigationController;
	}
	else if (indexPath.row == 10)
	{
		// Songs tab
		if (appDelegate.allSongsNavigationController == nil)
		{
			AllSongsViewController *allSongsViewController = [[AllSongsViewController alloc] initWithNibName:@"AllSongsViewController" bundle:nil];
			appDelegate.allSongsNavigationController = [[UINavigationController alloc] initWithRootViewController:allSongsViewController];
			[appDelegate.allSongsNavigationController viewDidLoad];
		}
		appDelegate.splitView.detailViewController = appDelegate.allSongsNavigationController;
	}
	[appDelegate.splitView.detailViewController willRotateToInterfaceOrientation:(UIInterfaceOrientation)[[UIDevice currentDevice] orientation] duration:0];
	[appDelegate.splitView.detailViewController viewWillAppear:NO];
	appDelegate.splitView.detailViewController.view.hidden = NO;
	[(UINavigationController*)appDelegate.splitView.detailViewController navigationBar].barStyle = UIBarStyleBlack;
	
	if ([tableView indexPathForSelectedRow].row == lastSelectedRow)
	{
		[(UINavigationController *)appDelegate.splitView.detailViewController popToRootViewControllerAnimated:YES];
	}
	
	lastSelectedRow = indexPath.row;
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}


@end

