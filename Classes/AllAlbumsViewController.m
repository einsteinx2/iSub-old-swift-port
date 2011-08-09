//
//  AllAlbumsViewController.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "AllAlbumsViewController.h"
#import "SearchOverlayViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicControlsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "XMLParser.h"
#import "AlbumViewController.h"
#import "AllAlbumsUITableViewCell.h"
#import "AsynchronousImageViewCached.h"
#import "Artist.h"
#import "Album.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString-md5.h"
#import "LoadingScreen.h"
#import "ASIHTTPRequest.h" 
#import "RootViewController.h"

#import "SA_OAuthTwitterEngine.h"

#import "CustomUITableView.h"
#import "CustomUIAlertView.h"

@implementation AllAlbumsViewController

@synthesize headerView, sectionInfo;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if ([[[iSubAppDelegate sharedInstance].settingsDictionary objectForKey:@"lockRotationSetting"] isEqualToString:@"YES"] 
		&& inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)viewDidLoad 
{
	//DLog(@"allAlbums viewDidLoad");
    [super viewDidLoad];
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicControlsSingleton sharedInstance];
	databaseControls = [DatabaseControlsSingleton sharedInstance];
	
	self.title = @"Albums";
	//self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];
	
	//Set defaults
	viewObjects.isSearchingAllAlbums = NO;
	letUserSelectRow = YES;	
	didBeginSearching = NO;
	
	numberOfRows = 0;
	//[self.headerView removeFromSuperview];
	self.sectionInfo = nil;
	if ([databaseControls.allAlbumsDb tableExists:@"allAlbums"] == YES && ![[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@isAllAlbumsLoading", appDelegate.defaultUrl]] isEqualToString:@"YES"])
	{
		//DLog(@"1");
		numberOfRows = [databaseControls.allAlbumsDb intForQuery:@"SELECT COUNT(*) FROM allAlbums"];
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


-(void)addCount
{
	//Build the search and reload view
	headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 90)] autorelease];
	headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
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
	searchBar.placeholder = @"Album name";
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
	
	countLabel.text = [NSString stringWithFormat:@"%i Albums", [databaseControls.allAlbumsDb intForQuery:@"SELECT COUNT(*) FROM allAlbums"]];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateStyle:NSDateFormatterMediumStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	reloadTimeLabel.text = [NSString stringWithFormat:@"last reload: %@", [formatter stringFromDate:[defaults objectForKey:[NSString stringWithFormat:@"%@albumsReloadTime", appDelegate.defaultUrl]]]];
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


-(void)loadData
{
	// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	viewObjects.isAlbumsLoading = YES;
	[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:[NSString stringWithFormat:@"%@isAllAlbumsLoading", appDelegate.defaultUrl]];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	// Check to see if we need to create the tables
	if ([databaseControls.allAlbumsDb tableExists:@"resumeLoad"] == NO)
	{
		// Inialize the DB
		[databaseControls.allAlbumsDb executeUpdate:@"CREATE TABLE resumeLoad (sectionNum INTEGER, artistNum INTEGER, iteration INTEGER)"];
		[databaseControls.allAlbumsDb executeUpdate:@"INSERT INTO resumeLoad (sectionNum, artistNum, iteration) VALUES (0, 0, 0)"];
		[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE allAlbums"];
		[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE allAlbumsTemp"];
		[databaseControls.allAlbumsDb executeUpdate:@"CREATE VIRTUAL TABLE allAlbums USING FTS3(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT, tokenize=porter)"];
		[databaseControls.allAlbumsDb executeUpdate:@"CREATE TABLE allAlbumsTemp(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
		[databaseControls.allAlbumsDb executeUpdate:@"CREATE INDEX title ON allAlbumsTemp (title ASC)"];
	}
	
	if ([databaseControls.allAlbumsDb intForQuery:@"SELECT iteration FROM resumeLoad"] == 0)
	{
		int sectionNum = [databaseControls.allAlbumsDb intForQuery:@"SELECT sectionNum FROM resumeLoad"];
		int sectionCount = [viewObjects.listOfArtists count];
		for (int i = sectionNum; i < sectionCount; i++)
		{
			// Check if loading should stop
			if (viewObjects.cancelLoading)
			{
				viewObjects.cancelLoading = NO;
				viewObjects.isAlbumsLoading = NO;
				[self performSelectorInBackground:@selector(hideLoadingScreen) withObject:nil];
				return;
			}
			
			NSAutoreleasePool *autoreleasePool2 = [[NSAutoreleasePool alloc] init];
			
			NSArray *artistArray = [viewObjects.listOfArtists objectAtIndex:i];
			//DLog(@"artistArray: %@", artistArray);
			int artistNum = [databaseControls.allAlbumsDb intForQuery:@"SELECT artistNum FROM resumeLoad"];
			int artistCount = [artistArray count];
			for (int j = artistNum; j < artistCount; j++)
			{
				// Check if loading should stop
				if (viewObjects.cancelLoading)
				{
					viewObjects.cancelLoading = NO;
					viewObjects.isAlbumsLoading = NO;
					[self performSelectorInBackground:@selector(hideLoadingScreen) withObject:nil];
					return;
				}
				
				// Start the transaction
				//[appDelegate.allAlbumsDb executeUpdate:@"BEGIN EXCLUSIVE TRANSACTION"];
				
				Artist *anArtist = [artistArray objectAtIndex:j];
				viewObjects.currentLoadingFolderId = anArtist.artistId;
				ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"getMusicDirectory.view"], anArtist.artistId]]];
				[request startSynchronous];
				if ([request error])
				{
					CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error grabbing the album list." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
					[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
					[alert release];
				}
				else
				{
					NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:[request responseData]];
					XMLParser *parser = [[XMLParser alloc] initXMLParser];
					parser.parseState = @"allAlbums";
					[xmlParser setDelegate:parser];
					[xmlParser parse];
					
					[xmlParser release];
					[parser release];
				}
				
				// End the transaction
				//[appDelegate.allAlbumsDb executeUpdate:@"COMMIT TRANSACTION"];
				
				[databaseControls.allAlbumsDb executeUpdate:@"UPDATE resumeLoad SET artistNum = ?", [NSNumber numberWithInt:(j + 1)]];
			}
			
			[databaseControls.allAlbumsDb executeUpdate:@"UPDATE resumeLoad SET sectionNum = ?, artistNum = ?", [NSNumber numberWithInt:(i + 1)], [NSNumber numberWithInt:0]];
			
			[autoreleasePool2 release];
		}
		
		[databaseControls.allAlbumsDb executeUpdate:@"UPDATE resumeLoad SET iteration = ?", [NSNumber numberWithInt:1]];
	}
	
	[self performSelectorOnMainThread:@selector(updateMessage) withObject:nil waitUntilDone:NO];
	
	if ([databaseControls.allAlbumsDb intForQuery:@"SELECT iteration FROM resumeLoad"] == 1)
	{
		// Sort the table
		[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE allAlbums"];
		[databaseControls.allAlbumsDb executeUpdate:@"CREATE VIRTUAL TABLE allAlbums USING FTS3(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT, tokenize=porter)"];
		[databaseControls.allAlbumsDb executeUpdate:@"INSERT INTO allAlbums SELECT * FROM allAlbumsTemp ORDER BY title COLLATE NOCASE"];
		
		// Check if loading should stop
		if (viewObjects.cancelLoading)
		{
			viewObjects.cancelLoading = NO;
			viewObjects.isAlbumsLoading = NO;
			[self performSelectorInBackground:@selector(hideLoadingScreen) withObject:nil];
			return;
		}
		[databaseControls.allAlbumsDb executeUpdate:@"UPDATE resumeLoad SET iteration = ?", [NSNumber numberWithInt:2]];
	}
	
	if ([databaseControls.allAlbumsDb intForQuery:@"SELECT iteration FROM resumeLoad"] == 2)
	{
		// Check if loading should stop
		if (viewObjects.cancelLoading)
		{
			viewObjects.cancelLoading = NO;
			viewObjects.isAlbumsLoading = NO;
			[self performSelectorInBackground:@selector(hideLoadingScreen) withObject:nil];
			return;
		}
		[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE allAlbumsTemp"];
		[databaseControls.allAlbumsDb executeUpdate:@"VACUUM"];
		
		// Check if loading should stop
		if (viewObjects.cancelLoading)
		{
			viewObjects.cancelLoading = NO;
			viewObjects.isAlbumsLoading = NO;
			[self performSelectorInBackground:@selector(hideLoadingScreen) withObject:nil];
			return;
		}
		// Create the section info array
		self.sectionInfo = [databaseControls sectionInfoFromTable:@"allAlbums" inDatabase:databaseControls.allAlbumsDb withColumn:@"title"];
		[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE sectionInfo"];
		[databaseControls.allAlbumsDb executeUpdate:@"CREATE TABLE sectionInfo (title TEXT, row INTEGER)"];
		for (NSArray *section in sectionInfo)
		{
			[databaseControls.allAlbumsDb executeUpdate:@"INSERT INTO sectionInfo (title, row) VALUES (?, ?)", [section objectAtIndex:0], [section objectAtIndex:1]];
		}
		
		// Count the table
		numberOfRows = [databaseControls.allAlbumsDb intForQuery:@"SELECT COUNT(*) FROM allAlbums"];
		
		// Save the reload time to user defaults
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setObject:[NSDate date] forKey:[NSString stringWithFormat:@"%@albumsReloadTime", appDelegate.defaultUrl]];
		[defaults synchronize];
		
		// Check if loading should stop
		if (viewObjects.cancelLoading)
		{
			viewObjects.cancelLoading = NO;
			viewObjects.isAlbumsLoading = NO;
			[self performSelectorInBackground:@selector(hideLoadingScreen) withObject:nil];
			return;
		}
		[databaseControls.allAlbumsDb executeUpdate:@"UPDATE resumeLoad SET iteration = ?", [NSNumber numberWithInt:3]];
	}
	
	// Must do the UI stuff in the main thread
	[self performSelectorOnMainThread:@selector(loadData2) withObject:nil waitUntilDone:NO];
	
	[autoreleasePool release];
}	


- (void) updateMessage
{
	[viewObjects.allAlbumsLoadingScreen setAllMessagesText:[NSArray arrayWithObjects:@"Sorting Table", @"", @"", @"", nil]];
}


- (void) hideLoadingScreen
{
	// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	self.tableView.scrollEnabled = YES;
	[(CustomUITableView*)self.tableView setBlockInput:NO];
	[viewObjects.allAlbumsLoadingScreen hide];
	viewObjects.allAlbumsLoadingScreen = nil;
	
	[autoreleasePool release];
}


- (void) loadData2
{
	// Check if loading should stop
	if (viewObjects.cancelLoading)
	{
		viewObjects.cancelLoading = NO;
		viewObjects.isAlbumsLoading = NO;
		[self hideLoadingScreen];
		return;
	}
	viewObjects.isAlbumsLoading = NO;
	[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:[NSString stringWithFormat:@"%@isAllAlbumsLoading", appDelegate.defaultUrl]];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
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
		viewObjects.isAlbumsLoading = NO;
		return;
	}
	[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE resumeLoad"];
}


- (NSArray *)createSectionInfo
{
	NSMutableArray *sections = [[NSMutableArray alloc] init];
	FMResultSet *result = [databaseControls.allAlbumsDb executeQuery:@"SELECT * FROM sectionInfo"];
	
	while ([result next])
	{
		[sections addObject:[NSArray arrayWithObjects:[NSString stringWithString:[result stringForColumnIndex:0]], 
													  [NSNumber numberWithInt:[result intForColumnIndex:1]], nil]];
	}
	
	NSArray *returnArray = [NSArray arrayWithArray:sections];
	[sections release];
	
	return returnArray;
}


-(void)viewWillAppear:(BOOL)animated 
{
	[super viewWillAppear:animated];
	
	// Don't run this while the table is updating
	if (!viewObjects.isAlbumsLoading)
	{
		if(musicControls.showPlayerIcon)
		{
			self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
		}
		else
		{
			self.navigationItem.rightBarButtonItem = nil;
		}
		
		// If the database hasn't been created or the device was shutoff during the process then create it, otherwise show the header
		if ([databaseControls.allAlbumsDb tableExists:@"allAlbums"] == NO || [[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@isAllAlbumsLoading", appDelegate.defaultUrl]] isEqualToString:@"YES"])
		{
			if(viewObjects.listOfArtists == nil)
			{
				CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"You must load the Folders tab first" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
				[alert show];
				[alert release];
			}
			else if (viewObjects.isSongsLoading)
			{
				CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Please Wait" message:@"You cannot reload the Albums tab while the Songs tab is loading" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
				[alert show];
				[alert release];
			}
			else
			{
				if ([[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@isAllAlbumsLoading", appDelegate.defaultUrl]] isEqualToString:@"YES"])
				{
					UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Resume Load?" message:@"If you've reloaded the Folders tab since this load started you should choose 'Restart Load'.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Restart Load", @"Resume Load", nil];
					[alert show];
					[alert release];
				}
				else
				{
					UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Load?" message:@"This could take a while if you have a big collection.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.\n\nNote: If you've added new artists, you should reload the Folders tab first." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
					[alert show];
					[alert release];
				}
			}
		}
	}
	else
	{
		[viewObjects.allAlbumsLoadingScreen.view removeFromSuperview];
		[self.view addSubview:viewObjects.allAlbumsLoadingScreen.view];
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


- (void)dealloc {
	[searchBar release];
	[searchOverlayView release];
	[url release];
    [super dealloc];
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
	viewObjects.isSearchingAllAlbums = NO;
	self.navigationItem.leftBarButtonItem = nil;
	//self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];
	self.tableView.scrollEnabled = YES;
	
	[searchOverlayView.view removeFromSuperview];
	[searchOverlayView release];
	searchOverlayView = nil;
	
	[self.tableView reloadData];
	
	[self.tableView setContentOffset:CGPointMake(0, 28) animated:YES];
}


- (void) reloadAction:(id)sender
{
	//if (!appDelegate.isArtistsLoading && !appDelegate.isSongsLoading && [[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@isAllSongsLoading", appDelegate.defaultUrl]] isEqualToString:@"NO"])
	if (!viewObjects.isArtistsLoading && !viewObjects.isSongsLoading)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Reload?" message:@"This could take a while if you have a big collection.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.\n\nNote: If you've added new artists, you should reload the Folders tab first." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
		[alert show];
		[alert release];
	}
	else
	{
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Please Wait" message:@"You cannot reload the Albums tab while the Folders or Songs tabs are loading" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
		[alert release];
	}	
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1)
	{
		[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE resumeLoad"];
		viewObjects.allAlbumsLoadingProgress = 0;
		viewObjects.allAlbumsLoadingScreen = [[LoadingScreen alloc] initOnView:self.view withMessage:[NSArray arrayWithObjects:@"Processing Artist:", @"", @"Total Albums:", @"", nil] blockInput:YES mainWindow:NO];
		self.tableView.scrollEnabled = NO;
		//DLog(@"self.tableView: %@", self.tableView);
		[(CustomUITableView*)self.tableView setBlockInput:YES];
		self.navigationItem.leftBarButtonItem = nil;
		self.navigationItem.rightBarButtonItem = nil;
		[self performSelectorInBackground:@selector(loadData) withObject:nil];
	}
	else if (buttonIndex == 2)
	{
		viewObjects.allAlbumsLoadingProgress = [databaseControls.allAlbumsDb intForQuery:@"SELECT COUNT(*) FROM allAlbumsTemp"];
		viewObjects.allAlbumsLoadingScreen = [[LoadingScreen alloc] initOnView:self.view withMessage:[NSArray arrayWithObjects:@"Processing Artist:", @"", @"Total Albums:", @"", nil] blockInput:YES mainWindow:NO];
		self.tableView.scrollEnabled = NO;
		//DLog(@"self.tableView: %@", self.tableView);
		[(CustomUITableView*)self.tableView setBlockInput:YES];
		self.navigationItem.leftBarButtonItem = nil;
		self.navigationItem.rightBarButtonItem = nil;
		[self performSelectorInBackground:@selector(loadData) withObject:nil];
	}
	//DLog(@"loading screen bounds: %@", NSStringFromCGRect(viewObjects.allAlbumsLoadingScreen.view.bounds));
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
	if(viewObjects.isSearchingAllAlbums || didBeginSearching)
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
	if(viewObjects.isSearchingAllAlbums || didBeginSearching)
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


- (NSIndexPath *)tableView :(UITableView *)theTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if(letUserSelectRow)
		return indexPath;
	else
		return nil;
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


- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText
{
	if([searchText length] > 0) 
	{
		[searchOverlayView.view removeFromSuperview];
		viewObjects.isSearchingAllAlbums = YES;
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
		
		viewObjects.isSearchingAllAlbums = NO;
		letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
		[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE allAlbumsSearch"];
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
	[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE allAlbumsSearch"];
	[databaseControls.allAlbumsDb executeUpdate:@"CREATE TABLE allAlbumsSearch(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];	
		
	// Perform the search
	[databaseControls.allAlbumsDb executeUpdate:@"INSERT INTO allAlbumsSearch SELECT * FROM allAlbums WHERE title MATCH ? LIMIT 100", searchBar.text];
	if ([databaseControls.allAlbumsDb hadError]) {
		DLog(@"Err %d: %@", [databaseControls.allAlbumsDb lastErrorCode], [databaseControls.allAlbumsDb lastErrorMessage]);
	}
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if(viewObjects.isSearchingAllAlbums)
	{
		return [databaseControls.allAlbumsDb intForQuery:@"SELECT COUNT(*) FROM allAlbumsSearch"];
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
	AllAlbumsUITableViewCell *cell = [[[AllAlbumsUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
	
	Album *anAlbum;
	if(viewObjects.isSearchingAllAlbums)
		anAlbum = [databaseControls albumFromDbRow:indexPath.row inTable:@"allAlbumsSearch" inDatabase:databaseControls.allAlbumsDb];
	else
		anAlbum = [databaseControls albumFromDbRow:indexPath.row inTable:@"allAlbums" inDatabase:databaseControls.allAlbumsDb];
	
	cell.myId = anAlbum.albumId;
	cell.myArtist = [Artist artistWithName:anAlbum.artistName andArtistId:anAlbum.artistId];
	
	if (anAlbum.coverArtId)
	{
		if ([databaseControls.coverArtCacheDb60 intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [NSString md5:anAlbum.coverArtId]] == 1)
		{
			// If the image is already in the cache dictionary, load it
			cell.coverArtView.image = [UIImage imageWithData:[databaseControls.coverArtCacheDb60 dataForQuery:@"SELECT data FROM coverArtCache WHERE id = ?", [NSString md5:anAlbum.coverArtId]]];
		}
		else 
		{			
			// If not, grab it from the url and cache it
			NSString *imgUrlString;
			if (appDelegate.isHighRez)
			{
				imgUrlString = [NSString stringWithFormat:@"%@%@&size=120", [appDelegate getBaseUrl:@"getCoverArt.view"], anAlbum.coverArtId];
			}
			else
			{
				imgUrlString = [NSString stringWithFormat:@"%@%@&size=60", [appDelegate getBaseUrl:@"getCoverArt.view"], anAlbum.coverArtId];
			}
			[cell.coverArtView loadImageFromURLString:imgUrlString coverArtId:anAlbum.coverArtId];
		}
	}
	else
	{
		cell.coverArtView.image = [UIImage imageNamed:@"default-album-art-small.png"];
	}
	
	cell.backgroundView = [[[UIView alloc] init] autorelease];
	if(indexPath.row % 2 == 0)
		cell.backgroundView.backgroundColor = [UIColor whiteColor];
	else
		cell.backgroundView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];	
	[cell.albumNameLabel setText:anAlbum.title];
	[cell.artistNameLabel setText:anAlbum.artistName];
	
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (viewObjects.isCellEnabled)
	{
		Album *anAlbum;
		if(viewObjects.isSearchingAllAlbums)
			anAlbum = [databaseControls albumFromDbRow:indexPath.row inTable:@"allAlbumsSearch" inDatabase:databaseControls.allAlbumsDb];
		else
			anAlbum = [databaseControls albumFromDbRow:indexPath.row inTable:@"allAlbums" inDatabase:databaseControls.allAlbumsDb];
		
		AlbumViewController* albumViewController = [[AlbumViewController alloc] initWithArtist:nil orAlbum:anAlbum];
		[self.navigationController pushViewController:albumViewController animated:YES];
		[albumViewController release];
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

@end

