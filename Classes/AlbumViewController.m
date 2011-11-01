//
//  AlbumViewController.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "AlbumViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "AlbumUITableViewCell.h"
#import "SongUITableViewCell.h"
#import "AsynchronousImageViewCached.h"
#import "XMLParser.h"
#import "Artist.h"
#import "Album.h"
#import "Song.h"
#import "NSString-md5.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "LoadingScreen.h"
#import "NSString-hex.h"
#import "AsynchronousImageView.h"

#import "EGORefreshTableHeaderView.h"

#import "ModalAlbumArtViewController.h"

#import "CustomUIAlertView.h"

#import "SavedSettings.h"
#import "NSString-time.h"

#import "NSData+Base64.h"

@interface AlbumViewController (Private)

- (void)dataSourceDidFinishLoadingNewData;
- (void)addHeaderAndIndex;
- (void)loadData;
- (void)createArrays;

@end


@implementation AlbumViewController
@synthesize myId, myArtist, myAlbum;
@synthesize listOfAlbums, listOfSongs, sectionInfo;

@synthesize reloading=_reloading;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	//if ([[[iSubAppDelegate sharedInstance].settingsDictionary objectForKey:@"lockRotationSetting"] isEqualToString:@"YES"] && inOrientation != UIInterfaceOrientationPortrait)
	if ([SavedSettings sharedInstance].isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

#pragma mark Lifecycle

- (AlbumViewController *)initWithArtist:(Artist *)anArtist orAlbum:(Album *)anAlbum
{
	if (anArtist == nil && anAlbum == nil)
	{
		return nil;
	}
	
	self = [super initWithNibName:@"AlbumViewController" bundle:nil];
	if (self != nil)
	{
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		viewObjects = [ViewObjectsSingleton sharedInstance];
		databaseControls = [DatabaseSingleton sharedInstance];
		musicControls = [MusicSingleton sharedInstance];
		self.sectionInfo = nil;
		
		if (anArtist != nil)
		{
			self.title = anArtist.name;
			self.myId = anArtist.artistId;
			self.myArtist = anArtist;
			self.myAlbum = nil;
		}
		else
		{
			self.title = anAlbum.title;
			self.myId = anAlbum.albumId;
			self.myArtist = [Artist artistWithName:anAlbum.artistName andArtistId:anAlbum.artistId];
			self.myAlbum = anAlbum;
		}
		
		// Create the listOfSongs and listOfAlbums arrays
		[self createArrays];
		
		if ((viewObjects.isAlbumsLoading || viewObjects.isSongsLoading) && [self.myId isEqualToString:viewObjects.currentLoadingFolderId])
		{
			CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Please Wait" message:@"This folder is currently being loaded by the Albums or Songs tab. Try again in a few seconds." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
			[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
			[alert release];
		}
		else
		{
			//if ([databaseControls.albumListCacheDb intForQuery:@"SELECT COUNT(*) FROM albumListCache WHERE id = ?", [NSString md5:self.myId]] == 0)
			if ([listOfAlbums count] == 0 && [listOfSongs count] == 0)
			{
				[self loadData];
			}
			else
			{
				[self.tableView reloadData];
				[self addHeaderAndIndex];
			}
		}
	}
	
	return self;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	// Add the pull to refresh view
	refreshHeaderView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, 320.0f, self.tableView.bounds.size.height)];
	refreshHeaderView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:237.0/255.0 alpha:1.0];
	[self.tableView addSubview:refreshHeaderView];
	[refreshHeaderView release];
	
	// Add the table fade
	UIImageView *fade = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]] autorelease];
	fade.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
	fade.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.tableView.tableFooterView = fade;
}


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
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc 
{
	[myId release]; myId = nil;
	[myArtist release]; myArtist = nil;
	[myAlbum release]; myAlbum = nil;
	
	[listOfAlbums release]; listOfAlbums = nil;
	[listOfSongs release]; listOfSongs = nil;
	[super dealloc];
}

#pragma mark Loading

- (void) createArrays
{
	// Create the album and song arrays
	self.listOfAlbums = [NSMutableArray arrayWithCapacity:0];
	self.listOfSongs = [NSMutableArray arrayWithCapacity:0];
	
	[databaseControls.albumListCacheDb beginTransaction];
	
	FMResultSet *result = [databaseControls.albumListCacheDb executeQuery:@"SELECT rowid FROM albumsCache WHERE folderId = ?", [NSString md5:self.myId]];
	while ([result next])
	{
		[listOfAlbums addObject:[NSNumber numberWithInt:[result intForColumnIndex:0]]];
	}
	[result close];
	
	result = [databaseControls.albumListCacheDb executeQuery:@"SELECT rowid FROM songsCache WHERE folderId = ?", [NSString md5:self.myId]];
	while ([result next])
	{
		[listOfSongs addObject:[NSNumber numberWithInt:[result intForColumnIndex:0]]];
	}
	[result close];
	
	[databaseControls.albumListCacheDb commit];
}

- (void)loadData
{
	/*NSString *urlString = [NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"getMusicDirectory.view"], self.myId];
	//DLog(@"loading from the server: %@", urlString);
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kLoadingTimeout];*/
    
    SavedSettings *settings = [SavedSettings sharedInstance];
    
    NSString *urlString = [NSString stringWithFormat:@"%@/rest/%@?v=1.1.0&c=iSub", settings.urlString, @"getMusicDirectory.view"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kLoadingTimeout];
    
    NSString *authStr = [NSString stringWithFormat:@"%@:%@", settings.username, settings.password];
    NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64EncodingWithLineLength:0]];
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
    
	connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
		// Create the NSMutableData to hold the received data.
		// receivedData is an instance variable declared elsewhere.
		loadingData = [[NSMutableData data] retain];
		
		[viewObjects showAlbumLoadingScreen:self.view sender:self];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error loading the album.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		alert.tag = 2;
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
		
		[self dataSourceDidFinishLoadingNewData];
	}
}

- (void)cancelLoad
{
	[connection cancel];
	[self dataSourceDidFinishLoadingNewData];
	[viewObjects hideLoadingScreen];
}



- (void)addHeaderAndIndex
{
	if (IS_IPAD() && myAlbum != nil)
	{
		UIView *headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 400, 300)] autorelease];
		headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		headerView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];
		
		// Cover art placeholder
		UIView *placeholder = [[UIView alloc] initWithFrame:CGRectMake(20, 20, 240, 240)];
		placeholder.backgroundColor = [UIColor blackColor];
		placeholder.alpha = .90;
		[headerView addSubview:placeholder];
		[placeholder release];
		
		// Cover art loading process activity indicator
		UIActivityIndicatorView *loadingSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		loadingSpinner.center = placeholder.center;
		[headerView addSubview:loadingSpinner];
		[loadingSpinner startAnimating];
		[loadingSpinner release];
		
		// Cover art
		AsynchronousImageView *coverArtImageView = [[AsynchronousImageView alloc] initWithFrame:placeholder.frame];
		[headerView addSubview:coverArtImageView];
		[coverArtImageView release];
		
		if(myAlbum.coverArtId)
		{			
			if ([databaseControls.coverArtCacheDb540 intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [NSString md5:myAlbum.coverArtId]] == 1)
			{
				NSData *imageData = [databaseControls.coverArtCacheDb540 dataForQuery:@"SELECT data FROM coverArtCache WHERE id = ?", [NSString md5:myAlbum.coverArtId]];
				coverArtImageView.image = [UIImage imageWithData:imageData];
			}
			else 
			{
				[coverArtImageView loadImageFromCoverArtId:myAlbum.coverArtId isForPlayer:NO];
				//[coverArtImageView loadImageFromURLString:[NSString stringWithFormat:@"%@%@&size=540", [appDelegate getBaseUrl:@"getCoverArt.view"], myAlbum.coverArtId]];
			}
			
			UIButton *coverArtExpand = [UIButton buttonWithType:UIButtonTypeCustom];
			coverArtExpand.frame = CGRectMake(20, 20, 240, 240);
			[coverArtExpand addTarget:self action:@selector(expandCoverArt) forControlEvents:UIControlEventTouchUpInside];
			[headerView addSubview:coverArtExpand];
		}
		else 
		{
			coverArtImageView.image = [UIImage imageNamed:@"default-album-art.png"];
		}
		
		UILabel *artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(280, 20, 100, 60)];
		artistLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		artistLabel.backgroundColor = [UIColor clearColor];
		artistLabel.textAlignment = UITextAlignmentRight;
		artistLabel.text = myAlbum.artistName;
		artistLabel.font = [UIFont boldSystemFontOfSize:48];
		artistLabel.adjustsFontSizeToFitWidth = YES;
		[headerView addSubview:artistLabel];
		[artistLabel release];
		
		UILabel *albumLabel = [[UILabel alloc] initWithFrame:CGRectMake(280, 90, 100, 40)];
		albumLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		albumLabel.backgroundColor = [UIColor clearColor];
		albumLabel.textAlignment = UITextAlignmentRight;
		albumLabel.text = myAlbum.title;
		albumLabel.font = [UIFont boldSystemFontOfSize:36];
		albumLabel.adjustsFontSizeToFitWidth = YES;
		[headerView addSubview:albumLabel];
		[albumLabel release];
		
		float duration = 0;
		for (NSNumber *rowId in self.listOfSongs)
		{
			NSUInteger row = [rowId intValue] - 1;
			Song *aSong = [databaseControls songFromDbRow:row inTable:@"songsCache" inDatabase:databaseControls.albumListCacheDb];
			duration += [aSong.duration floatValue];
		}
		UILabel *durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(280, 140, 100, 20)];
		durationLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		durationLabel.backgroundColor = [UIColor clearColor];
		durationLabel.textAlignment = UITextAlignmentRight;
		durationLabel.text = [NSString formatTime:duration];
		durationLabel.font = [UIFont boldSystemFontOfSize:24];
		[headerView addSubview:durationLabel];
		[durationLabel release];
		
		self.tableView.tableHeaderView = headerView;
	}
	else
	{
		// Add the play all button + shuffle button
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
		
		self.tableView.tableHeaderView = headerView;
	}
	
	
	// Create the section index
	if ([listOfAlbums count] > 10)
	{
		[databaseControls.inMemoryDb executeUpdate:@"DROP TABLE albumIndex"];
		[databaseControls.inMemoryDb executeUpdate:@"CREATE TABLE albumIndex (album TEXT)"];

		[databaseControls.albumListCacheDb beginTransaction];
		for (NSNumber *rowId in listOfAlbums)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			NSString *albumTitle = [databaseControls.albumListCacheDb stringForQuery:@"SELECT title FROM albumsCache WHERE rowid = ?", rowId];
			[databaseControls.inMemoryDb executeUpdate:@"INSERT INTO albumIndex (album) VALUES (?)", albumTitle];
			
			[pool release];
		}
		[databaseControls.albumListCacheDb commit];
		
		self.sectionInfo = [databaseControls sectionInfoFromTable:@"albumIndex" inDatabase:databaseControls.inMemoryDb withColumn:@"album"];
		
		if (sectionInfo)
		{
			if ([sectionInfo count] < 5)
				self.sectionInfo = nil;
			else
				[self.tableView reloadData];
		}
	}	
}

#pragma mark Actions

- (void)expandCoverArt
{
	ModalAlbumArtViewController *largeArt = [[ModalAlbumArtViewController alloc] initWithAlbum:myAlbum];
	if (IS_IPAD())
		[appDelegate.splitView presentModalViewController:largeArt animated:YES];
	else
		[self presentModalViewController:largeArt animated:YES];
	[largeArt release];
}

- (void)playAllAction:(id)sender
{
	[databaseControls playAllSongs:myId artist:myArtist];
}

- (void)shuffleAction:(id)sender
{
	[databaseControls shuffleAllSongs:myId artist:myArtist];
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

// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView 
{
	NSMutableArray *indexes = [[[NSMutableArray alloc] init] autorelease];
	for (int i = 0; i < [sectionInfo count]; i++)
	{
		[indexes addObject:[[sectionInfo objectAtIndex:i] objectAtIndex:0]];
	}
	return indexes;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index 
{
	if (index == 0)
	{
		[tableView scrollRectToVisible:CGRectMake(0, 50, 320, 40) animated:NO];
	}
	else
	{
		NSUInteger row = [[[sectionInfo objectAtIndex:(index - 1)] objectAtIndex:1] intValue];
		NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
		[tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
	}
	
	return -1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	NSUInteger albumCount = [listOfAlbums count];
	NSUInteger songCount = [listOfSongs count];
	
	return (albumCount + songCount);
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{		
	static NSString *CellIdentifier = @"Cell";
	
	// Set up the cell...
	if (indexPath.row < [listOfAlbums count])
	{
		AlbumUITableViewCell *cell = [[[AlbumUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];

		//Album *anAlbum = [listOfAlbums objectAtIndex:indexPath.row];
		NSUInteger row = [[listOfAlbums objectAtIndex:indexPath.row] intValue] - 1;
		Album *anAlbum = [databaseControls albumFromDbRow:row inTable:@"albumsCache" inDatabase:databaseControls.albumListCacheDb];
		cell.myId = anAlbum.albumId;
		cell.myArtist = [Artist artistWithName:anAlbum.artistName andArtistId:anAlbum.artistId];
		if (sectionInfo)
			cell.isIndexShowing = YES;
		
		//DLog(@"%@\n%@\n%@\n%@", anAlbum.albumId, [NSString stringFromHex:anAlbum.albumId], [NSString stringToHex:[NSString stringFromHex:anAlbum.albumId]], [NSString stringFromHex:[NSString stringToHex:[NSString stringFromHex:anAlbum.albumId]]]);
		
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
		
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		
		// Setup cell backgrond color
		cell.backgroundView = [[[UIView alloc] init] autorelease];
		if(indexPath.row % 2 == 0)
			cell.backgroundView.backgroundColor = viewObjects.lightNormal;
		else
			cell.backgroundView.backgroundColor = viewObjects.darkNormal;
		
		return cell;
	}
	else
	{
		SongUITableViewCell *cell = [[[SongUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		cell.indexPath = indexPath;
		cell.accessoryType = UITableViewCellAccessoryNone;
		
		NSUInteger songRow = indexPath.row - [listOfAlbums count];
		//Song *aSong = [listOfSongs objectAtIndex:songRow];
		NSUInteger row = [[listOfSongs objectAtIndex:songRow] intValue] - 1;
		Song *aSong = [databaseControls songFromDbRow:row inTable:@"songsCache" inDatabase:databaseControls.albumListCacheDb];
		
		cell.mySong = aSong;
		
		if ( aSong.track )
			cell.trackNumberLabel.text = [NSString stringWithFormat:@"%i", [aSong.track intValue]];
		else
			cell.trackNumberLabel.text = @"";
		
		cell.songNameLabel.text = aSong.title;
		
		if ( aSong.artist)
			cell.artistNameLabel.text = aSong.artist;
		else
			cell.artistNameLabel.text = @"";		
		
		if ( aSong.duration )
			cell.songDurationLabel.text = [NSString formatTime:[aSong.duration floatValue]];
		else
			cell.songDurationLabel.text = @"";
		
		cell.backgroundView = [[[UIView alloc] init] autorelease];
		if(indexPath.row % 2 == 0)
		{
			if ([databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ? and finished = 'YES'", [NSString md5:aSong.path]] != nil)
				cell.backgroundView.backgroundColor = [viewObjects currentLightColor];
			else
				cell.backgroundView.backgroundColor = viewObjects.lightNormal;
		}
		else
		{
			if ([databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ? and finished = 'YES'", [NSString md5:aSong.path]] != nil)
				cell.backgroundView.backgroundColor = [viewObjects currentDarkColor];
			else
				cell.backgroundView.backgroundColor = viewObjects.darkNormal;
		}
		
		return cell;
	}
}


// Customize the height of individual rows to make the album rows taller to accomidate the album art.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (indexPath.row < [listOfAlbums count])
		return 60.0;
	else
		return 50.0;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{	
	if (viewObjects.isCellEnabled)
	{
		if (indexPath.row < [listOfAlbums count])
		{
			//Album *anAlbum = [listOfAlbums objectAtIndex:indexPath.row];
			NSUInteger row = [[listOfAlbums objectAtIndex:indexPath.row] intValue] - 1;
			Album *anAlbum = [databaseControls albumFromDbRow:row inTable:@"albumsCache" inDatabase:databaseControls.albumListCacheDb];
			
			AlbumViewController *albumViewController = [[AlbumViewController alloc] initWithArtist:nil orAlbum:anAlbum];	
			
			[self.navigationController pushViewController:albumViewController animated:YES];
			[albumViewController release];
		}
		else
		{
			/*if ([SavedSettings sharedInstance].isJukeboxEnabled)
			{
				NSUInteger songRow = indexPath.row - [listOfAlbums count];
				musicControls.currentPlaylistPosition = songRow;
				
				NSMutableArray *songIds = [[NSMutableArray alloc] init];
				for (NSNumber *rowId in listOfSongs)
				{
					NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
					
					NSString *songId = [databaseControls.albumListCacheDb stringForQuery:@"SELECT songId FROM songsCache WHERE rowId = ?", rowId];
					[songIds addObject:songId];
					
					[pool release];
				}

				[musicControls jukeboxStop];
				[musicControls jukeboxClearPlaylist];
				[musicControls jukeboxAddSongs:songIds];
				[songIds release];
				
				[musicControls jukeboxPlaySongAtPosition:songRow];
				
				musicControls.isNewSong = YES;
				musicControls.isShuffle = NO;
				
				iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
				streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
				[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
				[streamingPlayerViewController release];
			}
			else
			{*/
			
			// Kill the streamer if it's playing
			[musicControls destroyStreamer];
			
			// Find the new playlist position
			NSUInteger songRow = indexPath.row - [listOfAlbums count];
			musicControls.currentPlaylistPosition = songRow;
			
			// Clear the current playlist
			if ([SavedSettings sharedInstance].isJukeboxEnabled)
				[databaseControls resetJukeboxPlaylist];
			else
				[databaseControls resetCurrentPlaylistDb];
			
			// Add the songs to the playlist 
			NSMutableArray *songIds = [[NSMutableArray alloc] init];
			for (NSNumber *rowId in listOfSongs)
			{
				NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
				
				NSInteger row = [rowId intValue] - 1;
				Song *aSong = [databaseControls songFromDbRow:row inTable:@"songsCache" inDatabase:databaseControls.albumListCacheDb];
				[databaseControls addSongToPlaylistQueue:aSong];
				//[databaseControls insertSong:aSong intoTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
				
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
			
			// Set the current and next song objects
			//musicControls.currentSongObject = nil;
			//musicControls.nextSongObject = nil; 
			if ([SavedSettings sharedInstance].isJukeboxEnabled)
			{
				musicControls.currentSongObject = [databaseControls songFromDbRow:songRow inTable:@"jukeboxCurrentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
				musicControls.nextSongObject = [databaseControls songFromDbRow:(songRow + 1) inTable:@"jukeboxCurrentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
			}
			else
			{
				musicControls.currentSongObject = [databaseControls songFromDbRow:songRow inTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
				musicControls.nextSongObject = [databaseControls songFromDbRow:(songRow + 1) inTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
			}
			
			// Set player defaults
			musicControls.isNewSong = YES;
			musicControls.isShuffle = NO;
			
			
			// Start the song
			musicControls.seekTime = 0.0;
			[musicControls playSongAtPosition:songRow];
			
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
		}
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
	[loadingData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
	NSLog(@"album load did receive data");
    [loadingData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	// Inform the user that the connection failed.
	NSString *message = [NSString stringWithFormat:@"There was an error loading the album.\n\nError %i: %@", [error code], [error localizedDescription]];
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	alert.tag = 2;
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
	[alert release];
	
	[viewObjects hideLoadingScreen];
	
	[theConnection release];
	[loadingData release];
	
	[self dataSourceDidFinishLoadingNewData];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	NSLog(@"album load connection finished, parsing...");
	NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:loadingData];
	XMLParser *parser = [[XMLParser alloc] initXMLParser];
	
	parser.myId = self.myId;
	parser.myArtist = myArtist;
	parser.parseState = @"albums";
	[xmlParser setDelegate:parser];
	[xmlParser parse];
	
	[xmlParser release];
	[parser release];
	
	[self createArrays];
	
	[viewObjects hideLoadingScreen];
	
	[theConnection release];
	[loadingData release];
	
	[self.tableView reloadData];
	[self addHeaderAndIndex];
	
	[self dataSourceDidFinishLoadingNewData];
}


#pragma mark -
#pragma mark Pull to refresh methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{	
	if (scrollView.isDragging) 
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
	
	if (scrollView.contentOffset.y <= - 65.0f && !_reloading) 
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

