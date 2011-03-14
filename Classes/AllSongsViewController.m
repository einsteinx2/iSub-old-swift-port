//
//  AllSongsViewController.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright Ben Baron 2010. All rights reserved.
//


#import "AllSongsViewController.h"
#import "SearchOverlayViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicControlsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "AllSongsXMLParser.h"
#import "AllSongsUITableViewCell.h"
#import "AsynchronousImageViewCached.h"
#import "Album.h"
#import "Song.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString-md5.h"
#import "LoadingScreen.h"
#import "ASIHTTPRequest.h"
#import "RootViewController.h"
#import "TBXML.h"
#import "CustomUITableView.h"
#import "CustomUIAlertView.h"

@interface AllSongsViewController (Private)

- (void)loadData;
- (void)loadAlbumFolder;
- (void)loadSort;
- (void)loadFinish;

@end

@implementation AllSongsViewController

@synthesize headerView, sectionInfo, currentAlbum;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if ([[[iSubAppDelegate sharedInstance].settingsDictionary objectForKey:@"lockRotationSetting"] isEqualToString:@"YES"] 
		&& inOrientation != UIDeviceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicControlsSingleton sharedInstance];
	databaseControls = [DatabaseControlsSingleton sharedInstance];
	
	self.title = @"Songs";
	//self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];

	// Set defaults
	didBeginSearching = NO;
	viewObjects.isSearchingAllSongs = NO;
	letUserSelectRow = YES;	
	
	numberOfRows = 0;
	[self.headerView removeFromSuperview];
	self.sectionInfo = nil;
	if ([databaseControls.allSongsDb tableExists:@"allSongs"] == YES && ![[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@isAllSongsLoading", appDelegate.defaultUrl]] isEqualToString:@"YES"])
	{
		numberOfRows = [databaseControls.allSongsDb intForQuery:@"SELECT COUNT(*) FROM allSongs"];
		self.sectionInfo = [self createSectionInfo];
		[self addCount];
	}
	[self.tableView reloadData];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(doneSearching_Clicked:) name:@"endSearch" object:searchOverlayView];

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
	
	// Don't run this while the table is updating
	if (!viewObjects.isSongsLoading)
	{
		if(musicControls.showPlayerIcon)
		{
			self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
		}
		else
		{
			self.navigationItem.rightBarButtonItem = nil;
		}
		
		// If the database hasn't been created then create it otherwise show the header
		if ([databaseControls.allSongsDb tableExists:@"allSongs"] == NO || [[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@isAllSongsLoading", appDelegate.defaultUrl]] isEqualToString:@"YES"])
		{
			if ([databaseControls.allAlbumsDb tableExists:@"allAlbums"] == NO || [[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@isAllAlbumsLoading", appDelegate.defaultUrl]] isEqualToString:@"YES"])
			{
				CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"You must load the Albums tab first" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
				[alert show];
				[alert release];
			}
			else if (viewObjects.isAlbumsLoading)
			{
				CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Please Wait" message:@"You cannot reload the Songs tab while the Albums tab is loading" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
				[alert show];
				[alert release];
			}
			else
			{
				if ([[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@isAllSongsLoading", appDelegate.defaultUrl]] isEqualToString:@"YES"])
				{
					CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Resume Load?" message:@"If you've reloaded the albums tab since this load started you should choose 'Restart Load'.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Restart Load", @"Resume Load", nil];
					[alert show];
					[alert release];
				}
				else
				{
					CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Load?" message:@"This could take a while if you have a big collection.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.\n\nNote: If you've added new artists or albums, you should reload the Folders and Albums first." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
					[alert show];
					[alert release];
				}
			}
		}
		else 
		{
			//numberOfRows = [appDelegate.allSongsDb intForQuery:@"SELECT COUNT(*) FROM allSongs"];
			//self.sectionInfo = [self createSectionInfo];
			//[self addCount];
		}
	}
	else
	{
		[viewObjects.allSongsLoadingScreen.view removeFromSuperview];
		[self.view addSubview:viewObjects.allSongsLoadingScreen.view];
	}
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}


- (void)viewDidUnload {
	// Release anything that can be recreated in viewDidLoad or on demand.
	// e.g. self.myOutlet = nil;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"endSearch" object:searchOverlayView];
}


- (void)dealloc 
{
	[searchBar release];
	[searchOverlayView release];
	[url release];
    [super dealloc];
}

-(void)addCount
{
	// Build the search and reload view
	headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 90)] autorelease];
	headerView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];
	
	reloadButton = [UIButton buttonWithType:UIButtonTypeCustom];
	reloadButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	reloadButton.frame = CGRectMake(0, 0, 320, 40);
	[reloadButton addTarget:self action:@selector(reloadAction:) forControlEvents:UIControlEventTouchUpInside];
	[headerView addSubview:reloadButton];
	
	countLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, 320, 30)];
	countLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	countLabel.backgroundColor = [UIColor clearColor];
	countLabel.textColor = [UIColor colorWithRed:156.0/255.0 green:161.0/255.0 blue:168.0/255.0 alpha:1];
	countLabel.textAlignment = UITextAlignmentCenter;
	countLabel.font = [UIFont boldSystemFontOfSize:30];
	[headerView addSubview:countLabel];
	[countLabel release];
	
	reloadImage = [[UIImageView alloc] initWithFrame:CGRectMake(20, 13, 24, 26)];
	reloadImage.image = [UIImage imageNamed:@"reload-table.png"];
	[headerView addSubview:reloadImage];
	[reloadImage release];
	
	searchBar = [[UISearchBar  alloc] initWithFrame:CGRectMake(0, 50, 320, 40)];
	searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	searchBar.delegate = self;
	searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	searchBar.placeholder = @"Song name";
	[headerView addSubview:searchBar];
	[searchBar release];
	
	reloadTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 36, 320, 12)];
	reloadTimeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	reloadTimeLabel.backgroundColor = [UIColor clearColor];
	reloadTimeLabel.textColor = [UIColor colorWithRed:176.0/255.0 green:181.0/255.0 blue:188.0/255.0 alpha:1];
	reloadTimeLabel.textAlignment = UITextAlignmentCenter;
	reloadTimeLabel.font = [UIFont systemFontOfSize:11];
	[headerView addSubview:reloadTimeLabel];
	[reloadTimeLabel release];
	
	countLabel.text = [NSString stringWithFormat:@"%i Songs", [databaseControls.allSongsDb intForQuery:@"SELECT COUNT(*) FROM allSongs"]];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateStyle:NSDateFormatterMediumStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	reloadTimeLabel.text = [NSString stringWithFormat:@"last reload: %@", [formatter stringFromDate:[defaults objectForKey:[NSString stringWithFormat:@"%@songsReloadTime", appDelegate.defaultUrl]]]];
	[formatter release];
	
	self.tableView.tableHeaderView = headerView;
	[self.tableView reloadData];
}


static NSInteger order (id a, id b, void* context)
{
    NSString* catA = [a lastObject];
    NSString* catB = [b lastObject];
    return [catA caseInsensitiveCompare:catB];
}

#pragma mark Data loading

- (void)createLoadTables
{
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	// Inialize the all songs db
	[databaseControls.allSongsDb executeUpdate:@"CREATE TABLE resumeLoad (albumNum INTEGER, iteration INTEGER)"];
	[databaseControls.allSongsDb executeUpdate:@"INSERT INTO resumeLoad (albumNum, iteration) VALUES (0, 0)"];
	[databaseControls.allSongsDb executeUpdate:@"DROP TABLE allSongs"];
	[databaseControls.allSongsDb executeUpdate:@"DROP TABLE allSongsTemp"];
	[databaseControls.allSongsDb executeUpdate:@"CREATE VIRTUAL TABLE allSongs USING FTS3 (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER, tokenize=porter)"];
	[databaseControls.allSongsDb executeUpdate:@"CREATE TABLE allSongsTemp (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
	[databaseControls.allSongsDb executeUpdate:@"CREATE INDEX title ON allSongsTemp (title ASC)"];
	
	// Initialize the subalbums tables
	[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE subalbums1"];
	[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE subalbums2"];
	[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE subalbums3"];
	[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE subalbums4"];
	[databaseControls.allAlbumsDb executeUpdate:@"CREATE TABLE subalbums1 (title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
	[databaseControls.allAlbumsDb executeUpdate:@"CREATE TABLE subalbums2 (title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
	[databaseControls.allAlbumsDb executeUpdate:@"CREATE TABLE subalbums3 (title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
	[databaseControls.allAlbumsDb executeUpdate:@"CREATE TABLE subalbums4 (title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
	
	// Initialize the genres db
	[databaseControls.genresDb close]; databaseControls.genresDb = nil;
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@genres.db", databaseControls.databaseFolderPath, [NSString md5:appDelegate.defaultUrl]] error:NULL];
	databaseControls.genresDb = [[FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@genres.db", databaseControls.databaseFolderPath, [NSString md5:appDelegate.defaultUrl]]] retain];
	if ([databaseControls.genresDb open] == NO) { NSLog(@"Could not open genresDb."); }
	
	[databaseControls.genresDb executeUpdate:@"CREATE TABLE genres (genre TEXT UNIQUE)"];
	[databaseControls.genresDb executeUpdate:@"CREATE TABLE genresTemp (genre TEXT UNIQUE)"];
	[databaseControls.genresDb executeUpdate:@"CREATE TABLE genresSongs (md5 TEXT UNIQUE, title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX songGenre ON genresSongs (genre)"];
	
	[databaseControls.genresDb executeUpdate:@"CREATE TABLE genresLayout (md5 TEXT UNIQUE, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX layoutGenre ON genresLayout (genre)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX seg1 ON genresLayout (seg1)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX seg2 ON genresLayout (seg2)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX seg3 ON genresLayout (seg3)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX seg4 ON genresLayout (seg4)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX seg5 ON genresLayout (seg5)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX seg6 ON genresLayout (seg6)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX seg7 ON genresLayout (seg7)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX seg8 ON genresLayout (seg8)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX seg9 ON genresLayout (seg9)"];
	
	[autoreleasePool release];
}

/*- (void)createConnection
{
	
}*/

- (void)loadAlbumFolder
{	
	// Check if loading should stop
	if (viewObjects.cancelLoading)
	{
		viewObjects.cancelLoading = NO;
		viewObjects.isSongsLoading = NO;
		[self performSelectorInBackground:@selector(hideLoadingScreen) withObject:nil];
		return;
	}
	
	if (iteration == 0)
		self.currentAlbum = [databaseControls albumFromDbRow:currentRow inTable:@"allAlbums" inDatabase:databaseControls.allAlbumsDb];
	else
		self.currentAlbum = [databaseControls albumFromDbRow:currentRow inTable:[NSString stringWithFormat:@"subalbums%i", iteration] inDatabase:databaseControls.allAlbumsDb];
	viewObjects.allSongsCurrentArtistId = currentAlbum.artistId;
	viewObjects.allSongsCurrentArtistName = currentAlbum.artistName;
	viewObjects.currentLoadingFolderId = currentAlbum.albumId;
	
	/*// Remove any rows for this folder  --- DONE IN CONN DELEGATE
	[databaseControls.albumListCacheDb beginTransaction];
	[databaseControls.albumListCacheDb executeUpdate:@"DELETE FROM albumsCache WHERE folderId = ?", [NSString md5:anAlbum.albumId]];
	[databaseControls.albumListCacheDb executeUpdate:@"DELETE FROM songsCache WHERE folderId = ?", [NSString md5:anAlbum.albumId]];
	[databaseControls.albumListCacheDb commit];*/
	
	NSString *urlString = [NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"getMusicDirectory.view"], currentAlbum.albumId];
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kLoadingTimeout];
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
		loadingData = [[NSMutableData data] retain];
	} 
	else 
	{
		//NSLog(@"%@", [NSString stringWithFormat:@"There was an error grabbing the song list for album: %@", currentAlbum.title]);
	}
}

- (void)loadSort
{
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	[viewObjects.allSongsLoadingScreen performSelectorOnMainThread:@selector(setAllMessagesText:) withObject:[NSArray arrayWithObjects:@"Sorting Table", @"", @"", @"", nil] waitUntilDone:NO];
	//[self performSelectorOnMainThread:@selector(updateMessage) withObject:nil waitUntilDone:NO];
	
	// Sort the tables
	[databaseControls.allSongsDb executeUpdate:@"DROP TABLE allSongs"];
	[databaseControls.allSongsDb executeUpdate:@"CREATE VIRTUAL TABLE allSongs USING FTS3 (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER, tokenize=porter)"];
	[databaseControls.allSongsDb executeUpdate:@"INSERT INTO allSongs SELECT * FROM allSongsTemp ORDER BY title COLLATE NOCASE"];

	[databaseControls.genresDb executeUpdate:@"DROP TABLE genres"];
	[databaseControls.genresDb executeUpdate:@"CREATE TABLE genres (genre TEXT UNIQUE)"];
	[databaseControls.genresDb executeUpdate:@"INSERT INTO genres SELECT * FROM genresTemp ORDER BY genre COLLATE NOCASE"];
	
	[databaseControls.allSongsDb executeUpdate:@"UPDATE resumeLoad SET albumNum = ?, iteration = ?", [NSNumber numberWithInt:0], [NSNumber numberWithInt:5]];
	
	NSLog(@"calling loadFinish");
	[self loadFinish];
	
	[autoreleasePool release];
}

- (void)loadFinish
{
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	NSLog(@"loadFinish called");
	// Check if loading should stop
	if (viewObjects.cancelLoading)
	{
		viewObjects.cancelLoading = NO;
		viewObjects.isSongsLoading = NO;
		[self performSelectorInBackground:@selector(hideLoadingScreen) withObject:nil];
		return;
	}
	[databaseControls.allSongsDb executeUpdate:@"DROP TABLE allSongsTemp"];
	//[databaseControls.allSongsDb executeUpdate:@"VACUUM"];
	NSLog(@"1");
	
	// Check if loading should stop
	if (viewObjects.cancelLoading)
	{
		viewObjects.cancelLoading = NO;
		viewObjects.isSongsLoading = NO;
		[self performSelectorInBackground:@selector(hideLoadingScreen) withObject:nil];
		return;
	}
	[databaseControls.genresDb executeUpdate:@"DROP TABLE genresTemp"];
	//[databaseControls.genresDb executeUpdate:@"VACUUM"];
	NSLog(@"2");
	
	// Check if loading should stop
	if (viewObjects.cancelLoading)
	{
		viewObjects.cancelLoading = NO;
		viewObjects.isSongsLoading = NO;
		[self performSelectorInBackground:@selector(hideLoadingScreen) withObject:nil];
		return;
	}
	// Create the section info array
	self.sectionInfo = [databaseControls sectionInfoFromTable:@"allSongs" inDatabase:databaseControls.allSongsDb withColumn:@"title"];
	[databaseControls.allSongsDb executeUpdate:@"DROP TABLE sectionInfo"];
	[databaseControls.allSongsDb executeUpdate:@"CREATE TABLE sectionInfo (title TEXT, row INTEGER)"];
	for (NSArray *section in sectionInfo)
	{
		[databaseControls.allSongsDb executeUpdate:@"INSERT INTO sectionInfo (title, row) VALUES (?, ?)", [section objectAtIndex:0], [section objectAtIndex:1]];
	}
	NSLog(@"3");
	
	// Check if loading should stop
	if (viewObjects.cancelLoading)
	{
		viewObjects.cancelLoading = NO;
		viewObjects.isSongsLoading = NO;
		[self performSelectorInBackground:@selector(hideLoadingScreen) withObject:nil];
		return;
	}
	// Count the table
	numberOfRows = [databaseControls.allSongsDb intForQuery:@"SELECT COUNT (*) FROM allSongs"];
	
	NSLog(@"4");
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:[NSDate date] forKey:[NSString stringWithFormat:@"%@songsReloadTime", appDelegate.defaultUrl]];
	[defaults synchronize];
	
	[databaseControls.allSongsDb executeUpdate:@"UPDATE resumeLoad SET albumNum = ?, iteration = ?", [NSNumber numberWithInt:0], [NSNumber numberWithInt:6]];
	
	[self performSelectorOnMainThread:@selector(loadData2) withObject:nil waitUntilDone:NO];
	
	[autoreleasePool release];
}

- (void)loadData
{
	viewObjects.isSongsLoading = YES;
	[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:[NSString stringWithFormat:@"%@isAllSongsLoading", appDelegate.defaultUrl]];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	// Check to see if we need to create the tables
	if ([databaseControls.allSongsDb tableExists:@"resumeLoad"] == NO)
	{
		[self createLoadTables];
	}
	
	iteration = [databaseControls.allSongsDb intForQuery:@"SELECT iteration FROM resumeLoad"];
	
	if (iteration == 0)
	{
		currentRow = [databaseControls.allSongsDb intForQuery:@"SELECT albumNum FROM resumeLoad"];
		albumCount = [databaseControls.allAlbumsDb intForQuery:@"SELECT COUNT(*) FROM allAlbums"];
				
		[self loadAlbumFolder];
	}
	else if (iteration < 4)
	{
		currentRow = [databaseControls.allSongsDb intForQuery:@"SELECT albumNum FROM resumeLoad"];
		albumCount = [databaseControls.allAlbumsDb intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM subalbums%i", iteration]];
		
		[self loadAlbumFolder];
	}
	else if (iteration == 4)
	{
		[self performSelectorInBackground:@selector(loadSort) withObject:nil];
	}
	else if (iteration == 5)
	{
		[self performSelectorInBackground:@selector(loadFinish) withObject:nil];
	}
}	


- (void) updateMessage
{
	//[viewObjects.allSongsLoadingScreen setAllMessagesText:[NSArray arrayWithObjects:@"Sorting Table", @"", @"", @"", nil]];
	[viewObjects.allSongsLoadingScreen setMessage1Text:currentAlbum.title];
	[viewObjects.allSongsLoadingScreen setMessage2Text:[NSString stringWithFormat:@"%i", viewObjects.allSongsLoadingProgress]];
}


- (void) hideLoadingScreen
{
	// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	//NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	self.tableView.scrollEnabled = YES;
	[(CustomUITableView*)self.tableView setBlockInput:NO];
	
	// Hide the loading screen
	[viewObjects.allSongsLoadingScreen hide];
	viewObjects.allSongsLoadingScreen = nil;
	
	//[autoreleasePool release];
}


- (void) loadData2
{
	NSLog(@"loadData2 called");
	// Check if loading should stop
	if (viewObjects.cancelLoading)
	{
		viewObjects.cancelLoading = NO;
		viewObjects.isSongsLoading = NO;
		//[self performSelectorInBackground:@selector(hideLoadingScreen) withObject:nil];
		[self hideLoadingScreen];
		return;
	}
	viewObjects.isSongsLoading = NO;
	[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:[NSString stringWithFormat:@"%@isAllSongsLoading", appDelegate.defaultUrl]];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	NSLog(@"1");
	
	[self addCount];
	
	self.tableView.backgroundColor = [UIColor clearColor];
	
	// Hide the loading screen
	[self hideLoadingScreen];
	
	//self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];
	if(musicControls.streamer || musicControls.showNowPlayingIcon)
	{
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	// Check if loading should stop
	if (viewObjects.cancelLoading)
	{
		viewObjects.cancelLoading = NO;
		viewObjects.isSongsLoading = NO;
		return;
	}
	[databaseControls.allSongsDb executeUpdate:@"DROP TABLE resumeLoad"];
}


- (NSArray *)createSectionInfo
{
	NSMutableArray *sections = [[NSMutableArray alloc] init];
	FMResultSet *result = [databaseControls.allSongsDb executeQuery:@"SELECT * FROM sectionInfo"];
	
	while ([result next])
	{
		[sections addObject:[NSArray arrayWithObjects:[result stringForColumnIndex:0], [NSNumber numberWithInt:[result intForColumnIndex:1]], nil]];
	}
	
	NSArray *returnArray = [NSArray arrayWithArray:sections];
	[sections release];
	
	return returnArray;
}


#pragma mark Connection Delegate

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[loadingData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [loadingData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	// Load the same folder
	//
	[self loadAlbumFolder];
	
	[theConnection release];
	[loadingData release];	
}	

static NSString *kName_Directory = @"directory";
static NSString *kName_Child = @"child";
static NSString *kName_Error = @"error";

- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	/*CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:appDelegate cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	 [alert show];
	 [alert release];*/
	NSLog(@"Subsonic error %@:  %@", errorCode, message);
}

- (BOOL) insertSong:(Song *)aSong intoGenreTable:(NSString *)table
{
	[databaseControls.genresDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (md5, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", table], [NSString md5:aSong.path], aSong.title, aSong.songId, aSong.artist, aSong.album, aSong.genre, aSong.coverArtId, aSong.path, aSong.suffix, aSong.transcodedSuffix, aSong.duration, aSong.bitRate, aSong.track, aSong.year, aSong.size];
	
	if ([databaseControls.genresDb hadError]) {
		NSLog(@"Err inserting song into genre table %d: %@", [databaseControls.genresDb lastErrorCode], [databaseControls.genresDb lastErrorMessage]);
	}
	
	return [databaseControls.genresDb hadError];
}

- (void)parseData:(NSURLConnection*)theConnection
{
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	// Parse the data
	//
	TBXML *tbxml = [[TBXML alloc] initWithXMLData:loadingData];
    TBXMLElement *root = tbxml.rootXMLElement;
    if (root) 
	{
		TBXMLElement *error = [TBXML childElementNamed:kName_Error parentElement:root];
		if (error)
		{
			NSString *code = [TBXML valueOfAttributeNamed:@"code" forElement:error];
			NSString *message = [TBXML valueOfAttributeNamed:@"message" forElement:error];
			[self subsonicErrorCode:code message:message];
		}
		
        TBXMLElement *directory = [TBXML childElementNamed:kName_Directory parentElement:root];
        if (directory) 
		{
			// Set the artist name and id
			viewObjects.allSongsCurrentAlbumName = [TBXML valueOfAttributeNamed:@"name" forElement:directory];
			viewObjects.allSongsCurrentAlbumId = [TBXML valueOfAttributeNamed:@"id" forElement:directory];
			
			//Initialize the arrays and lookup dictionaries for automatic directory caching
			viewObjects.allSongsListOfAlbums = [NSMutableArray arrayWithCapacity:1];
			viewObjects.allSongsListOfSongs = [NSMutableArray arrayWithCapacity:1];
			
			/*[databaseControls.albumListCacheDb beginTransaction];
			[databaseControls.albumListCacheDb executeUpdate:@"DELETE FROM albumsCache WHERE folderId = ?", [NSString md5:viewObjects.allSongsCurrentAlbumId]];
			[databaseControls.albumListCacheDb executeUpdate:@"DELETE FROM songsCache WHERE folderId = ?", [NSString md5:viewObjects.allSongsCurrentAlbumId]];
			[databaseControls.albumListCacheDb commit];*/
		
            TBXMLElement *child = [TBXML childElementNamed:kName_Child parentElement:directory];
            while (child != nil) 
			{
				if ([[TBXML valueOfAttributeNamed:@"isDir" forElement:child] isEqualToString:@"true"])
				{
					//Initialize the Album.
					Album *anAlbum = [[Album alloc] init];
					
					//Extract the attributes here.
					anAlbum.title = [TBXML valueOfAttributeNamed:@"title" forElement:child];
					anAlbum.albumId = [TBXML valueOfAttributeNamed:@"id" forElement:child];
					if([TBXML valueOfAttributeNamed:@"coverArt" forElement:child])
						anAlbum.coverArtId = [TBXML valueOfAttributeNamed:@"coverArt" forElement:child];
					anAlbum.artistName = [viewObjects.allSongsCurrentArtistName copy];
					anAlbum.artistId = [viewObjects.allSongsCurrentArtistId copy];
					
					//NSLog(@"Album: %@", anAlbum.title);
					
					//Add album object to the subalbums table to be processed in the next iteration
					if (![anAlbum.title isEqualToString:@".AppleDouble"])
					{
						[databaseControls insertAlbum:anAlbum intoTable:[NSString stringWithFormat:@"subalbums%i", (iteration + 1)] inDatabase:databaseControls.allAlbumsDb];
					}
					
					/*//Add album object to lookup dictionary and list array for caching
					if (![anAlbum.title isEqualToString:@".AppleDouble"])
					{
						//[viewObjects.allSongsListOfAlbums addObject:anAlbum];
						[databaseControls insertAlbumIntoFolderCache:anAlbum forId:viewObjects.allSongsCurrentAlbumId];
					}*/
					
					// Update the loading screen message
					[self performSelectorOnMainThread:@selector(updateMessage) withObject:nil waitUntilDone:NO];
					
					[anAlbum.artistName release];
					[anAlbum.artistId release];
					[anAlbum release];
				}
				else
				{
					//Initialize the Song.
					Song *aSong = [[Song alloc] init];
					
					//Extract the attributes here.
					aSong.title = [TBXML valueOfAttributeNamed:@"title" forElement:child];
					aSong.songId = [TBXML valueOfAttributeNamed:@"id" forElement:child];
					aSong.artist = [TBXML valueOfAttributeNamed:@"artist" forElement:child];
					if([TBXML valueOfAttributeNamed:@"album" forElement:child])
						aSong.album = [TBXML valueOfAttributeNamed:@"album" forElement:child];
					if([TBXML valueOfAttributeNamed:@"genre" forElement:child])
						aSong.genre = [TBXML valueOfAttributeNamed:@"genre" forElement:child];
					if([TBXML valueOfAttributeNamed:@"coverArt" forElement:child])
						aSong.coverArtId = [TBXML valueOfAttributeNamed:@"coverArt" forElement:child];
					aSong.path = [TBXML valueOfAttributeNamed:@"path" forElement:child];
					aSong.suffix = [TBXML valueOfAttributeNamed:@"suffix" forElement:child];
					if ([TBXML valueOfAttributeNamed:@"transcodedSuffix" forElement:child])
						aSong.transcodedSuffix = [TBXML valueOfAttributeNamed:@"transcodedSuffix" forElement:child];
					NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
					if([TBXML valueOfAttributeNamed:@"duration" forElement:child])
						aSong.duration = [numberFormatter numberFromString:[TBXML valueOfAttributeNamed:@"duration" forElement:child]];
					if([TBXML valueOfAttributeNamed:@"bitRate" forElement:child])
						aSong.bitRate = [numberFormatter numberFromString:[TBXML valueOfAttributeNamed:@"bitRate" forElement:child]];
					if([TBXML valueOfAttributeNamed:@"track" forElement:child])
						aSong.track = [numberFormatter numberFromString:[TBXML valueOfAttributeNamed:@"track" forElement:child]];
					if([TBXML valueOfAttributeNamed:@"year" forElement:child])
						aSong.year = [numberFormatter numberFromString:[TBXML valueOfAttributeNamed:@"year" forElement:child]];
					if([TBXML valueOfAttributeNamed:@"size" forElement:child])
						aSong.size = [numberFormatter numberFromString:[TBXML valueOfAttributeNamed:@"size" forElement:child]];
					
					/*//Add song object to lookup dictionary
					if (aSong.path)
					{
						//[viewObjects.allSongsListOfSongs addObject:aSong];
						[databaseControls insertSongIntoFolderCache:aSong forId:viewObjects.allSongsCurrentAlbumId];
					}*/
					
					// Add song object to the allSongs and genre databases
					if (![aSong.title isEqualToString:@".AppleDouble"])
					{
						if (aSong.path)
						{
							[databaseControls insertSong:aSong intoTable:@"allSongsTemp" inDatabase:databaseControls.allSongsDb];
							
							if (aSong.genre)
							{
								/*// Check if the genre has a table in the database yet, if not create it and add the new genre to the genres table
								if ([databaseControls.genresDb intForQuery:@"SELECT COUNT(*) FROM genresTemp WHERE genre = ?", aSong.genre] == 0)
								{							
									[databaseControls.genresDb executeUpdate:@"INSERT INTO genresTemp (genre) VALUES (?)", aSong.genre];
									if ([databaseControls.genresDb hadError]) { NSLog(@"Err adding the genre %d: %@", [databaseControls.genresDb lastErrorCode], [databaseControls.genresDb lastErrorMessage]); }
								}*/
								[databaseControls.genresDb executeUpdate:@"INSERT INTO genresTemp (genre) VALUES (?)", aSong.genre];
								
								// Insert the song object into the appropriate genre table
								[self insertSong:aSong intoGenreTable:@"genresSongs"];
								
								// Insert the song into the genresLayout table
								NSArray *splitPath = [aSong.path componentsSeparatedByString:@"/"];
								if ([splitPath count] <= 9)
								{
									NSMutableArray *segments = [[NSMutableArray alloc] initWithArray:splitPath];
									while ([segments count] < 9)
									{
										[segments addObject:@""];
									}
									
									NSString *query = @"INSERT INTO genresLayout (md5, genre, segs, seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8, seg9) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
									[databaseControls.genresDb executeUpdate:query, [NSString md5:aSong.path], aSong.genre, [NSNumber numberWithInt:[splitPath count]], [segments objectAtIndex:0], [segments objectAtIndex:1], [segments objectAtIndex:2], [segments objectAtIndex:3], [segments objectAtIndex:4], [segments objectAtIndex:5], [segments objectAtIndex:6], [segments objectAtIndex:7], [segments objectAtIndex:8]];
									
									[segments release];
								}
							}
						}
					}
					
					// Update the loading screen message
					viewObjects.allSongsLoadingProgress++;
					[self performSelectorOnMainThread:@selector(updateMessage) withObject:nil waitUntilDone:NO];
					
					[aSong release];
					[numberFormatter release];
				}
				
				child = [TBXML nextSiblingNamed:kName_Child searchFromElement:child];
            }
        }
    }
    [tbxml release];
	
	// Close the connection
	//
	[theConnection release];
	[loadingData release];
	
	// Handle the iteration
	//
	currentRow++;
	//NSLog(@"currentRow: %i", currentRow);
	if (currentRow == albumCount)
	{
		// This iteration is done
		currentRow = 0;
		iteration++;
		[databaseControls.allSongsDb executeUpdate:@"UPDATE resumeLoad SET albumNum = ?, iteration = ?", [NSNumber numberWithInt:0], [NSNumber numberWithInt:iteration]];
	}
	else
	{
		[databaseControls.allSongsDb executeUpdate:@"UPDATE resumeLoad SET albumNum = ?", [NSNumber numberWithInt:currentRow]];
	}
	
	// Load the next folder
	//
	if (iteration < 4)
		[self performSelectorOnMainThread:@selector(loadAlbumFolder) withObject:nil waitUntilDone:NO];
	else if (iteration == 4)
		[self loadSort];
	
	[autoreleasePool release];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	[self performSelectorInBackground:@selector(parseData:) withObject:theConnection];
}

#pragma mark -
#pragma mark Button handling methods


- (void) doneSearching_Clicked:(id)sender 
{
	self.tableView.tableHeaderView = nil;
	[self addCount];
	
	searchBar.text = @"";
	[searchBar resignFirstResponder];
	
	didBeginSearching = NO;
	letUserSelectRow = YES;
	viewObjects.isSearchingAllSongs = NO;
	self.navigationItem.leftBarButtonItem = nil;
	//self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];
	self.tableView.scrollEnabled = YES;
	
	[searchOverlayView.view removeFromSuperview];
	[searchOverlayView release];
	searchOverlayView = nil;
	
	[self.tableView reloadData];
	
	[self.tableView setContentOffset:CGPointMake(0, 0) animated:YES];
}


- (void) reloadAction:(id)sender
{
	//if (!appDelegate.isArtistsLoading && !appDelegate.isAlbumsLoading && [[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@isAllAlbumsLoading", appDelegate.defaultUrl]] isEqualToString:@"NO"])
	if (!viewObjects.isArtistsLoading && !viewObjects.isAlbumsLoading)
	{
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Reload?" message:@"This could take a while if you have a big collection.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.\n\nNote: If you've added new artists or albums, you should reload the Folders and Albums tabs first." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
		[alert show];
		[alert release];
	}
	else
	{
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Please Wait" message:@"You cannot reload the Songs tab while the Folders or Albums tabs are loading" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
		[alert release];
	}
}


- (void)alertView:(CustomUIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1)
	{
		[databaseControls.allSongsDb executeUpdate:@"DROP TABLE resumeLoad"];
		viewObjects.allSongsLoadingProgress = 0;
		viewObjects.allSongsLoadingScreen = [[LoadingScreen alloc] initOnView:self.view withMessage:[NSArray arrayWithObjects:@"Processing Album:", @"", @"Total Songs:", @"", nil] blockInput:YES mainWindow:NO];
		self.tableView.scrollEnabled = NO;
		[(CustomUITableView*)self.tableView setBlockInput:YES];
		self.navigationItem.leftBarButtonItem = nil;
		self.navigationItem.rightBarButtonItem = nil;
		//[self performSelectorInBackground:@selector(loadData) withObject:nil];
		[self loadData];
	}
	else if (buttonIndex == 2)
	{
		viewObjects.allSongsLoadingProgress = [databaseControls.allSongsDb intForQuery:@"SELECT COUNT(*) FROM allSongsTemp"];
		viewObjects.allSongsLoadingScreen = [[LoadingScreen alloc] initOnView:self.view withMessage:[NSArray arrayWithObjects:@"Processing Album:", @"", @"Total Songs:", @"", nil] blockInput:YES mainWindow:NO];
		self.tableView.scrollEnabled = NO;
		[(CustomUITableView*)self.tableView setBlockInput:YES];
		self.navigationItem.leftBarButtonItem = nil;
		self.navigationItem.rightBarButtonItem = nil;
		//[self performSelectorInBackground:@selector(loadData) withObject:nil];
		[self loadData];
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
#pragma mark Tableview methods


// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView 
{
	if(viewObjects.isSearchingAllSongs || didBeginSearching)
		return nil;
	else
	{
		NSMutableArray *searchIndexes = [[[NSMutableArray alloc] init] autorelease];
		[searchIndexes addObject:@"{search}"];
		for (int i = 0; i < [sectionInfo count]; i++)
		{
			[searchIndexes addObject:[[sectionInfo objectAtIndex:i] objectAtIndex:0]];
		}
		return searchIndexes;
	}
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index 
{
	if(viewObjects.isSearchingAllSongs || didBeginSearching)
		return -1;
	
	if (index == 0)
	{
		[tableView scrollRectToVisible:CGRectMake(0, 50, 320, 40) animated:NO];
	}
	else
	{
		[tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:[[[sectionInfo objectAtIndex:(index - 1)] objectAtIndex:1] intValue] inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
	}
	
	return -1;
}


- (void) searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar 
{	
	[self.tableView.tableHeaderView retain];
	
	[self.tableView setContentOffset:CGPointMake(0, 50) animated:YES];
	
	if ([theSearchBar.text length] == 0)
	{
		//Add the overlay view.
		if(searchOverlayView == nil)
			searchOverlayView = [[SearchOverlayViewController alloc] initWithNibName:@"SearchOverlayViewController" bundle:[NSBundle mainBundle]];
		//CGFloat y = self.tableView.contentOffset.y - searchBar.frame.origin.y + searchBar.frame.size.height;
		CGFloat width = self.view.frame.size.width;
		CGFloat height = self.view.frame.size.height;
		CGRect frame = CGRectMake(0, 40, width, height);
		searchOverlayView.view.frame = frame;
		[self.view.superview addSubview:searchOverlayView.view];
		
		letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
	}
	
	// Remove the index bar
	didBeginSearching = YES;
	[self.tableView reloadData];
	
	//Add the done button.
	self.navigationItem.leftBarButtonItem = nil;
	self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneSearching_Clicked:)] autorelease];
}


- (NSIndexPath *)tableView :(UITableView *)theTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if(letUserSelectRow)
		return indexPath;
	else
		return nil;
}


- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText
{
	if([searchText length] > 0) 
	{
		[searchOverlayView.view removeFromSuperview];
		viewObjects.isSearchingAllSongs = YES;
		letUserSelectRow = YES;
		self.tableView.scrollEnabled = YES;
		[self searchTableView];
	}
	else 
	{
		[self.tableView setContentOffset:CGPointMake(0, 50) animated:YES];
		
		//Add the overlay view.
		if(searchOverlayView == nil)
			searchOverlayView = [[SearchOverlayViewController alloc] initWithNibName:@"SearchOverlayViewController" bundle:[NSBundle mainBundle]];
		CGFloat width = self.view.frame.size.width;
		CGFloat height = self.view.frame.size.height;
		CGRect frame = CGRectMake(0, 40, width, height);
		searchOverlayView.view.frame = frame;
		[self.view.superview addSubview:searchOverlayView.view];
		
		viewObjects.isSearchingAllSongs = NO;
		letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
		[databaseControls.allSongsDb executeUpdate:@"DROP TABLE allSongsSearch"];
	}
	
	[self.tableView reloadData];
}


- (void) searchBarSearchButtonClicked:(UISearchBar *)theSearchBar 
{	
	[self searchTableView];
	[searchBar resignFirstResponder];
}

- (void) searchTableView 
{	
	// Inialize the search DB
	[databaseControls.allSongsDb executeUpdate:@"DROP TABLE allSongsSearch"];
	[databaseControls.allSongsDb executeUpdate:@"CREATE TABLE allSongsSearch(title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];	
	
	// Perform the search
	[databaseControls.allSongsDb executeUpdate:@"INSERT INTO allSongsSearch SELECT * FROM allSongs WHERE title MATCH ? LIMIT 100", searchBar.text];
	if ([databaseControls.allSongsDb hadError]) {
		NSLog(@"Err %d: %@", [databaseControls.allSongsDb lastErrorCode], [databaseControls.allSongsDb lastErrorMessage]);
	}
	
	//NSLog(@"allSongsSearch count: %i", [databaseControls.allSongsDb intForQuery:@"SELECT count(*) FROM allSongsSearch"]);
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if(viewObjects.isSearchingAllSongs)
	{
		return [databaseControls.allSongsDb intForQuery:@"SELECT COUNT(*) FROM allSongsSearch"];
	}
	else 
	{
		return numberOfRows;
	}
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *CellIdentifier = @"Cell";
	AllSongsUITableViewCell *cell = [[[AllSongsUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
	cell.indexPath = indexPath;
	
	Song *aSong;
	if(viewObjects.isSearchingAllSongs)
		aSong = [databaseControls songFromDbRow:indexPath.row inTable:@"allSongsSearch" inDatabase:databaseControls.allSongsDb];
	else
		aSong = [databaseControls songFromDbRow:indexPath.row inTable:@"allSongs" inDatabase:databaseControls.allSongsDb];
	
	cell.md5 = [NSString md5:aSong.path];
	
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
	{
		if ([databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ? and finished = 'YES'", cell.md5] != nil)
			cell.backgroundView.backgroundColor = [viewObjects currentLightColor];
		else
			cell.backgroundView.backgroundColor = viewObjects.lightNormal;
	}
	else
	{
		if ([databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ? and finished = 'YES'", cell.md5] != nil)
			cell.backgroundView.backgroundColor = [viewObjects currentDarkColor];
		else
			cell.backgroundView.backgroundColor = viewObjects.darkNormal;
	}
	
	[cell.songNameLabel setText:aSong.title];
	if (aSong.album)
		[cell.artistNameLabel setText:[NSString stringWithFormat:@"%@ - %@", aSong.artist, aSong.album]];
	else
		[cell.artistNameLabel setText:aSong.artist];
	
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (viewObjects.isCellEnabled)
	{
		// Kill the streamer if it's playing
		[musicControls destroyStreamer];
		
		// Set the new playlist position
		musicControls.currentPlaylistPosition = 0;
		
		// Clear the current playlist
		if (viewObjects.isJukebox)
			[databaseControls resetJukeboxPlaylist];
		else
			[databaseControls resetCurrentPlaylistDb];
		
		// Add selected song to the playlist
		Song *aSong;
		if(viewObjects.isSearchingAllSongs)
		{
			aSong = [databaseControls songFromDbRow:indexPath.row inTable:@"allSongsSearch" inDatabase:databaseControls.allSongsDb];
		}
		else
		{
			aSong = [databaseControls songFromDbRow:indexPath.row inTable:@"allSongs" inDatabase:databaseControls.allSongsDb];
		}
		[databaseControls addSongToPlaylistQueue:aSong];
		
		// If jukebox mode, send song id to server
		if (viewObjects.isJukebox)
		{
			[musicControls jukeboxStop];
			[musicControls jukeboxClearPlaylist];
			[musicControls jukeboxAddSong:aSong.songId];
		}
		
		// Set the current and next song objects
		// Set the current and next song objects
		musicControls.currentSongObject == nil;
		musicControls.nextSongObject = nil; 
		if (viewObjects.isJukebox)
		{
			musicControls.currentSongObject = [databaseControls songFromDbRow:indexPath.row inTable:@"jukeboxCurrentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
		}
		else
		{
			musicControls.currentSongObject = [databaseControls songFromDbRow:indexPath.row inTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
		}
		
		// Set player defaults
		musicControls.isNewSong = YES;
		musicControls.isShuffle = NO;
		
		// Start the song
		musicControls.seekTime = 0.0;
		[musicControls playSongAtPosition:0];
		
		// Show the player
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
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}


@end

