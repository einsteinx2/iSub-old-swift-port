//
//  GenresViewController.m
//  iSub
//
//  Created by Ben Baron on 5/26/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "GenresViewController.h"
#import "GenresArtistViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "iSub-Swift.h"

@interface GenresViewController() <CustomUITableViewCellDelegate>
@end

@implementation GenresViewController
@synthesize isNoGenresScreenShowing, noGenresScreen;

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	self.isNoGenresScreenShowing = NO;
	
	self.title = @"Genres";
	
	if (!self.tableView.tableHeaderView) self.tableView.tableHeaderView = [[UIView alloc] init];		
}


- (void)showNoGenresScreen
{
	if (self.isNoGenresScreenShowing == NO)
	{
		self.isNoGenresScreenShowing = YES;
		self.noGenresScreen = [[UIImageView alloc] init];
		self.noGenresScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
		self.noGenresScreen.frame = CGRectMake(40, 100, 240, 180);
		self.noGenresScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
		self.noGenresScreen.image = [UIImage imageNamed:@"loading-screen-image"];
		self.noGenresScreen.alpha = .80;
		
		UILabel *textLabel = [[UILabel alloc] init];
		textLabel.backgroundColor = [UIColor clearColor];
		textLabel.textColor = [UIColor whiteColor];
		textLabel.font = ISMSBoldFont(30);
		textLabel.textAlignment = NSTextAlignmentCenter;
		textLabel.numberOfLines = 0;
		if (settingsS.isOfflineMode) {
			[textLabel setText:@"No Cached\nSongs"];
		}
		else {
			[textLabel setText:@"Load The\nSongs Tab\nFirst"];
		}
		textLabel.frame = CGRectMake(20, 20, 200, 140);
		[self.noGenresScreen addSubview:textLabel];
		
		[self.view addSubview:self.noGenresScreen];
	}
}

- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
    	
	if (settingsS.isOfflineMode)
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
	if (self.isNoGenresScreenShowing == YES)
	{
		[self.noGenresScreen removeFromSuperview];
		self.isNoGenresScreenShowing = NO;
	}
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
	if (settingsS.isOfflineMode)
		return [databaseS.songCacheDbQueue intForQuery:@"SELECT COUNT(*) FROM genres"];
	else
		return [databaseS.genresDbQueue intForQuery:@"SELECT COUNT(*) FROM genres"];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *cellIdentifier = @"GenresGenreCell";
	CustomUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell)
	{
		cell = [[CustomUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}

    // Configure the cell...
    cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
	
    FMDatabaseQueue *databaseQueue = settingsS.isOfflineMode ? databaseS.songCacheDbQueue : databaseS.genresDbQueue;
    cell.title = [databaseQueue stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", @(indexPath.row + 1)];
	
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
		if (settingsS.isOfflineMode) 
		{
			NSString *title = [databaseS.songCacheDbQueue stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", @(indexPath.row + 1)];
			artistViewController.title = [NSString stringWithString:title ? title : @""];
		}
		else
		{
			NSString *title = [databaseS.genresDbQueue stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", @(indexPath.row + 1)];
			artistViewController.title = [NSString stringWithString:title ? title : @""];
		}
		artistViewController.listOfArtists = [NSMutableArray arrayWithCapacity:1];

		FMDatabaseQueue *dbQueue;
		NSString *query;
		
		if (settingsS.isOfflineMode) 
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
			//DLog(@"Error grabbing the artists for this genre... Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
			}
			else 
			{
				while ([result next])
				{
					NSString *artist = [result stringForColumnIndex:0];
					if (artist) [artistViewController.listOfArtists addObject:artist];
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

#pragma mark - CustomUITableViewCell Delegate -

- (void)tableCellDownloadButtonPressed:(CustomUITableViewCell *)cell
{
    [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
    [self performSelector:@selector(downloadAllSongs:) withObject:cell afterDelay:0.05];
    
    [cell.overlayView disableDownloadButton];
}

- (void)downloadAllSongs:(CustomUITableViewCell *)cell
{
    FMDatabaseQueue *dbQueue;
    NSString *query;
    
    if (settingsS.isOfflineMode)
    {
        dbQueue = databaseS.songCacheDbQueue;
        query = [NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE"];
    }
    else
    {
        dbQueue = databaseS.genresDbQueue;
        query = [NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE"];
    }
    
    NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
    [dbQueue inDatabase:^(FMDatabase *db)
     {
         FMResultSet *result = [db executeQuery:query, cell.title];
         while ([result next])
         {
             @autoreleasepool
             {
                 NSString *md5 = [result stringForColumnIndex:0];
                 if (md5) [songMd5s addObject:md5];
             }
         }
         [result close];
     }];
    
    for (NSString *md5 in songMd5s)
    {
        @autoreleasepool
        {
            ISMSSong *aSong = [ISMSSong songFromGenreDbQueue:md5];
            [aSong addToCacheQueueDbQueue];
        }
    }
    
    // Hide the loading screen
    [viewObjectsS hideLoadingScreen];
}

- (void)tableCellQueueButtonPressed:(CustomUITableViewCell *)cell
{
    [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
    [self performSelector:@selector(queueAllSongs:) withObject:cell afterDelay:0.05];
}

- (void)queueAllSongs:(CustomUITableViewCell *)cell
{
    FMDatabaseQueue *dbQueue;
    NSString *query;
    
    if (settingsS.isOfflineMode)
    {
        dbQueue = databaseS.songCacheDbQueue;
        query = @"SELECT md5 FROM cachedSongsLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE";
    }
    else
    {
        dbQueue = databaseS.genresDbQueue;
        query = @"SELECT md5 FROM genresLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE";
    }
    
    NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
    [dbQueue inDatabase:^(FMDatabase *db)
     {
         FMResultSet *result = [db executeQuery:query, cell.title];
         
         while ([result next])
         {
             @autoreleasepool
             {
                 NSString *md5 = [result stringForColumnIndex:0];
                 if (md5) [songMd5s addObject:md5];
             }
         }
         [result close];
     }];
    
    for (NSString *md5 in songMd5s)
    {
        @autoreleasepool
        {
            ISMSSong *aSong = [ISMSSong songFromGenreDbQueue:md5];
            [aSong addToCurrentPlaylistDbQueue];
        }
    }
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
    
    [viewObjectsS hideLoadingScreen];
}

@end

