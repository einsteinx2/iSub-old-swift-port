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
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "ServerListViewController.h"
#import "ArtistUITableViewCell.h"
#import "AlbumUITableViewCell.h"
#import "Artist.h"
#import "Album.h"
#import "Song.h"
#import "NSString+md5.h"
#import "AsynchronousImageViewCached.h"
#import "AlbumViewController.h"
#import "UITableViewCell+overlay.h"
#import "MGSplitViewController.h"
#import "NSString+rfcEncode.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
#import "NSString+URLEncode.h"
#import "NSMutableURLRequest+SUS.h"

@implementation SearchSongsViewController

@synthesize query, searchType;
@synthesize listOfArtists, listOfAlbums, listOfSongs, offset, isMoreResults;
@synthesize connection;

#pragma mark -
#pragma mark View lifecycle

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
		
- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	/*if ([listOfArtists count] > 0 || [listOfAlbums count] > 0 || [listOfSongs count] > 0)
	{
		// Add the play all button + shuffle button
		UIView *headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)] autorelease];
		headerView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];
		
		UIImageView *playAllImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"play-all-note.png"]];
		playAllImage.frame = CGRectMake(10, 10, 19, 30);
		[headerView addSubview:playAllImage];
		[playAllImage release];
		
		UILabel *playAllLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 160, 50)];
		playAllLabel.backgroundColor = [UIColor clearColor];
		playAllLabel.textColor = [UIColor colorWithRed:186.0/255.0 green:191.0/255.0 blue:198.0/255.0 alpha:1];
		playAllLabel.textAlignment = UITextAlignmentCenter;
		playAllLabel.font = [UIFont boldSystemFontOfSize:30];
		playAllLabel.text = @"Play All";
		[headerView addSubview:playAllLabel];
		[playAllLabel release];
		
		UIButton *playAllButton = [UIButton buttonWithType:UIButtonTypeCustom];
		playAllButton.frame = CGRectMake(0, 0, 160, 40);
		[playAllButton addTarget:self action:@selector(playAllAction:) forControlEvents:UIControlEventTouchUpInside];
		[headerView addSubview:playAllButton];
		
		UILabel *spacerLabel = [[UILabel alloc] initWithFrame:CGRectMake(158, -2, 6, 50)];
		spacerLabel.backgroundColor = [UIColor clearColor];
		spacerLabel.textColor = [UIColor colorWithRed:186.0/255.0 green:191.0/255.0 blue:198.0/255.0 alpha:1];
		spacerLabel.font = [UIFont systemFontOfSize:40];
		spacerLabel.text = @"|";
		[headerView addSubview:spacerLabel];
		[spacerLabel release];
		
		UIImageView *shuffleImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"shuffle-small.png"]];
		shuffleImage.frame = CGRectMake(180, 12, 24, 26);
		[headerView addSubview:shuffleImage];
		[shuffleImage release];
		
		UILabel *shuffleLabel = [[UILabel alloc] initWithFrame:CGRectMake(180, 0, 160, 50)];
		shuffleLabel.backgroundColor = [UIColor clearColor];
		shuffleLabel.textColor = [UIColor colorWithRed:186.0/255.0 green:191.0/255.0 blue:198.0/255.0 alpha:1];
		shuffleLabel.textAlignment = UITextAlignmentCenter;
		shuffleLabel.font = [UIFont boldSystemFontOfSize:30];
		shuffleLabel.text = @"Shuffle";
		[headerView addSubview:shuffleLabel];
		[shuffleLabel release];
		
		UIButton *shuffleButton = [UIButton buttonWithType:UIButtonTypeCustom];
		shuffleButton.frame = CGRectMake(160, 0, 160, 40);
		[shuffleButton addTarget:self action:@selector(shuffleAction:) forControlEvents:UIControlEventTouchUpInside];
		[headerView addSubview:shuffleButton];
		
		self.tableView.tableHeaderView = headerView;
	}*/
}

- (void) viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	[connection cancel];
	[connection release];
	connection = nil;
}

/*- (void)loadPlayAllPlaylist:(NSString *)shuffle
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
	
	// Add each song to playlist if there are any
	for (Song *aSong in listOfSongs)
	{
		[databaseControls insertSong:aSong intoTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
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
	
	[self performSelectorOnMainThread:@selector(loadPlayAllPlaylist2) withObject:nil waitUntilDone:NO];	
	
	[autoreleasePool release];
}


- (void)playAllPlaySong
{	
	[musicControls destroyStreamer];
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


- (void)playAllAction:(id)sender
{	
	//[viewObjects showLoadingScreen:appDelegate.currentTabBarController.view blockInput:YES mainWindow:YES];
	//[self performSelectorInBackground:@selector(loadPlayAllPlaylist:) withObject:@"NO"];
}

- (void)shuffleAction:(id)sender
{
	//[viewObjects showLoadingScreen:appDelegate.currentTabBarController.view blockInput:YES mainWindow:YES];
	//[self performSelectorInBackground:@selector(loadPlayAllPlaylist:) withObject:@"YES"];
}*/

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
	if ([SavedSettings sharedInstance].isNewSearchAPI)
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
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
}

- (UITableViewCell *)createLoadingCell:(NSUInteger)row
{
	// This is the last cell and there could be more results, load the next 20 results;
	UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"] autorelease];
	
	// Set background color
	cell.backgroundView = [[ViewObjectsSingleton sharedInstance] createCellBackground:row];
	
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
    static NSString *CellIdentifier = @"Cell";
    
	if (searchType == 0)
	{
		if (indexPath.row < [listOfArtists count])
		{
			ArtistUITableViewCell *cell = [[[ArtistUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
			
			Artist *anArtist = [listOfArtists objectAtIndex:indexPath.row];
			cell.myArtist = anArtist;
			
			[cell.artistNameLabel setText:anArtist.name];
			cell.backgroundView = [viewObjects createCellBackground:indexPath.row];
			
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
			AlbumUITableViewCell *cell = [[[AlbumUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
			
			Album *anAlbum = [listOfAlbums objectAtIndex:indexPath.row];
			cell.myId = anAlbum.albumId;
			cell.myArtist = [Artist artistWithName:anAlbum.artistName andArtistId:anAlbum.artistId];
			cell.isIndexShowing = NO;
			
			[cell.coverArtView loadImageFromCoverArtId:anAlbum.coverArtId];
			
			[cell.albumNameLabel setText:anAlbum.title];
			
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
			return [self createLoadingCell:indexPath.row];
		}
	}
	else
	{
		if (indexPath.row < [listOfSongs count])
		{
			// Configure the cell...
			SearchSongUITableViewCell *cell = [[[SearchSongUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
			cell.row = indexPath.row;
			cell.mySong = [listOfSongs objectAtIndex:indexPath.row];
			return cell;
		}
		else if (indexPath.row == [listOfSongs count])
		{
			return [self createLoadingCell:indexPath.row];
		}
	}
	
	// In case somehow no cell is created, return an empty cell
	return [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{	
	if (searchType == 0)
	{
		if (viewObjects.isCellEnabled && indexPath.row != [listOfArtists count])
		{
			Artist *anArtist = [listOfArtists objectAtIndex:indexPath.row];
			AlbumViewController *albumView = [[AlbumViewController alloc] initWithArtist:anArtist orAlbum:nil];
			
			[self.navigationController pushViewController:albumView animated:YES];
			
			[albumView release];
			
			return;
		}
	}
	else if (searchType == 1)
	{
		if (viewObjects.isCellEnabled && indexPath.row != [listOfAlbums count])
		{
			Album *anAlbum = [listOfAlbums objectAtIndex:indexPath.row];
			AlbumViewController *albumView = [[AlbumViewController alloc] initWithArtist:nil orAlbum:anAlbum];
			
			[self.navigationController pushViewController:albumView animated:YES];
			
			[albumView release];
			
			return;
		}
	}
	else
	{
		if (viewObjects.isCellEnabled && indexPath.row != [listOfSongs count])
		{
			// Clear the current playlist
			if ([SavedSettings sharedInstance].isJukeboxEnabled)
				[databaseControls resetJukeboxPlaylist];
			else
				[databaseControls resetCurrentPlaylistDb];
			
			// Add the songs to the playlist 
			NSMutableArray *songIds = [[NSMutableArray alloc] init];
			for (Song *aSong in listOfSongs)
			{
				NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
				
				[aSong addToPlaylistQueue];
				
				// In jukebox mode, collect the song ids to send to the server
				if ([SavedSettings sharedInstance].isJukeboxEnabled)
					[songIds addObject:aSong.songId];
				
				[pool release];
			}
			
			// If jukebox mode, send song ids to server
			if ([SavedSettings sharedInstance].isJukeboxEnabled)
			{
				[musicControls jukeboxStop];
				[musicControls jukeboxClearPlaylist];
				[musicControls jukeboxAddSongs:songIds];
			}
			[songIds release];
			
			// Set player defaults
			musicControls.isShuffle = NO;
			
			// Start the song
			[musicControls playSongAtPosition:indexPath.row];
			
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
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
	[alert release];
	
	[connection release]; connection = nil;
	[receivedData release];
	
	[viewObjects hideLoadingScreen];
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
	[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
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

- (void)viewDidUnload 
{
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
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

