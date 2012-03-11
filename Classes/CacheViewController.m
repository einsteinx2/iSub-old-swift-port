//
//  CacheViewController.m
//  iSub
//
//  Created by Ben Baron on 6/1/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CacheViewController.h"
#import "CacheAlbumViewController.h"
#import "Song.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "CacheQueueSongUITableViewCell.h"
#import "FMDatabaseAdditions.h"
#import "AsynchronousImageView.h"
#import "ServerListViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "Reachability.h"
#import "CacheArtistUITableViewCell.h"
#import "StoreViewController.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
#import "CacheSingleton.h"
#import "PlaylistSingleton.h"
#import "FlurryAnalytics.h"
#import "NSString+Additions.h"
#import "AudioEngine.h"
#import "NSArray+Additions.h"
#import "NSNotificationCenter+MainThread.h"
#import "JukeboxSingleton.h"
#import "ISMSCacheQueueManager.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "UIViewController+IsVisible.h"

@interface CacheViewController ()
- (void)addNoSongsScreen;
- (void)segmentAction:(id)sender;
- (void)removeSaveEditButtons;
- (void)addSaveEditButtons;
- (void)removeNoSongsScreen;
@property NSUInteger cacheQueueCount;
@end

@implementation CacheViewController

@synthesize listOfArtists, listOfArtistsSections, sectionInfo, cacheQueueCount;

#pragma mark - Rotation handling

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if (settingsS.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	if (!IS_IPAD() && isNoSongsScreenShowing)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:duration];
		if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
		{
			noSongsScreen.transform = CGAffineTransformTranslate(noSongsScreen.transform, 0.0, -23.0);
		}
		else
		{
			noSongsScreen.transform = CGAffineTransformTranslate(noSongsScreen.transform, 0.0, 110.0);
		}
		[UIView commitAnimations];
	}
}

#pragma mark - View lifecycle

- (void)registerForNotifications
{
	// Set notification receiver for when queued songs finish downloading to reload the table
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable) name:ISMSNotification_CacheQueueSongDownloaded object:nil];
	
	// Set notification receiver for when cached songs are deleted to reload the table
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable) name:@"cachedSongDeleted" object:nil];
	
	// Set notification receiver for when network status changes to reload the table
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(segmentAction:) name:kReachabilityChangedNotification object: nil];
}

- (void)unregisterForNotifications
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CacheQueueSongDownloaded object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"cachedSongDeleted" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
}

- (void)viewDidLoad 
{
	[super viewDidLoad];
	
	DLog(@"isVisible: %@", NSStringFromBOOL(self.isVisible));
	
	//DLog(@"Cache viewDidLoad");
	
	cacheSizeLabel = nil;
	
	jukeboxInputBlocker = nil;
	
	viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
	//viewObjectsS.multiDeleteList = nil; viewObjectsS.multiDeleteList = [[NSMutableArray alloc] init];
	isNoSongsScreenShowing = NO;
	isSaveEditShowing = NO;
		
	self.tableView.separatorColor = [UIColor clearColor];
	
	if (viewObjectsS.isOfflineMode)
	{
		self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] 
																				  style:UIBarButtonItemStyleBordered 
																				 target:self 
																				 action:@selector(settingsAction:)] autorelease];
	}
	
	headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)] autorelease];
	headerView.backgroundColor = [UIColor colorWithWhite:.3 alpha:1];
	segmentedControl = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Cached", @"Downloading", nil]];
	[segmentedControl addTarget:self action:@selector(segmentAction:) forControlEvents:UIControlEventValueChanged];
	
	segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
	segmentedControl.frame = CGRectMake(5, 5, 310, 36);
	segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	segmentedControl.tintColor = [UIColor colorWithWhite:.57 alpha:1];
	segmentedControl.selectedSegmentIndex = 0;
	if (viewObjectsS.isOfflineMode) 
	{
		segmentedControl.hidden = YES;
	}
	[headerView addSubview:segmentedControl];
	
	if (viewObjectsS.isOfflineMode) 
	{
		headerView.frame = CGRectMake(0, 0, 320, 50);
		headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		
		headerView2 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
		headerView2.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		headerView2.backgroundColor = viewObjectsS.darkNormal;
		[headerView addSubview:headerView2];
		[headerView2 release];
		
		playAllImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"play-all-note.png"]];
		playAllImage.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		playAllImage.frame = CGRectMake(10, 10, 19, 30);
		[headerView2 addSubview:playAllImage];
		[playAllImage release];
		
		playAllLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 160, 50)];
		playAllLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
		playAllLabel.backgroundColor = [UIColor clearColor];
		playAllLabel.textColor = [UIColor colorWithRed:186.0/255.0 green:191.0/255.0 blue:198.0/255.0 alpha:1];
		playAllLabel.textAlignment = UITextAlignmentCenter;
		playAllLabel.font = [UIFont boldSystemFontOfSize:30];
		playAllLabel.text = @"Play All";
		[headerView2 addSubview:playAllLabel];
		[playAllLabel release];
		
		playAllButton = [UIButton buttonWithType:UIButtonTypeCustom];
		playAllButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
		playAllButton.frame = CGRectMake(0, 0, 160, 40);
		[playAllButton addTarget:self action:@selector(playAllAction:) forControlEvents:UIControlEventTouchUpInside];
		[headerView2 addSubview:playAllButton];
		
		spacerLabel2 = [[UILabel alloc] initWithFrame:CGRectMake(158, -2, 6, 50)];
		spacerLabel2.backgroundColor = [UIColor clearColor];
		spacerLabel2.textColor = [UIColor colorWithRed:186.0/255.0 green:191.0/255.0 blue:198.0/255.0 alpha:1];
		spacerLabel2.font = [UIFont systemFontOfSize:40];
		spacerLabel2.text = @"|";
		spacerLabel2.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		[headerView2 addSubview:spacerLabel2];
		[spacerLabel2 release];
		
		shuffleImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"shuffle-small.png"]];
		shuffleImage.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		shuffleImage.frame = CGRectMake(180, 12, 24, 26);
		[headerView2 addSubview:shuffleImage];
		[shuffleImage release];
		
		shuffleLabel = [[UILabel alloc] initWithFrame:CGRectMake(180, 0, 160, 50)];
		shuffleLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth;
		shuffleLabel.backgroundColor = [UIColor clearColor];
		shuffleLabel.textColor = [UIColor colorWithRed:186.0/255.0 green:191.0/255.0 blue:198.0/255.0 alpha:1];
		shuffleLabel.textAlignment = UITextAlignmentCenter;
		shuffleLabel.font = [UIFont boldSystemFontOfSize:30];
		shuffleLabel.text = @"Shuffle";
		[headerView2 addSubview:shuffleLabel];
		[shuffleLabel release];
		
		shuffleButton = [UIButton buttonWithType:UIButtonTypeCustom];
		shuffleButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth;
		shuffleButton.frame = CGRectMake(160, 0, 160, 40);
		[shuffleButton addTarget:self action:@selector(shuffleAction:) forControlEvents:UIControlEventTouchUpInside];
		[headerView2 addSubview:shuffleButton];
		
		// Add the top fade
		UIImageView *fadeTop = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-top.png"]];
		fadeTop.frame =CGRectMake(0, -10, self.tableView.bounds.size.width, 10);
		fadeTop.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self.tableView addSubview:fadeTop];
		[fadeTop release];
	}
	
	self.tableView.tableHeaderView = headerView;
	
	UIImageView *fadeBottom = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]] autorelease];
	fadeBottom.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
	fadeBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.tableView.tableFooterView = fadeBottom;
	
	if (viewObjectsS.isOfflineMode)
	{
		self.title = @"Artists";
	}
	else 
	{
		self.title = @"Cache";
		
		// Setup the update timer
		[self updateQueueDownloadProgress];
		
		//[self registerForNotifications];
	}
	
	if (IS_IPAD())
		self.view.backgroundColor = ISMSiPadBackgroundColor;
		
	self.tableView.scrollEnabled = YES;
	[jukeboxInputBlocker removeFromSuperview];
	jukeboxInputBlocker = nil;
	if (settingsS.isJukeboxEnabled)
	{
		self.tableView.scrollEnabled = NO;
		
		jukeboxInputBlocker = [UIButton buttonWithType:UIButtonTypeCustom];
		jukeboxInputBlocker.frame = CGRectMake(0, 0, 1004, 1004);
		[self.view addSubview:jukeboxInputBlocker];
		
		UIView *colorView = [[UIView alloc] initWithFrame:jukeboxInputBlocker.frame];
		colorView.backgroundColor = [UIColor blackColor];
		colorView.alpha = 0.5;
		[jukeboxInputBlocker addSubview:colorView];
		[colorView release];
	}
	
	if(musicS.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	// Reload the data in case it changed
	if (settingsS.isCacheUnlocked)
	{
		self.tableView.tableHeaderView.hidden = NO;
		
		segmentedControl.selectedSegmentIndex = 0;
		[self segmentAction:nil];
	}
	else
	{
		self.tableView.tableHeaderView.hidden = YES;
		[self addNoSongsScreen];
	}
}

- (void)viewWillAppear:(BOOL)animated 
{	
	[super viewWillAppear:animated];
	
	DLog(@"isVisible: %@", NSStringFromBOOL(self.isVisible));
	
	[self registerForNotifications];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewWillAppear:) name:ISMSNotification_StorePurchaseComplete object:nil];
	
	[self reloadTable];
	
	[self updateQueueDownloadProgress];
	[self updateCacheSizeLabel];
	
	[FlurryAnalytics logEvent:@"CacheTab"];
}

-(void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	DLog(@"isVisible: %@", NSStringFromBOOL(self.isVisible));
	
	[self unregisterForNotifications];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateQueueDownloadProgress) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateCacheSizeLabel) object:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_StorePurchaseComplete object:nil];
}

- (void)didReceiveMemoryWarning 
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)dealloc
{
    [super dealloc];
}

- (void)segmentAction:(id)sender
{
	DLog(@"isVisible: %@", NSStringFromBOOL(self.isVisible));
	
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		if (self.tableView.editing)
		{
			[self editSongsAction:nil];
		}
		
		[self reloadTable];
		
		if ([listOfArtists count] == 0)
		{
			[self removeSaveEditButtons];
			
			[self addNoSongsScreen];
		}
		else 
		{
			[self removeNoSongsScreen];
			
			if (viewObjectsS.isOfflineMode == NO)
			{
				[self addSaveEditButtons];
			}
		}
	}
	else if (segmentedControl.selectedSegmentIndex == 1)
	{
		if (self.tableView.editing)
		{
			[self editSongsAction:nil];
		}
		
		[self reloadTable];
		
		if (self.cacheQueueCount > 0)
		{
			[self removeNoSongsScreen];
			[self addSaveEditButtons];
		}
	}
	
	[self.tableView reloadData];
}

#pragma mark - Button Handling

- (void)showStore
{
	StoreViewController *store = [[StoreViewController alloc] init];
	//DLog(@"store: %@", store);
	[self.navigationController pushViewController:store animated:YES];
	[store release];
}

- (void)settingsAction:(id)sender 
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

- (void)playAllAction:(id)sender
{	
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	[self performSelector:@selector(loadPlayAllPlaylist:) withObject:@"NO" afterDelay:0.05];
}

- (void)shuffleAction:(id)sender
{
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	[self performSelector:@selector(loadPlayAllPlaylist:) withObject:@"YES" afterDelay:0.05];
}

- (void)loadPlayAllPlaylist:(NSString *)shuffle
{			
	playlistS.isShuffle = NO;
	
	BOOL isShuffle;
	if ([shuffle isEqualToString:@"YES"])
		isShuffle = YES;
	else
		isShuffle = NO;
	
	[databaseS resetCurrentPlaylistDb];
	
	FMResultSet *result = [databaseS.songCacheDb executeQuery:@"SELECT md5 FROM cachedSongsLayout ORDER BY seg1 COLLATE NOCASE"];
	
	while ([result next])
	{			
		@autoreleasepool 
		{
			Song *aSong = [Song songFromCacheDb:[NSString stringWithString:[result stringForColumnIndex:0]]];
			
			if (aSong.path)
				[aSong addToCurrentPlaylist];
		}
	}
	[result close];
	
	if (isShuffle)
	{
		playlistS.isShuffle = YES;
		[databaseS shufflePlaylist];
	}
	else
	{
		playlistS.isShuffle = NO;
	}
	
	if (settingsS.isJukeboxEnabled)
		[jukeboxS jukeboxReplacePlaylistWithLocal];
	
	// Must do UI stuff in main thread
	[viewObjectsS hideLoadingScreen];
	[self playAllPlaySong];	
}

#pragma mark -

- (void)reloadTable
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		// Create the artist list
		self.listOfArtists = [NSMutableArray arrayWithCapacity:1];
		self.listOfArtistsSections = [NSMutableArray arrayWithCapacity:28];
		
		// Fix for slow load problem (EDIT: Looks like it didn't actually work :(
		FMDatabase *db = databaseS.songCacheDb;
		[db executeUpdate:@"DROP TABLE IF EXISTS cachedSongsArtistList"];
		[db executeUpdate:@"CREATE TEMP TABLE cachedSongsArtistList (artist TEXT UNIQUE)"];
		[db executeUpdate:@"INSERT OR IGNORE INTO cachedSongsArtistList SELECT seg1 FROM cachedSongsLayout"];
		
		FMResultSet *result = [db executeQuery:@"SELECT artist FROM cachedSongsArtistList ORDER BY artist COLLATE NOCASE"];
		while ([result next])
		{
			// Cover up for blank insert problem
			if ([[result stringForColumnIndex:0] length] > 0)
				[listOfArtists addObject:[NSString stringWithString:[result stringForColumnIndex:0]]]; 
		}
		[result close];
		
		[listOfArtists sortUsingSelector:@selector(caseInsensitiveCompareWithoutIndefiniteArticles:)];
		//DLog(@"listOfArtists: %@", listOfArtists);
		
		// Create the section index
		[db executeUpdate:@"DROP TABLE IF EXISTS cachedSongsArtistIndex"];
		[db executeUpdate:@"CREATE TEMP TABLE cachedSongsArtistIndex (artist TEXT)"];
		DLog(@"listOfArtists: %@", listOfArtists);
		for (NSString *artist in listOfArtists)
		{
			[db executeUpdate:@"INSERT INTO cachedSongsArtistIndex (artist) VALUES (?)", [artist stringWithoutIndefiniteArticle], nil];
		}
		self.sectionInfo = nil; 
		self.sectionInfo = [databaseS sectionInfoFromTable:@"cachedSongsArtistIndex" inDatabase:db withColumn:@"artist"];
		DLog(@"sectionInfo: %@", sectionInfo);
		showIndex = YES;
		if ([sectionInfo count] < 5)
			showIndex = NO;
		
		//DLog(@"sectionInfo: %@", sectionInfo);
		
		// Sort into sections		
		if ([sectionInfo count] > 0)
		{
			int lastIndex = 0;
			for (int i = 0; i < [sectionInfo count] - 1; i++)
			{
				NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
				int index = [[[sectionInfo objectAtIndexSafe:i+1] objectAtIndexSafe:1] intValue];
				NSMutableArray *section = [NSMutableArray arrayWithCapacity:0];
				for (int i = lastIndex; i < index; i++)
				{
					[section addObject:[listOfArtists objectAtIndexSafe:i]];
				}
				[listOfArtistsSections addObject:section];
				lastIndex = index;
				[pool release];
			}
			NSMutableArray *section = [NSMutableArray arrayWithCapacity:0];
			for (int i = lastIndex; i < [listOfArtists count]; i++)
			{
				[section addObject:[listOfArtists objectAtIndexSafe:i]];
			}
			[listOfArtistsSections addObject:section];
		}
		
		if (isSaveEditShowing)
		{
			NSUInteger cachedSongsCount = [databaseS.songCacheDb intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE finished = 'YES' AND md5 != ''"];
			if ([databaseS.songCacheDb intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE finished = 'YES' AND md5 != ''"] == 1)
				songsCountLabel.text = [NSString stringWithFormat:@"1 Song"];
			else 
				songsCountLabel.text = [NSString stringWithFormat:@"%i Songs", cachedSongsCount];
		}
	}
	else
	{
		[databaseS.cacheQueueDb executeUpdate:@"DROP TABLE IF EXISTS cacheQueueList"];
		//[databaseS.cacheQueueDb executeUpdate:[NSString stringWithFormat:@"CREATE TEMP TABLE cacheQueueList (md5 TEXT, finished TEXT, cachedDate INTEGER, playedDate INTEGER, %@)", [Song standardSongColumnSchema]]];
		[databaseS.cacheQueueDb executeUpdate:@"CREATE TEMP TABLE cacheQueueList (md5 TEXT)"];
		[databaseS.cacheQueueDb executeUpdate:@"INSERT INTO cacheQueueList SELECT md5 FROM cacheQueue"];
		
		if (self.tableView.editing)
		{
			NSArray *multiDeleteList = [NSArray arrayWithArray:viewObjectsS.multiDeleteList];
			for (NSString *md5 in multiDeleteList)
			{
				NSString *dbMd5 = [databaseS.cacheQueueDb stringForQuery:@"SELECT md5 FROM cacheQueueList WHERE md5 = ?", md5];
				DLog(@"md5: %@   dbMD5: %@", md5, dbMd5);
				if (!dbMd5) 
					[viewObjectsS.multiDeleteList removeObject:md5];
			}
		}
		
		self.cacheQueueCount = [databaseS.cacheQueueDb intForQuery:@"SELECT COUNT(*) FROM cacheQueueList"];
		if (self.cacheQueueCount == 0)
		{
			[self removeSaveEditButtons];	
			[self addNoSongsScreen];
		}
		else
		{
			if (isSaveEditShowing)
			{
				if (self.cacheQueueCount == 1)
					songsCountLabel.text = [NSString stringWithFormat:@"1 Song"];
				else 
					songsCountLabel.text = [NSString stringWithFormat:@"%i Songs", self.cacheQueueCount];
			}
			else
			{
				[self addSaveEditButtons];
			}
			
			if (isNoSongsScreenShowing)
				[self removeNoSongsScreen];
		}
	}
	
	[self.tableView reloadData];
}

- (void)updateCacheSizeLabel
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		if (cacheS.cacheSize <= 0)
			cacheSizeLabel.text = @"";
		else
			cacheSizeLabel.text = [NSString formatFileSize:cacheS.cacheSize];
	}
	
	// Make sure this didn't get called multiple times
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateCacheSizeLabel) object:nil];
	
	// Call again in a couple seconds
	[self performSelector:@selector(updateCacheSizeLabel) withObject:nil afterDelay:2.0];
}

- (void)updateQueueDownloadProgress
{
	if (segmentedControl.selectedSegmentIndex == 1 && cacheQueueManagerS.isQueueDownloading)
	{	
		[self reloadTable];
	}
	
	// Make sure this didn't get called multiple times
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateQueueDownloadProgress) object:nil];
	
	// Call again in a second
	[self performSelector:@selector(updateQueueDownloadProgress) withObject:nil afterDelay:1.];
}

- (void)removeSaveEditButtons
{
	if (isSaveEditShowing == YES)
	{
		isSaveEditShowing = NO;
		[songsCountLabel removeFromSuperview]; songsCountLabel = nil;
		[deleteSongsButton removeFromSuperview]; deleteSongsButton = nil;
		[spacerLabel removeFromSuperview]; spacerLabel = nil;
		[editSongsLabel removeFromSuperview]; editSongsLabel = nil;
		[editSongsButton removeFromSuperview]; editSongsButton = nil;
		[deleteSongsLabel removeFromSuperview]; deleteSongsLabel = nil;
		[cacheSizeLabel removeFromSuperview]; cacheSizeLabel = nil;
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateCacheSizeLabel) object:nil];
		[headerView2 removeFromSuperview]; headerView2 = nil;
		
		headerView.frame = CGRectMake(0, 0, 320, 44);
		
		self.tableView.tableHeaderView = headerView;
	}
}

- (void)addSaveEditButtons
{
	[self removeSaveEditButtons];
	
	if (isSaveEditShowing == NO)
	{
		// Modify the header view to include the save and edit buttons
		isSaveEditShowing = YES;
		int y = 45;
		
		headerView.frame = CGRectMake(0, 0, 320, y + 100);
		if (segmentedControl.selectedSegmentIndex == 1)
			headerView.frame = CGRectMake(0, 0, 320, y + 50);
		
		songsCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, y, 227, 34)];
		songsCountLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		songsCountLabel.backgroundColor = [UIColor clearColor];
		songsCountLabel.textColor = [UIColor whiteColor];
		songsCountLabel.textAlignment = UITextAlignmentCenter;
		songsCountLabel.font = [UIFont boldSystemFontOfSize:22];
		if (segmentedControl.selectedSegmentIndex == 0)
		{
			NSUInteger cachedSongsCount = [databaseS.songCacheDb intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE finished = 'YES' AND md5 != ''"];
			if ([databaseS.songCacheDb intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE finished = 'YES' AND md5 != ''"] == 1)
				songsCountLabel.text = [NSString stringWithFormat:@"1 Song"];
			else 
				songsCountLabel.text = [NSString stringWithFormat:@"%i Songs", cachedSongsCount];
		}
		else if (segmentedControl.selectedSegmentIndex == 1)
		{
			if (self.cacheQueueCount == 1)
				songsCountLabel.text = [NSString stringWithFormat:@"1 Song"];
			else 
				songsCountLabel.text = [NSString stringWithFormat:@"%i Songs", self.cacheQueueCount];
		}
		[headerView addSubview:songsCountLabel];
		[songsCountLabel release];
		
		cacheSizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, y + 33, 227, 14)];
		cacheSizeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		cacheSizeLabel.backgroundColor = [UIColor clearColor];
		cacheSizeLabel.textColor = [UIColor whiteColor];
		cacheSizeLabel.textAlignment = UITextAlignmentCenter;
		cacheSizeLabel.font = [UIFont boldSystemFontOfSize:12];
		if (segmentedControl.selectedSegmentIndex == 0)
		{
			if (cacheS.cacheSize <= 0)
				cacheSizeLabel.text = @"";
			else
				cacheSizeLabel.text = [NSString formatFileSize:cacheS.cacheSize];
		}
		else if (segmentedControl.selectedSegmentIndex == 1)
		{
			/*unsigned long long combinedSize = 0;
			FMResultSet *result = [databaseS.cacheQueueDb executeQuery:@"SELECT size FROM cacheQueue"];
			while ([result next])
			{
				combinedSize += [result longLongIntForColumnIndex:0];
			}
			[result close];
			cacheSizeLabel.text = [NSString formatFileSize:combinedSize];*/
			
			cacheSizeLabel.text = @"";
		}
		[headerView addSubview:cacheSizeLabel];
		[cacheSizeLabel release];
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateCacheSizeLabel) object:nil];
		[self updateCacheSizeLabel];
		
		deleteSongsButton = [UIButton buttonWithType:UIButtonTypeCustom];
		deleteSongsButton.frame = CGRectMake(0, y, 230, 50);
		deleteSongsButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		[deleteSongsButton addTarget:self action:@selector(deleteSongsAction:) forControlEvents:UIControlEventTouchUpInside];
		[headerView addSubview:deleteSongsButton];
		
		spacerLabel = [[UILabel alloc] initWithFrame:CGRectMake(226, y - 2, 6, 50)];
		spacerLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		spacerLabel.backgroundColor = [UIColor clearColor];
		spacerLabel.textColor = [UIColor whiteColor];
		spacerLabel.font = [UIFont systemFontOfSize:40];
		spacerLabel.text = @"|";
		[headerView addSubview:spacerLabel];
		[spacerLabel release];	
		
		editSongsLabel = [[UILabel alloc] initWithFrame:CGRectMake(234, y, 86, 50)];
		editSongsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
		editSongsLabel.backgroundColor = [UIColor clearColor];
		editSongsLabel.textColor = [UIColor whiteColor];
		editSongsLabel.textAlignment = UITextAlignmentCenter;
		editSongsLabel.font = [UIFont boldSystemFontOfSize:22];
		editSongsLabel.text = @"Edit";
		[headerView addSubview:editSongsLabel];
		[editSongsLabel release];
		
		editSongsButton = [UIButton buttonWithType:UIButtonTypeCustom];
		editSongsButton.frame = CGRectMake(234, y, 86, 40);
		editSongsButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
		[editSongsButton addTarget:self action:@selector(editSongsAction:) forControlEvents:UIControlEventTouchUpInside];
		[headerView addSubview:editSongsButton];	
		
		deleteSongsLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, y, 227, 50)];
		deleteSongsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		deleteSongsLabel.backgroundColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:.5];
		deleteSongsLabel.textColor = [UIColor whiteColor];
		deleteSongsLabel.textAlignment = UITextAlignmentCenter;
		deleteSongsLabel.font = [UIFont boldSystemFontOfSize:22];
		deleteSongsLabel.adjustsFontSizeToFitWidth = YES;
		deleteSongsLabel.minimumFontSize = 12;
		deleteSongsLabel.text = @"Delete # Songs";
		deleteSongsLabel.hidden = YES;
		[headerView addSubview:deleteSongsLabel];
		[deleteSongsLabel release];
		
		headerView2 = nil;
		if (segmentedControl.selectedSegmentIndex == 0)
		{
			headerView2 = [[UIView alloc] initWithFrame:CGRectMake(0, y + 50, 320, 50)];
			headerView2.autoresizingMask = UIViewAutoresizingFlexibleWidth;
			headerView2.backgroundColor = viewObjectsS.darkNormal;
			[headerView addSubview:headerView2];
			[headerView2 release];
			
			playAllImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"play-all-note.png"]];
			playAllImage.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
			playAllImage.frame = CGRectMake(10, 10, 19, 30);
			[headerView2 addSubview:playAllImage];
			[playAllImage release];
			
			playAllLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 160, 50)];
			playAllLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
			playAllLabel.backgroundColor = [UIColor clearColor];
			playAllLabel.textColor = [UIColor colorWithRed:186.0/255.0 green:191.0/255.0 blue:198.0/255.0 alpha:1];
			playAllLabel.textAlignment = UITextAlignmentCenter;
			playAllLabel.font = [UIFont boldSystemFontOfSize:30];
			playAllLabel.text = @"Play All";
			[headerView2 addSubview:playAllLabel];
			[playAllLabel release];
			
			playAllButton = [UIButton buttonWithType:UIButtonTypeCustom];
			playAllButton.frame = CGRectMake(0, 0, 160, 40);
			playAllButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
			[playAllButton addTarget:self action:@selector(playAllAction:) forControlEvents:UIControlEventTouchUpInside];
			[headerView2 addSubview:playAllButton];
			
			spacerLabel2 = [[UILabel alloc] initWithFrame:CGRectMake(158, -2, 6, 50)];
			spacerLabel2.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
			spacerLabel2.backgroundColor = [UIColor clearColor];
			spacerLabel2.textColor = [UIColor colorWithRed:186.0/255.0 green:191.0/255.0 blue:198.0/255.0 alpha:1];
			spacerLabel2.font = [UIFont systemFontOfSize:40];
			spacerLabel2.text = @"|";
			[headerView2 addSubview:spacerLabel2];
			[spacerLabel2 release];
			
			shuffleImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"shuffle-small.png"]];
			shuffleImage.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
			shuffleImage.frame = CGRectMake(180, 12, 24, 26);
			[headerView2 addSubview:shuffleImage];
			[shuffleImage release];
			
			shuffleLabel = [[UILabel alloc] initWithFrame:CGRectMake(180, 0, 160, 50)];
			shuffleLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth;
			shuffleLabel.backgroundColor = [UIColor clearColor];
			shuffleLabel.textColor = [UIColor colorWithRed:186.0/255.0 green:191.0/255.0 blue:198.0/255.0 alpha:1];
			shuffleLabel.textAlignment = UITextAlignmentCenter;
			shuffleLabel.font = [UIFont boldSystemFontOfSize:30];
			shuffleLabel.text = @"Shuffle";
			[headerView2 addSubview:shuffleLabel];
			[shuffleLabel release];
			
			shuffleButton = [UIButton buttonWithType:UIButtonTypeCustom];
			shuffleButton.frame = CGRectMake(160, 0, 160, 40);
			shuffleButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth;
			[shuffleButton addTarget:self action:@selector(shuffleAction:) forControlEvents:UIControlEventTouchUpInside];
			[headerView2 addSubview:shuffleButton];
		}
		
		self.tableView.tableHeaderView = headerView;
	}
}

- (void)removeNoSongsScreen
{
	if (isNoSongsScreenShowing == YES)
	{
		[noSongsScreen removeFromSuperview];
		isNoSongsScreenShowing = NO;
	}
}

- (void)addNoSongsScreen
{
	[self removeNoSongsScreen];
	
	if (isNoSongsScreenShowing == NO)
	{		
		isNoSongsScreenShowing = YES;
		noSongsScreen = [[UIImageView alloc] init];
		noSongsScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
		noSongsScreen.frame = CGRectMake(40, 100, 240, 180);
		noSongsScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
		noSongsScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
		noSongsScreen.alpha = .80;
		noSongsScreen.userInteractionEnabled = YES;
		
		UILabel *textLabel = [[UILabel alloc] init];
		textLabel.backgroundColor = [UIColor clearColor];
		textLabel.textColor = [UIColor whiteColor];
		textLabel.font = [UIFont boldSystemFontOfSize:32];
		textLabel.textAlignment = UITextAlignmentCenter;
		textLabel.numberOfLines = 0;
		if (settingsS.isCacheUnlocked)
		{
			if (segmentedControl.selectedSegmentIndex == 0)
				[textLabel setText:@"No Cached\nSongs"];
			else if (segmentedControl.selectedSegmentIndex == 1)
				[textLabel setText:@"No Queued\nSongs"];
			
			textLabel.frame = CGRectMake(20, 20, 200, 140);
		}
		else
		{
			textLabel.text = @"Caching\nLocked";
			textLabel.frame = CGRectMake(20, 0, 200, 100);
		}
		[noSongsScreen addSubview:textLabel];
		[textLabel release];
		
		if (settingsS.isCacheUnlocked == NO)
		{
			UILabel *textLabel2 = [[UILabel alloc] init];
			textLabel2.backgroundColor = [UIColor clearColor];
			textLabel2.textColor = [UIColor whiteColor];
			textLabel2.font = [UIFont boldSystemFontOfSize:14];
			textLabel2.textAlignment = UITextAlignmentCenter;
			textLabel2.numberOfLines = 0;
			textLabel2.text = @"Tap to purchase the ability to cache songs for better streaming performance and offline playback";
			textLabel2.frame = CGRectMake(20, 90, 200, 70);
			[noSongsScreen addSubview:textLabel2];
			[textLabel2 release];
			
			UIButton *storeLauncher = [UIButton buttonWithType:UIButtonTypeCustom];
			storeLauncher.frame = CGRectMake(0, 0, noSongsScreen.frame.size.width, noSongsScreen.frame.size.height);
			[storeLauncher addTarget:self action:@selector(showStore) forControlEvents:UIControlEventTouchUpInside];
			[noSongsScreen addSubview:storeLauncher];
		}
		
		[self.view addSubview:noSongsScreen];
		
		[noSongsScreen release];
		
		if (!IS_IPAD())
		{
			if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
			{
				noSongsScreen.transform = CGAffineTransformTranslate(noSongsScreen.transform, 0.0, 23.0);
			}
		}
	}
}

- (void) showDeleteButton
{
	if ([viewObjectsS.multiDeleteList count] == 0)
	{
		deleteSongsLabel.text = @"Select All";
	}
	else if ([viewObjectsS.multiDeleteList count] == 1)
	{
		if (segmentedControl.selectedSegmentIndex == 0)
			deleteSongsLabel.text = @"Delete 1 Folder  ";
		else
			deleteSongsLabel.text = @"Delete 1 Song  ";
	}
	else
	{
		if (segmentedControl.selectedSegmentIndex == 0)
			deleteSongsLabel.text = [NSString stringWithFormat:@"Delete %i Folders", [viewObjectsS.multiDeleteList count]];
		else
			deleteSongsLabel.text = [NSString stringWithFormat:@"Delete %i Songs", [viewObjectsS.multiDeleteList count]];
	}
	
	songsCountLabel.hidden = YES;
	cacheSizeLabel.hidden = YES;
	deleteSongsLabel.hidden = NO;
}


- (void)hideDeleteButton
{
	if ([viewObjectsS.multiDeleteList count] == 0)
	{
		if (!self.tableView.editing)
		{
			songsCountLabel.hidden = NO;
			cacheSizeLabel.hidden = NO;
			deleteSongsLabel.hidden = YES;
		}
		else
		{
			deleteSongsLabel.text = @"Select All";
		}
	}
	else if ([viewObjectsS.multiDeleteList count] == 1)
	{
		if (segmentedControl.selectedSegmentIndex == 0)
			deleteSongsLabel.text = @"Delete 1 Folder  ";
		else
			deleteSongsLabel.text = @"Delete 1 Song  ";
	}
	else 
	{
		if (segmentedControl.selectedSegmentIndex == 0)
			deleteSongsLabel.text = [NSString stringWithFormat:@"Delete %i Folders", [viewObjectsS.multiDeleteList count]];
		else
			deleteSongsLabel.text = [NSString stringWithFormat:@"Delete %i Songs", [viewObjectsS.multiDeleteList count]];
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


- (void)editSongsAction:(id)sender
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		if (!self.tableView.editing)
		{
			[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(showDeleteButton) name:@"showDeleteButton" object: nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(hideDeleteButton) name:@"hideDeleteButton" object: nil];
			viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			[self.tableView setEditing:YES animated:YES];
			editSongsLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
			editSongsLabel.text = @"Done";
			[self showDeleteButton];
			
			[self performSelector:@selector(showDeleteToggle) withObject:nil afterDelay:0.3];
		}
		else 
		{
			[[NSNotificationCenter defaultCenter] removeObserver:self name:@"showDeleteButton" object:nil];
			[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideDeleteButton" object:nil];
			viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			[self.tableView setEditing:NO animated:YES];
			[self hideDeleteButton];
			editSongsLabel.backgroundColor = [UIColor clearColor];
			editSongsLabel.text = @"Edit";
			
			// Reload the table
			[self.tableView reloadData];
		}
	}
	else if (segmentedControl.selectedSegmentIndex == 1)
	{
		if (!self.tableView.editing)
		{
			[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(showDeleteButton) name:@"showDeleteButton" object: nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(hideDeleteButton) name:@"hideDeleteButton" object: nil];
			viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			[self.tableView setEditing:YES animated:YES];
			editSongsLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
			editSongsLabel.text = @"Done";
			[self showDeleteButton];
			
			[self performSelector:@selector(showDeleteToggle) withObject:nil afterDelay:0.3];
		}
		else 
		{
			[[NSNotificationCenter defaultCenter] removeObserver:self name:@"showDeleteButton" object:nil];
			[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideDeleteButton" object:nil];
			viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			[self hideDeleteButton];
			[self.tableView setEditing:NO animated:YES];
			editSongsLabel.backgroundColor = [UIColor clearColor];
			editSongsLabel.text = @"Edit";
			
			// Reload the table
			[self reloadTable];
		}
	}
}

- (void)deleteRowsAtIndexPathsWithAnimation:(NSArray *)indexes
{
	@try
	{
		[self.tableView deleteRowsAtIndexPaths:indexes withRowAnimation:YES];
	}
	@catch (NSException *exception) 
	{
		DLog(@"Exception: %@ - %@", exception.name, exception.reason);
	}
}

- (void)deleteCachedSongs
{	
	[self unregisterForNotifications];
	
	for (NSString *folderName in viewObjectsS.multiDeleteList)
	{
		FMResultSet *result;
		result = [databaseS.songCacheDb executeQuery:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? ", folderName];
		
		while ([result next])
		{
			if ([result stringForColumnIndex:0] != nil)
				[Song removeSongFromCacheDbByMD5:[NSString stringWithString:[result stringForColumnIndex:0]]];
		}
		[result close];
	}	
	
	[self segmentAction:nil];
	
	[cacheS findCacheSize];
	
	[viewObjectsS hideLoadingScreen];
	
	if (!cacheQueueManagerS.isQueueDownloading)
		[cacheQueueManagerS startDownloadQueue];
	
	[self registerForNotifications];
}

- (void)deleteQueuedSongs
{
	[self unregisterForNotifications];
	
	// Sort the multiDeleteList to make sure it's accending
	[viewObjectsS.multiDeleteList sortUsingSelector:@selector(compare:)];
	
	// Delete each song from the database
	for (NSString *md5 in viewObjectsS.multiDeleteList)
	{
		// Check if we're deleting the song that's currently caching. If so, stop the download.
		if (cacheQueueManagerS.currentQueuedSong)
		{
			if ([[cacheQueueManagerS.currentQueuedSong.path md5] isEqualToString:md5])
			{
				[cacheQueueManagerS stopDownloadQueue];
			}
		}
		
		// Delete the row from the cacheQueue
		[databaseS.cacheQueueDb executeUpdate:@"DELETE FROM cacheQueue WHERE md5 = ?", md5];
	}		
	
	// Reload the table
	[self editSongsAction:nil];
	
	if (!cacheQueueManagerS.isQueueDownloading)
		[cacheQueueManagerS startDownloadQueue];
	
	[viewObjectsS hideLoadingScreen];
	
	[self registerForNotifications];
}

- (void)deleteSongsAction:(id)sender
{
	if (self.tableView.editing)
	{
		if ([deleteSongsLabel.text isEqualToString:@"Select All"])
		{
			if (segmentedControl.selectedSegmentIndex == 0)
			{
				NSUInteger count = 0;
				for (NSArray *section in listOfArtistsSections)
				{
					count += [section count];
				}
				
				// Select all the rows
				for (int i = 0; i < count; i++)
				{
					for (NSArray *section in listOfArtistsSections)
					{
						for (NSString *folderName in section)
						{
							[viewObjectsS.multiDeleteList addObject:folderName];
						}
					}
				}
			}
			else
			{
				// Select all the rows
				FMResultSet *result = [databaseS.cacheQueueDb executeQuery:@"SELECT md5 FROM cacheQueueList"];
				while ([result next])
				{
					NSString *md5 = [result stringForColumnIndex:0];
					if (md5) [viewObjectsS.multiDeleteList addObject:md5];
				}
			}
			
			[self.tableView reloadData];
			[self showDeleteButton];
		}
		else
		{
			[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Deleting"];
			if (segmentedControl.selectedSegmentIndex == 0)
				[self performSelector:@selector(deleteCachedSongs) withObject:nil afterDelay:0.05];
			else
				[self performSelector:@selector(deleteQueuedSongs) withObject:nil afterDelay:0.05];
		}
	}
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


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	if (segmentedControl.selectedSegmentIndex == 0 && settingsS.isCacheUnlocked)
	{
		DLog(@"sectionInfo count: %i", [sectionInfo count]);
		return [sectionInfo count];
	}
	
	return 1;
}

// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView 
{
	if (segmentedControl.selectedSegmentIndex == 0 && settingsS.isCacheUnlocked && showIndex)
	{
		NSMutableArray *indexes = [[[NSMutableArray alloc] init] autorelease];
		for (int i = 0; i < [sectionInfo count]; i++)
		{
			[indexes addObject:[[sectionInfo objectAtIndexSafe:i] objectAtIndexSafe:0]];
		}
		return indexes;
	}
		
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	
	if (segmentedControl.selectedSegmentIndex == 0 && settingsS.isCacheUnlocked)
	{
		return [[sectionInfo objectAtIndexSafe:section] objectAtIndexSafe:0];
	}
	
	return @"";
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index 
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		/*if (index == 0)
		{
			[tableView scrollRectToVisible:CGRectMake(0, 90, 320, 40) animated:NO];
		}
		else
		{
			NSUInteger row = [[[sectionInfo objectAtIndexSafe:(index - 1)] objectAtIndexSafe:1] intValue];
			NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
			[tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
		}*/
		
		if (index == 0) 
		{
			[tableView scrollRectToVisible:CGRectMake(0, 90, 320, 40) animated:NO];
			return -1;
		}
		
		return index;
	}
	
	return -1;
}


// Customize the height of individual rows to make the album rows taller to accomidate the album art.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (segmentedControl.selectedSegmentIndex == 0)
		return 44.0;
	else
		return 80.0;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	if (settingsS.isCacheUnlocked)
	{
		// Return the number of rows in the section.
		if (segmentedControl.selectedSegmentIndex == 0)
		{
			//return [listOfArtists count];
			return [[listOfArtistsSections objectAtIndexSafe:section] count];
		}
		else if (segmentedControl.selectedSegmentIndex == 1)
		{
			return self.cacheQueueCount;
		}
	}
	
	return 0;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{    
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		static NSString *cellIdentifier = @"CacheArtistCell";
		CacheArtistUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[CacheArtistUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		}

		NSString *name = [[listOfArtistsSections objectAtIndexSafe:indexPath.section] objectAtIndexSafe:indexPath.row];
		
		cell.deleteToggleImage.hidden = !self.tableView.editing;
		cell.deleteToggleImage.image = [UIImage imageNamed:@"unselected.png"];
		if ([viewObjectsS.multiDeleteList containsObject:name])
		{
			cell.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
		}
		
		if (showIndex)
			cell.isIndexShowing = YES;
		
		// Set up the cell...
		[cell.artistNameLabel setText:[name cleanString]];
		
		cell.backgroundView = [[[UIView alloc] init] autorelease];
		if(indexPath.row % 2 == 0)
			cell.backgroundView.backgroundColor = viewObjectsS.lightNormal;
		else
			cell.backgroundView.backgroundColor = viewObjectsS.darkNormal;
		
		return cell;
	}
	else
	{
		static NSString *cellIdentifier = @"CacheQueueCell";
		CacheQueueSongUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[CacheQueueSongUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		}
		cell.indexPath = indexPath;

		// Set up the cell...
		FMResultSet *result = [databaseS.cacheQueueDb executeQuery:@"SELECT * FROM cacheQueue JOIN cacheQueueList USING(md5) WHERE cacheQueueList.ROWID = ?", [NSNumber numberWithInt:(indexPath.row + 1)]];
		Song *aSong = [Song songFromDbResult:result];
		NSDate *cached = [NSDate dateWithTimeIntervalSince1970:[result doubleForColumn:@"cachedDate"]];
		cell.md5 = [result stringForColumn:@"md5"];
		[result close];

		cell.deleteToggleImage.hidden = !self.tableView.editing;
		cell.deleteToggleImage.image = [UIImage imageNamed:@"unselected.png"];
		if ([viewObjectsS.multiDeleteList containsObject:cell.md5])
		{
			cell.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
		}
		
		cell.coverArtView.coverArtId = aSong.coverArtId;
		
		cell.backgroundView = [[[UIView alloc] init] autorelease];
		if(indexPath.row % 2 == 0)
			cell.backgroundView.backgroundColor = viewObjectsS.lightNormal;
		else
			cell.backgroundView.backgroundColor = viewObjectsS.darkNormal;
		
		if (indexPath.row == 0)
		{
			if ([aSong isEqualToSong:cacheQueueManagerS.currentQueuedSong] && cacheQueueManagerS.isQueueDownloading)
			{
				queueDownloadProgress = cacheQueueManagerS.currentQueuedSong.localFileSize;
				cell.cacheInfoLabel.text = [NSString stringWithFormat:@"Added %@ - Progress: %@", [NSString relativeTime:cached], [NSString formatFileSize:queueDownloadProgress]];
			}
			else if (appDelegateS.isWifi)
			{
				cell.cacheInfoLabel.text = [NSString stringWithFormat:@"Added %@ - Progress: Waiting...", [NSString relativeTime:cached]];
			}
			else
			{
				cell.cacheInfoLabel.text = [NSString stringWithFormat:@"Added %@ - Progress: Need Wifi", [NSString relativeTime:cached]];
			}
		}
		else
		{
			cell.cacheInfoLabel.text = [NSString stringWithFormat:@"Added %@ - Progress: Waiting...", [NSString relativeTime:cached]];
		}
		
		cell.songNameLabel.text = aSong.title;
		if (aSong.album)
			cell.artistNameLabel.text = [NSString stringWithFormat:@"%@ - %@", aSong.artist, aSong.album];
		else
			cell.artistNameLabel.text = aSong.artist;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		
		return cell;
	}
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}


// Set the editing style, set to none for no delete minus sign (overriding with own custom multi-delete boxes)
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return UITableViewCellEditingStyleNone;
	//return UITableViewCellEditingStyleDelete;
}


#pragma mark -
#pragma mark Table view delegate

NSInteger trackSort1(id obj1, id obj2, void *context)
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath)
		return;
	
    if (segmentedControl.selectedSegmentIndex == 0)
	{
		if (viewObjectsS.isCellEnabled)
		{
			NSString *name = nil;
			if ([listOfArtistsSections count] > indexPath.section)
				if ([[listOfArtistsSections objectAtIndexSafe:indexPath.section] count] > indexPath.row)
					name = [[listOfArtistsSections objectAtIndexSafe:indexPath.section] objectAtIndexSafe:indexPath.row];
			
			CacheAlbumViewController *cacheAlbumViewController = [[CacheAlbumViewController alloc] initWithNibName:@"CacheAlbumViewController" bundle:nil];
			cacheAlbumViewController.title = name;
			cacheAlbumViewController.listOfAlbums = [NSMutableArray arrayWithCapacity:1];
			cacheAlbumViewController.listOfSongs = [NSMutableArray arrayWithCapacity:1];
			//DLog(@"cacheAlbumViewController.seg1: %@", cacheAlbumViewController.seg1);
			FMResultSet *result = [databaseS.songCacheDb executeQuery:@"SELECT md5, segs, seg2, track FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? GROUP BY seg2 ORDER BY seg2 COLLATE NOCASE", name];
			while ([result next])
			{
				NSUInteger numOfSegments = [result intForColumnIndex:1];
				
				if (numOfSegments > 2)
				{
					[cacheAlbumViewController.listOfAlbums addObject:[NSArray arrayWithObjects:[NSString stringWithString:[result stringForColumn:@"md5"]], 
																							   [NSString stringWithString:[result stringForColumn:@"seg2"]], nil]];
				}
				else
				{
					[cacheAlbumViewController.listOfSongs addObject:[NSArray arrayWithObjects:[NSString stringWithString:[result stringForColumn:@"md5"]], 
																							  [NSNumber numberWithInt:[result intForColumn:@"track"]], nil]];
					
					/*// Sort by track number -- iOS 4.0+ only
					[cacheAlbumViewController.listOfSongs sortUsingComparator: ^NSComparisonResult(id obj1, id obj2) {
						NSUInteger track1 = [(NSNumber*)[(NSArray*)obj1 objectAtIndexSafe:1] intValue];
						NSUInteger track2 = [(NSNumber*)[(NSArray*)obj2 objectAtIndexSafe:1] intValue];
						if (track1 < track2)
							return NSOrderedAscending;
						else if (track1 == track2)
							return NSOrderedSame;
						else
							return NSOrderedDescending;
					}];*/
					
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
						[cacheAlbumViewController.listOfSongs sortUsingFunction:trackSort1 context:NULL];
				}

				if (!cacheAlbumViewController.segments)
				{
					NSArray *segments = [NSArray arrayWithObjects:name, nil];
					cacheAlbumViewController.segments = segments;				
				}
			}
			[result close];
			
			[self pushViewControllerCustom:cacheAlbumViewController];
			//[self.navigationController pushViewController:cacheAlbumViewController animated:YES];
			[cacheAlbumViewController release];
		}
		else
		{
			[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
		}
	}
}

@end

