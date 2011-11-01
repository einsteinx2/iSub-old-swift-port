//
//  PlayingViewController.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "PlayingViewController.h"
#import "PlayingUITableViewCell.h"
#import "PlayingXMLParser.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "AsynchronousImageViewCached.h"
#import "Song.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString-md5.h"
#import "MGSplitViewController.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
#import "NSMutableURLRequest+SUS.h"

@implementation PlayingViewController

@synthesize nothingPlayingScreen;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	//if ([[[iSubAppDelegate sharedInstance].settingsDictionary objectForKey:@"lockRotationSetting"] isEqualToString:@"YES"] && inOrientation != UIInterfaceOrientationPortrait)
	if ([SavedSettings sharedInstance].isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicSingleton sharedInstance];
	databaseControls = [DatabaseSingleton sharedInstance];
	
	isNothingPlayingScreenShowing = NO;
	
	self.tableView.separatorColor = [UIColor clearColor];
	
	self.title = @"Now Playing";
	//self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];

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


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	
	if(musicControls.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	viewObjects.listOfPlayingSongs = [NSMutableArray arrayWithCapacity:1];
	//viewObjects.listOfPlayingSongs = nil, viewObjects.listOfPlayingSongs = [[NSMutableArray alloc] init];

	// Load the data
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getNowPlaying" andParameters:nil];
    
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
		// Create the NSMutableData to hold the received data.
		// receivedData is an instance variable declared elsewhere.
		receivedData = [[NSMutableData data] retain];
		
		// Display the loading screen
		[viewObjects showLoadingScreenOnMainWindow];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error grabbing the playing songs.\n\nThe connection could not be created" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		alert.tag = 2;
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
}

-(void)viewWillDisappear:(BOOL)animated
{
	if (isNothingPlayingScreenShowing == YES)
	{
		[nothingPlayingScreen removeFromSuperview];
		isNothingPlayingScreenShowing = NO;
	}
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


#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [viewObjects.listOfPlayingSongs count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
	PlayingUITableViewCell *cell = [[[PlayingUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
	
    // Set up the cell...
	NSArray *cellValue = [viewObjects.listOfPlayingSongs objectAtIndex:indexPath.row];
	Song *aSong = [cellValue objectAtIndex:0];
	
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
			if (SCREEN_SCALE() == 2.0)
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
	
	if([[cellValue objectAtIndex:2] isEqualToString:@""])
		[cell.userNameLabel setText:[NSString stringWithFormat:@"%@ - %i mins ago", [cellValue objectAtIndex:1], [[cellValue objectAtIndex:3] intValue]]];
	else
		[cell.userNameLabel setText:[NSString stringWithFormat:@"%@ @ %@ - %i mins ago", [cellValue objectAtIndex:1], [cellValue objectAtIndex:2], [[cellValue objectAtIndex:3] intValue]]];
	[cell.songNameLabel setText:aSong.title];
	if (aSong.album)
		[cell.artistNameLabel setText:[NSString stringWithFormat:@"%@ - %@", aSong.artist, aSong.album]];
	else
		[cell.artistNameLabel setText:aSong.artist];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	
    return cell;
}


#pragma mark -
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
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"There was an error grabbing the list of playing songs.\n\nError:%@", error.localizedDescription] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	alert.tag = 2;
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
	[alert release];
	
	[theConnection release];
	[receivedData release];
	
	[viewObjects hideLoadingScreen];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	// Parse the response
	NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:receivedData];
	PlayingXMLParser *parser = [[PlayingXMLParser alloc] initXMLParser];
	[xmlParser setDelegate:parser];
	[xmlParser parse];
	
	[xmlParser release];
	[parser release];
	
	// Hide the loading screen
	[viewObjects hideLoadingScreen];
	
	// Reload the table
	[self.tableView reloadData]; 
	
	// Display the no songs overlay if 0 results
	if ([viewObjects.listOfPlayingSongs count] == 0)
	{
		if (isNothingPlayingScreenShowing == NO)
		{
			isNothingPlayingScreenShowing = YES;
			nothingPlayingScreen = [[UIImageView alloc] init];
			nothingPlayingScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
			nothingPlayingScreen.frame = CGRectMake(40, 100, 240, 180);
			nothingPlayingScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
			nothingPlayingScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
			nothingPlayingScreen.alpha = .80;
			
			UILabel *textLabel = [[UILabel alloc] init];
			textLabel.backgroundColor = [UIColor clearColor];
			textLabel.textColor = [UIColor whiteColor];
			textLabel.font = [UIFont boldSystemFontOfSize:32];
			textLabel.textAlignment = UITextAlignmentCenter;
			textLabel.numberOfLines = 0;
			[textLabel setText:@"Nothing Playing\non the\nServer"];
			textLabel.frame = CGRectMake(15, 15, 210, 150);
			[nothingPlayingScreen addSubview:textLabel];
			[textLabel release];
			
			[self.view addSubview:nothingPlayingScreen];
			
			[nothingPlayingScreen release];
		}
	}
	
	[theConnection release];
	[receivedData release];
}

- (void)dealloc {
    [super dealloc];
}




@end

