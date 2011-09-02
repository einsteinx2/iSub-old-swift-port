//
//  GenresViewController.m
//  iSub
//
//  Created by Ben Baron on 5/26/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "GenresViewController.h"
#import "GenresArtistViewController.h"
#import "GenresGenreUITableViewCell.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString-md5.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "SavedSettings.h"

@implementation GenresViewController


#pragma mark -
#pragma mark View lifecycle

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	//if ([[[iSubAppDelegate sharedInstance].settingsDictionary objectForKey:@"lockRotationSetting"] isEqualToString:@"YES"] && inOrientation != UIInterfaceOrientationPortrait)
	if ([SavedSettings sharedInstance].isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];

	//DLog(@"Cache viewDidLoad");
	
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicSingleton sharedInstance];
	databaseControls = [DatabaseSingleton sharedInstance];
	
	isNoGenresScreenShowing = NO;
	
	self.title = @"Genres";
	
	if (viewObjects.isOfflineMode)
		self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];
	
	//Set defaults
	//letUserSelectRow = YES;	

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


- (void)showNoGenresScreen
{
	if (isNoGenresScreenShowing == NO)
	{
		isNoGenresScreenShowing = YES;
		noGenresScreen = [[UIImageView alloc] init];
		noGenresScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
		noGenresScreen.frame = CGRectMake(40, 100, 240, 180);
		noGenresScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
		noGenresScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
		noGenresScreen.alpha = .80;
		
		UILabel *textLabel = [[UILabel alloc] init];
		textLabel.backgroundColor = [UIColor clearColor];
		textLabel.textColor = [UIColor whiteColor];
		textLabel.font = [UIFont boldSystemFontOfSize:32];
		textLabel.textAlignment = UITextAlignmentCenter;
		textLabel.numberOfLines = 0;
		if (viewObjects.isOfflineMode) {
			[textLabel setText:@"No Cached\nSongs"];
		}
		else {
			[textLabel setText:@"Load The\nSongs Tab\nFirst"];
		}
		textLabel.frame = CGRectMake(20, 20, 200, 140);
		[noGenresScreen addSubview:textLabel];
		[textLabel release];
		
		[self.view addSubview:noGenresScreen];
		
		[noGenresScreen release];
	}
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
	
	if (viewObjects.isOfflineMode)
	{
		if ([databaseControls.songCacheDb intForQuery:@"SELECT COUNT(*) FROM genres"] == 0)
		{
			[self showNoGenresScreen];
		}
	}
	else 
	{
		if ([databaseControls.genresDb intForQuery:@"SELECT COUNT(*) FROM genres"] == 0)
		{
			[self showNoGenresScreen];
		}
	}

	[self.tableView reloadData];
}


-(void)viewWillDisappear:(BOOL)animated
{
	if (isNoGenresScreenShowing == YES)
	{
		[noGenresScreen removeFromSuperview];
		isNoGenresScreenShowing = NO;
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
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1; 
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
    // Return the number of rows in the section.
	if (viewObjects.isOfflineMode)
		return [databaseControls.songCacheDb intForQuery:@"SELECT COUNT(*) FROM genres"];
	else
		return [databaseControls.genresDb intForQuery:@"SELECT COUNT(*) FROM genres"];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
	GenresGenreUITableViewCell *cell = [[[GenresGenreUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];    
    // Configure the cell...
    cell.backgroundView = [[[UIView alloc] init] autorelease];
	if(indexPath.row % 2 == 0)
		cell.backgroundView.backgroundColor = [UIColor whiteColor];
	else
		cell.backgroundView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];
	
	if (viewObjects.isOfflineMode) {
		cell.genreNameLabel.text = [databaseControls.songCacheDb stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", [NSNumber numberWithInt:indexPath.row + 1]];
	}
	else {
		cell.genreNameLabel.text = [databaseControls.genresDb stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", [NSNumber numberWithInt:indexPath.row + 1]];
	}
	
    return cell;
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{	
	if (viewObjects.isCellEnabled)
	{
		GenresArtistViewController *artistViewController = [[GenresArtistViewController alloc] initWithNibName:@"GenresArtistViewController" bundle:nil];
		if (viewObjects.isOfflineMode) 
		{
			artistViewController.title = [NSString stringWithString:[databaseControls.songCacheDb stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", [NSNumber numberWithInt:indexPath.row + 1]]];
		}
		else
		{
			artistViewController.title = [NSString stringWithString:[databaseControls.genresDb stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", [NSNumber numberWithInt:indexPath.row + 1]]];
		}
		artistViewController.listOfArtists = [NSMutableArray arrayWithCapacity:1];
		//artistViewController.listOfArtists = [[NSMutableArray alloc] init];
		FMResultSet *result;
		if (viewObjects.isOfflineMode) 
		{
			//result = [appDelegate.songCacheDb executeQuery:@"SELECT seg1 FROM cachedSongsLayout a INNER JOIN genresSongs b ON a.md5 = b.md5 WHERE b.genre = ? GROUP BY seg1 ORDER BY seg1 COLLATE NOCASE", artistViewController.title];
			result = [databaseControls.songCacheDb executeQuery:@"SELECT seg1 FROM cachedSongsLayout a INNER JOIN genresSongs b ON a.md5 = b.md5 WHERE b.genre = ? GROUP BY seg1 ORDER BY seg1 COLLATE NOCASE", artistViewController.title];
			if ([databaseControls.songCacheDb hadError])
				DLog(@"Error grabbing the artists for this genre... Err %d: %@", [databaseControls.songCacheDb lastErrorCode], [databaseControls.songCacheDb lastErrorMessage]);
		}
		else 
		{
			//result = [databaseControls.genresDb executeQuery:@"SELECT seg1 FROM genresLayout a INNER JOIN genresSongs b ON a.md5 = b.md5 WHERE b.genre = ? GROUP BY seg1 ORDER BY seg1 COLLATE NOCASE", artistViewController.title];
			result = [databaseControls.genresDb executeQuery:@"SELECT seg1 FROM genresLayout a INNER JOIN genresSongs b ON a.md5 = b.md5 WHERE b.genre = ? GROUP BY seg1 ORDER BY seg1 COLLATE NOCASE", artistViewController.title];
			if ([databaseControls.genresDb hadError])
				DLog(@"Error grabbing the artists for this genre... Err %d: %@", [databaseControls.genresDb lastErrorCode], [databaseControls.genresDb lastErrorMessage]);
		}
		while ([result next])
		{
			[artistViewController.listOfArtists addObject:[NSString stringWithString:[result stringForColumnIndex:0]]];
		}
		[result close];
		
		[self.navigationController pushViewController:artistViewController animated:YES];
		[artistViewController release];
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
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

