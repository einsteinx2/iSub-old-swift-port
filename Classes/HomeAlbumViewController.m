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
#import "XMLParser.h"
#import "Artist.h"
#import "Album.h"
#import "Song.h"
#import "NSString-md5.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "ASIHTTPRequest.h"
#import "LoadingScreen.h"
#import "HomeXMLParser.h"
#import "ServerListViewController.h"
#import "UITableViewCell-overlay.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"


@implementation HomeAlbumViewController
@synthesize listOfAlbums;
@synthesize offset, isMoreAlbums, modifier;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	//if ([[[iSubAppDelegate sharedInstance].settingsDictionary objectForKey:@"lockRotationSetting"] isEqualToString:@"YES"] && inOrientation != UIInterfaceOrientationPortrait)
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
	
	/*// Add the play all button + shuffle button
	UIView *headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)] autorelease];
	headerView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];
	
	UIImageView *playAllImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"play-all-note.png"]];
	playAllImage.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	playAllImage.frame = CGRectMake(10, 10, 19, 30);
	[headerView addSubview:playAllImage];
	[playAllImage release];
	
	UILabel *playAllLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 160, 50)];
	playAllLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
	playAllLabel.backgroundColor = [UIColor clearColor];
	playAllLabel.textColor = [UIColor colorWithRed:186.0/255.0 green:191.0/255.0 blue:198.0/255.0 alpha:1];
	playAllLabel.textAlignment = UITextAlignmentCenter;
	playAllLabel.font = [UIFont boldSystemFontOfSize:30];
	playAllLabel.text = @"Play All";
	[headerView addSubview:playAllLabel];
	[playAllLabel release];
	
	UIButton *playAllButton = [UIButton buttonWithType:UIButtonTypeCustom];
	playAllButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
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
	
	self.tableView.tableHeaderView = headerView;*/
	
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

	for (Album *anAlbum in listOfAlbums)
	{
		// Do an XML parse for each item.
		NSURL *url = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"getMusicDirectory.view"], anAlbum.albumId]];
		
		ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
		[request startSynchronous];
		if ([request error])
		{
			CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"There was an error grabbing the album list.\n\nError: %@", [request error].localizedDescription] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
			[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
			[alert release];
		}
		else
		{
			NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:[request responseData]];
			XMLParser *parser = [(XMLParser *)[XMLParser alloc] initXMLParser];
			
			parser.myId = anAlbum.albumId;
			parser.myArtist = [Artist artistWithName:anAlbum.artistName andArtistId:anAlbum.artistId];
			parser.parseState = @"albums";
			
			[xmlParser setDelegate:parser];
			[xmlParser parse];
			
			// Add each song to playlist
			for (Song *aSong in parser.listOfSongs)
			{
				[databaseControls addSongToPlaylistQueue:aSong];
				//[databaseControls insertSong:aSong intoTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
			}
			
			// If there are any sub-albums, recurse through them 1 level deep
			if ([parser.listOfAlbums count] > 0)
			{
				for (Album *anAlbum in parser.listOfAlbums)
				{
					// Do an XML parse for each item.
					NSURL *url = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"getMusicDirectory.view"], anAlbum.albumId]];
					
					ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
					[request startSynchronous];
					if ([request error])
					{
						CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"There was an error grabbing the album list.\n\nError:%@", [request error].localizedDescription] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
						[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
						[alert release];
					}
					else
					{
						NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:[request responseData]];
						XMLParser *parser2 = [(XMLParser *)[XMLParser alloc] initXMLParser];
						
						parser2.myId = anAlbum.albumId;
						parser2.myArtist = [Artist artistWithName:anAlbum.artistName andArtistId:anAlbum.artistId];
						parser2.parseState = @"albums";
						
						[xmlParser setDelegate:parser2];
						[xmlParser parse];
						
						// Add each song to playlist
						for (Song *aSong in parser2.listOfSongs)
						{
							[databaseControls insertSong:aSong intoTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
						}
						
						[xmlParser release];
						[parser2 release];
					}
					
					[url release];
				}
			}
			
			[xmlParser release];
			[parser release];
		}
		
		[url release];
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
	
	[viewObjects performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:NO];
	[self performSelectorOnMainThread:@selector(playAllPlaySong) withObject:nil waitUntilDone:NO];
	
	[autoreleasePool release];
}


- (void)playAllPlaySong
{
	musicControls.isNewSong = YES;
	
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

- (void)playAllAction:(id)sender
{	
	if (IS_IPAD())
		[viewObjects showLoadingScreen:appDelegate.window blockInput:YES mainWindow:YES];
	else
		 [viewObjects showLoadingScreen:appDelegate.currentTabBarController.view blockInput:YES mainWindow:YES];
	[self performSelectorInBackground:@selector(loadPlayAllPlaylist:) withObject:@"NO"];
}

- (void)shuffleAction:(id)sender
{
	if (IS_IPAD())
		[viewObjects showLoadingScreen:appDelegate.window blockInput:YES mainWindow:YES];
	else
		[viewObjects showLoadingScreen:appDelegate.currentTabBarController.view blockInput:YES mainWindow:YES];
	[self performSelectorInBackground:@selector(loadPlayAllPlaylist:) withObject:@"YES"];
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
	[listOfAlbums release];
	[super dealloc];
}

- (void)loadMoreResults
{
	NSAutoreleasePool *releasePool = [[NSAutoreleasePool alloc] init];
	
	offset += 20;
	
	NSString *urlString = [NSString stringWithFormat:@"%@&size=20&type=%@&offset=%i", [appDelegate getBaseUrl:@"getAlbumList.view"], modifier, offset];
	
	// Parse the XML
	NSURL *url = [[NSURL alloc] initWithString:urlString];
	//DLog(@"url: %@", urlString);
	ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
	[request startSynchronous];
	if ([request error])
	{
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"There was an error doing the search.\n\nError:%@", [request error].localizedDescription] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
	else
	{
		NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:[request responseData]];
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
	}
	
	[url release];
	
	[releasePool release];
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
				if (SCREEN_SCALE() == 2.0)
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
		//AllAlbumsUITableViewCell *cell = [[[AllAlbumsUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		//cell.canShowOverlay = NO;
		
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
			[self performSelectorInBackground:@selector(loadMoreResults) withObject:nil];
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

