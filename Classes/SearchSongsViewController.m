//
//  SearchSongsViewController.m
//  iSub
//
//  Created by bbaron on 10/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SearchSongsViewController.h"
#import "SearchSongUITableViewCell.h"
#import "iSubAppDelegate.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "ViewObjectsSingleton.h"
#import "SearchXMLParser.h"
#import "ViewObjectsSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "FMDatabaseAdditions.h"
#import "ServerListViewController.h"
#import "ArtistUITableViewCell.h"
#import "AlbumUITableViewCell.h"
#import "Artist.h"
#import "Album.h"
#import "Song.h"
#import "NSString+md5.h"
#import "AsynchronousImageView.h"
#import "AlbumViewController.h"
#import "UITableViewCell+overlay.h"
#import "NSString+rfcEncode.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
#import "NSString+URLEncode.h"
#import "NSMutableURLRequest+SUS.h"
#import "PlaylistSingleton.h"
#import "NSArray+Additions.h"
#import "NSNotificationCenter+MainThread.h"
#import "JukeboxSingleton.h"

@implementation SearchSongsViewController

@synthesize query, searchType;
@synthesize listOfArtists, listOfAlbums, listOfSongs, offset, isMoreResults;
@synthesize connection;

#pragma mark -
#pragma mark View lifecycle

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if (settingsS.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (id)initWithNibName:(NSString *)n bundle:(NSBundle *)b;
{
    self = [super initWithNibName:n bundle:b];
	
    if (self != nil)
    {
		
		listOfArtists = nil;
		listOfAlbums = nil;
		listOfSongs = nil;
		
		offset = 0;
		isMoreResults = YES;
		isLoading = NO;
		
		connection = nil;
    }
	
    return self;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	if(musicS.showPlayerIcon)
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
		
- (void) viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	[connection cancel];
	[connection release];
	connection = nil;
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

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	if (searchType == 0)
	{
		return [listOfArtists count] + 1;
	}
	else if (searchType == 1)
	{
		return [listOfAlbums count] + 1;
	}
	else
	{
		return [listOfSongs count] + 1;
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (searchType == 0)
	{
		return 44.0;
	}
	else 
	{
		return 60.0;
	}
}

- (void)loadMoreResults
{
	offset += 20;
    NSDictionary *parameters = nil;
    NSString *action = nil;
	NSString *offsetString = [NSString stringWithFormat:@"%i", offset];
	if (settingsS.isNewSearchAPI)
	{
        action = @"search2";
		NSString *queryString = [NSString stringWithFormat:@"%@*", query];
		if (searchType == 0)
		{
            parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"20", @"artistCount", @"0", @"albumCount", @"0", @"songCount", 
                          n2N(queryString), @"query", n2N(offsetString), @"artistOffset", nil];
		}
		else if (searchType == 1)
		{
            parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"0", @"artistCount", @"20", @"albumCount", @"0", @"songCount", 
                          n2N(queryString), @"query", n2N(offsetString), @"albumOffset", nil];
		}
		else
		{
            parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"0", @"artistCount", @"0", @"albumCount", @"20", @"songCount", 
                          n2N(queryString), @"query", n2N(offsetString), @"songOffset", nil];
		}
	}
	else
	{
        action = @"search";
        parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"20", @"count", n2N(query), @"any", n2N(offsetString), @"offset", nil];
	}
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:action andParameters:parameters];

	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (connection)
	{
		receivedData = [[NSMutableData alloc] initWithCapacity:0];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error performing the search.\n\nThe connection could not be created" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
		[alert release];
	}
}

- (UITableViewCell *)createLoadingCell:(NSUInteger)row
{
	// This is the last cell and there could be more results, load the next 20 results;
	UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"NoReuse"] autorelease];
	
	// Set background color
	cell.backgroundView = [viewObjectsS createCellBackground:row];
	
	if (isMoreResults && !isLoading)
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
		if ([listOfArtists count] > 0 || [listOfAlbums count] > 0 || [listOfSongs count] > 0)
		{			
			cell.textLabel.text = @"No more search results";
		}
		else
		{
			cell.textLabel.text = @"No results";
		}
	}
	
	return cell;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{    
	if (searchType == 0)
	{
		if (indexPath.row < [listOfArtists count])
		{
			static NSString *cellIdentifier = @"ArtistCell";
			ArtistUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
			if (!cell)
			{
				cell = [[ArtistUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
			}
						
			Artist *anArtist = [listOfArtists objectAtIndexSafe:indexPath.row];
			cell.myArtist = anArtist;
			
			[cell.artistNameLabel setText:anArtist.name];
			cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
			
			return cell;
		}
		else if (indexPath.row == [listOfArtists count])
		{
			return [self createLoadingCell:indexPath.row];
		}
	}
	else if (searchType == 1)
	{
		if (indexPath.row < [listOfAlbums count])
		{
			static NSString *cellIdentifier = @"AlbumCell";
			AlbumUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
			if (!cell)
			{
				cell = [[AlbumUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
				cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			}
						
			Album *anAlbum = [listOfAlbums objectAtIndexSafe:indexPath.row];
			cell.myId = anAlbum.albumId;
			cell.myArtist = [Artist artistWithName:anAlbum.artistName andArtistId:anAlbum.artistId];
			cell.isIndexShowing = NO;
			
			cell.coverArtView.coverArtId = anAlbum.coverArtId;
			
			[cell.albumNameLabel setText:anAlbum.title];
			
			
			// Setup cell backgrond color
			cell.backgroundView = [[[UIView alloc] init] autorelease];
			if(indexPath.row % 2 == 0)
				cell.backgroundView.backgroundColor = viewObjectsS.lightNormal;
			else
				cell.backgroundView.backgroundColor = viewObjectsS.darkNormal;
			
			return cell;
		}
		else if (indexPath.row == [listOfAlbums count])
		{
			return [self createLoadingCell:indexPath.row];
		}
	}
	else
	{
		if (indexPath.row < [listOfSongs count])
		{
			static NSString *cellIdentifier = @"SearchSongCell";
			SearchSongUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
			if (!cell)
			{
				cell = [[SearchSongUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
			}
			
			cell.row = indexPath.row;
			cell.mySong = [listOfSongs objectAtIndexSafe:indexPath.row];
			return cell;
		}
		else if (indexPath.row == [listOfSongs count])
		{
			return [self createLoadingCell:indexPath.row];
		}
	}
	
	// In case somehow no cell is created, return an empty cell
	static NSString *cellIdentifier = @"EmptyCell";
	return [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier] autorelease];
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{	
	if (!indexPath)
		return;
	
	if (searchType == 0)
	{
		if (viewObjectsS.isCellEnabled && indexPath.row != [listOfArtists count])
		{
			Artist *anArtist = [listOfArtists objectAtIndexSafe:indexPath.row];
			AlbumViewController *albumView = [[AlbumViewController alloc] initWithArtist:anArtist orAlbum:nil];
			
			[self.navigationController pushViewController:albumView animated:YES];
			
			[albumView release];
			
			return;
		}
	}
	else if (searchType == 1)
	{
		if (viewObjectsS.isCellEnabled && indexPath.row != [listOfAlbums count])
		{
			Album *anAlbum = [listOfAlbums objectAtIndexSafe:indexPath.row];
			AlbumViewController *albumView = [[AlbumViewController alloc] initWithArtist:nil orAlbum:anAlbum];
			
			[self.navigationController pushViewController:albumView animated:YES];
			
			[albumView release];
			
			return;
		}
	}
	else
	{
		if (viewObjectsS.isCellEnabled && indexPath.row != [listOfSongs count])
		{
			// Clear the current playlist
			if (settingsS.isJukeboxEnabled)
				[databaseS resetJukeboxPlaylist];
			else
				[databaseS resetCurrentPlaylistDb];
			
			// Add the songs to the playlist 
			NSMutableArray *songIds = [[NSMutableArray alloc] init];
			for (Song *aSong in listOfSongs)
			{
				NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
				
				[aSong addToCurrentPlaylist];
				
				// In jukebox mode, collect the song ids to send to the server
				if (settingsS.isJukeboxEnabled)
					[songIds addObject:aSong.songId];
				
				[pool release];
			}
			
			// If jukebox mode, send song ids to server
			if (settingsS.isJukeboxEnabled)
			{
				[jukeboxS jukeboxStop];
				[jukeboxS jukeboxClearPlaylist];
				[jukeboxS jukeboxAddSongs:songIds];
			}
			[songIds release];
			
			// Set player defaults
			playlistS.isShuffle = NO;
			
			// Start the song
			[musicS playSongAtPosition:indexPath.row];
			
			// Show the player
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
			
			return;
		}
	}
	
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
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
	NSString *message = [NSString stringWithFormat:@"There was an error completing the search.\n\nError:%@", error.localizedDescription];

	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	[alert release];
	
	[connection release]; connection = nil;
	[receivedData release];
	
	[viewObjectsS hideLoadingScreen];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	//DLog(@"%@", [[[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding] autorelease]);
	
	NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:receivedData];
	SearchXMLParser *parser = [[SearchXMLParser alloc] initXMLParser];
	[xmlParser setDelegate:parser];
	[xmlParser parse];
	
	//DLog(@"parser.listOfSongs:\n%@", parser.listOfSongs);
	
	if (searchType == 0)
	{
		if ([parser.listOfArtists count] == 0)
		{
			isMoreResults = NO;
		}
		else 
		{
			[listOfArtists addObjectsFromArray:parser.listOfArtists];
		}
	}
	else if (searchType == 1)
	{
		if ([parser.listOfAlbums count] == 0)
		{
			isMoreResults = NO;
		}
		else 
		{
			[listOfAlbums addObjectsFromArray:parser.listOfAlbums];
		}
	}
	else if (searchType == 2)
	{
		if ([parser.listOfSongs count] == 0)
		{
			isMoreResults = NO;
		}
		else 
		{
			[listOfSongs addObjectsFromArray:parser.listOfSongs];
		}
	}
	
		
	[xmlParser release];
	[parser release];
	
	// Reload the table
	[self.tableView reloadData];
	isLoading = NO;
		
	[connection	release]; connection = nil;
	[receivedData release];
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning 
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)dealloc 
{
    [super dealloc];
	
	[query release];
	[listOfArtists release];
	[listOfAlbums release];
	[listOfSongs release];
}


@end

