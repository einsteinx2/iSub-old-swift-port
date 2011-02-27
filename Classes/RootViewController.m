//
//  RootViewController.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "RootViewController.h"
#import "SearchOverlayViewController.h"
#import "iSubAppDelegate.h"
#import "MusicControlsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "XMLParser.h"
#import "AlbumViewController.h"
#import "Artist.h"
#import "LoadingScreen.h"
#import "ArtistUITableViewCell.h"
#import "NSString+md5.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

#import "ASIAuthenticationDialog.h"
#import "ASIFormDataRequest.h"
#import "ASIHTTPRequest.h"
#import "ASIInputStream.h"
#import "ASINetworkQueue.h"
#import "ASINSStringAdditions.h"

#import "ViewObjectsSingleton.h"

#import "UIView-tools.h"

@interface RootViewController (Private)

- (void)addCount;

@end

@implementation RootViewController

@synthesize searchBar, headerView;
@synthesize copyListOfArtists;
@synthesize isSearching;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation {
    return YES;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	databaseControls = [DatabaseControlsSingleton sharedInstance];
	musicControls = [MusicControlsSingleton sharedInstance];
	
	/*UIView *gray = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, 320.0f, self.tableView.bounds.size.height)];
	gray.backgroundColor = viewObjects.darkNormal;
	[self.tableView addSubview:gray];
	[gray release];*/
	
	self.title = @"Folders";
	
	//self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];
	
	//Initialize the copy array for searching.
	copyListOfArtists = [[NSMutableArray alloc] init];
		
	//Set defaults
	isSearching = NO;
	didBeginSearching = NO;
	letUserSelectRow = YES;	
	isCountShowing = NO;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadArtistList) name:@"reloadArtistList" object:nil];
	
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

- (void)reloadArtistList
{
	[self.tableView reloadData];
	[self addCount];
}


-(void)addCount
{
	//float parentWidth = self.view.bounds.size.width;
	
	isCountShowing = YES;
	
	//Build the search and reload view
	headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 90)] autorelease];
	headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	headerView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];
	
	reloadButton = [UIButton buttonWithType:UIButtonTypeCustom];
	reloadButton.frame = CGRectMake(0, 0, 320, 40);
	reloadButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
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
	searchBar.placeholder = @"Folder name";
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
	
	NSInteger count = 0;
	for (NSArray *array in viewObjects.listOfArtists)
	{
		count = count + [array count];
	}
	countLabel.text = [NSString stringWithFormat:@"%i Folders", count];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateStyle:NSDateFormatterMediumStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	reloadTimeLabel.text = [NSString stringWithFormat:@"last reload: %@", [formatter stringFromDate:[defaults objectForKey:[NSString stringWithFormat:@"%@artistsReloadTime", appDelegate.defaultUrl]]]];
	[formatter release];
	
	self.tableView.tableHeaderView = headerView;
}


-(void)loadData
{
	// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	//NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	viewObjects.isArtistsLoading = YES;
		
	//NSLog(@"%@", [appDelegate getBaseUrl:@"getIndexes.view"]);
	
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[appDelegate getBaseUrl:@"getIndexes.view"]] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kLoadingTimeout];
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
		// Create the NSMutableData to hold the received data.
		// receivedData is an instance variable declared elsewhere.
		receivedData = [[NSMutableData data] retain];
		
		viewObjects.listOfArtists = nil;
		viewObjects.artistIndex = nil;
		
		allArtistsLoadingScreen = [[LoadingScreen alloc] initOnView:self.view.superview withMessage:[NSArray arrayWithObjects:@"Processing Folders", @"", @"", @"", nil] blockInput:YES mainWindow:NO];
	} 
	else 
	{
		viewObjects.isArtistsLoading = NO;
		
		// Inform the user that the connection failed.
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"There was an error loading the artist list.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
	
	/*ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:[appDelegate getBaseUrl:@"getIndexes.view"]]];
	[request setTimeOutSeconds:240];
	[request startSynchronous];
	if ([request error])
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"There was an error grabbing the album list.\n\nError: %@", [request error].localizedDescription] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
	else
	{
		NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:[request responseData]];
		XMLParser *parser = [[XMLParser alloc] initXMLParser];
		parser.parseState = @"artists";
		[xmlParser setDelegate:parser];
		[xmlParser parse];
		
		viewObjects.artistIndex = [[NSArray alloc] initWithArray:parser.indexes copyItems:YES];
		viewObjects.listOfArtists = [[NSArray alloc] initWithArray:parser.listOfArtists copyItems:YES];
	
		[xmlParser release];
		[parser release];
	}
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:viewObjects.listOfArtists] forKey:[NSString stringWithFormat:@"%@listOfArtists", appDelegate.defaultUrl]];
	[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:viewObjects.artistIndex] forKey:[NSString stringWithFormat:@"%@indexes", appDelegate.defaultUrl]];
	[defaults setObject:[NSDate date] forKey:[NSString stringWithFormat:@"%@artistsReloadTime", appDelegate.defaultUrl]];
	[defaults synchronize];
	
	// Must do the UI stuff in the main thread
	[self performSelectorOnMainThread:@selector(loadData2) withObject:nil waitUntilDone:NO];
	
	[autoreleasePool release];*/
}


/*-(void) loadData2
{
	[self addCount];
	
	[self.tableView reloadData];
	self.tableView.backgroundColor = [UIColor clearColor];
	
	viewObjects.isArtistsLoading = NO;
	
	// Hide the loading screen
	[allArtistsLoadingScreen hide]; [allArtistsLoadingScreen release];
	
}*/



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
	
	if (!viewObjects.isAlbumsLoading && !viewObjects.isSongsLoading && !viewObjects.isArtistsLoading)
	{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		if(viewObjects.listOfArtists == nil || [[appDelegate.settingsDictionary objectForKey:@"autoReloadArtistsSetting"] isEqualToString:@"YES"])
		{
			if([defaults objectForKey:[NSString stringWithFormat:@"%@listOfArtists", appDelegate.defaultUrl]] == nil || 
			   [[appDelegate.settingsDictionary objectForKey:@"autoReloadArtistsSetting"] isEqualToString:@"YES"])
			{
				//[appDelegate showLoadingScreen:self.view.superview blockInput:YES mainWindow:NO];
				//allArtistsLoadingScreen = [[LoadingScreen alloc] initOnView:self.view.superview withMessage:[NSArray arrayWithObjects:@"Processing Artists", @"", @"", @"", nil] blockInput:YES mainWindow:NO];
				//[self performSelectorInBackground:@selector(loadData) withObject:nil];
				[self loadData];
			}
			else 
			{
				viewObjects.listOfArtists = [NSKeyedUnarchiver unarchiveObjectWithData:[defaults objectForKey:[NSString stringWithFormat:@"%@listOfArtists", appDelegate.defaultUrl]]];
				viewObjects.artistIndex = [NSKeyedUnarchiver unarchiveObjectWithData:[defaults objectForKey:[NSString stringWithFormat:@"%@indexes", appDelegate.defaultUrl]]];
				
				// Handle the change to the listOfArtists structure gracefully
				if ([viewObjects.listOfArtists count] > 0)
				{
					if ([[viewObjects.listOfArtists objectAtIndex:0] count] > 0)
					{
						if ([[[viewObjects.listOfArtists objectAtIndex:0] objectAtIndex:0] isKindOfClass:[NSArray class]])
						{
							//allArtistsLoadingScreen = [[LoadingScreen alloc] initOnView:self.view.superview withMessage:[NSArray arrayWithObjects:@"Processing Artists", @"", @"", @"", nil] blockInput:YES mainWindow:NO];
							//[self performSelectorInBackground:@selector(loadData) withObject:nil];
							[self loadData];
						}
						else
						{
							[self addCount];
							[self.tableView reloadData];
						}
					}
					else
					{
						[self addCount];
						[self.tableView reloadData];
					}
				}
				else
				{
					[self addCount];
					[self.tableView reloadData];
				}
			}
		}
		else 
		{
			if (!isCountShowing)
				[self addCount];
		}
	}
	
	if (!viewObjects.isArtistsLoading)
	{
		if (!isCountShowing)
			[self addCount];
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
	[copyListOfArtists release];
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
	
	letUserSelectRow = YES;
	isSearching = NO;
	didBeginSearching = NO;
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
	if (!viewObjects.isAlbumsLoading && !viewObjects.isSongsLoading)
	{
		//viewObjects.listOfArtists = nil;
		//allArtistsLoadingScreen = [[LoadingScreen alloc] initOnView:self.view.superview withMessage:[NSArray arrayWithObjects:@"Processing Artists", @"", @"", @"", nil] blockInput:YES mainWindow:NO];
		//[self performSelectorInBackground:@selector(loadData) withObject:nil];	
		[self loadData];
	}
	else
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Please Wait" message:@"You cannot reload the Artists tab while the Albums or Songs tabs are loading" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
		[alert release];
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
#pragma mark SearchBar


- (void) searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar 
{
	[self.tableView.tableHeaderView retain];

	[self.tableView setContentOffset:CGPointMake(0, 50) animated:YES];
	//[self.tableView setContentOffset:CGPointMake(0, 50) animated:NO];
	
	if ([theSearchBar.text length] == 0)
	{
		//Add the overlay view.
		if(searchOverlayView == nil)
			searchOverlayView = [[SearchOverlayViewController alloc] initWithNibName:@"SearchOverlayViewController" bundle:[NSBundle mainBundle]];
		//CGFloat y = self.tableView.contentOffset.y - searchBar.frame.origin.y + searchBar.frame.size.height;
		CGFloat width = self.view.frame.size.width;
		CGFloat height = self.view.frame.size.height;
		//CGRect frame = CGRectMake(0, y, width, height);
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
	//Remove all objects first.
	[copyListOfArtists removeAllObjects];
	
	if([searchText length] > 0) 
	{
		[searchOverlayView.view removeFromSuperview];
		isSearching = YES;
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
		
		isSearching = NO;
		letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
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
	NSString *searchText = searchBar.text;
	NSMutableArray *searchArray = [[NSMutableArray alloc] init];
	
	for (NSArray *array in viewObjects.listOfArtists)
	{
		[searchArray addObjectsFromArray:array];
	}
	
	for (Artist *anArtist in searchArray)
	{
		NSRange titleResultsRange = [anArtist.name rangeOfString:searchText options:NSCaseInsensitiveSearch];
		
		if (titleResultsRange.length > 0)
			[copyListOfArtists addObject:anArtist];
	}
	
	[searchArray release];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	if (isSearching)
		return 1;
	else
		return [viewObjects.listOfArtists count];
}


#pragma mark TableView

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (isSearching)
	{
		return [copyListOfArtists count];
	}
	else 
	{
		return [[viewObjects.listOfArtists objectAtIndex:section] count];
	}
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *CellIdentifier = @"Cell";
	ArtistUITableViewCell *cell = [[[ArtistUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
	
	Artist *anArtist;
	if(isSearching)
	{
		//anArtist = [[copyListOfArtists objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
		anArtist = [copyListOfArtists objectAtIndex:indexPath.row];
	}
	else
	{
		anArtist = [[viewObjects.listOfArtists objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
	}
	cell.myArtist = anArtist;
	
	[cell.artistNameLabel setText:anArtist.name];
	cell.backgroundView = [viewObjects createCellBackground:indexPath.row];
	
	return cell;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	
	if(isSearching || didBeginSearching)
		return @"";
	
	return [viewObjects.artistIndex objectAtIndex:section];
}


// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView 
{
	if(isSearching || didBeginSearching)
		return nil;
	else
	{
		NSMutableArray *searchIndexes = [[[NSMutableArray alloc] init] autorelease];
		[searchIndexes addObject:@"{search}"];
		[searchIndexes addObjectsFromArray:viewObjects.artistIndex];
		
		return searchIndexes;
	}
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index 
{
	if(isSearching || didBeginSearching)
		return -1;
	
	if (index == 0) 
	{
		[tableView scrollRectToVisible:CGRectMake(0, 50, 320, 40) animated:NO];
		return -1;
	}
	
	return index - 1;
}


- (NSIndexPath *)tableView :(UITableView *)theTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if(letUserSelectRow)
		return indexPath;
	else
		return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (viewObjects.isCellEnabled)
	{
		Artist *anArtist;
		if(isSearching)
		{
			anArtist = [copyListOfArtists objectAtIndex:indexPath.row];
		}
		else 
		{	
			anArtist = [[viewObjects.listOfArtists objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
		}
		AlbumViewController* albumViewController = [[AlbumViewController alloc] initWithArtist:anArtist orAlbum:nil];
				
		[self.navigationController pushViewController:albumViewController animated:YES];
		[albumViewController release];
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
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
	[receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	// Inform the user that the connection failed.
	NSString *message = [NSString stringWithFormat:@"There was an error loading the artist list.\n\nError %i: %@", [error code], [error localizedDescription]];
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
	[alert release];
	
	[theConnection release];
	[receivedData release];
	
	viewObjects.isArtistsLoading = NO;
	
	// Hide the loading screen
	[allArtistsLoadingScreen hide]; [allArtistsLoadingScreen release];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:receivedData];
	XMLParser *parser = [[XMLParser alloc] initXMLParser];
	parser.parseState = @"artists";
	[xmlParser setDelegate:parser];
	[xmlParser parse];
	
	viewObjects.artistIndex = [[NSArray alloc] initWithArray:parser.indexes copyItems:YES];
	viewObjects.listOfArtists = [[NSArray alloc] initWithArray:parser.listOfArtists copyItems:YES];
	
	[xmlParser release];
	[parser release];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:viewObjects.listOfArtists] forKey:[NSString stringWithFormat:@"%@listOfArtists", appDelegate.defaultUrl]];
	[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:viewObjects.artistIndex] forKey:[NSString stringWithFormat:@"%@indexes", appDelegate.defaultUrl]];
	[defaults setObject:[NSDate date] forKey:[NSString stringWithFormat:@"%@artistsReloadTime", appDelegate.defaultUrl]];
	[defaults synchronize];
	
	[self addCount];
	
	[self.tableView reloadData];
	self.tableView.backgroundColor = [UIColor clearColor];
	
	viewObjects.isArtistsLoading = NO;
	
	// Hide the loading screen
	[allArtistsLoadingScreen hide]; [allArtistsLoadingScreen release];
	
	[theConnection release];
	[receivedData release];
}

@end

