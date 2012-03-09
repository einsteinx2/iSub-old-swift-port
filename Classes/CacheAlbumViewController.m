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
#import "FMDatabaseAdditions.h"
//#import "NSString+md5.h"
#import "SavedSettings.h"
//#import "NSString+time.h"
#import "NSMutableURLRequest+SUS.h"
#import "PlaylistSingleton.h"
#import "NSArray+Additions.h"
#import "NSString+Additions.h"
#import "NSNotificationCenter+MainThread.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "iPadRootViewController.h"
#import "StackScrollViewController.h"

@implementation CacheAlbumViewController

@synthesize listOfAlbums, listOfSongs, sectionInfo, segments;

NSInteger trackSort2(id obj1, id obj2, void *context)
{
	NSUInteger track1 = [(NSNumber*)[(NSArray*)obj1 objectAtIndexSafe:1] intValue];
	NSUInteger track2 = [(NSNumber*)[(NSArray*)obj2 objectAtIndexSafe:1] intValue];
	if (track1 < track2)
		return NSOrderedAscending;
	else if (track1 == track2)
		return NSOrderedSame;
	else
		return NSOrderedDescending;
}

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if (settingsS.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];

	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
	//else
	//{
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
	//}
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
		FMDatabase *db = databaseS.albumListCacheDb;
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
		
		self.sectionInfo = [databaseS sectionInfoFromTable:@"albumIndex" inDatabase:db withColumn:@"album"];
		[db executeUpdate:@"DROP TABLE IF EXSITS albumIndex"];
		
		if (sectionInfo)
		{
			if ([sectionInfo count] < 5)
				self.sectionInfo = nil;
			else
				[self.tableView reloadData];
		}
	}	
	
	// Set notification receiver for when cached songs are deleted to reload the table
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cachedSongDeleted) name:@"cachedSongDeleted" object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"cachedSongDeleted" object:nil];
}


- (void)cachedSongDeleted
{
	NSUInteger segment = [segments count];
	
	self.listOfAlbums = [NSMutableArray arrayWithCapacity:1];
	self.listOfSongs = [NSMutableArray arrayWithCapacity:1];
	
	NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT md5, segs, seg%i, track FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? ", segment+1];
	for (int i = 2; i <= segment; i++)
	{
		[query appendFormat:@" AND seg%i = ? ", i];
	}
	[query appendFormat:@"GROUP BY seg%i ORDER BY seg%i COLLATE NOCASE", segment+1, segment+1];
	
	FMResultSet *result = [databaseS.songCacheDb executeQuery:query withArgumentsInArray:segments];
	
	while ([result next])
	{
		if ([result intForColumnIndex:1] > (segment + 1))
		{
			NSArray *albumEntry = [NSArray arrayWithObjects:[result stringForColumnIndex:0], [result stringForColumnIndex:2], nil];
			[self.listOfAlbums addObject:albumEntry];
		}
		else
		{
			NSArray *songEntry = [NSArray arrayWithObjects:[result stringForColumnIndex:0], [NSNumber numberWithInt:[result intForColumnIndex:3]], nil];
			[self.listOfSongs addObject:songEntry];
			
			BOOL multipleSameTrackNumbers = NO;
			NSMutableArray *trackNumbers = [NSMutableArray arrayWithCapacity:[self.listOfSongs count]];
			for (NSArray *song in self.listOfSongs)
			{
				NSNumber *track = [song objectAtIndexSafe:1];
				
				if ([trackNumbers containsObject:track])
				{
					multipleSameTrackNumbers = YES;
					break;
				}
				
				[trackNumbers addObject:track];
			}
			
			// Sort by track number
			if (!multipleSameTrackNumbers)
				[self.listOfSongs sortUsingFunction:trackSort2 context:NULL];
		}
	}
	[result close];
	
	// If the table is empty, pop back one view, otherwise reload the table data
	if ([self.listOfAlbums count] + [self.listOfSongs count] == 0)
	{
		if (IS_IPAD())
		{
			// TODO: implement this properly
			//[appDelegateS.ipadRootViewController.stackScrollViewController popToRootViewController];
		}
		else
		{
			// Handle the moreNavigationController stupidity
			if (appDelegateS.currentTabBarController.selectedIndex == 4)
			{
				[appDelegateS.currentTabBarController.moreNavigationController popToViewController:[appDelegateS.currentTabBarController.moreNavigationController.viewControllers objectAtIndexSafe:1] animated:YES];
			}
			else
			{
				[(UINavigationController*)appDelegateS.currentTabBarController.selectedViewController popToRootViewControllerAnimated:YES];
			}
		}
	}
	else
	{
		[self.tableView reloadData];
	}
}

- (void)playAllAction:(id)sender
{	
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	[self performSelector:@selector(loadPlayAllPlaylist:) withObject:@"NO" afterDelay:0.05];
}

- (void)shuffleAction:(id)sender
{
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Shuffling"];
	[self performSelector:@selector(loadPlayAllPlaylist:) withObject:@"YES" afterDelay:0.05];
}


- (void)loadPlayAllPlaylist:(NSString *)shuffle
{		
	NSUInteger segment = [segments count];
	
	BOOL isShuffle;
	if ([shuffle isEqualToString:@"YES"])
		isShuffle = YES;
	else
		isShuffle = NO;
	
	[databaseS resetCurrentPlaylistDb];
	
	NSMutableString *query = [NSMutableString stringWithString:@"SELECT md5 FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? "];
	for (int i = 2; i <= segment; i++)
	{
		[query appendFormat:@" AND seg%i = ? ", i];
	}
	[query appendFormat:@"ORDER BY seg%i COLLATE NOCASE", segment];
	
	FMResultSet *result = [databaseS.songCacheDb executeQuery:query withArgumentsInArray:segments];
	while ([result next])
	{
		if ([result stringForColumnIndex:0] != nil)
			[[Song songFromCacheDb:[NSString stringWithString:[result stringForColumnIndex:0]]] addToCurrentPlaylist];
	}
	[result close];
	
	if (isShuffle)
	{
		playlistS.isShuffle = YES;
		
		[databaseS resetShufflePlaylist];
		[databaseS.currentPlaylistDb executeUpdate:@"INSERT INTO shufflePlaylist SELECT * FROM currentPlaylist ORDER BY RANDOM()"];
	}
	else
	{
		playlistS.isShuffle = NO;
	}
			
	// Must do UI stuff in main thread
	[self performSelectorOnMainThread:@selector(loadPlayAllPlaylist2) withObject:nil waitUntilDone:NO];	
}


- (void)playAllPlaySong
{	
	[musicS playSongAtPosition:0];
	
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
}


- (void)loadPlayAllPlaylist2
{
	[viewObjectsS hideLoadingScreen];

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

- (void)dealloc 
{
	self.listOfAlbums = nil;
	self.listOfSongs = nil;
    [super dealloc];
}

#pragma mark Table view methods

// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView 
{
	NSMutableArray *indexes = [[[NSMutableArray alloc] init] autorelease];
	for (int i = 0; i < [sectionInfo count]; i++)
	{
		[indexes addObject:[[sectionInfo objectAtIndexSafe:i] objectAtIndexSafe:0]];
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
		NSUInteger row = [[[sectionInfo objectAtIndexSafe:(index - 1)] objectAtIndexSafe:1] intValue];
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
	// Set up the cell...
	if (indexPath.row < [listOfAlbums count])
	{
		//NSUInteger segment = [segments count];
		//NSString *seg1 = [segments objectAtIndexSafe:0];
		
		static NSString *cellIdentifier = @"CacheAlbumCell";
		CacheAlbumUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[CacheAlbumUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		}
		
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		//cell.segment = segment;
		//cell.seg1 = seg1;
		cell.segments = [NSArray arrayWithArray:segments];
		DLog(@"segments: %@", cell.segments);
		
		NSString *md5 = [[listOfAlbums objectAtIndexSafe:indexPath.row] objectAtIndexSafe:0];
		NSString *coverArtId = [databaseS.songCacheDb stringForQuery:@"SELECT coverArtId FROM cachedSongs WHERE md5 = ?", md5];
		NSString *name = [[listOfAlbums objectAtIndexSafe:indexPath.row] objectAtIndexSafe:1];
		
		if (coverArtId)
		{
			NSString *test = [databaseS.coverArtCacheDb60 stringForQuery:@"SELECT id FROM coverArtCache WHERE id = ?", [coverArtId md5]];
			if (test)
			{
				// If the image is already in the cache database, load it
				cell.coverArtView.image = [UIImage imageWithData:[databaseS.coverArtCacheDb60 dataForQuery:@"SELECT data FROM coverArtCache WHERE id = ?", [coverArtId md5]]];
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
		
		[cell.albumNameLabel setText:[name cleanString]];
		cell.backgroundView = [[[UIView alloc] init] autorelease];
		if(indexPath.row % 2 == 0)
			cell.backgroundView.backgroundColor = [UIColor whiteColor];
		else
			cell.backgroundView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];		
		
		return cell;
	}
	else
	{
		static NSString *cellIdentifier = @"CacheSongCell";
		CacheSongUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[CacheSongUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
		
		NSUInteger a = indexPath.row - [listOfAlbums count];
		cell.md5 = [[listOfSongs objectAtIndexSafe:a] objectAtIndexSafe:0];
		
		Song *aSong = [Song songFromCacheDb:cell.md5];
		
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{	
	if (!indexPath)
		return;
	
	if (viewObjectsS.isCellEnabled)
	{
		if (indexPath.row < [listOfAlbums count])
		{		
			NSUInteger segment = [segments count] + 1;
			
			CacheAlbumViewController *cacheAlbumViewController = [[CacheAlbumViewController alloc] initWithNibName:@"CacheAlbumViewController" bundle:nil];
			cacheAlbumViewController.title = [[listOfAlbums objectAtIndexSafe:indexPath.row] objectAtIndexSafe:1];
			cacheAlbumViewController.listOfAlbums = [NSMutableArray arrayWithCapacity:1];
			cacheAlbumViewController.listOfSongs = [NSMutableArray arrayWithCapacity:1];

			NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT md5, segs, seg%i, track FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? ", segment+1];
			for (int i = 2; i <= segment; i++)
			{
				[query appendFormat:@" AND seg%i = ? ", i];
			}
			[query appendFormat:@"GROUP BY seg%i ORDER BY seg%i COLLATE NOCASE", segment+1, segment+1];
			DLog(@"query: %@", query);

			NSMutableArray *newSegments = [NSMutableArray arrayWithArray:segments];
			[newSegments addObject:cacheAlbumViewController.title];
			cacheAlbumViewController.segments = [NSArray arrayWithArray:newSegments];
			DLog(@"newSegments: %@", newSegments);
			
			FMResultSet *result = [databaseS.songCacheDb executeQuery:query withArgumentsInArray:newSegments];
			while ([result next])
			{
				if ([result intForColumnIndex:1] > (segment + 1))
				{
					NSArray *albumEntry = [NSArray arrayWithObjects:[result stringForColumnIndex:0], [result stringForColumnIndex:2], nil];
					[cacheAlbumViewController.listOfAlbums addObject:albumEntry];
				}
				else
				{
					NSArray *songEntry = [NSArray arrayWithObjects:[result stringForColumnIndex:0], [NSNumber numberWithInt:[result intForColumnIndex:3]], nil];
					[cacheAlbumViewController.listOfSongs addObject:songEntry];
					
					BOOL multipleSameTrackNumbers = NO;
					NSMutableArray *trackNumbers = [NSMutableArray arrayWithCapacity:[cacheAlbumViewController.listOfSongs count]];
					for (NSArray *song in cacheAlbumViewController.listOfSongs)
					{
						NSNumber *track = [song objectAtIndexSafe:1];
						
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
			[result close];
			
			[self pushViewControllerCustom:cacheAlbumViewController];
			[cacheAlbumViewController release];
		}
		else
		{			
			NSUInteger a = indexPath.row - [listOfAlbums count];
			
			[databaseS resetCurrentPlaylistDb];
			for(NSArray *song in listOfSongs)
			{
				Song *aSong = [Song songFromCacheDb:[song objectAtIndexSafe:0]];
				[aSong addToCurrentPlaylist];
			}
						
			playlistS.isShuffle = NO;
			
			[musicS playSongAtPosition:a];
			
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
		}
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}


@end

