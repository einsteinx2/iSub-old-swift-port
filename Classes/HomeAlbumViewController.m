//
//  HomeAlbumViewController.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "HomeAlbumViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "AlbumViewController.h"
#import "AllAlbumsUITableViewCell.h"
#import "SongUITableViewCell.h"
#import "AsynchronousImageViewCached.h"
#import "Artist.h"
#import "Album.h"
#import "Song.h"
#import "NSString+md5.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "LoadingScreen.h"
#import "HomeXMLParser.h"
#import "ServerListViewController.h"
#import "UITableViewCell+overlay.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
#import "NSMutableURLRequest+SUS.h"


@implementation HomeAlbumViewController
@synthesize listOfAlbums;
@synthesize offset, isMoreAlbums, modifier;
@synthesize receivedData;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if ([SavedSettings sharedInstance].isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (id)initWithNibName:(NSString *)n bundle:(NSBundle *)b;
{
    self = [super initWithNibName:n bundle:b];
	
    if (self != nil)
    {
		appDelegate = (iSubAppDelegate *)[UIApplication sharedApplication].delegate;
		musicControls = [MusicSingleton sharedInstance];
		databaseControls = [DatabaseSingleton sharedInstance];
		viewObjects = [ViewObjectsSingleton sharedInstance];

		offset = 0;
		isMoreAlbums = YES;
		isLoading = NO;
    }
	
    return self;
}

- (void)viewDidLoad  
{	
	[super viewDidLoad];
	
	//self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];

	if(musicControls.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
	
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

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}


- (void)viewDidUnload
{
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc 
{
	[listOfAlbums release];
	[super dealloc];
}

- (void)loadMoreResults
{	
	offset += 20;
	
	NSString *offsetString = [NSString stringWithFormat:@"%i", offset];
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"20", @"size", n2N(modifier), @"type", n2N(offsetString), @"offset", nil];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getAlbumList" andParameters:parameters];
	
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
		self.receivedData = [NSMutableData data];
		
		[viewObjects showLoadingScreenOnMainWindow];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error doing the search.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
}

#pragma mark - Connection Delegate

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
	[self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [self.receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	self.receivedData = nil;
	[theConnection release];
	
	[viewObjects hideLoadingScreen];
    
    CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"There was an error doing the search.\n\nError:%@", error.localizedDescription] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
    [alert release];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
    NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:self.receivedData];
    HomeXMLParser *parser = (HomeXMLParser*)[[HomeXMLParser alloc] initXMLParser];
    [xmlParser setDelegate:parser];
    [xmlParser parse];
    
    if ([parser.listOfAlbums count] == 0)
    {
        // There are no more songs
        isMoreAlbums = NO;
    }
    else 
    {
        // Add the new results to the list of songs
        [listOfAlbums addObjectsFromArray:parser.listOfAlbums];
    }
    
    [xmlParser release];
    [parser release];
    
    // Reload the table
    [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
    isLoading = NO;
    
	self.receivedData = nil;
	[theConnection release];
	
	[viewObjects hideLoadingScreen];
}

#pragma mark Table view methods

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	return [listOfAlbums count] + 1;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{		
	static NSString *CellIdentifier = @"Cell";
		
	if (indexPath.row < [listOfAlbums count])
	{
		AllAlbumsUITableViewCell *cell = [[[AllAlbumsUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		
		Album *anAlbum = [listOfAlbums objectAtIndex:indexPath.row];
		cell.myId = anAlbum.albumId;
		cell.myArtist = [Artist artistWithName:anAlbum.artistName andArtistId:anAlbum.artistId];
		
		[cell.coverArtView loadImageFromCoverArtId:anAlbum.coverArtId];
		
		[cell.albumNameLabel setText:anAlbum.title];
		[cell.artistNameLabel setText:anAlbum.artistName];
		
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		
		// Setup cell backgrond color
		cell.backgroundView = [[[UIView alloc] init] autorelease];
		if(indexPath.row % 2 == 0)
			cell.backgroundView.backgroundColor = viewObjects.lightNormal;
		else
			cell.backgroundView.backgroundColor = viewObjects.darkNormal;
		
		return cell;
	}
	else if (indexPath.row == [listOfAlbums count])
	{
		// This is the last cell and there could be more results, load the next 20 songs;
		UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];

		// Set background color
		cell.backgroundView = [[ViewObjectsSingleton sharedInstance] createCellBackground:indexPath.row];
		
		if (isMoreAlbums && !isLoading)
		{
			isLoading = YES;
			cell.textLabel.text = @"Loading more results...";
			UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
			indicator.center = CGPointMake(300, 30);
			[cell addSubview:indicator];
			[indicator startAnimating];
			[indicator release];
            [self loadMoreResults];
		}
		else 
		{
			cell.textLabel.text = @"No more results";
		}
		
		return cell;
	}
	
	// In case somehow no cell is created, return an empty cell
	return [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{	
	if (viewObjects.isCellEnabled && indexPath.row != [listOfAlbums count])
	{
		Album *anAlbum = [listOfAlbums objectAtIndex:indexPath.row];
		AlbumViewController *albumViewController = [[AlbumViewController alloc] initWithArtist:nil orAlbum:anAlbum];
		[self.navigationController pushViewController:albumViewController animated:YES];
		[albumViewController release];
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}


@end

