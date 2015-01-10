//
//  PlaylistSongsViewController.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "PlaylistSongsViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"
#import "iSub-Swift.h"

@interface PlaylistSongsViewController() <CustomUITableViewCellDelegate>
{
    BOOL _reloading;
    NSUInteger _playlistCount;
    
    NSURLConnection *_connection;
    NSMutableData *_receivedData;
}
@end


@implementation PlaylistSongsViewController

#pragma mark - Lifecycle -

- (void)viewDidLoad 
{
    [super viewDidLoad];

    if (_localPlaylist)
	{
		self.title = [databaseS.localPlaylistsDbQueue stringForQuery:@"SELECT playlist FROM localPlaylists WHERE md5 = ?", _md5];
		
		if (!settingsS.isOfflineMode)
		{
			UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
			headerView.backgroundColor = viewObjectsS.darkNormal;
			
			UIImageView *sendImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"upload-playlist"]];
			sendImage.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
			sendImage.frame = CGRectMake(23, 11, 24, 24);
			[headerView addSubview:sendImage];
			
			UILabel *sendLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 320, 50)];
			sendLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
			sendLabel.backgroundColor = [UIColor clearColor];
			sendLabel.textColor = ISMSHeaderTextColor;
			sendLabel.textAlignment = NSTextAlignmentCenter;
			sendLabel.font = ISMSBoldFont(30);
			sendLabel.text = @"Save to Server";
			[headerView addSubview:sendLabel];
			
			UIButton *sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
			sendButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
			sendButton.frame = CGRectMake(0, 0, 320, 40);
			[sendButton addTarget:self action:@selector(a_uploadPlaylist:) forControlEvents:UIControlEventTouchUpInside];
			[headerView addSubview:sendButton];
			
			self.tableView.tableHeaderView = headerView;
		}
		
		if (!IS_IPAD())
		{
			if (!self.tableView.tableHeaderView) self.tableView.tableHeaderView = [[UIView alloc] init];
		}
	}
	else
	{
        self.title = _serverPlaylist.playlistName;
        NSString *query = [NSString stringWithFormat:@"SELECT COUNT(*) FROM splaylist%@", _md5];
		_playlistCount = [databaseS.localPlaylistsDbQueue intForQuery:query];
		[self.tableView reloadData];
	}	
}

- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
	
	if (_localPlaylist)
	{
        NSString *query = [NSString stringWithFormat:@"SELECT COUNT(*) FROM playlist%@", _md5];
		_playlistCount = [databaseS.localPlaylistsDbQueue intForQuery:query];
		[self.tableView reloadData];
	}
	else
	{
		if (_playlistCount == 0)
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

#pragma mark - Loading -

- (void)loadData
{
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(_serverPlaylist.playlistId) forKey:@"id"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getPlaylist" parameters:parameters];
    
    _connection = [NSURLConnection connectionWithRequest:request delegate:self];
    if (_connection)
    {
        _receivedData = [NSMutableData data];
        
        self.tableView.scrollEnabled = NO;
        [viewObjectsS showAlbumLoadingScreen:self.view sender:self];
    }
    else
    {
        CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error"
                                                                    message:@"There was an error grabbing the playlist.\n\nCould not create the network request."
                                                                   delegate:nil
                                                          cancelButtonTitle:@"OK"
                                                          otherButtonTitles:nil];
        [alert show];
    }
}

- (void)cancelLoad
{
    [_connection cancel];
    _connection = nil;
    _receivedData = nil;
    self.tableView.scrollEnabled = YES;
    [viewObjectsS hideLoadingScreen];
    
    if (!_localPlaylist)
    {
        [self dataSourceDidFinishLoadingNewData];
    }
}

#pragma mark - Pull to Refresh -

- (BOOL)shouldSetupRefreshControl
{
    return !_localPlaylist;
}

- (void)didPullToRefresh
{
    if (!_reloading)
    {
        _reloading = YES;
        [self loadData];
    }
}

- (void)dataSourceDidFinishLoadingNewData
{
    _reloading = NO;
    
    [self.refreshControl endRefreshing];
}

#pragma mark - Actions -

- (void)a_uploadPlaylist:(id)sender
{	
    NSMutableDictionary *parameters = [@{ @"name" : n2N(self.title) } mutableCopy];
    
	NSString *query = [NSString stringWithFormat:@"SELECT COUNT(*) FROM playlist%@", _md5];
	NSUInteger count = [databaseS.localPlaylistsDbQueue intForQuery:query];
	NSMutableArray *songIds = [NSMutableArray arrayWithCapacity:count];
	for (int i = 1; i <= count; i++)
	{
		@autoreleasepool 
		{
			NSString *query = [NSString stringWithFormat:@"SELECT songId FROM playlist%@ WHERE ROWID = %i", _md5, i];
			NSString *songId = [databaseS.localPlaylistsDbQueue stringForQuery:query];
			
            if (songId.hasValue)
                [songIds addObject:songId];
		}
	}
	[parameters setObject:songIds forKey:@"songId"];
	
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"createPlaylist" parameters:parameters];
	
	_connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (_connection)
	{
		_receivedData = [NSMutableData data];
		
		self.tableView.scrollEnabled = NO;
		[viewObjectsS showAlbumLoadingScreen:self.view sender:self];
	} 
	else 
    {
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error"
                                                                    message:@"There was an error saving the playlist to the server.\n\nCould not create the network request."
                                                                   delegate:nil
                                                          cancelButtonTitle:@"OK"
                                                          otherButtonTitles:nil];
		[alert show];
	}
}

#pragma mark - Connection Delegate -

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
	[_receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [_receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	NSString *message = @"";
	if (_localPlaylist)
	{
		message = [NSString stringWithFormat:@"There was an error saving the playlist to the server.\n\nError %li: %@", 
											 (long)[error code],
											 [error localizedDescription]];
	}
	else
	{
		message = [NSString stringWithFormat:@"There was an error loading the playlist.\n\nError %li: %@",
				   (long)[error code],
				   [error localizedDescription]];
	}
	
	// Inform the user that the connection failed.
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error"
                                                                message:message
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
	[alert show];
	
	self.tableView.scrollEnabled = YES;
	[viewObjectsS hideLoadingScreen];
	
	_connection = nil;
	_receivedData = nil;
	
	[self dataSourceDidFinishLoadingNewData];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	if (!_localPlaylist)
	{
        // Parse the data
        //
        RXMLElement *root = [[RXMLElement alloc] initFromXMLData:_receivedData];
        if (![root isValid])
        {
            //NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
            // TODO: Handle this error
        }
        else
        {
            RXMLElement *error = [root child:@"error"];
            if ([error isValid])
            {
                //NSString *code = [error attribute:@"code"];
                //NSString *message = [error attribute:@"message"];
                //[self subsonicErrorCode:[code intValue] message:message];
                // TODO: Handle this error
            }
            else
            {
                // TODO: Handle !isValid case
                if ([[root child:@"playlist"] isValid])
                {
                    [databaseS removeServerPlaylistTable:_md5];
                    [databaseS createServerPlaylistTable:_md5];
                    [root iterate:@"playlist.entry" usingBlock:^(RXMLElement *e) {
                        ISMSSong *aSong = [[ISMSSong alloc] initWithRXMLElement:e];
                        [aSong insertIntoServerPlaylistWithPlaylistId:_md5];
                    }];
                }
            }
        }
		
		self.tableView.scrollEnabled = YES;

		_playlistCount = [databaseS.localPlaylistsDbQueue intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM splaylist%@", _md5]];
		[self.tableView reloadData];
		
		[self dataSourceDidFinishLoadingNewData];
		
		[viewObjectsS hideLoadingScreen];
	}
	else
	{
		[self _parseData];
	}
	
	self.tableView.scrollEnabled = YES;
	_receivedData = nil;
	_connection = nil;
}

static NSString *kName_Error = @"error";

- (void)_subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Subsonic Error"
                                                                message:message
                                                               delegate:nil
                                                      cancelButtonTitle:@"Ok"
                                                      otherButtonTitles: nil];
	alert.tag = 1;
	[alert show];
}

- (void)_parseData
{
    // Parse the data
    //
    RXMLElement *root = [[RXMLElement alloc] initFromXMLData:_receivedData];
    if (![root isValid])
    {
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
        [self _subsonicErrorCode:nil message:error.description];
    }
    else
    {
        RXMLElement *error = [root child:@"error"];
        if ([error isValid])
        {
            NSString *code = [error attribute:@"code"];
            NSString *message = [error attribute:@"message"];
            [self _subsonicErrorCode:code message:message];
        }
    }
		
	[viewObjectsS hideLoadingScreen];
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return _playlistCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *cellIdentifier = @"PlaylistSongCell";
	CustomUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell)
	{
		cell = [[CustomUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.alwaysShowCoverArt = YES;
        cell.delegate = self;
	}
	
	cell.indexPath = indexPath;
	
	// Set up the cell...
	ISMSSong *aSong;
	if (_localPlaylist)
	{
		aSong = [ISMSSong songFromDbRow:indexPath.row inTable:[NSString stringWithFormat:@"playlist%@", _md5] inDatabaseQueue:databaseS.localPlaylistsDbQueue];
	}
	else
	{
		aSong = [ISMSSong songFromServerPlaylistId:_md5 row:indexPath.row];
	}
	cell.associatedObject = aSong;
	
	cell.coverArtId = aSong.coverArtId;
	
    if (aSong.isFullyCached)
    {
        cell.backgroundView = [[UIView alloc] init];
        cell.backgroundView.backgroundColor = [viewObjectsS currentLightColor];
    }
    else
    {
        cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
    }
    
	//[cell.numberLabel setText:[NSString stringWithFormat:@"%li", (long)(indexPath.row + 1)]];
    cell.title = aSong.title;
    cell.subTitle = aSong.albumName ? [NSString stringWithFormat:@"%@ - %@", aSong.artistName, aSong.albumName] : aSong.artistName;
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath)
		return;
	
	if (viewObjectsS.isCellEnabled)
	{
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
		[self performSelector:@selector(_didSelectRowInternal:) withObject:indexPath afterDelay:0.05];
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

- (void)_didSelectRowInternal:(NSIndexPath *)indexPath
{
    // Clear the current playlist
    if (settingsS.isJukeboxEnabled)
    {
        [databaseS resetJukeboxPlaylist];
        [jukeboxS jukeboxClearRemotePlaylist];
    }
    else
    {
        [databaseS resetCurrentPlaylistDb];
    }
    
    playlistS.isShuffle = NO;
    
    // Need to do this for speed
    NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", [settingsS.urlString md5]];
    NSString *currTableName = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
    NSString *playTableName = [NSString stringWithFormat:@"%@%@", _localPlaylist ? @"playlist" : @"splaylist", _md5];
    [databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
     {
         [db executeUpdate:@"ATTACH DATABASE ? AS ?", [databaseS.databaseFolderPath stringByAppendingPathComponent:databaseName], @"currentPlaylistDb"];
         if ([db hadError]) { DLog(@"Err attaching the currentPlaylistDb %d: %@", [db lastErrorCode], [db lastErrorMessage]); }
         
         [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ SELECT * FROM %@", currTableName, playTableName]];
         [db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
     }];
    
    if (settingsS.isJukeboxEnabled)
        [jukeboxS jukeboxReplacePlaylistWithLocal];
    
    [viewObjectsS hideLoadingScreen];
    
    ISMSSong *playedSong = [musicS playSongAtPosition:indexPath.row];
    if (!playedSong.isVideo)
        [self showPlayer];
}

#pragma mark - CustomUITableViewCell Delegate -

- (void)tableCellDownloadButtonPressed:(CustomUITableViewCell *)cell
{
    ISMSSong *song = cell.associatedObject;
    [song addToCacheQueueDbQueue];
    
    [[cell overlayView] disableDownloadButton];
}

- (void)tableCellQueueButtonPressed:(CustomUITableViewCell *)cell
{
    ISMSSong *song = cell.associatedObject;
    [song addToCurrentPlaylistDbQueue];
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
}

@end

