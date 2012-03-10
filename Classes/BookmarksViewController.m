//
//  BookmarksViewController.m
//  iSub
//
//  Created by Ben Baron on 5/10/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "BookmarksViewController.h"
#import "BookmarkUITableViewCell.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "ServerListViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "Song.h"
#import "AsynchronousImageView.h"
#import "FMDatabaseAdditions.h"
#import "NSString+md5.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
#import "NSString+time.h"
#import "FlurryAnalytics.h"
#import "Song+DAO.h"
#import "PlaylistSingleton.h"
#import "NSNotificationCenter+MainThread.h"

@implementation BookmarksViewController

#pragma mark -
#pragma mark View lifecycle

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if (settingsS.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	//DLog(@"Cache viewDidLoad");
	
	
	viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
	//viewObjectsS.multiDeleteList = nil; viewObjectsS.multiDeleteList = [[NSMutableArray alloc] init];
	isNoBookmarksScreenShowing = NO;
	
	self.tableView.separatorColor = [UIColor clearColor];
	
	self.title = @"Bookmarks";
	
	if (viewObjectsS.isOfflineMode)
		self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];
	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
	
	// Add the table fade
	/*UIImageView *fadeTop = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-top.png"]];
	fadeTop.frame =CGRectMake(0, -10, self.tableView.bounds.size.width, 10);
	fadeTop.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.tableView addSubview:fadeTop];
	[fadeTop release];*/
		
	UIImageView *fadeBottom = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]] autorelease];
	fadeBottom.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
	fadeBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.tableView.tableFooterView = fadeBottom;
}


- (void)viewWillAppear:(BOOL)animated
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
	
	self.tableView.tableHeaderView = nil;
	
	if (isNoBookmarksScreenShowing == YES)
	{
		[noBookmarksScreen removeFromSuperview];
		isNoBookmarksScreenShowing = NO;
	}
	
	NSUInteger bookmarksCount = [databaseS.bookmarksDb intForQuery:@"SELECT COUNT(*) FROM bookmarks"];
	if (bookmarksCount == 0)
	{
		isNoBookmarksScreenShowing = YES;
		noBookmarksScreen = [[UIImageView alloc] init];
		noBookmarksScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
		noBookmarksScreen.frame = CGRectMake(40, 100, 240, 180);
		noBookmarksScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
		noBookmarksScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
		noBookmarksScreen.alpha = .80;
		
		UILabel *textLabel = [[UILabel alloc] init];
		textLabel.backgroundColor = [UIColor clearColor];
		textLabel.textColor = [UIColor whiteColor];
		textLabel.font = [UIFont boldSystemFontOfSize:32];
		textLabel.textAlignment = UITextAlignmentCenter;
		textLabel.numberOfLines = 0;
		if (viewObjectsS.isOfflineMode) {
			[textLabel setText:@"No Offline\nBookmarks"];
		}
		else {
			[textLabel setText:@"No Saved\nBookmarks"];
		}
		textLabel.frame = CGRectMake(20, 20, 200, 140);
		[noBookmarksScreen addSubview:textLabel];
		[textLabel release];
		
		[self.view addSubview:noBookmarksScreen];
		
		[noBookmarksScreen release];
	}
	else
	{
		// Add the header
		headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)] autorelease];
		headerView.backgroundColor = [UIColor colorWithWhite:.3 alpha:1];
		
		bookmarkCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 230, 50)];
		bookmarkCountLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		bookmarkCountLabel.backgroundColor = [UIColor clearColor];
		bookmarkCountLabel.textColor = [UIColor whiteColor];
		bookmarkCountLabel.textAlignment = UITextAlignmentCenter;
		bookmarkCountLabel.font = [UIFont boldSystemFontOfSize:22];
		if (bookmarksCount == 1)
			bookmarkCountLabel.text = [NSString stringWithFormat:@"1 Bookmark"];
		else 
			bookmarkCountLabel.text = [NSString stringWithFormat:@"%i Bookmarks", bookmarksCount];
		[headerView addSubview:bookmarkCountLabel];
		[bookmarkCountLabel release];
		
		deleteBookmarksButton = [UIButton buttonWithType:UIButtonTypeCustom];
		deleteBookmarksButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		deleteBookmarksButton.frame = CGRectMake(0, 0, 230, 50);
		[deleteBookmarksButton addTarget:self action:@selector(deleteBookmarksAction:) forControlEvents:UIControlEventTouchUpInside];
		[headerView addSubview:deleteBookmarksButton];
		
		spacerLabel = [[UILabel alloc] initWithFrame:CGRectMake(226, 0, 6, 50)];
		spacerLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		spacerLabel.backgroundColor = [UIColor clearColor];
		spacerLabel.textColor = [UIColor whiteColor];
		spacerLabel.font = [UIFont systemFontOfSize:40];
		spacerLabel.text = @"|";
		[headerView addSubview:spacerLabel];
		[spacerLabel release];	
		
		editBookmarksLabel = [[UILabel alloc] initWithFrame:CGRectMake(234, 0, 86, 50)];
		editBookmarksLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
		editBookmarksLabel.backgroundColor = [UIColor clearColor];
		editBookmarksLabel.textColor = [UIColor whiteColor];
		editBookmarksLabel.textAlignment = UITextAlignmentCenter;
		editBookmarksLabel.font = [UIFont boldSystemFontOfSize:22];
		editBookmarksLabel.text = @"Edit";
		[headerView addSubview:editBookmarksLabel];
		[editBookmarksLabel release];
		
		editBookmarksButton = [UIButton buttonWithType:UIButtonTypeCustom];
		editBookmarksButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
		editBookmarksButton.frame = CGRectMake(234, 0, 86, 40);
		[editBookmarksButton addTarget:self action:@selector(editBookmarksAction:) forControlEvents:UIControlEventTouchUpInside];
		[headerView addSubview:editBookmarksButton];	
		
		deleteBookmarksLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 227, 50)];
		deleteBookmarksLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		deleteBookmarksLabel.backgroundColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:.5];
		deleteBookmarksLabel.textColor = [UIColor whiteColor];
		deleteBookmarksLabel.textAlignment = UITextAlignmentCenter;
		deleteBookmarksLabel.font = [UIFont boldSystemFontOfSize:22];
		deleteBookmarksLabel.adjustsFontSizeToFitWidth = YES;
		deleteBookmarksLabel.minimumFontSize = 12;
		deleteBookmarksLabel.text = @"Remove # Bookmarks";
		deleteBookmarksLabel.hidden = YES;
		[headerView addSubview:deleteBookmarksLabel];
		[deleteBookmarksLabel release];
		
		self.tableView.tableHeaderView = headerView;
	}
	
	[self.tableView reloadData];
	
	[FlurryAnalytics logEvent:@"BookmarksTab"];
}


-(void)viewWillDisappear:(BOOL)animated
{
	
}


- (void) showDeleteButton
{
	if ([viewObjectsS.multiDeleteList count] == 0)
	{
		deleteBookmarksLabel.text = @"Clear Bookmarks";
	}
	else if ([viewObjectsS.multiDeleteList count] == 1)
	{
		deleteBookmarksLabel.text = @"Remove 1 Bookmark";
	}
	else
	{
		deleteBookmarksLabel.text = [NSString stringWithFormat:@"Remove %i Bookmarks", [viewObjectsS.multiDeleteList count]];
	}
	
	bookmarkCountLabel.hidden = YES;
	deleteBookmarksLabel.hidden = NO;
}


- (void) hideDeleteButton
{
	if ([viewObjectsS.multiDeleteList count] == 0)
	{
		if (!self.tableView.editing)
		{
			bookmarkCountLabel.hidden = NO;
			deleteBookmarksLabel.hidden = YES;
		}
		else
		{
			deleteBookmarksLabel.text = @"Clear Bookmarks";
		}
	}
	else if ([viewObjectsS.multiDeleteList count] == 1)
	{
		deleteBookmarksLabel.text = @"Remove 1 Bookmark";
	}
	else 
	{
		deleteBookmarksLabel.text = [NSString stringWithFormat:@"Remove %i Bookmarks", [viewObjectsS.multiDeleteList count]];
	}
}



- (void)editBookmarksAction:(id)sender
{
	if (self.tableView.editing == NO)
	{
		[self.tableView reloadData];
		[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(showDeleteButton) name:@"showDeleteButton" object: nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(hideDeleteButton) name:@"hideDeleteButton" object: nil];
		viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		//viewObjectsS.multiDeleteList = nil; viewObjectsS.multiDeleteList = [[NSMutableArray alloc] init];
		[self.tableView setEditing:YES animated:YES];
		editBookmarksLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
		editBookmarksLabel.text = @"Done";
		[self showDeleteButton];
		
		[NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(showDeleteToggle) userInfo:nil repeats:NO];
	}
	else 
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"showDeleteButton" object:nil];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideDeleteButton" object:nil];
		viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		//viewObjectsS.multiDeleteList = nil; viewObjectsS.multiDeleteList = [[NSMutableArray alloc] init];
		[self hideDeleteButton];
		[self.tableView setEditing:NO animated:YES];
		editBookmarksLabel.backgroundColor = [UIColor clearColor];
		editBookmarksLabel.text = @"Edit";
		
		// Reload the table
		//[self.tableView reloadData];
		[self viewWillAppear:NO];
	}
}


- (void) showDeleteToggle
{
	// Show the delete toggle for already visible cells
	for (id cell in self.tableView.visibleCells) 
	{
		[[cell deleteToggleImage] setHidden:NO];
	}
}


- (void) deleteBookmarksAction:(id)sender
{
	if ([deleteBookmarksLabel.text isEqualToString:@"Clear Bookmarks"])
	{
		[databaseS.bookmarksDb executeUpdate:@"DELETE FROM bookmarks"];
		[databaseS.bookmarksDb executeUpdate:@"VACUUM"];
		[self editBookmarksAction:nil];
		
		// Reload table data
		[self viewWillAppear:NO];
	}
	else
	{
		// Sort the multiDeleteList to make sure it's accending
		[viewObjectsS.multiDeleteList sortUsingSelector:@selector(compare:)];
		//DLog(@"multiDeleteList: %@", viewObjectsS.multiDeleteList);
		
		for (NSNumber *index in [viewObjectsS.multiDeleteList reverseObjectEnumerator])
		{
			int row = [index intValue] + 1;
			[databaseS.bookmarksDb executeUpdate:[NSString stringWithFormat:@"DELETE FROM bookmarks WHERE ROWID = %i", row]];
		}
		[databaseS.bookmarksDb executeUpdate:@"DROP TABLE bookmarksTemp"];
		[databaseS.bookmarksDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarksTemp (name TEXT, position INTEGER, %@, bytes INTEGER)", [Song standardSongColumnSchema]]];
		[databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks"];
		[databaseS.bookmarksDb executeUpdate:@"DROP TABLE bookmarks"];
		[databaseS.bookmarksDb executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];
		[databaseS.bookmarksDb executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
		
		// Create indexPaths from multiDeleteList
		NSMutableArray *indexes = [[NSMutableArray alloc] init];
		for (NSNumber *index in viewObjectsS.multiDeleteList)
		{
			[indexes addObject:[NSIndexPath indexPathForRow:[index integerValue] inSection:0]];
		}
		[self.tableView deleteRowsAtIndexPaths:indexes withRowAnimation:YES];
		
		[indexes release];
		
		[self editBookmarksAction:nil];
	}
}


// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath 
{
	// Move the bookmark
	NSInteger fromRow = fromIndexPath.row + 1;
	NSInteger toRow = toIndexPath.row + 1;
	
	[databaseS.bookmarksDb executeUpdate:@"DROP TABLE bookmarksTemp"];
	[databaseS.bookmarksDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarksTemp (name TEXT, position INTEGER, %@, bytes INTEGER)", [Song standardSongColumnSchema]]];
		
	if (fromRow < toRow)
	{
		[databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID < ?", [NSNumber numberWithInt:fromRow]];
		[databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID > ? AND ROWID <= ?", [NSNumber numberWithInt:fromRow], [NSNumber numberWithInt:toRow]];
		[databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
		[databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID > ?", [NSNumber numberWithInt:toRow]];
		
		[databaseS.bookmarksDb executeUpdate:@"DROP TABLE bookmarks"];
		[databaseS.bookmarksDb executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];
		[databaseS.bookmarksDb executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
	}
	else
	{
		[databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID < ?", [NSNumber numberWithInt:toRow]];
		[databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
		[databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID >= ? AND ROWID < ?", [NSNumber numberWithInt:toRow], [NSNumber numberWithInt:fromRow]];
		[databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID > ?", [NSNumber numberWithInt:fromRow]];
		
		[databaseS.bookmarksDb executeUpdate:@"DROP TABLE bookmarks"];
		[databaseS.bookmarksDb executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];
		[databaseS.bookmarksDb executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
	}
	
	
	// Fix the multiDeleteList to reflect the new row positions
	//DLog(@"multiDeleteList: %@", viewObjectsS.multiDeleteList);
	if ([viewObjectsS.multiDeleteList count] > 0)
	{
		NSMutableArray *tempMultiDeleteList = [[NSMutableArray alloc] init];
		int newPosition;
		for (NSNumber *position in viewObjectsS.multiDeleteList)
		{
			if (fromIndexPath.row > toIndexPath.row)
			{
				if ([position intValue] >= toIndexPath.row && [position intValue] <= fromIndexPath.row)
				{
					if ([position intValue] == fromIndexPath.row)
					{
						[tempMultiDeleteList addObject:[NSNumber numberWithInt:toIndexPath.row]];
					}
					else 
					{
						newPosition = [position intValue] + 1;
						[tempMultiDeleteList addObject:[NSNumber numberWithInt:newPosition]];
					}
				}
				else
				{
					[tempMultiDeleteList addObject:position];
				}
			}
			else
			{
				if ([position intValue] <= toIndexPath.row && [position intValue] >= fromIndexPath.row)
				{
					if ([position intValue] == fromIndexPath.row)
					{
						[tempMultiDeleteList addObject:[NSNumber numberWithInt:toIndexPath.row]];
					}
					else 
					{
						newPosition = [position intValue] - 1;
						[tempMultiDeleteList addObject:[NSNumber numberWithInt:newPosition]];
					}
				}
				else
				{
					[tempMultiDeleteList addObject:position];
				}
			}
		}
		viewObjectsS.multiDeleteList = [NSMutableArray arrayWithArray:tempMultiDeleteList];
		[tempMultiDeleteList release];
	}
	//DLog(@"multiDeleteList: %@", viewObjectsS.multiDeleteList);
}


// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return YES;
}

// Set the editing style, set to none for no delete minus sign (overriding with own custom multi-delete boxes)
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return UITableViewCellEditingStyleNone;
	//return UITableViewCellEditingStyleDelete;
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
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
    return [databaseS.bookmarksDb intForQuery:@"SELECT COUNT(*) FROM bookmarks"];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *cellIdentifier = @"BookmarkCell";
	BookmarkUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell)
	{
		cell = [[BookmarkUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}
	cell.indexPath = indexPath;
	
	cell.deleteToggleImage.hidden = !self.tableView.editing;
	cell.deleteToggleImage.image = [UIImage imageNamed:@"unselected.png"];
	if ([viewObjectsS.multiDeleteList containsObject:[NSNumber numberWithInt:indexPath.row]])
	{
		cell.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
	}
	
    // Set up the cell...
	Song *aSong = [Song songFromDbRow:indexPath.row inTable:@"bookmarks" inDatabase:databaseS.bookmarksDb];
	
	cell.coverArtView.coverArtId = aSong.coverArtId;
	
	cell.backgroundView = [[[UIView alloc] init] autorelease];
	if(indexPath.row % 2 == 0)
		cell.backgroundView.backgroundColor = viewObjectsS.lightNormal;
	else
		cell.backgroundView.backgroundColor = viewObjectsS.darkNormal;
	
	NSString *name = [databaseS.bookmarksDb stringForQuery:@"SELECT name FROM bookmarks WHERE ROWID = ?", [NSNumber numberWithInt:(indexPath.row + 1)]];
	int position = [databaseS.bookmarksDb intForQuery:@"SELECT position FROM bookmarks WHERE ROWID = ?", [NSNumber numberWithInt:(indexPath.row + 1)]];
	[cell.bookmarkNameLabel setText:[NSString stringWithFormat:@"%@ - %@", name, [NSString formatTime:(float)position]]];
	
	[cell.songNameLabel setText:aSong.title];
	if (aSong.album)
		[cell.artistNameLabel setText:[NSString stringWithFormat:@"%@ - %@", aSong.artist, aSong.album]];
	else
		[cell.artistNameLabel setText:aSong.artist];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	
    return cell;
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath)
		return;
	
	// TODO: verify bookmark loading	
	[databaseS resetCurrentPlaylistDb];
	Song *aSong = [Song songFromDbRow:indexPath.row inTable:@"bookmarks" inDatabase:databaseS.bookmarksDb];
	[aSong addToCurrentPlaylist];
	
	playlistS.isShuffle = NO;
	
	if (IS_IPAD())
	{
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowPlayer];
	}
	else
	{
		iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
		streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
		[streamingPlayerViewController release];
	}
		
	NSUInteger offsetSeconds = [databaseS.bookmarksDb intForQuery:@"SELECT position FROM bookmarks WHERE ROWID = ?", [NSNumber numberWithInt:indexPath.row + 1]];
	NSUInteger offsetBytes = [databaseS.bookmarksDb intForQuery:@"SELECT bytes FROM bookmarks WHERE ROWID = ?", [NSNumber numberWithInt:indexPath.row + 1]];
	
	// Check if these are old bookmarks and don't have byteOffset saved
	if (offsetBytes == 0 && offsetSeconds != 0)
	{
		// By default, use the server reported bitrate
		NSUInteger bitrate = [aSong.bitRate intValue];
		
		if (aSong.transcodedSuffix)
		{
			// This is a transcode, guess the bitrate and byteoffset
			NSUInteger maxBitrate = settingsS.currentMaxBitrate == 0 ? 128 : settingsS.currentMaxBitrate;
			bitrate = maxBitrate < [aSong.bitRate intValue] ? maxBitrate : [aSong.bitRate intValue];
		}

		// Use the bitrate to get byteoffset
		offsetBytes = BytesForSecondsAtBitrate(offsetSeconds, bitrate);
	}
	else
	{
		[musicS startSongAtOffsetInBytes:offsetBytes andSeconds:offsetSeconds];
	}
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}



- (void)dealloc {
    [super dealloc];
}


@end

