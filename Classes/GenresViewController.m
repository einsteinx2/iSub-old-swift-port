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
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueueAdditions.h"
#import "NSString+md5.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "SavedSettings.h"
#import "UIViewController+PushViewControllerCustom.h"

@implementation GenresViewController


#pragma mark -
#pragma mark View lifecycle

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if (settingsS.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];

	//DLog(@"Cache viewDidLoad");
	
	
	isNoGenresScreenShowing = NO;
	
	self.title = @"Genres";
	
	if (viewObjectsS.isOfflineMode)
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)];
	
	//Set defaults
	//letUserSelectRow = YES;
	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}

	[self.tableView addHeaderShadow];
		
	[self.tableView addFooterShadow];
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
		if (viewObjectsS.isOfflineMode) {
			[textLabel setText:@"No Cached\nSongs"];
		}
		else {
			[textLabel setText:@"Load The\nSongs Tab\nFirst"];
		}
		textLabel.frame = CGRectMake(20, 20, 200, 140);
		[noGenresScreen addSubview:textLabel];
		
		[self.view addSubview:noGenresScreen];
		
	}
}


- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
	
	if(musicS.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	if (viewObjectsS.isOfflineMode)
	{
		if ([databaseS.songCacheDbQueue intForQuery:@"SELECT COUNT(*) FROM genres"] == 0)
		{
			[self showNoGenresScreen];
		}
	}
	else 
	{
		if ([databaseS.genresDbQueue intForQuery:@"SELECT COUNT(*) FROM genres"] == 0)
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
}


- (IBAction)nowPlayingAction:(id)sender
{
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
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
	if (viewObjectsS.isOfflineMode)
		return [databaseS.songCacheDbQueue intForQuery:@"SELECT COUNT(*) FROM genres"];
	else
		return [databaseS.genresDbQueue intForQuery:@"SELECT COUNT(*) FROM genres"];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *cellIdentifier = @"GenresGenreCell";
	GenresGenreUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell)
	{
		cell = [[GenresGenreUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}

    // Configure the cell...
    cell.backgroundView = [[UIView alloc] init];
	if(indexPath.row % 2 == 0)
		cell.backgroundView.backgroundColor = [UIColor whiteColor];
	else
		cell.backgroundView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];
	
	if (viewObjectsS.isOfflineMode)
	{
		cell.genreNameLabel.text = [databaseS.songCacheDbQueue stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", [NSNumber numberWithInt:indexPath.row + 1]];
	}
	else
	{
		cell.genreNameLabel.text = [databaseS.genresDbQueue stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", [NSNumber numberWithInt:indexPath.row + 1]];
	}
	
    return cell;
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{	
	if (!indexPath)
		return;
	
	if (viewObjectsS.isCellEnabled)
	{
		GenresArtistViewController *artistViewController = [[GenresArtistViewController alloc] initWithNibName:@"GenresArtistViewController" bundle:nil];
		if (viewObjectsS.isOfflineMode) 
		{
			NSString *title = [databaseS.songCacheDbQueue stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", [NSNumber numberWithInt:indexPath.row + 1]];
			artistViewController.title = [NSString stringWithString:title ? title : @""];
		}
		else
		{
			NSString *title = [databaseS.genresDbQueue stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", [NSNumber numberWithInt:indexPath.row + 1]];
			artistViewController.title = [NSString stringWithString:title ? title : @""];
		}
		artistViewController.listOfArtists = [NSMutableArray arrayWithCapacity:1];

		FMDatabaseQueue *dbQueue;
		NSString *query;
		
		if (viewObjectsS.isOfflineMode) 
		{
			dbQueue = databaseS.songCacheDbQueue;
			query = @"SELECT seg1 FROM cachedSongsLayout a INNER JOIN genresSongs b ON a.md5 = b.md5 WHERE b.genre = ? GROUP BY seg1 ORDER BY seg1 COLLATE NOCASE";
		}
		else
		{
			dbQueue = databaseS.genresDbQueue;
			query = @"SELECT seg1 FROM genresLayout a INNER JOIN genresSongs b ON a.md5 = b.md5 WHERE b.genre = ? GROUP BY seg1 ORDER BY seg1 COLLATE NOCASE";
		}
		
		[dbQueue inDatabase:^(FMDatabase *db)
		{
			FMResultSet *result = [db executeQuery:query, artistViewController.title];
			if ([db hadError])
			{
				DLog(@"Error grabbing the artists for this genre... Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
			}
			else 
			{
				while ([result next])
				{
					if ([result stringForColumnIndex:0] != nil)
						[artistViewController.listOfArtists addObject:[NSString stringWithString:[result stringForColumnIndex:0]]];
				}
			}
			[result close];
		}];
		
		[self pushViewControllerCustom:artistViewController];
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning 
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}



@end

