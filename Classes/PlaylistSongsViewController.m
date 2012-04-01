//
//  PlaylistSongsViewController.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "PlaylistSongsViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "PlaylistSongUITableViewCell.h"
#import "AsynchronousImageView.h"
#import "Song.h"
#import "FMDatabaseAdditions.h"
#import "NSString+md5.h"
#import "EGORefreshTableHeaderView.h"
#import "CustomUIAlertView.h"
#import "NSString+rfcEncode.h"
#import "TBXML.h"
#import "SavedSettings.h"
#import "NSMutableURLRequest+SUS.h"
#import "OrderedDictionary.h"
#import "SUSServerPlaylist.h"
#import "NSNotificationCenter+MainThread.h"

#import "PlaylistSingleton.h"
#import "JukeboxSingleton.h"
#import "UIViewController+PushViewControllerCustom.h"

@interface PlaylistSongsViewController (Private)

- (void)dataSourceDidFinishLoadingNewData;

@end


@implementation PlaylistSongsViewController

@synthesize md5, serverPlaylist;
@synthesize reloading=_reloading;
@synthesize connection, receivedData, playlistCount; 


-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if (settingsS.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];

    if (viewObjectsS.isLocalPlaylist)
	{
		self.title = [databaseS.localPlaylistsDb stringForQuery:@"SELECT playlist FROM localPlaylists WHERE md5 = ?", self.md5];
		
		UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
		headerView.backgroundColor = viewObjectsS.darkNormal;
		
		UIImageView *sendImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"upload-playlist.png"]];
		sendImage.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		sendImage.frame = CGRectMake(23, 11, 24, 24);
		[headerView addSubview:sendImage];
		[sendImage release];
		
		UILabel *sendLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 320, 50)];
		sendLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		sendLabel.backgroundColor = [UIColor clearColor];
		sendLabel.textColor = [UIColor colorWithRed:186.0/255.0 green:191.0/255.0 blue:198.0/255.0 alpha:1];
		sendLabel.textAlignment = UITextAlignmentCenter;
		sendLabel.font = [UIFont boldSystemFontOfSize:30];
		sendLabel.text = @"Save to Server";
		[headerView addSubview:sendLabel];
		[sendLabel release];
		
		UIButton *sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
		sendButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		sendButton.frame = CGRectMake(0, 0, 320, 40);
		[sendButton addTarget:self action:@selector(uploadPlaylistAction:) forControlEvents:UIControlEventTouchUpInside];
		[headerView addSubview:sendButton];
		
		self.tableView.tableHeaderView = headerView;
		[headerView release];
		
		if (!IS_IPAD())
		{
			UIImageView *fadeTop = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-top.png"]];
			fadeTop.frame =CGRectMake(0, -10, self.tableView.bounds.size.width, 10);
			fadeTop.autoresizingMask = UIViewAutoresizingFlexibleWidth;
			[self.tableView addSubview:fadeTop];
			[fadeTop release];
		}
	}
	else
	{
        self.title = serverPlaylist.playlistName;
		playlistCount = [databaseS.localPlaylistsDb intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM splaylist%@", md5]];
		[self.tableView reloadData];
		
		// Add the pull to refresh view
		refreshHeaderView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, 320.0f, self.tableView.bounds.size.height)];
		refreshHeaderView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:237.0/255.0 alpha:1.0];
		[self.tableView addSubview:refreshHeaderView];
		[refreshHeaderView release];
	}
	

	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
	
	// Add the table fade
	UIImageView *fadeBottom = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]] autorelease];
	fadeBottom.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
	fadeBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.tableView.tableFooterView = fadeBottom;
}

-(void)loadData
{
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(serverPlaylist.playlistId) forKey:@"id"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getPlaylist" andParameters:parameters];
	
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		// Create the NSMutableData to hold the received data.
		// receivedData is an instance variable declared elsewhere.
		self.receivedData = [NSMutableData data];
		
		self.tableView.scrollEnabled = NO;
		[viewObjectsS showAlbumLoadingScreen:self.view sender:self];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error grabbing the playlist.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
		[alert release];
	}
}	

- (void)cancelLoad
{
	[self.connection cancel];
	self.connection = nil;
	self.receivedData = nil;
	self.tableView.scrollEnabled = YES;
	[viewObjectsS hideLoadingScreen];
	
	if (!viewObjectsS.isLocalPlaylist)
	{
		[self dataSourceDidFinishLoadingNewData];
	}
}

- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
	
	if(musicS.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	if (viewObjectsS.isLocalPlaylist)
	{
		//appDelegate.listOfPlaylistSongs = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@%@List", appDelegateS.defaultUrl, appDelegateS.localPlaylist]]];
		//appDelegate.dictOfPlaylistSongs = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@%@Dict", appDelegateS.defaultUrl, appDelegateS.localPlaylist]]];
	}
	else
	{
		if (playlistCount == 0)
		{
			[self loadData];
		}
	}
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
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

- (void)uploadPlaylistAction:(id)sender
{	
	NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(self.title), @"name", nil];
    
	NSString *query = [NSString stringWithFormat:@"SELECT COUNT(*) FROM playlist%@", self.md5];
	NSUInteger count = [databaseS.localPlaylistsDb intForQuery:query];
	NSMutableArray *songIds = [NSMutableArray arrayWithCapacity:count];
	for (int i = 1; i <= count; i++)
	{
		@autoreleasepool 
		{
			NSString *query = [NSString stringWithFormat:@"SELECT songId FROM playlist%@ WHERE ROWID = %i", self.md5, i];
			NSString *songId = [databaseS.localPlaylistsDb stringForQuery:query];
			
			[songIds addObject:n2N(songId)];
		}
	}
	[parameters setObject:[NSArray arrayWithArray:songIds] forKey:@"songId"];
	
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"createPlaylist" andParameters:parameters];
	
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		// Create the NSMutableData to hold the received data.
		// receivedData is an instance variable declared elsewhere.
		self.receivedData = [NSMutableData data];
		
		self.tableView.scrollEnabled = NO;
		[viewObjectsS showAlbumLoadingScreen:self.view sender:self];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error saving the playlist to the server.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
		[alert release];
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
	[self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [self.receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	NSString *message = @"";
	if (viewObjectsS.isLocalPlaylist)
	{
		message = [NSString stringWithFormat:@"There was an error saving the playlist to the server.\n\nError %i: %@", 
											 [error code], 
											 [error localizedDescription]];
	}
	else
	{
		message = [NSString stringWithFormat:@"There was an error loading the playlist.\n\nError %i: %@", 
				   [error code], 
				   [error localizedDescription]];
	}
	
	// Inform the user that the connection failed.
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	[alert release];
	
	self.tableView.scrollEnabled = YES;
	[viewObjectsS hideLoadingScreen];
	
	self.connection = nil;
	self.receivedData = nil;
	
	[self dataSourceDidFinishLoadingNewData];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	if (!viewObjectsS.isLocalPlaylist)
	{
        // Parse the data
        //
        TBXML *tbxml = [[TBXML alloc] initWithXMLData:self.receivedData];
        TBXMLElement *root = tbxml.rootXMLElement;
        if (root) 
        {
            TBXMLElement *error = [TBXML childElementNamed:@"error" parentElement:root];
            if (error)
            {
                // TODO: handle error
            }
            else
            {
                TBXMLElement *playlist = [TBXML childElementNamed:@"playlist" parentElement:root];
                if (playlist)
                {
                    [databaseS removeServerPlaylistTable:self.md5];
                    [databaseS createServerPlaylistTable:self.md5];
                    
                    TBXMLElement *entry = [TBXML childElementNamed:@"entry" parentElement:playlist];
                    while (entry != nil)
                    {
                        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
                        
                        Song *aSong = [[Song alloc] initWithTBXMLElement:entry];
                        [aSong insertIntoServerPlaylistWithPlaylistId:self.md5];
                        [aSong release];
                        
                        // Get the next message
                        entry = [TBXML nextSiblingNamed:@"entry" searchFromElement:entry];
                        
                        [pool release];
                    }
                }
            }
        }
		[tbxml release];
		
		self.tableView.scrollEnabled = YES;

		self.playlistCount = [databaseS.localPlaylistsDb intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM splaylist%@", self.md5]];
		[self.tableView reloadData];
		
		[self dataSourceDidFinishLoadingNewData];
		
		[viewObjectsS hideLoadingScreen];
	}
	else
	{
		[self parseData];
	}
	
	self.tableView.scrollEnabled = YES;
	self.receivedData = nil;
	self.connection = nil;
}

static NSString *kName_Error = @"error";

- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil];
	alert.tag = 1;
	[alert show];
	[alert release];
	//DLog(@"Subsonic error %@:  %@", errorCode, message);
}

- (void)parseData
{	
	// Parse the data
	//
	TBXML *tbxml = [[TBXML alloc] initWithXMLData:receivedData];
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
	}
    [tbxml release];
		
	[viewObjectsS hideLoadingScreen];
}


#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	if (viewObjectsS.isLocalPlaylist)
	{
		return [databaseS.localPlaylistsDb intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM playlist%@", self.md5]];
	}
	else
	{
		return playlistCount;
		//return [viewObjectsS.listOfPlaylistSongs count];
	}
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *cellIdentifier = @"PlaylistSongCell";
	PlaylistSongUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell)
	{
		cell = [[[PlaylistSongUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier] autorelease];
	}
	
	cell.indexPath = indexPath;
	cell.playlistMD5 = self.md5;
	
	// Set up the cell...
	Song *aSong;
	if (viewObjectsS.isLocalPlaylist)
	{
		aSong = [Song songFromDbRow:indexPath.row inTable:[NSString stringWithFormat:@"playlist%@", self.md5] inDatabase:databaseS.localPlaylistsDb];
		//DLog(@"aSong: %@", aSong);
	}
	else
	{
		//aSong = [viewObjectsS.listOfPlaylistSongs objectAtIndexSafe:indexPath.row];
		aSong = [Song songFromServerPlaylistId:md5 row:indexPath.row];
	}
	
	cell.coverArtView.coverArtId = aSong.coverArtId;
	
	cell.backgroundView = [[[UIView alloc] init] autorelease];
	if(indexPath.row % 2 == 0)
	{
		if ([databaseS.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ? and finished = 'YES'", [aSong.path md5]] != nil)
			cell.backgroundView.backgroundColor = [viewObjectsS currentLightColor];
		else
			cell.backgroundView.backgroundColor = viewObjectsS.lightNormal;
	}
	else
	{
		if ([databaseS.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ? and finished = 'YES'", [aSong.path md5]] != nil)
			cell.backgroundView.backgroundColor = [viewObjectsS currentDarkColor];
		else
			cell.backgroundView.backgroundColor = viewObjectsS.darkNormal;
	}
	
	[cell.numberLabel setText:[NSString stringWithFormat:@"%i", (indexPath.row + 1)]];
	[cell.songNameLabel setText:aSong.title];
	if (aSong.album)
		[cell.artistNameLabel setText:[NSString stringWithFormat:@"%@ - %@", aSong.artist, aSong.album]];
	else
		[cell.artistNameLabel setText:aSong.artist];
	
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath)
		return;
	
	if (viewObjectsS.isCellEnabled)
	{		
		// Clear the current playlist
		if (settingsS.isJukeboxEnabled)
			[databaseS resetJukeboxPlaylist];
		else
			[databaseS resetCurrentPlaylistDb];
		
		if (viewObjectsS.isLocalPlaylist)
		{			
			[databaseS.localPlaylistsDb executeUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseS.databaseFolderPath, [settingsS.urlString md5]], @"currentPlaylistDb"];
			if ([databaseS.localPlaylistsDb hadError]) { DLog(@"Err attaching the localPlaylistsDb %d: %@", [databaseS.localPlaylistsDb lastErrorCode], [databaseS.localPlaylistsDb lastErrorMessage]); }
			if (settingsS.isJukeboxEnabled)
				[databaseS.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO jukeboxCurrentPlaylist SELECT * FROM playlist%@", self.md5]];
			else
				[databaseS.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO currentPlaylist SELECT * FROM playlist%@", self.md5]];
			[databaseS.localPlaylistsDb executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
		}
		else
		{
			[databaseS.localPlaylistsDb executeUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseS.databaseFolderPath, [settingsS.urlString md5]], @"currentPlaylistDb"];
			if ([databaseS.localPlaylistsDb hadError]) { DLog(@"Err attaching the localPlaylistsDb %d: %@", [databaseS.localPlaylistsDb lastErrorCode], [databaseS.localPlaylistsDb lastErrorMessage]); }
			if (settingsS.isJukeboxEnabled)
				[databaseS.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO jukeboxCurrentPlaylist SELECT * FROM splaylist%@", self.md5]];
			else
				[databaseS.localPlaylistsDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO currentPlaylist SELECT * FROM splaylist%@", self.md5]];
			[databaseS.localPlaylistsDb executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
		}
		
		if (settingsS.isJukeboxEnabled)
		{
			[jukeboxS jukeboxReplacePlaylistWithLocal];
		}
			
		playlistS.isShuffle = NO;
		
		[musicS playSongAtPosition:indexPath.row];
		
		[self showPlayer];
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}


- (void)dealloc 
{
    [serverPlaylist release]; serverPlaylist = nil;
    [super dealloc];
}


#pragma mark -
#pragma mark Pull to refresh methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{	
	if (scrollView.isDragging && !viewObjectsS.isLocalPlaylist) 
	{
		if (refreshHeaderView.state == EGOOPullRefreshPulling && scrollView.contentOffset.y > -65.0f && scrollView.contentOffset.y < 0.0f && !_reloading) 
		{
			[refreshHeaderView setState:EGOOPullRefreshNormal];
		} 
		else if (refreshHeaderView.state == EGOOPullRefreshNormal && scrollView.contentOffset.y < -65.0f && !_reloading) 
		{
			[refreshHeaderView setState:EGOOPullRefreshPulling];
		}
	}
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	
	if (scrollView.contentOffset.y <= - 65.0f && !_reloading && !viewObjectsS.isLocalPlaylist) 
	{
		_reloading = YES;
		//[self reloadAction:nil];
		[self loadData];
		[refreshHeaderView setState:EGOOPullRefreshLoading];
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.2];
		self.tableView.contentInset = UIEdgeInsetsMake(60.0f, 0.0f, 0.0f, 0.0f);
		[UIView commitAnimations];
	}
}

- (void)dataSourceDidFinishLoadingNewData
{
	_reloading = NO;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	[self.tableView setContentInset:UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f)];
	[UIView commitAnimations];
	
	[refreshHeaderView setState:EGOOPullRefreshNormal];
}



@end

