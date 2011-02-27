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
#import "MusicControlsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "CacheAlbumUITableViewCell.h"
#import "CacheSongUITableViewCell.h"
#import "Artist.h"
#import "Album.h"
#import "Song.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString+md5.h"

@implementation CacheAlbumViewController

@synthesize listOfAlbums, listOfSongs, sectionInfo, segment, seg1;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation {
    return YES;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicControlsSingleton sharedInstance];
	databaseControls = [DatabaseControlsSingleton sharedInstance];
	
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
		[databaseControls.inMemoryDb executeUpdate:@"DROP TABLE albumIndex"];
		[databaseControls.inMemoryDb executeUpdate:@"CREATE TABLE albumIndex (album TEXT)"];
		/*for (Album *album in listOfAlbums)
		 {
		 [databaseControls.inMemoryDb executeUpdate:@"INSERT INTO albumIndex (album) VALUES (?)", album.title];
		 }*/
		
		[databaseControls.albumListCacheDb beginTransaction];
		for (NSNumber *rowId in listOfAlbums)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			NSString *albumTitle = [databaseControls.albumListCacheDb stringForQuery:@"SELECT title FROM albumsCache WHERE rowid = ?", rowId];
			[databaseControls.inMemoryDb executeUpdate:@"INSERT INTO albumIndex (album) VALUES (?)", albumTitle];
			
			[pool release];
		}
		[databaseControls.albumListCacheDb commit];
		
		/*FMResultSet *result = [databaseControls.albumListCacheDb executeQuery:@"SELECT title FROM albumsCache WHERE folderId = ?", self.myId];
		 while ([result next]);
		 {
		 NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		 
		 NSString *albumTitle = [result stringForColumnIndex:0];
		 [databaseControls.inMemoryDb executeUpdate:@"INSERT INTO albumIndex (album) VALUES (?)", albumTitle];
		 
		 [pool release];
		 }*/
		//self.sectionInfo = nil; 
		self.sectionInfo = [databaseControls sectionInfoFromTable:@"albumIndex" inDatabase:databaseControls.inMemoryDb withColumn:@"album"];
		
		if (sectionInfo)
		{
			if ([sectionInfo count] < 5)
				self.sectionInfo = nil;
			else
				[self.tableView reloadData];
		}
	}	
}


- (void) cachedSongDeleted
{
	FMResultSet *result = [databaseControls.songCacheDb executeQuery:[NSString stringWithFormat:@"SELECT md5, segs, seg%i FROM cachedSongsLayout WHERE seg1 = ? AND seg%i = ? GROUP BY seg%i ORDER BY seg%i COLLATE NOCASE", segment, (segment - 1), segment, segment], seg1, self.title];
	self.listOfAlbums = [NSMutableArray arrayWithCapacity:1];
	self.listOfSongs = [NSMutableArray arrayWithCapacity:1];
	//self.listOfAlbums = nil; self.listOfAlbums = [[NSMutableArray alloc] init];
	//self.listOfSongs = nil; self.listOfSongs = [[NSMutableArray alloc] init];
	while ([result next])
	{
		if ([result intForColumnIndex:1] > segment)
		{
			[self.listOfAlbums addObject:[NSArray arrayWithObjects:[result stringForColumnIndex:0], [result stringForColumnIndex:2], nil]];
		}
		else
		{
			[self.listOfSongs addObject:[result stringForColumnIndex:0]];
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
		[self.tableView reloadData];
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
	
	BOOL isShuffle;
	if ([shuffle isEqualToString:@"YES"])
		isShuffle = YES;
	else
		isShuffle = NO;
	
	[musicControls performSelectorOnMainThread:@selector(destroyStreamer) withObject:nil waitUntilDone:YES];
	[databaseControls resetCurrentPlaylistDb];
	
	FMResultSet *result;
	if (segment == 2)
	{
		result = [databaseControls.songCacheDb executeQuery:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? ORDER BY seg2 COLLATE NOCASE", seg1];
	}
	else
	{
		result = [databaseControls.songCacheDb executeQuery:[NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND seg%i = ? ORDER BY seg%i COLLATE NOCASE", (segment - 1), segment], seg1, self.title];
	}

	while ([result next])
	{
		[databaseControls addSongToPlaylistQueue:[databaseControls songFromCacheDb:[result stringForColumnIndex:0]]];
	}
	
	if (isShuffle)
	{
		musicControls.isShuffle = YES;
		
		[databaseControls resetShufflePlaylist];
		[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO shufflePlaylist SELECT * FROM currentPlaylist ORDER BY RANDOM()"];
	}
	else
	{
		musicControls.isShuffle = NO;
	}
	
	musicControls.currentPlaylistPosition = 0;
	
	musicControls.currentSongObject = nil;
	musicControls.nextSongObject = nil;
	if (isShuffle)
	{
		musicControls.currentSongObject = [databaseControls songFromDbRow:0 inTable:@"shufflePlaylist" inDatabase:databaseControls.currentPlaylistDb];
		musicControls.nextSongObject = [databaseControls songFromDbRow:1 inTable:@"shufflePlaylist" inDatabase:databaseControls.currentPlaylistDb];
	}
	else
	{
		musicControls.currentSongObject = [databaseControls songFromDbRow:0 inTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
		musicControls.nextSongObject = [databaseControls songFromDbRow:1 inTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
	}
		
	// Must do UI stuff in main thread
	[self performSelectorOnMainThread:@selector(loadPlayAllPlaylist2) withObject:nil waitUntilDone:NO];	
	
	[autoreleasePool release];
}


- (void)playAllPlaySong
{
	musicControls.isNewSong = YES;
	
	[musicControls playPauseSong];
	
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
	musicControls.isNewSong = NO;
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
	FMResultSet *result = [databaseControls.songCacheDb executeQuery:@"SELECT * FROM cachedSongs WHERE md5 = ?", md5];
	[result next];
	if ([databaseControls.songCacheDb hadError]) {
		NSLog(@"Err %d: %@", [databaseControls.songCacheDb lastErrorCode], [databaseControls.songCacheDb lastErrorMessage]);
	}
	
	aSong.title = [result stringForColumnIndex:4];
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
	aSong.size = [NSNumber numberWithInt:[result intForColumnIndex:17]];
	
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
		NSString *coverArtId = [databaseControls.songCacheDb stringForQuery:@"SELECT coverArtId FROM cachedSongs WHERE md5 = ?", md5];
		NSString *name = [[listOfAlbums objectAtIndex:indexPath.row] objectAtIndex:1];
		
		if (coverArtId)
		{
			if ([databaseControls.coverArtCacheDb60 intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [NSString md5:coverArtId]] == 1)
			{
				// If the image is already in the cache database, load it
				cell.coverArtView.image = [UIImage imageWithData:[databaseControls.coverArtCacheDb60 dataForQuery:@"SELECT data FROM coverArtCache WHERE id = ?", [NSString md5:coverArtId]]];
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
		
		[cell.albumNameLabel setText:name];
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
		cell.md5 = [listOfSongs objectAtIndex:a];
		
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
			cell.songDurationLabel.text = [appDelegate formatTime:[aSong.duration floatValue]];
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
			//NSLog(@"query: %@", [NSString stringWithFormat:@"SELECT md5, segs, seg%i FROM cachedSongsLayout WHERE seg1 = '%@' AND seg%i = '%@' GROUP BY seg%i ORDER BY seg%i COLLATE NOCASE", (segment + 1), seg1, segment, [[listOfAlbums objectAtIndex:indexPath.row] objectAtIndex:1], (segment + 1), (segment + 1)]);
			FMResultSet *result = [databaseControls.songCacheDb executeQuery:[NSString stringWithFormat:@"SELECT md5, segs, seg%i FROM cachedSongsLayout WHERE seg1 = ? AND seg%i = ? GROUP BY seg%i ORDER BY seg%i COLLATE NOCASE", (segment + 1), segment, (segment + 1), (segment + 1)], seg1, [[listOfAlbums objectAtIndex:indexPath.row] objectAtIndex:1]];
			while ([result next])
			{
				if ([result intForColumnIndex:1] > (segment + 1))
				{
					[cacheAlbumViewController.listOfAlbums addObject:[NSArray arrayWithObjects:[result stringForColumnIndex:0], [result stringForColumnIndex:2], nil]];
				}
				else
				{
					[cacheAlbumViewController.listOfSongs addObject:[result stringForColumnIndex:0]];
				}
			}
						
			[self.navigationController pushViewController:cacheAlbumViewController animated:YES];
			[cacheAlbumViewController release];
		}
		else
		{
			NSUInteger a = indexPath.row - [listOfAlbums count];
			musicControls.currentSongObject = nil; musicControls.currentSongObject = [self songFromCacheDb:[listOfSongs objectAtIndex:a]];
			
			musicControls.currentPlaylistPosition = a;
			[databaseControls resetCurrentPlaylistDb];
			for(NSString *songMD5 in listOfSongs)
			{
				//NSLog(@"songMD5: %@", songMD5);
				Song *aSong = [self songFromCacheDb:songMD5];
				//NSLog(@"aSong: %@", aSong);
				[databaseControls insertSong:aSong intoTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
			}
			
			musicControls.nextSongObject = nil; musicControls.nextSongObject = [databaseControls songFromDbRow:(a + 1) inTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
			
			musicControls.isNewSong = YES;
			musicControls.isShuffle = NO;
			
			[musicControls destroyStreamer];
			musicControls.seekTime = 0.0;
			[musicControls playPauseSong];
			
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

