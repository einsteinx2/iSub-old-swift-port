//
//  CacheAlbumViewController.m
//  iSub
//
//  Created by Ben Baron on 6/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CacheAlbumViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "CacheAlbumUITableViewCell.h"
#import "CacheSongUITableViewCell.h"
#import "Artist.h"
#import "Album.h"
#import "Song.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
//#import "NSString+md5.h"
#import "SavedSettings.h"
//#import "NSString+time.h"
#import "NSMutableURLRequest+SUS.h"
#import "PlaylistSingleton.h"
#import "FMDatabase+Synchronized.h"
#import "NSString+Additions.h"

@implementation CacheAlbumViewController

@synthesize listOfAlbums, listOfSongs, sectionInfo, segment, seg1;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	
	if ([SavedSettings sharedInstance].isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicSingleton sharedInstance];
	databaseControls = [DatabaseSingleton sharedInstance];
	
	// Set notification receiver for when cached songs are deleted to reload the table
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cachedSongDeleted) name:@"cachedSongDeleted" object:nil];

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
		
	// Add the play all button + shuffle button
	UIView *headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)] autorelease];
	headerView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];
	
	UIImageView *playAllImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"play-all-note.png"]];
	playAllImage.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	playAllImage.frame = CGRectMake(10, 10, 19, 30);
	[headerView addSubview:playAllImage];
	[playAllImage release];
	
	UILabel *playAllLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 160, 50)];
	playAllLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
	playAllLabel.backgroundColor = [UIColor clearColor];
	playAllLabel.textColor = [UIColor colorWithRed:186.0/255.0 green:191.0/255.0 blue:198.0/255.0 alpha:1];
	playAllLabel.textAlignment = UITextAlignmentCenter;
	playAllLabel.font = [UIFont boldSystemFontOfSize:30];
	playAllLabel.text = @"Play All";
	[headerView addSubview:playAllLabel];
	[playAllLabel release];
	
	UIButton *playAllButton = [UIButton buttonWithType:UIButtonTypeCustom];
	playAllButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
	playAllButton.frame = CGRectMake(0, 0, 160, 40);
	[playAllButton addTarget:self action:@selector(playAllAction:) forControlEvents:UIControlEventTouchUpInside];
	[headerView addSubview:playAllButton];
	
	UILabel *spacerLabel = [[UILabel alloc] initWithFrame:CGRectMake(158, -2, 6, 50)];
	spacerLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	spacerLabel.backgroundColor = [UIColor clearColor];
	spacerLabel.textColor = [UIColor colorWithRed:186.0/255.0 green:191.0/255.0 blue:198.0/255.0 alpha:1];
	spacerLabel.font = [UIFont systemFontOfSize:40];
	spacerLabel.text = @"|";
	[headerView addSubview:spacerLabel];
	[spacerLabel release];
	
	UIImageView *shuffleImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"shuffle-small.png"]];
	shuffleImage.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	shuffleImage.frame = CGRectMake(180, 12, 24, 26);
	[headerView addSubview:shuffleImage];
	[shuffleImage release];
	
	UILabel *shuffleLabel = [[UILabel alloc] initWithFrame:CGRectMake(180, 0, 160, 50)];
	shuffleLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth;
	shuffleLabel.backgroundColor = [UIColor clearColor];
	shuffleLabel.textColor = [UIColor colorWithRed:186.0/255.0 green:191.0/255.0 blue:198.0/255.0 alpha:1];
	shuffleLabel.textAlignment = UITextAlignmentCenter;
	shuffleLabel.font = [UIFont boldSystemFontOfSize:30];
	shuffleLabel.text = @"Shuffle";
	[headerView addSubview:shuffleLabel];
	[shuffleLabel release];
	
	UIButton *shuffleButton = [UIButton buttonWithType:UIButtonTypeCustom];
	shuffleButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth;
	shuffleButton.frame = CGRectMake(160, 0, 160, 40);
	[shuffleButton addTarget:self action:@selector(shuffleAction:) forControlEvents:UIControlEventTouchUpInside];
	[headerView addSubview:shuffleButton];
	
	self.tableView.tableHeaderView = headerView;
	
	// Create the section index
	if ([listOfAlbums count] > 10)
	{
		FMDatabase *db = databaseControls.albumListCacheDb;
		[db executeUpdate:@"DROP TABLE IF EXSITS albumIndex"];
		[db executeUpdate:@"CREATE TEMP TABLE albumIndex (album TEXT)"];
		
		[db beginTransaction];
		for (NSNumber *rowId in listOfAlbums)
		{
			@autoreleasepool 
			{
				[db executeUpdate:@"INSERT INTO albumIndex SELECT title FROM albumsCache WHERE rowid = ?", rowId];
			}
		}
		[db commit];
		
		self.sectionInfo = [databaseControls sectionInfoFromTable:@"albumIndex" inDatabase:db withColumn:@"album"];
		[db executeUpdate:@"DROP TABLE IF EXSITS albumIndex"];
		
		if (sectionInfo)
		{
			if ([sectionInfo count] < 5)
				self.sectionInfo = nil;
			else
				[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
		}
	}	
}


- (void) cachedSongDeleted
{
	FMResultSet *result = [databaseControls.songCacheDb synchronizedQuery:[NSString stringWithFormat:@"SELECT md5, segs, seg%i, track FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? AND seg%i = ? GROUP BY seg%i ORDER BY seg%i COLLATE NOCASE", segment, (segment - 1), segment, segment], seg1, self.title];
	
	self.listOfAlbums = [NSMutableArray arrayWithCapacity:1];
	self.listOfSongs = [NSMutableArray arrayWithCapacity:1];
	//self.listOfAlbums = nil; self.listOfAlbums = [[NSMutableArray alloc] init];
	//self.listOfSongs = nil; self.listOfSongs = [[NSMutableArray alloc] init];
	while ([result next])
	{
		if ([result intForColumnIndex:1] > segment)
		{
			[self.listOfAlbums addObject:[NSArray arrayWithObjects:[NSString stringWithString:[result stringForColumnIndex:0]], 
																   [NSString stringWithString:[result stringForColumnIndex:2]], nil]];
		}
		else
		{
			[self.listOfSongs addObject:[NSArray arrayWithObjects:[NSString stringWithString:[result stringForColumnIndex:0]], 
																  [NSString stringWithFormat:@"%i", [result intForColumnIndex:3]], nil]];
		}
	}

	// If the table is empty, pop back one view, otherwise reload the table data
	if ([self.listOfAlbums count] + [self.listOfSongs count] == 0)
	{
		// Handle the moreNavigationController stupidity
		if (appDelegate.currentTabBarController.selectedIndex == 4)
		{
			[appDelegate.currentTabBarController.moreNavigationController popToViewController:[appDelegate.currentTabBarController.moreNavigationController.viewControllers objectAtIndex:1] animated:YES];
		}
		else
		{
			[(UINavigationController*)appDelegate.currentTabBarController.selectedViewController popToRootViewControllerAnimated:YES];
		}
	}
	else
	{
		[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
	}
}

- (void)playAllAction:(id)sender
{	
	[viewObjects showLoadingScreenOnMainWindow];
	[self performSelectorInBackground:@selector(loadPlayAllPlaylist:) withObject:@"NO"];
}

- (void)shuffleAction:(id)sender
{
	[viewObjects showLoadingScreenOnMainWindow];
	[self performSelectorInBackground:@selector(loadPlayAllPlaylist:) withObject:@"YES"];
}


- (void)loadPlayAllPlaylist:(NSString *)shuffle
{	
	// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	PlaylistSingleton *currentPlaylist = [PlaylistSingleton sharedInstance];
	
	BOOL isShuffle;
	if ([shuffle isEqualToString:@"YES"])
		isShuffle = YES;
	else
		isShuffle = NO;
	
	[databaseControls resetCurrentPlaylistDb];
	
	FMResultSet *result;
	if (segment == 2)
	{
		result = [databaseControls.songCacheDb synchronizedQuery:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? ORDER BY seg2 COLLATE NOCASE", seg1];
	}
	else
	{
		result = [databaseControls.songCacheDb synchronizedQuery:[NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND seg%i = ? ORDER BY seg%i COLLATE NOCASE", (segment - 1), segment], seg1, self.title];
	}

	while ([result next])
	{
		if ([result stringForColumnIndex:0] != nil)
			[[Song songFromCacheDb:[NSString stringWithString:[result stringForColumnIndex:0]]] addToCurrentPlaylist];
	}
	
	if (isShuffle)
	{
		currentPlaylist.isShuffle = YES;
		
		[databaseControls resetShufflePlaylist];
		[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO shufflePlaylist SELECT * FROM currentPlaylist ORDER BY RANDOM()"];
	}
	else
	{
		currentPlaylist.isShuffle = NO;
	}
			
	// Must do UI stuff in main thread
	[self performSelectorOnMainThread:@selector(loadPlayAllPlaylist2) withObject:nil waitUntilDone:NO];	
	
	[autoreleasePool release];
}


- (void)playAllPlaySong
{	
	[musicControls playSongAtPosition:0];
	
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
}


- (void) loadPlayAllPlaylist2
{
	// Hide the loading screen
	[[[appDelegate.currentTabBarController.view subviews] objectAtIndex:([[appDelegate.currentTabBarController.view subviews] count] - 1)] removeFromSuperview];
	[[[appDelegate.currentTabBarController.view subviews] objectAtIndex:([[appDelegate.currentTabBarController.view subviews] count] - 1)] removeFromSuperview];
	
	[self playAllPlaySong];
}


- (IBAction)nowPlayingAction:(id)sender
{
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
	[streamingPlayerViewController release];
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}


- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc 
{
	self.listOfAlbums = nil;
	self.listOfSongs = nil;
    [super dealloc];
}


- (Song *) songFromCacheDb:(NSString *)md5
{
	Song *aSong = [[Song alloc] init];
	FMResultSet *result = [databaseControls.songCacheDb synchronizedQuery:@"SELECT * FROM cachedSongs WHERE md5 = ?", md5];
	if ([databaseControls.songCacheDb hadError]) 
	{
		DLog(@"Err %d: %@", [databaseControls.songCacheDb lastErrorCode], [databaseControls.songCacheDb lastErrorMessage]);
	}
	else
	{
		[result next];
		
		if ([result stringForColumn:@"title"] != nil)
			aSong.title = [[result stringForColumn:@"title"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		if ([result stringForColumn:@"songId"] != nil)
			aSong.songId = [NSString stringWithString:[result stringForColumn:@"songId"]];
		if ([result stringForColumn:@"artist"] != nil)
			aSong.artist = [[result stringForColumn:@"artist"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		if ([result stringForColumn:@"album"] != nil)
			aSong.album = [[result stringForColumn:@"album"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		if ([result stringForColumn:@"genre"] != nil)
			aSong.genre = [[result stringForColumn:@"genre"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		if ([result stringForColumn:@"coverArtId"] != nil)
			aSong.coverArtId = [NSString stringWithString:[result stringForColumn:@"coverArtId"]];
		if ([result stringForColumn:@"path"] != nil)
			aSong.path = [NSString stringWithString:[result stringForColumn:@"path"]];
		if ([result stringForColumn:@"suffix"] != nil)
			aSong.suffix = [NSString stringWithString:[result stringForColumn:@"suffix"]];
		if ([result stringForColumn:@"transcodedSuffix"] != nil)
			aSong.transcodedSuffix = [NSString stringWithString:[result stringForColumn:@"transcodedSuffix"]];
		aSong.duration = [NSNumber numberWithInt:[result intForColumn:@"duration"]];
		aSong.bitRate = [NSNumber numberWithInt:[result intForColumn:@"bitRate"]];
		aSong.track = [NSNumber numberWithInt:[result intForColumn:@"track"]];
		aSong.year = [NSNumber numberWithInt:[result intForColumn:@"year"]];
		aSong.size = [NSNumber numberWithInt:[result intForColumn:@"size"]];
	}
	
	/*aSong.title = [result stringForColumnIndex:4];
	aSong.songId = [result stringForColumnIndex:5];
	aSong.artist = [result stringForColumnIndex:6];
	aSong.album = [result stringForColumnIndex:7];
	aSong.genre = [result stringForColumnIndex:8];
	aSong.coverArtId = [result stringForColumnIndex:9];
	aSong.path = [result stringForColumnIndex:10];
	aSong.suffix = [result stringForColumnIndex:11];
	aSong.transcodedSuffix = [result stringForColumnIndex:12];
	aSong.duration = [NSNumber numberWithInt:[result intForColumnIndex:13]];
	aSong.bitRate = [NSNumber numberWithInt:[result intForColumnIndex:14]];
	aSong.track = [NSNumber numberWithInt:[result intForColumnIndex:15]];
	aSong.year = [NSNumber numberWithInt:[result intForColumnIndex:16]];
	aSong.size = [NSNumber numberWithInt:[result intForColumnIndex:17]];*/
	
	[result close];
	return [aSong autorelease];
}


#pragma mark Table view methods

// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView 
{
	NSMutableArray *indexes = [[[NSMutableArray alloc] init] autorelease];
	for (int i = 0; i < [sectionInfo count]; i++)
	{
		[indexes addObject:[[sectionInfo objectAtIndex:i] objectAtIndex:0]];
	}
	return indexes;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index 
{
	if (index == 0)
	{
		[tableView scrollRectToVisible:CGRectMake(0, 50, 320, 40) animated:NO];
	}
	else
	{
		NSUInteger row = [[[sectionInfo objectAtIndex:(index - 1)] objectAtIndex:1] intValue];
		NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
		[tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
	}
	
	return -1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	return ([self.listOfAlbums count] + [self.listOfSongs count]);
}


// Customize the height of individual rows to make the album rows taller to accomidate the album art.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (indexPath.row < [listOfAlbums count])
		return 60.0;
	else
		return 50.0;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{	
	static NSString *CellIdentifier = @"Cell";
	
	// Set up the cell...
	if (indexPath.row < [listOfAlbums count])
	{
		CacheAlbumUITableViewCell *cell = [[[CacheAlbumUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.segment = self.segment;
		cell.seg1 = self.seg1;
		
		NSString *md5 = [[listOfAlbums objectAtIndex:indexPath.row] objectAtIndex:0];
		NSString *coverArtId = [databaseControls.songCacheDb synchronizedStringForQuery:@"SELECT coverArtId FROM cachedSongs WHERE md5 = ?", md5];
		NSString *name = [[listOfAlbums objectAtIndex:indexPath.row] objectAtIndex:1];
		
		if (coverArtId)
		{
			if ([databaseControls.coverArtCacheDb60 intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [coverArtId md5]] == 1)
			{
				// If the image is already in the cache database, load it
				cell.coverArtView.image = [UIImage imageWithData:[databaseControls.coverArtCacheDb60 dataForQuery:@"SELECT data FROM coverArtCache WHERE id = ?", [coverArtId md5]]];
			}
			else 
			{	
				// If it's not, display the default image
				cell.coverArtView.image = [UIImage imageNamed:@"default-album-art-small.png"];
			}
		}
		else
		{
			// If there's no cover art at all, display the default image
			cell.coverArtView.image = [UIImage imageNamed:@"default-album-art-small.png"];
		}
		
		[cell.albumNameLabel setText:[name gtm_stringByUnescapingFromHTML]];
		cell.backgroundView = [[[UIView alloc] init] autorelease];
		if(indexPath.row % 2 == 0)
			cell.backgroundView.backgroundColor = [UIColor whiteColor];
		else
			cell.backgroundView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];		
		
		return cell;
	}
	else
	{
		CacheSongUITableViewCell *cell = [[[CacheSongUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		cell.accessoryType = UITableViewCellAccessoryNone;
		NSUInteger a = indexPath.row - [listOfAlbums count];
		cell.md5 = [[listOfSongs objectAtIndex:a] objectAtIndex:0];
		
		Song *aSong = [self songFromCacheDb:cell.md5];
		
		if (aSong.track)
		{
			cell.trackNumberLabel.text = [NSString stringWithFormat:@"%i", [aSong.track intValue]];
		}
		else
		{	
			cell.trackNumberLabel.text = @"";
		}
			
		cell.songNameLabel.text = aSong.title;
		
		if (aSong.artist)
			cell.artistNameLabel.text = aSong.artist;
		else
			cell.artistNameLabel.text = @"";		
		
		if (aSong.duration)
			cell.songDurationLabel.text = [NSString formatTime:[aSong.duration floatValue]];
		else
			cell.songDurationLabel.text = @"";
		
		cell.backgroundView = [[[UIView alloc] init] autorelease];
		if(indexPath.row % 2 == 0)
			cell.backgroundView.backgroundColor = [UIColor whiteColor];
		else
			cell.backgroundView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];		
		
		return cell;
	}
}

NSInteger trackSort2(id obj1, id obj2, void *context)
{
	NSUInteger track1 = [(NSNumber*)[(NSArray*)obj1 objectAtIndex:1] intValue];
	NSUInteger track2 = [(NSNumber*)[(NSArray*)obj2 objectAtIndex:1] intValue];
	if (track1 < track2)
		return NSOrderedAscending;
	else if (track1 == track2)
		return NSOrderedSame;
	else
		return NSOrderedDescending;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{	
	if (viewObjects.isCellEnabled)
	{
		if (indexPath.row < [listOfAlbums count])
		{		
			CacheAlbumViewController *cacheAlbumViewController = [[CacheAlbumViewController alloc] initWithNibName:@"CacheAlbumViewController" bundle:nil];
			cacheAlbumViewController.title = [[listOfAlbums objectAtIndex:indexPath.row] objectAtIndex:1];
			cacheAlbumViewController.listOfAlbums = [NSMutableArray arrayWithCapacity:1];
			cacheAlbumViewController.listOfSongs = [NSMutableArray arrayWithCapacity:1];
			//cacheAlbumViewController.listOfAlbums = [[NSMutableArray alloc] init];
			//cacheAlbumViewController.listOfSongs = [[NSMutableArray alloc] init];
			cacheAlbumViewController.segment = (self.segment + 1);
			cacheAlbumViewController.seg1 = self.seg1;
			//DLog(@"query: %@", [NSString stringWithFormat:@"SELECT md5, segs, seg%i FROM cachedSongsLayout WHERE seg1 = '%@' AND seg%i = '%@' GROUP BY seg%i ORDER BY seg%i COLLATE NOCASE", (segment + 1), seg1, segment, [[listOfAlbums objectAtIndex:indexPath.row] objectAtIndex:1], (segment + 1), (segment + 1)]);
			FMResultSet *result = [databaseControls.songCacheDb synchronizedQuery:[NSString stringWithFormat:@"SELECT md5, segs, seg%i, track FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? AND seg%i = ? GROUP BY seg%i ORDER BY seg%i COLLATE NOCASE", (segment + 1), segment, (segment + 1), (segment + 1)], seg1, [[listOfAlbums objectAtIndex:indexPath.row] objectAtIndex:1]];
			while ([result next])
			{
				if ([result intForColumnIndex:1] > (segment + 1))
				{
					[cacheAlbumViewController.listOfAlbums addObject:[NSArray arrayWithObjects:[NSString stringWithString:[result stringForColumnIndex:0]], 
																							   [NSString stringWithString:[result stringForColumnIndex:2]], nil]];
				}
				else
				{
					[cacheAlbumViewController.listOfSongs addObject:[NSArray arrayWithObjects:[NSString stringWithString:[result stringForColumnIndex:0]], 
																							  [NSNumber numberWithInt:[result intForColumnIndex:3]], nil]];
					
					BOOL multipleSameTrackNumbers = NO;
					NSMutableArray *trackNumbers = [NSMutableArray arrayWithCapacity:[cacheAlbumViewController.listOfSongs count]];
					for (NSArray *song in cacheAlbumViewController.listOfSongs)
					{
						NSNumber *track = [song objectAtIndex:1];
						
						if ([trackNumbers containsObject:track])
						{
							multipleSameTrackNumbers = YES;
							break;
						}
						
						[trackNumbers addObject:track];
					}
					
					// Sort by track number
					if (!multipleSameTrackNumbers)
						[cacheAlbumViewController.listOfSongs sortUsingFunction:trackSort2 context:NULL];
				}
			}
						
			[self.navigationController pushViewController:cacheAlbumViewController animated:YES];
			[cacheAlbumViewController release];
		}
		else
		{
			PlaylistSingleton *currentPlaylist = [PlaylistSingleton sharedInstance];
			
			NSUInteger a = indexPath.row - [listOfAlbums count];
			
			[databaseControls resetCurrentPlaylistDb];
			for(NSArray *song in listOfSongs)
			{
				//DLog(@"songMD5: %@", songMD5);
				Song *aSong = [self songFromCacheDb:[song objectAtIndex:0]];
				//DLog(@"aSong: %@", aSong);
				[aSong addToCurrentPlaylist];
				//[databaseControls insertSong:aSong intoTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
			}
						
			currentPlaylist.isShuffle = NO;
			
			[musicControls playSongAtPosition:a];
			
			Song *currentSong = [PlaylistSingleton sharedInstance].currentSong;
			
			// Grab the first bytes of the song to trick Subsonic into seeing that it's being played
            NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(currentSong.songId) forKey:@"id"];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"stream" andParameters:parameters];
            
			NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:musicControls];
			if (!connection)
			{
				DLog(@"Subsonic cached song play notification failed");
			}
			
			// Update the playtime to now
			NSString *query = [NSString stringWithFormat:@"UPDATE cachedSongs SET playedDate = %i WHERE md5 = '%@'", 
														 (NSUInteger)[[NSDate date] timeIntervalSince1970], 
														 [currentSong.songId md5]];
			[databaseControls.songCacheDb synchronizedUpdate:query];
			
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
		}
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}


@end

