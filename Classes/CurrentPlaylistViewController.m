//
//  CurrentPlaylistViewController.m
//  iSub
//
//  Created by Ben Baron on 4/9/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CurrentPlaylistViewController.h"
#import "CurrentPlaylistSongSmallUITableViewCell.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "NSString+md5.h"
#import "Song.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueueAdditions.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
#import "NSString+time.h"
#import "PlaylistSingleton.h"
#import "AudioEngine.h"
#import "NSArray+Additions.h"
#import "NSNotificationCenter+MainThread.h"
#import "JukeboxSingleton.h"
#import "StoreViewController.h"
#import "NSMutableURLRequest+SUS.h"

@implementation CurrentPlaylistViewController

@synthesize playlistNameTextField, request, currentPlaylistCount;

#pragma mark -
#pragma mark View lifecycle

- (void)registerForNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_BassInitialized object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_BassFreed object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCurrentPlaylistCount) name:@"updateCurrentPlaylistCount" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(songsQueued) name:ISMSNotification_CurrentPlaylistSongsQueued object:nil];
}

- (void)unregisterForNotifications
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_BassInitialized object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_BassFreed object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"updateCurrentPlaylistCount" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_StorePurchaseComplete object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistSongsQueued object:nil];
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
		
	//NSDate *start = [NSDate date];	
	self.tableView.backgroundColor = [UIColor clearColor];
	
	if (settingsS.isPlaylistUnlocked)
	{
		[self registerForNotifications];
		
		viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		//viewObjectsS.multiDeleteList = nil; viewObjectsS.multiDeleteList = [[NSMutableArray alloc] init];
		
		//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
		//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
		
		if ([databaseS.currentPlaylistDbQueue intForQuery:@"SELECT COUNT(*) FROM currentPlaylist"] > 0)
		{
			[self selectRow];
		}
		
		// Setup header view
		headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
		headerView.backgroundColor = [UIColor colorWithWhite:.3 alpha:1];
		
		savePlaylistLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 227, 34)];
		savePlaylistLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		savePlaylistLabel.backgroundColor = [UIColor clearColor];
		savePlaylistLabel.textColor = [UIColor whiteColor];
		savePlaylistLabel.textAlignment = UITextAlignmentCenter;
		savePlaylistLabel.font = [UIFont boldSystemFontOfSize:22];
		savePlaylistLabel.text = @"Save Playlist";
		[headerView addSubview:savePlaylistLabel];
		
		playlistCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 33, 227, 14)];
		playlistCountLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		playlistCountLabel.backgroundColor = [UIColor clearColor];
		playlistCountLabel.textColor = [UIColor whiteColor];
		playlistCountLabel.textAlignment = UITextAlignmentCenter;
		playlistCountLabel.font = [UIFont boldSystemFontOfSize:12];
		[headerView addSubview:playlistCountLabel];
		
		[self updateCurrentPlaylistCount];
		
		savePlaylistButton = [UIButton buttonWithType:UIButtonTypeCustom];
		savePlaylistButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		savePlaylistButton.frame = CGRectMake(0, 0, 240, 40);
		[savePlaylistButton addTarget:self action:@selector(savePlaylistAction:) forControlEvents:UIControlEventTouchUpInside];
		[headerView addSubview:savePlaylistButton];
		
		UILabel *spacerLabel = [[UILabel alloc] initWithFrame:CGRectMake(236, -2.5, 6, 50)];
		spacerLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		//spacerLabel.textAlignment = UITextAlignmentCenter;
		spacerLabel.backgroundColor = [UIColor clearColor];
		spacerLabel.textColor = [UIColor whiteColor];
		spacerLabel.font = [UIFont systemFontOfSize:40];
		spacerLabel.text = @"|";
		[headerView addSubview:spacerLabel];
		
		editPlaylistLabel = [[UILabel alloc] initWithFrame:CGRectMake(244, 0, 76, 50)];
		editPlaylistLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
		editPlaylistLabel.backgroundColor = [UIColor clearColor];
		editPlaylistLabel.textColor = [UIColor whiteColor];
		editPlaylistLabel.textAlignment = UITextAlignmentCenter;
		editPlaylistLabel.font = [UIFont boldSystemFontOfSize:22];
		editPlaylistLabel.text = @"Edit";
		[headerView addSubview:editPlaylistLabel];
		
		UIButton *editPlaylistButton = [UIButton buttonWithType:UIButtonTypeCustom];
		editPlaylistButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
		editPlaylistButton.frame = CGRectMake(244, 0, 76, 40);
		[editPlaylistButton addTarget:self action:@selector(editPlaylistAction:) forControlEvents:UIControlEventTouchUpInside];
		[headerView addSubview:editPlaylistButton];
		
		deleteSongsLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 237, 50)];
		deleteSongsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		deleteSongsLabel.backgroundColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:.5];
		deleteSongsLabel.textColor = [UIColor whiteColor];
		deleteSongsLabel.textAlignment = UITextAlignmentCenter;
		deleteSongsLabel.font = [UIFont boldSystemFontOfSize:22];
		deleteSongsLabel.adjustsFontSizeToFitWidth = YES;
		deleteSongsLabel.minimumFontSize = 12;
		deleteSongsLabel.text = @"Remove # Songs";
		deleteSongsLabel.hidden = YES;
		[headerView addSubview:deleteSongsLabel];
		
		self.tableView.tableHeaderView = headerView;
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hideEditControls) name:@"hideEditControls" object:nil];
	}
	else
	{
		self.tableView.separatorColor = [UIColor clearColor];
		
		UIImageView *noPlaylistsScreen = [[UIImageView alloc] init];
		noPlaylistsScreen.userInteractionEnabled = YES;
		noPlaylistsScreen.frame = CGRectMake(40, 80, 240, 180);
		noPlaylistsScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
		
		UILabel *textLabel = [[UILabel alloc] init];
		textLabel.backgroundColor = [UIColor clearColor];
		textLabel.textColor = [UIColor whiteColor];
		textLabel.font = [UIFont boldSystemFontOfSize:32];
		textLabel.textAlignment = UITextAlignmentCenter;
		textLabel.numberOfLines = 0;
		textLabel.text = @"Playlists\nLocked";
		textLabel.frame = CGRectMake(20, 0, 200, 100);
		[noPlaylistsScreen addSubview:textLabel];
		
		UILabel *textLabel2 = [[UILabel alloc] init];
		textLabel2.backgroundColor = [UIColor clearColor];
		textLabel2.textColor = [UIColor whiteColor];
		textLabel2.font = [UIFont boldSystemFontOfSize:14];
		textLabel2.textAlignment = UITextAlignmentCenter;
		textLabel2.numberOfLines = 0;
		textLabel2.text = @"Tap to purchase the ability to view, create, and manage playlists";
		textLabel2.frame = CGRectMake(20, 100, 200, 60);
		[noPlaylistsScreen addSubview:textLabel2];
		
		UIButton *storeLauncher = [UIButton buttonWithType:UIButtonTypeCustom];
		storeLauncher.frame = CGRectMake(0, 0, noPlaylistsScreen.frame.size.width, noPlaylistsScreen.frame.size.height);
		[storeLauncher addTarget:self action:@selector(showStore) forControlEvents:UIControlEventTouchUpInside];
		[noPlaylistsScreen addSubview:storeLauncher];
		
		[self.view addSubview:noPlaylistsScreen];
		
	}
	//DLog(@"end: %f", [[NSDate date] timeIntervalSinceDate:start]);
	
	[self.tableView reloadData];
}

- (void)showStore
{
	[NSNotificationCenter postNotificationToMainThreadWithName:@"player show store"];
}

- (void)viewWillAppear:(BOOL)animated 
{
	[super viewWillAppear:animated];
	
	[self selectRow];
}

- (void)viewWillDisappear:(BOOL)animated 
{
    [super viewWillDisappear:animated];
	
	[self unregisterForNotifications];
	//[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	//[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	
	if (self.tableView.editing)
	{
		// Clear the edit stuff if they switch tabs in the middle of editing
		viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		self.tableView.editing = NO;
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"showDeleteButton" object:nil];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideDeleteButton" object:nil];
	}
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideEditControls" object:nil];
	
	 headerView = nil;
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}



#pragma mark -

- (void)songsQueued
{
	[self updateCurrentPlaylistCount];
	[self.tableView reloadData];
}

- (void)updateCurrentPlaylistCount
{
	self.currentPlaylistCount = [playlistS count];
		
	if (self.currentPlaylistCount == 1)
		playlistCountLabel.text = [NSString stringWithFormat:@"1 song"];
	else 
		playlistCountLabel.text = [NSString stringWithFormat:@"%i songs", currentPlaylistCount];
}

- (void)editPlaylistAction:(id)sender
{
	if (!self.tableView.editing)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(showDeleteButton) name:@"showDeleteButton" object: nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(hideDeleteButton) name:@"hideDeleteButton" object: nil];
		viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		[self.tableView setEditing:YES animated:YES];
		editPlaylistLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
		editPlaylistLabel.text = @"Done";
		[self showDeleteButton];
		
		// Hide the duration labels and shorten the song and artist labels
		for (CurrentPlaylistSongSmallUITableViewCell *cell in [self.tableView visibleCells])
		{
			cell.durationLabel.hidden = YES;
		}
		
		[NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(showDeleteToggle) userInfo:nil repeats:NO];
	}
	else 
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"showDeleteButton" object:nil];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideDeleteButton" object:nil];
		viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		[self.tableView setEditing:NO animated:YES];
		[self hideDeleteButton];
		editPlaylistLabel.backgroundColor = [UIColor clearColor];
		editPlaylistLabel.text = @"Edit";
		
		// Reload the table to correct the numbers
		[self.tableView reloadData];

		if (playlistS.currentIndex >= 0 && playlistS.currentIndex < currentPlaylistCount)
		{
			[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:playlistS.currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
		}
	}
}

- (void) hideEditControls
{
	if (self.tableView.editing == YES)
		[self editPlaylistAction:nil];
}

- (void) showDeleteButton
{
	if ([viewObjectsS.multiDeleteList count] == 0)
	{
		deleteSongsLabel.text = @"Clear Playlist";
	}
	else if ([viewObjectsS.multiDeleteList count] == 1)
	{
		deleteSongsLabel.text = @"Remove 1 Song  ";
	}
	else
	{
		deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %i Songs", [viewObjectsS.multiDeleteList count]];
	}
	
	savePlaylistLabel.hidden = YES;
	playlistCountLabel.hidden = YES;
	deleteSongsLabel.hidden = NO;
}

- (void) hideDeleteButton
{
	if ([viewObjectsS.multiDeleteList count] == 0)
	{
		if (!self.tableView.editing)
		{
			savePlaylistLabel.hidden = NO;
			playlistCountLabel.hidden = NO;
			deleteSongsLabel.hidden = YES;
		}
		else
		{
			deleteSongsLabel.text = @"Clear Playlist";
		}
	}
	else if ([viewObjectsS.multiDeleteList count] == 1)
	{
		deleteSongsLabel.text = @"Remove 1 Song  ";
	}
	else 
	{
		deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %i Songs", [viewObjectsS.multiDeleteList count]];
	}
}

- (void) showDeleteToggle
{
	// Show the delete toggle for already visible cells
	for (id cell in self.tableView.visibleCells) 
	{
		[[cell deleteToggleImage] setHidden:NO];
	}
}

- (void)savePlaylistAction:(id)sender
{
	if (deleteSongsLabel.hidden == YES)
	{
		if (!self.tableView.editing)
		{
			UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Local or Server?" 
																  message:@"Would you like to save this playlist to your device or to your Subsonic server?" 
																 delegate:self 
														cancelButtonTitle:nil
														otherButtonTitles:@"Local", @"Server", nil];
			[myAlertView show];
		}
	}
	else 
	{
		[self unregisterForNotifications];
		
		if ([deleteSongsLabel.text isEqualToString:@"Clear Playlist"])
		{
			if (settingsS.isJukeboxEnabled)
			{
				[databaseS resetJukeboxPlaylist];
				[jukeboxS jukeboxClearPlaylist];
			}
			else
			{
                [audioEngineS stop];
				[databaseS resetCurrentPlaylistDb];
			}
			
			[self editPlaylistAction:nil];
		}
		else
		{
			//
			// Delete action
			//
			
			[playlistS deleteSongs:viewObjectsS.multiDeleteList];
						
			// Create indexPaths from multiDeleteList and delete the rows in the table view
			NSMutableArray *indexes = [[NSMutableArray alloc] init];
			for (NSNumber *index in viewObjectsS.multiDeleteList)
			{
				@autoreleasepool 
				{
					[indexes addObject:[NSIndexPath indexPathForRow:[index integerValue] inSection:0]];
				}
			}
			
			@try
			{
				[self.tableView deleteRowsAtIndexPaths:indexes withRowAnimation:NO];
			}
			@catch (NSException *exception) 
			{
				DLog(@"Exception: %@ - %@", exception.name, exception.reason);
			}
		
			
			[self editPlaylistAction:nil];
		}
		
		// Fix the playlist count
		NSUInteger songCount = playlistS.count;
		if (songCount == 1)
			playlistCountLabel.text = [NSString stringWithFormat:@"1 song"];
		else
			playlistCountLabel.text = [NSString stringWithFormat:@"%i songs", songCount];
		
		if (!settingsS.isJukeboxEnabled)
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistOrderChanged];
		
		[self registerForNotifications];
	}
}

- (void)uploadPlaylist:(NSString*)name
{	
	NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(name), @"name", nil];
	
	NSMutableArray *songIds = [NSMutableArray arrayWithCapacity:currentPlaylistCount];
	for (int i = 0; i < currentPlaylistCount; i++)
	{
		@autoreleasepool 
		{
			Song *aSong = nil;
			if (settingsS.isJukeboxEnabled)
			{
				aSong = [Song songFromDbRow:i inTable:@"jukeboxCurrentPlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue];
			}
			else
			{
				if (playlistS.isShuffle)
					aSong = [Song songFromDbRow:i inTable:@"shufflePlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue];
				else
					aSong = [Song songFromDbRow:i inTable:@"currentPlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue];
			}
			
			[songIds addObject:n2N(aSong.songId)];
		}
	}
	[parameters setObject:[NSArray arrayWithArray:songIds] forKey:@"songId"];
	
	self.request = [NSMutableURLRequest requestWithSUSAction:@"createPlaylist" andParameters:parameters];
	
	connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
		receivedData = [NSMutableData data];
		
		self.tableView.scrollEnabled = NO;
		[viewObjectsS showAlbumLoadingScreen:self.view sender:self];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error saving the playlist to the server.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
	}
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ([alertView.title isEqualToString:@"Local or Server?"])
	{
		if (buttonIndex == 0)
		{
			savePlaylistLocal = YES;
		}
		else if (buttonIndex == 1)
		{
			savePlaylistLocal = NO;
		}
		else if (buttonIndex == 2)
		{
			return;
		}
		
		UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Playlist Name:" message:@"      \n      " delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
		myAlertView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
		self.playlistNameTextField = [[UITextField alloc] initWithFrame:CGRectMake(12.0, 47.0, 260.0, 24.0)];
		playlistNameTextField.layer.cornerRadius = 3.;
		[playlistNameTextField setBackgroundColor:[UIColor whiteColor]];
		[myAlertView addSubview:playlistNameTextField];
		if ([[[[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."] objectAtIndexSafe:0] isEqualToString:@"3"])
		{
			CGAffineTransform myTransform = CGAffineTransformMakeTranslation(0.0, 100.0);
			[myAlertView setTransform:myTransform];
		}
		[myAlertView show];
		[playlistNameTextField becomeFirstResponder];
	}
    else if([alertView.title isEqualToString:@"Playlist Name:"])
	{
		[playlistNameTextField resignFirstResponder];
		if(buttonIndex == 1)
		{
			if (savePlaylistLocal)
			{
				// Check if the playlist exists, if not create the playlist table and add the entry to localPlaylists table
				NSString *test = [databaseS.localPlaylistsDbQueue stringForQuery:@"SELECT md5 FROM localPlaylists WHERE md5 = ?", [playlistNameTextField.text md5]];
				if (!test)
				{
					[databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
					{
						[db executeUpdate:@"INSERT INTO localPlaylists (playlist, md5) VALUES (?, ?)", playlistNameTextField.text, [playlistNameTextField.text md5]];
						[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (%@)", [playlistNameTextField.text md5], [Song standardSongColumnSchema]]];
						
						[db executeUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseS.databaseFolderPath, [settingsS.urlString md5]], @"currentPlaylistDb"];
						if ([db hadError]) { DLog(@"Err attaching the currentPlaylistDb %d: %@", [db lastErrorCode], [db lastErrorMessage]); }
						if (playlistS.isShuffle)
							[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM shufflePlaylist", [playlistNameTextField.text md5]]];
						else
							[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM currentPlaylist", [playlistNameTextField.text md5]]];
						[db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
					}];
				}
				else
				{
					// If it exists, ask to overwrite
					UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Overwrite?" message:@"There is already a playlist with this name. Would you like to overwrite it?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
					[myAlertView show];
				}
			}
			else
			{
				NSString *tableName = [NSString stringWithFormat:@"splaylist%@", [playlistNameTextField.text md5]];
				if ([databaseS.localPlaylistsDbQueue tableExists:tableName])
				{
					// If it exists, ask to overwrite
					UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Overwrite?" message:@"There is already a playlist with this name. Would you like to overwrite it?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
					[myAlertView show];
				}
				else 
				{
					[self uploadPlaylist:playlistNameTextField.text];
				}
			}
		}
	}
	else if([alertView.title isEqualToString:@"Overwrite?"])
	{
		if(buttonIndex == 1)
		{
			// If yes, overwrite the playlist
			if (savePlaylistLocal)
			{
				[databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
				{
					[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE playlist%@", [playlistNameTextField.text md5]]];
					[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (%@)", [playlistNameTextField.text md5], [Song standardSongColumnSchema]]];
					
					[db executeUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseS.databaseFolderPath, [settingsS.urlString md5]], @"currentPlaylistDb"];
					if ([db hadError]) { DLog(@"Err attaching the currentPlaylistDb %d: %@", [db lastErrorCode], [db lastErrorMessage]); }
					if (playlistS.isShuffle)
						[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM shufflePlaylist", [playlistNameTextField.text md5]]];
					else
						[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM currentPlaylist", [playlistNameTextField.text md5]]];
					[db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
				}];
			}
			else
			{
				[databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
				{
					[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE splaylist%@", [playlistNameTextField.text md5]]];
				}];
				
				[self uploadPlaylist:playlistNameTextField.text];
			}
		}
	}
	
	savePlaylistLabel.backgroundColor = [UIColor clearColor];
	playlistCountLabel.backgroundColor = [UIColor clearColor];
}

- (void)selectRow
{
	[self.tableView reloadData];
	if (playlistS.currentIndex >= 0 && playlistS.currentIndex < currentPlaylistCount)
	{
		[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:playlistS.currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
	}
}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
    /*// Return the number of rows in the section.
	if (settingsS.isPlaylistUnlocked)
	{
		if (settingsS.isJukeboxEnabled)
			currentPlaylistCount = [databaseS.currentPlaylistDb intForQuery:@"SELECT COUNT(*) FROM jukeboxCurrentPlaylist"];
		else
			currentPlaylistCount = [databaseS.currentPlaylistDb intForQuery:@"SELECT COUNT(*) FROM currentPlaylist"];
	}
	else
	{
		currentPlaylistCount = 0;
	}*/
	
	return self.currentPlaylistCount;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{	
	static NSString *cellIdentifier = @"CurrentPlaylistSongSmallCell";
    CurrentPlaylistSongSmallUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) 
	{
        cell = [[CurrentPlaylistSongSmallUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
	
    cell.indexPath = indexPath;
	
	cell.deleteToggleImage.hidden = !self.tableView.editing;
	cell.deleteToggleImage.image = [UIImage imageNamed:@"unselected.png"];
	if ([viewObjectsS.multiDeleteList containsObject:[NSNumber numberWithInt:indexPath.row]])
	{
		cell.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
	}
	
	Song *aSong;
	if (settingsS.isJukeboxEnabled)
	{
		aSong = [Song songFromDbRow:indexPath.row inTable:@"jukeboxCurrentPlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue];
	}
	else
	{
		if (playlistS.isShuffle)
			aSong = [Song songFromDbRow:indexPath.row inTable:@"shufflePlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue];
		else
			aSong = [Song songFromDbRow:indexPath.row inTable:@"currentPlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue];
	}
	
	if (indexPath.row == playlistS.currentIndex && !audioEngineS.isBassFreed)
	{
		cell.numberLabel.hidden = YES;
		cell.nowPlayingImageView.hidden = NO;
	}
	else
	{
		cell.numberLabel.hidden = NO;
		cell.nowPlayingImageView.hidden = YES;
		cell.numberLabel.text = [NSString stringWithFormat:@"%i", (indexPath.row + 1)];
	}
	
	cell.songNameLabel.text = aSong.title;

	if (aSong.album)
		cell.artistNameLabel.text = [NSString stringWithFormat:@"%@ - %@", aSong.artist, aSong.album];
	else
		cell.artistNameLabel.text = aSong.artist;

	cell.durationLabel.text = [NSString formatTime:[aSong.duration floatValue]];	
	
	// Hide the duration labels if editing
	if (self.tableView.editing)
	{
		cell.durationLabel.hidden = YES;
	}
	
    return cell;
}



// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}


// Set the editing style, set to none for no delete minus sign (overriding with own custom multi-delete boxes)
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return UITableViewCellEditingStyleNone;
	//return UITableViewCellEditingStyleDelete;
}


// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath 
{
	
	NSInteger fromRow = fromIndexPath.row + 1;
	NSInteger toRow = toIndexPath.row + 1;
	
	[databaseS.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
	{
		if (settingsS.isJukeboxEnabled)
		{
			[db executeUpdate:@"DROP TABLE jukeboxTemp"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxTemp(%@)", [Song standardSongColumnSchema]]];
			
			if (fromRow < toRow)
			{
				[db executeUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID < ?", [NSNumber numberWithInt:fromRow]];
				[db executeUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID > ? AND ROWID <= ?", [NSNumber numberWithInt:fromRow], [NSNumber numberWithInt:toRow]];
				[db executeUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
				[db executeUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID > ?", [NSNumber numberWithInt:toRow]];
				
				[db executeUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
				[db executeUpdate:@"ALTER TABLE jukeboxTemp RENAME TO jukeboxCurrentPlaylist"];
			}
			else
			{
				[db executeUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID < ?", [NSNumber numberWithInt:toRow]];
				[db executeUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
				[db executeUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID >= ? AND ROWID < ?", [NSNumber numberWithInt:toRow], [NSNumber numberWithInt:fromRow]];
				[db executeUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID > ?", [NSNumber numberWithInt:fromRow]];
				
				[db executeUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
				[db executeUpdate:@"ALTER TABLE jukeboxTemp RENAME TO jukeboxCurrentPlaylist"];
			}
		}
		else
		{
			if (playlistS.isShuffle)
			{
				[db executeUpdate:@"DROP TABLE shuffleTemp"];
				[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shuffleTemp(%@)", [Song standardSongColumnSchema]]];
				
				if (fromRow < toRow)
				{
					[db executeUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID < ?", [NSNumber numberWithInt:fromRow]];
					[db executeUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID > ? AND ROWID <= ?", [NSNumber numberWithInt:fromRow], [NSNumber numberWithInt:toRow]];
					[db executeUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
					[db executeUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID > ?", [NSNumber numberWithInt:toRow]];
					
					[db executeUpdate:@"DROP TABLE shufflePlaylist"];
					[db executeUpdate:@"ALTER TABLE shuffleTemp RENAME TO shufflePlaylist"];
				}
				else
				{
					[db executeUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID < ?", [NSNumber numberWithInt:toRow]];
					[db executeUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
					[db executeUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID >= ? AND ROWID < ?", [NSNumber numberWithInt:toRow], [NSNumber numberWithInt:fromRow]];
					[db executeUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist WHERE ROWID > ?", [NSNumber numberWithInt:fromRow]];
					
					[db executeUpdate:@"DROP TABLE shufflePlaylist"];
					[db executeUpdate:@"ALTER TABLE shuffleTemp RENAME TO shufflePlaylist"];
				}
			}
			else
			{
				[db executeUpdate:@"DROP TABLE currentTemp"];
				[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentTemp(%@)", [Song standardSongColumnSchema]]];
				
				if (fromRow < toRow)
				{
					[db executeUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID < ?", [NSNumber numberWithInt:fromRow]];
					[db executeUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID > ? AND ROWID <= ?", [NSNumber numberWithInt:fromRow], [NSNumber numberWithInt:toRow]];
					[db executeUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
					[db executeUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID > ?", [NSNumber numberWithInt:toRow]];
					
					[db executeUpdate:@"DROP TABLE currentPlaylist"];
					[db executeUpdate:@"ALTER TABLE currentTemp RENAME TO currentPlaylist"];
				}
				else
				{
					[db executeUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID < ?", [NSNumber numberWithInt:toRow]];
					[db executeUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
					[db executeUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID >= ? AND ROWID < ?", [NSNumber numberWithInt:toRow], [NSNumber numberWithInt:fromRow]];
					[db executeUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist WHERE ROWID > ?", [NSNumber numberWithInt:fromRow]];
					
					[db executeUpdate:@"DROP TABLE currentPlaylist"];
					[db executeUpdate:@"ALTER TABLE currentTemp RENAME TO currentPlaylist"];
				}
			}	
		}
	}];
		
	// Fix the multiDeleteList to reflect the new row positions
	if ([viewObjectsS.multiDeleteList count] > 0)
	{
		NSMutableArray *tempMultiDeleteList = [[NSMutableArray alloc] init];
		int newPosition;
		for (NSNumber *position in viewObjectsS.multiDeleteList)
		{
			if (fromIndexPath.row > toIndexPath.row)
			{
				if ([position intValue] >= toIndexPath.row && [position intValue] <= fromIndexPath.row)
				{
					if ([position intValue] == fromIndexPath.row)
					{
						[tempMultiDeleteList addObject:[NSNumber numberWithInt:toIndexPath.row]];
					}
					else 
					{
						newPosition = [position intValue] + 1;
						[tempMultiDeleteList addObject:[NSNumber numberWithInt:newPosition]];
					}
				}
				else
				{
					[tempMultiDeleteList addObject:position];
				}
			}
			else
			{
				if ([position intValue] <= toIndexPath.row && [position intValue] >= fromIndexPath.row)
				{
					if ([position intValue] == fromIndexPath.row)
					{
						[tempMultiDeleteList addObject:[NSNumber numberWithInt:toIndexPath.row]];
					}
					else 
					{
						newPosition = [position intValue] - 1;
						[tempMultiDeleteList addObject:[NSNumber numberWithInt:newPosition]];
					}
				}
				else
				{
					[tempMultiDeleteList addObject:position];
				}
			}
		}
		viewObjectsS.multiDeleteList = [NSMutableArray arrayWithArray:tempMultiDeleteList];
	}
	
	// Correct the value of currentPlaylistPosition
	if (fromIndexPath.row == playlistS.currentIndex)
	{
		playlistS.currentIndex = toIndexPath.row;
	}
	else 
	{
		if (fromIndexPath.row < playlistS.currentIndex && toIndexPath.row >= playlistS.currentIndex)
		{
			playlistS.currentIndex = playlistS.currentIndex - 1;
		}
		else if (fromIndexPath.row > playlistS.currentIndex && toIndexPath.row <= playlistS.currentIndex)
		{
			playlistS.currentIndex = playlistS.currentIndex + 1;
		}
	}
	
	if (settingsS.isJukeboxEnabled)
	{
		[jukeboxS jukeboxReplacePlaylistWithLocal];
	}
	
	if (!settingsS.isJukeboxEnabled)
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistOrderChanged];
}


// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return YES;
}



#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath)
		return;
	
	[musicS playSongAtPosition:indexPath.row];
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
	[receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
	[receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	NSString *message = @"";
	message = [NSString stringWithFormat:@"There was an error saving the playlist to the server.\n\nError %i: %@", 
			   [error code], 
			   [error localizedDescription]];
	
	// Inform the user that the connection failed.
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	
	self.tableView.scrollEnabled = YES;
	[viewObjectsS hideLoadingScreen];
	
	 connection = nil;
	
	 receivedData = nil;
}	

- (NSURLRequest *)connection: (NSURLConnection *)inConnection willSendRequest:(NSURLRequest *)inRequest redirectResponse:(NSURLResponse *)inRedirectResponse;
{
    if (inRedirectResponse) 
	{
        NSMutableURLRequest *newRequest = [request mutableCopy];
        [newRequest setURL:[inRequest URL]];
        return newRequest;
    } 
	else 
	{
        return inRequest;
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	[self parseData];
	
	self.tableView.scrollEnabled = YES;
	 connection = nil;
}

static NSString *kName_Error = @"error";

- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil];
	alert.tag = 1;
	[alert show];
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
	
	 receivedData = nil;
	
	[viewObjectsS hideLoadingScreen];
}


@end

