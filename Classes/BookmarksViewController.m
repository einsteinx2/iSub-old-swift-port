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
#import "MusicControlsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "ServerListViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "Song.h"
#import "AsynchronousImageViewCached.h"
#import "AudioStreamer.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString+md5.h"
#import "CustomUIAlertView.h"

@implementation BookmarksViewController

#pragma mark -
#pragma mark View lifecycle

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if ([[[iSubAppDelegate sharedInstance].settingsDictionary objectForKey:@"lockRotationSetting"] isEqualToString:@"YES"])
		return NO;
	
    return YES;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	//NSLog(@"Cache viewDidLoad");
	
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicControlsSingleton sharedInstance];
	databaseControls = [DatabaseControlsSingleton sharedInstance];
	
	viewObjects.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
	//viewObjects.multiDeleteList = nil; viewObjects.multiDeleteList = [[NSMutableArray alloc] init];
	isNoBookmarksScreenShowing = NO;
	
	self.tableView.separatorColor = [UIColor clearColor];
	
	self.title = @"Bookmarks";
	
	if (viewObjects.isOfflineMode)
		self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];

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
	
	if(musicControls.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	self.tableView.tableHeaderView = nil;
	
	if ([databaseControls.bookmarksDb intForQuery:@"SELECT COUNT(*) FROM bookmarks"] == 0)
	{
		if (isNoBookmarksScreenShowing == NO)
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
			if (viewObjects.isOfflineMode) {
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
		if ([databaseControls.bookmarksDb intForQuery:@"SELECT COUNT(*) FROM bookmarks"] == 1)
			bookmarkCountLabel.text = [NSString stringWithFormat:@"1 Bookmark"];
		else 
			bookmarkCountLabel.text = [NSString stringWithFormat:@"%i Bookmarks", [databaseControls.bookmarksDb intForQuery:@"SELECT COUNT(*) FROM bookmarks"]];
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
}


-(void)viewWillDisappear:(BOOL)animated
{
	if (isNoBookmarksScreenShowing == YES)
	{
		[noBookmarksScreen removeFromSuperview];
		isNoBookmarksScreenShowing = NO;
	}
}


- (void) showDeleteButton
{
	if ([viewObjects.multiDeleteList count] == 0)
	{
		deleteBookmarksLabel.text = @"Clear Bookmarks";
	}
	else if ([viewObjects.multiDeleteList count] == 1)
	{
		deleteBookmarksLabel.text = @"Remove 1 Bookmark";
	}
	else
	{
		deleteBookmarksLabel.text = [NSString stringWithFormat:@"Remove %i Bookmarks", [viewObjects.multiDeleteList count]];
	}
	
	bookmarkCountLabel.hidden = YES;
	deleteBookmarksLabel.hidden = NO;
}


- (void) hideDeleteButton
{
	if ([viewObjects.multiDeleteList count] == 0)
	{
		if (viewObjects.isEditing == NO)
		{
			bookmarkCountLabel.hidden = NO;
			deleteBookmarksLabel.hidden = YES;
		}
		else
		{
			deleteBookmarksLabel.text = @"Clear Bookmarks";
		}
	}
	else if ([viewObjects.multiDeleteList count] == 1)
	{
		deleteBookmarksLabel.text = @"Remove 1 Bookmark";
	}
	else 
	{
		deleteBookmarksLabel.text = [NSString stringWithFormat:@"Remove %i Bookmarks", [viewObjects.multiDeleteList count]];
	}
}



- (void) editBookmarksAction:(id)sender
{
	if (self.tableView.editing == NO)
	{
		viewObjects.isEditing = YES;
		[self.tableView reloadData];
		[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(showDeleteButton) name:@"showDeleteButton" object: nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(hideDeleteButton) name:@"hideDeleteButton" object: nil];
		viewObjects.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		//viewObjects.multiDeleteList = nil; viewObjects.multiDeleteList = [[NSMutableArray alloc] init];
		[self.tableView setEditing:YES animated:YES];
		editBookmarksLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
		editBookmarksLabel.text = @"Done";
		[self showDeleteButton];
		
		[NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(showDeleteToggle) userInfo:nil repeats:NO];
	}
	else 
	{
		viewObjects.isEditing = NO;
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"showDeleteButton" object:nil];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideDeleteButton" object:nil];
		viewObjects.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		//viewObjects.multiDeleteList = nil; viewObjects.multiDeleteList = [[NSMutableArray alloc] init];
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
		[databaseControls.bookmarksDb executeUpdate:@"DELETE FROM bookmarks"];
		[databaseControls.bookmarksDb executeUpdate:@"VACUUM"];
		[self editBookmarksAction:nil];
		
		// Reload table data
		[self viewWillAppear:NO];
	}
	else
	{
		// Sort the multiDeleteList to make sure it's accending
		[viewObjects.multiDeleteList sortUsingSelector:@selector(compare:)];
		//NSLog(@"multiDeleteList: %@", viewObjects.multiDeleteList);
		
		for (NSNumber *index in [viewObjects.multiDeleteList reverseObjectEnumerator])
		{
			int row = [index intValue] + 1;
			[databaseControls.bookmarksDb executeUpdate:[NSString stringWithFormat:@"DELETE FROM bookmarks WHERE ROWID = %i", row]];
		}
		[databaseControls.bookmarksDb executeUpdate:@"DROP TABLE bookmarksTemp"];
		[databaseControls.bookmarksDb executeUpdate:@"CREATE TABLE bookmarksTemp (name TEXT, position INTEGER, title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
		[databaseControls.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks"];
		[databaseControls.bookmarksDb executeUpdate:@"DROP TABLE bookmarks"];
		[databaseControls.bookmarksDb executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];
		[databaseControls.bookmarksDb executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
		
		// Create indexPaths from multiDeleteList
		NSMutableArray *indexes = [[NSMutableArray alloc] init];
		for (NSNumber *index in viewObjects.multiDeleteList)
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
	
	[databaseControls.bookmarksDb executeUpdate:@"DROP TABLE bookmarksTemp"];
	[databaseControls.bookmarksDb executeUpdate:@"CREATE TABLE bookmarksTemp (name TEXT, position INTEGER, title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
		
	if (fromRow < toRow)
	{
		[databaseControls.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID < ?", [NSNumber numberWithInt:fromRow]];
		[databaseControls.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID > ? AND ROWID <= ?", [NSNumber numberWithInt:fromRow], [NSNumber numberWithInt:toRow]];
		[databaseControls.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
		[databaseControls.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID > ?", [NSNumber numberWithInt:toRow]];
		
		[databaseControls.bookmarksDb executeUpdate:@"DROP TABLE bookmarks"];
		[databaseControls.bookmarksDb executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];
		[databaseControls.bookmarksDb executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
	}
	else
	{
		[databaseControls.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID < ?", [NSNumber numberWithInt:toRow]];
		[databaseControls.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
		[databaseControls.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID >= ? AND ROWID < ?", [NSNumber numberWithInt:toRow], [NSNumber numberWithInt:fromRow]];
		[databaseControls.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID > ?", [NSNumber numberWithInt:fromRow]];
		
		[databaseControls.bookmarksDb executeUpdate:@"DROP TABLE bookmarks"];
		[databaseControls.bookmarksDb executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];
		[databaseControls.bookmarksDb executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
	}
	
	
	// Fix the multiDeleteList to reflect the new row positions
	//NSLog(@"multiDeleteList: %@", viewObjects.multiDeleteList);
	if ([viewObjects.multiDeleteList count] > 0)
	{
		NSMutableArray *tempMultiDeleteList = [[NSMutableArray alloc] init];
		int newPosition;
		for (NSNumber *position in viewObjects.multiDeleteList)
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
		viewObjects.multiDeleteList = [NSMutableArray arrayWithArray:tempMultiDeleteList];
		[tempMultiDeleteList release];
	}
	//NSLog(@"multiDeleteList: %@", viewObjects.multiDeleteList);
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
    return [databaseControls.bookmarksDb intForQuery:@"SELECT COUNT(*) FROM bookmarks"];
}


- (Song *) songFromDbRow:(NSUInteger)row
{
	row++;
	Song *aSong = [[Song alloc] init];
	FMResultSet *result = [databaseControls.bookmarksDb executeQuery:[NSString stringWithFormat:@"SELECT * FROM bookmarks WHERE ROWID = %i", row]];
	[result next];
	if ([databaseControls.bookmarksDb hadError]) {
		NSLog(@"Err %d: %@", [databaseControls.bookmarksDb lastErrorCode], [databaseControls.bookmarksDb lastErrorMessage]);
	}
	
	aSong.title = [result stringForColumnIndex:2];
	aSong.songId = [result stringForColumnIndex:3];
	aSong.artist = [result stringForColumnIndex:4];
	aSong.album = [result stringForColumnIndex:5];
	aSong.genre = [result stringForColumnIndex:6];
	aSong.coverArtId = [result stringForColumnIndex:7];
	aSong.path = [result stringForColumnIndex:8];
	aSong.suffix = [result stringForColumnIndex:9];
	aSong.transcodedSuffix = [result stringForColumnIndex:10];
	aSong.duration = [NSNumber numberWithInt:[result intForColumnIndex:11]];
	aSong.bitRate = [NSNumber numberWithInt:[result intForColumnIndex:12]];
	aSong.track = [NSNumber numberWithInt:[result intForColumnIndex:13]];
	aSong.year = [NSNumber numberWithInt:[result intForColumnIndex:14]];
	aSong.size = [NSNumber numberWithInt:[result intForColumnIndex:15]];
	
	[result close];
	return [aSong autorelease];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
    static NSString *CellIdentifier = @"Cell";
	BookmarkUITableViewCell *cell = [[[BookmarkUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
	cell.indexPath = indexPath;
	
	cell.deleteToggleImage.hidden = !viewObjects.isEditing;
	if ([viewObjects.multiDeleteList containsObject:[NSNumber numberWithInt:indexPath.row]])
	{
		cell.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
	}
	
    // Set up the cell...
	Song *aSong = [self songFromDbRow:indexPath.row];
	
	if (aSong.coverArtId)
	{
		if ([databaseControls.coverArtCacheDb60 intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [NSString md5:aSong.coverArtId]] == 1)
		{
			// If the image is already in the cache dictionary, load it
			cell.coverArtView.image = [UIImage imageWithData:[databaseControls.coverArtCacheDb60 dataForQuery:@"SELECT data FROM coverArtCache WHERE id = ?", [NSString md5:aSong.coverArtId]]];
		}
		else 
		{			
			// If not, grab it from the url and cache it
			NSString *imgUrlString;
			if (appDelegate.isHighRez)
			{
				imgUrlString = [NSString stringWithFormat:@"%@%@&size=120", [appDelegate getBaseUrl:@"getCoverArt.view"], aSong.coverArtId];
			}
			else
			{
				imgUrlString = [NSString stringWithFormat:@"%@%@&size=60", [appDelegate getBaseUrl:@"getCoverArt.view"], aSong.coverArtId];
			}
			[cell.coverArtView loadImageFromURLString:imgUrlString coverArtId:aSong.coverArtId];
		}
	}
	else
	{
		cell.coverArtView.image = [UIImage imageNamed:@"default-album-art-small.png"];
	}
	
	cell.backgroundView = [[[UIView alloc] init] autorelease];
	if(indexPath.row % 2 == 0)
		cell.backgroundView.backgroundColor = viewObjects.lightNormal;
	else
		cell.backgroundView.backgroundColor = viewObjects.darkNormal;
	
	NSString *name = [databaseControls.bookmarksDb stringForQuery:@"SELECT name FROM bookmarks WHERE ROWID = ?", [NSNumber numberWithInt:(indexPath.row + 1)]];
	int position = [databaseControls.bookmarksDb intForQuery:@"SELECT position FROM bookmarks WHERE ROWID = ?", [NSNumber numberWithInt:(indexPath.row + 1)]];
	[cell.bookmarkNameLabel setText:[NSString stringWithFormat:@"%@ - %@", name, [appDelegate formatTime:(float)position]]];
	
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

- (void)playBookmarkSong
{
	musicControls.songUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"stream.view"], musicControls.currentSongObject.songId]];
	
	// Determine the hashed filename
	musicControls.downloadFileNameHashA = nil; musicControls.downloadFileNameHashA = [NSString md5:musicControls.currentSongObject.path];
	
	// Check to see if the song is an m4a, if so don't resume and display message
	BOOL isM4A = NO;
	if (musicControls.currentSongObject.transcodedSuffix)
	{
		if ([musicControls.currentSongObject.transcodedSuffix isEqualToString:@"m4a"] || [musicControls.currentSongObject.transcodedSuffix isEqualToString:@"aac"])
			isM4A = YES;
	}
	else
	{
		if ([musicControls.currentSongObject.suffix isEqualToString:@"m4a"] || [musicControls.currentSongObject.suffix isEqualToString:@"aac"])
			isM4A = YES;
	}
	
	if (isM4A)
	{
		[musicControls startDownloadA];
		
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Sorry" message:@"It's currently not possible to skip within m4a files, so the song is starting from the begining instead of resuming.\n\nYou can turn on m4a > mp3 transcoding in Subsonic to resume this song properly." delegate:appDelegate cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
		[alert release];
	}
	else
	{
		// Check to see if the song is already cached
		if ([databaseControls.songCacheDb intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE md5 = ?", musicControls.downloadFileNameHashA])
		{
			// Looks like the song is in the database, check if it's cached fully
			NSString *isDownloadFinished = [databaseControls.songCacheDb stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", musicControls.downloadFileNameHashA];
			if ([isDownloadFinished isEqualToString:@"YES"])
			{
				// The song is fully cached, start streaming from the local copy
				//NSLog(@"Song in the cache. Resuming from local copy");
				
				musicControls.isTempDownload = NO;
				
				// Determine the file hash
				musicControls.downloadFileNameHashA = [NSString md5:musicControls.currentSongObject.path];
				
				// Determine the name and path of the file.
				if (musicControls.currentSongObject.transcodedSuffix)
					musicControls.downloadFileNameA = [musicControls.audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", musicControls.downloadFileNameHashA, musicControls.currentSongObject.transcodedSuffix]];
				else
					musicControls.downloadFileNameA = [musicControls.audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", musicControls.downloadFileNameHashA, musicControls.currentSongObject.suffix]];
				//NSLog(@"File name = %@", downloadFileNameA);		
				
				// Start streaming from the local copy
				//NSLog(@"Playing from local copy");
				
				// Check the file size
				NSNumber *fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:musicControls.downloadFileNameA error:NULL] objectForKey:NSFileSize];
				musicControls.bitRate = (UInt32) (([fileSize floatValue] / [musicControls.currentSongObject.duration floatValue]) / 128);
				//NSLog(@"bitrate: %i", musicControls.bitRate);
				musicControls.downloadedLengthA = [fileSize intValue];
				//NSLog(@"downloadedLengthA: %i", downloadedLengthA);
				
				musicControls.streamerProgress = 0.0;
				musicControls.streamer = [[AudioStreamer alloc] initWithFileURL:[NSURL fileURLWithPath:musicControls.downloadFileNameA]];
				if (musicControls.streamer)
				{
					musicControls.streamer.fileDownloadCurrentSize = musicControls.downloadedLengthA;
					//NSLog(@"fileDownloadCurrentSize: %i", streamer.fileDownloadCurrentSize);
					musicControls.streamer.fileDownloadComplete = YES;
					[musicControls.streamer startWithOffsetInSecs:(UInt32) musicControls.seekTime];
				}
			}
			else
			{
				if (viewObjects.isOfflineMode)
				{
					CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"Unable to resume this song in offline mode as it isn't fully cached." delegate:appDelegate cancelButtonTitle:@"Ok" otherButtonTitles:nil];
					[alert show];
					[alert release];
				}
				else 
				{
					// The song is not fully cached, call startTempDownloadA to start a temp cache stream
					//NSLog(@"Song in cache but not finished, resuming with a temp download");
					
					// Determine the name and path of the file.
					if (musicControls.currentSongObject.transcodedSuffix)
						musicControls.downloadFileNameA = [musicControls.audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", musicControls.downloadFileNameHashA, musicControls.currentSongObject.transcodedSuffix]];
					else
						musicControls.downloadFileNameA = [musicControls.audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", musicControls.downloadFileNameHashA, musicControls.currentSongObject.suffix]];
					//NSLog(@"File name = %@", downloadFileNameA);		
					
					if (musicControls.currentSongObject.transcodedSuffix)
					{
						// It's transcoded! Guess that it's transcoded at 160kbps
						musicControls.bitRate = 160;
					}
					else
					{
						// It's not transcoded, check the max bitrate setting
						if ([musicControls maxBitrateSetting] == 0)
						{
							// No max setting, use the bitrate of the song object
							musicControls.bitRate = [musicControls.currentSongObject.bitRate intValue];
						}
						else 
						{
							// Use the bitrate of the song object or the max bitrate setting, whichever is lower
							if ([musicControls maxBitrateSetting] > [musicControls.currentSongObject.bitRate intValue])
								musicControls.bitRate = [musicControls.currentSongObject.bitRate intValue];
							else
								musicControls.bitRate = [musicControls maxBitrateSetting];
						}
					}
					//NSLog(@"bitrate: %i", musicControls.bitRate);
					
					// Determine the byte offset
					float byteOffset;
					if (musicControls.bitRate < 1000)
						byteOffset = ((float)musicControls.bitRate * 128 * musicControls.seekTime);
					else
						byteOffset = (((float)musicControls.bitRate / 1000) * 128 * musicControls.seekTime);

					// Start the download
					[musicControls startTempDownloadA:byteOffset];
				}
			}
		}
		else
		{
			if (!viewObjects.isOfflineMode)
			{
				// Song not in the cache at all, call startTempDownloadA to start a temp cache stream
				//NSLog(@"Song not in cache at all, starting a temp download");
				
				// Determine the name and path of the file.
				if (musicControls.currentSongObject.transcodedSuffix)
					musicControls.downloadFileNameA = [musicControls.audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", musicControls.downloadFileNameHashA, musicControls.currentSongObject.transcodedSuffix]];
				else
					musicControls.downloadFileNameA = [musicControls.audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", musicControls.downloadFileNameHashA, musicControls.currentSongObject.suffix]];
				//NSLog(@"File name = %@", downloadFileNameA);		
				
				if (musicControls.currentSongObject.transcodedSuffix)
				{
					// It's transcoded! Guess that it's transcoded at 160kbps
					musicControls.bitRate = 160;
				}
				else
				{
					// It's not transcoded, check the max bitrate setting
					if ([musicControls maxBitrateSetting] == 0)
					{
						// No max setting, use the bitrate of the song object
						musicControls.bitRate = [musicControls.currentSongObject.bitRate intValue];
					}
					else 
					{
						// Use the bitrate of the song object or the max bitrate setting, whichever is lower
						if ([musicControls maxBitrateSetting] > [musicControls.currentSongObject.bitRate intValue])
							musicControls.bitRate = [musicControls.currentSongObject.bitRate intValue];
						else
							musicControls.bitRate = [musicControls maxBitrateSetting];
					}
				}
				//NSLog(@"bitrate: %i", musicControls.bitRate);
				
				// Determine the byte offset
				float byteOffset;
				if (musicControls.bitRate < 1000)
					byteOffset = ((float)musicControls.bitRate * 128 * musicControls.seekTime);
				else
					byteOffset = (((float)musicControls.bitRate / 1000) * 128 * musicControls.seekTime);
				
				
				// Start the download
				[musicControls startTempDownloadA:byteOffset];
			}
		}
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	musicControls.currentSongObject = nil;
	musicControls.nextSongObject = nil;
	musicControls.currentSongObject = [self songFromDbRow:indexPath.row];
	
	musicControls.currentPlaylistPosition = 0;
	[databaseControls resetCurrentPlaylistDb];
	[databaseControls insertSong:musicControls.currentSongObject intoTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
	
    musicControls.isNewSong = YES;
	musicControls.isShuffle = NO;
	
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
		
	[musicControls destroyStreamer];
	musicControls.isPlaying = YES;
	musicControls.seekTime = (float)[databaseControls.bookmarksDb intForQuery:@"SELECT position FROM bookmarks WHERE ROWID = ?", [NSNumber numberWithInt:(indexPath.row + 1)]];
	[self playBookmarkSong];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"setPauseButtonImage" object:nil];
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}


- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}


@end

