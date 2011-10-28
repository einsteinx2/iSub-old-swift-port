 //
//  SUSAllSongsLoader.m
//  iSub
//
//  Created by Ben Baron on 9/23/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSAllSongsLoader.h"
#import "ViewObjectsSingleton.h"
#import "DatabaseSingleton.h"
#import "SavedSettings.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString-md5.h"
#import "Artist.h"
#import "Album.h"
#import "Song.h"
#import "SUSRootFoldersDAO.h"

@interface SUSAllSongsLoader (Private)

- (void)loadData;
- (void)createLoadTempTables;
- (void)createLoadTables;
- (void)loadAlbumFolder;
- (void)loadSort;
- (void)loadFinish;
- (void)sendArtistNotification:(NSString *)artistName;
- (void)sendAlbumNotification:(NSString *)albumTitle;
- (void)sendSongNotification:(NSString *)songTitle;

@end

@implementation SUSAllSongsLoader

@synthesize currentArtist, currentAlbum, rootFolders, notificationTimeArtist, notificationTimeAlbum, notificationTimeSong;

- (void)setup
{
	viewObjects = [ViewObjectsSingleton sharedInstance];
	databaseControls = [DatabaseSingleton sharedInstance];
	settings = [SavedSettings sharedInstance];
	
	currentArtist = nil;
	currentAlbum = nil;
	rootFolders = nil;
	notificationTimeArtist = [[NSDate alloc] init];
	notificationTimeAlbum = [[NSDate alloc] init];
	notificationTimeSong = [[NSDate alloc] init];
}

- (id)init
{
    if ((self = [super init]))
	{
		[self setup];
	}
    
    return self;
}

- (id)initWithDelegate:(id <LoaderDelegate>)theDelegate
{
	if ((self = [super initWithDelegate:theDelegate]))
	{
		[self setup];
	}
	
	return self;
}

- (void)dealloc
{
	[currentArtist release]; currentArtist = nil;
	[currentAlbum release]; currentAlbum = nil;
	[rootFolders release]; rootFolders = nil;
	[notificationTimeArtist release]; notificationTimeArtist = nil;
	[notificationTimeAlbum release]; notificationTimeAlbum = nil;
	[notificationTimeSong release]; notificationTimeSong = nil;
	[super dealloc];
}

#pragma mark Data loading

static NSInteger order (id a, id b, void* context)
{
    NSString* catA = [a lastObject];
    NSString* catB = [b lastObject];
    return [catA caseInsensitiveCompare:catB];
}

- (void)cancelLoad
{
	viewObjects.cancelLoading = YES;
}

- (void)startLoad
{
	tempAlbumsCount = 0;
	tempSongsCount = 0;
	tempGenresCount = 0;
	tempGenresLayoutCount = 0;
	
	totalAlbumsProcessed = 0;
	totalSongsProcessed = 0;
	
	viewObjects.isAlbumsLoading = YES;
	viewObjects.isSongsLoading = YES;
	[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:[NSString stringWithFormat:@"%@isAllAlbumsLoading", settings.urlString]];
	[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:[NSString stringWithFormat:@"%@isAllSongsLoading", settings.urlString]];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	self.rootFolders = [[[SUSRootFoldersDAO alloc] init] autorelease];
	
	// Check to see if we need to create the tables
	if ((![databaseControls.allAlbumsDb tableExists:@"resumeLoad"] && ![databaseControls.allSongsDb tableExists:@"resumeLoad"]) ||
		[databaseControls.allSongsDb tableExists:@"restartLoad"])
	{
		// Both of the resume tables don't exist, so that means this is a new load not a resume
		// Or the restartLoad table was created explicitly
		// So create the tables for the load
		[self createLoadTables];
	}
	[self createLoadTempTables];
	
	if ([databaseControls.allAlbumsDb tableExists:@"resumeLoad"])
	{
		// The albums are still loading or are just starting
		iteration = -1;
		
		currentRow = [databaseControls.allAlbumsDb intForQuery:@"SELECT artistNum FROM resumeLoad"];
		artistCount = [databaseControls.albumListCacheDb intForQuery:@"SELECT count FROM rootFolderCount_all LIMIT 1"];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_LOADING_ARTISTS object:nil];
		
		[self loadAlbumFolder];	
	}
	else
	{
		// The songs are still loading or are just starting
		
		iteration = [databaseControls.allSongsDb intForQuery:@"SELECT iteration FROM resumeLoad"];
		
		if (iteration == 0)
		{
			currentRow = [databaseControls.allSongsDb intForQuery:@"SELECT albumNum FROM resumeLoad"];
			albumCount = [databaseControls.allAlbumsDb intForQuery:@"SELECT COUNT(*) FROM allAlbumsUnsorted"];
			DLog(@"albumCount: %i", albumCount);
			
			[[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_LOADING_ALBUMS object:nil];
			
			[self loadAlbumFolder];
		}
		else if (iteration < 4)
		{
			currentRow = [databaseControls.allSongsDb intForQuery:@"SELECT albumNum FROM resumeLoad"];
			albumCount = [databaseControls.allAlbumsDb intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM subalbums%i", iteration]];
			DLog(@"subalbums%i albumCount: %i", iteration, albumCount);
			
			if (albumCount > 0)
			{
				[[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_LOADING_ALBUMS object:nil];
				[self loadAlbumFolder];
			}
			else
			{
				// The table is empty so do the load sort
				iteration = 4;
				[databaseControls.allSongsDb executeUpdate:@"UPDATE resumeLoad SET albumNum = ?, iteration = ?", [NSNumber numberWithInt:0], [NSNumber numberWithInt:iteration]];
				DLog(@"calling loadSort");
				[self performSelectorInBackground:@selector(loadSort) withObject:nil];
			}
		}
		else if (iteration == 4)
		{
			DLog(@"calling loadSort");
			[self performSelectorInBackground:@selector(loadSort) withObject:nil];
		}
		else if (iteration == 5)
		{
			[self performSelectorInBackground:@selector(loadFinish) withObject:nil];
		}
	}
}	

- (void)createLoadTempTables
{
	[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE IF EXISTS allAlbumsTemp"];
	[databaseControls.allAlbumsDb executeUpdate:@"CREATE TEMPORARY TABLE allAlbumsTemp(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
	
	[databaseControls.allSongsDb executeUpdate:@"DROP TABLE IF EXISTS allSongsTemp"];
	[databaseControls.allSongsDb executeUpdate:@"CREATE TEMPORARY TABLE allSongsTemp (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
	
	[databaseControls.genresDb executeUpdate:@"DROP TABLE IF EXISTS genresTemp"];
	[databaseControls.genresDb executeUpdate:@"CREATE TEMPORARY TABLE genresTemp (genre TEXT)"];
	
	[databaseControls.genresDb executeUpdate:@"DROP TABLE IF EXISTS genresLayoutTemp"];
	[databaseControls.genresDb executeUpdate:@"CREATE TEMPORARY TABLE genresLayoutTemp (md5 TEXT, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
}

- (void)createLoadTables
{
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	DLog(@"url md5: %@", [settings.urlString md5]);
	
	// Initialize allAlbums db
	[databaseControls.allAlbumsDb close]; databaseControls.allAlbumsDb = nil;
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@allAlbums.db", settings.databasePath, [settings.urlString md5]] error:NULL];
	databaseControls.allAlbumsDb = [FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@allAlbums.db", settings.databasePath, [settings.urlString md5]]];
	[databaseControls.allAlbumsDb executeUpdate:@"PRAGMA cache_size = 1"];
	if ([databaseControls.allAlbumsDb open] == NO) { DLog(@"Could not open allAlbumsDb."); }
	
	// Create allAlbums tables
	[databaseControls.allAlbumsDb executeUpdate:@"CREATE TABLE resumeLoad (artistNum INTEGER, iteration INTEGER)"];
	[databaseControls.allAlbumsDb executeUpdate:@"INSERT INTO resumeLoad (artistNum, iteration) VALUES (1, 0)"];
	[databaseControls.allAlbumsDb executeUpdate:@"CREATE VIRTUAL TABLE allAlbums USING FTS3(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT, tokenize=porter)"];
	//[databaseControls.allAlbumsDb executeUpdate:@"CREATE INDEX title ON allAlbums (title ASC)"];
	[databaseControls.allAlbumsDb executeUpdate:@"CREATE TABLE allAlbumsUnsorted(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
	//[databaseControls.allAlbumsDb executeUpdate:@"CREATE INDEX title ON allAlbumsUnsorted (title ASC)"];
	[databaseControls.allAlbumsDb executeUpdate:@"CREATE TABLE allAlbumsCount (count INTEGER)"];
	[databaseControls.allAlbumsDb executeUpdate:@"CREATE TABLE allAlbumsUnsortedCount (count INTEGER)"];
	
	[databaseControls.allAlbumsDb executeUpdate:@"CREATE TABLE subalbums1 (title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
	[databaseControls.allAlbumsDb executeUpdate:@"CREATE TABLE subalbums2 (title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
	[databaseControls.allAlbumsDb executeUpdate:@"CREATE TABLE subalbums3 (title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
	[databaseControls.allAlbumsDb executeUpdate:@"CREATE TABLE subalbums4 (title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
	
	// Initialize allSongs db
	[databaseControls.allSongsDb close]; databaseControls.allSongsDb = nil;
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@allSongs.db", settings.databasePath, [settings.urlString md5]] error:NULL];
	databaseControls.allSongsDb = [FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@allSongs.db", settings.databasePath, [settings.urlString md5]]];
	[databaseControls.allSongsDb executeUpdate:@"PRAGMA cache_size = 1"];
	if ([databaseControls.allSongsDb open] == NO) { DLog(@"Could not open allSongsDb."); }
	//[databaseControls.allSongsDb executeUpdate:@"PRAGMA synchronous = OFF"];
	DLog(@"allSongsDb synchronous: %i", [databaseControls.allSongsDb intForQuery:@"PRAGMA synchronous"]);
	
	// Create allSongs tables
	[databaseControls.allSongsDb executeUpdate:@"CREATE TABLE resumeLoad (albumNum INTEGER, iteration INTEGER)"];
	[databaseControls.allSongsDb executeUpdate:@"INSERT INTO resumeLoad (albumNum, iteration) VALUES (1, 0)"];
	[databaseControls.allSongsDb executeUpdate:@"CREATE VIRTUAL TABLE allSongs USING FTS3 (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER, tokenize=porter)"];
	//[databaseControls.allSongsDb executeUpdate:@"CREATE INDEX title ON allSongs (title ASC)"];
	//[databaseControls.allSongsDb executeUpdate:@"CREATE INDEX songGenre ON allSongs (genre)"];
	[databaseControls.allSongsDb executeUpdate:@"CREATE TABLE allSongsUnsorted (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
	//[databaseControls.allSongsDb executeUpdate:@"CREATE INDEX title ON allSongsUnsorted (title ASC)"];
	[databaseControls.allSongsDb executeUpdate:@"CREATE TABLE allSongsCount (count INTEGER)"];
	
	// Initialize genres db
	[databaseControls.genresDb close]; databaseControls.genresDb = nil;
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@genres.db", settings.databasePath, [settings.urlString md5]] error:NULL];
	databaseControls.genresDb = [FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@genres.db", settings.databasePath, [settings.urlString md5]]];
	[databaseControls.genresDb executeUpdate:@"PRAGMA cache_size = 1"];
	if ([databaseControls.genresDb open] == NO) { DLog(@"Could not open genresDb."); }
	
	// Create genres tables
	[databaseControls.genresDb executeUpdate:@"CREATE TABLE genres (genre TEXT UNIQUE)"];
	[databaseControls.genresDb executeUpdate:@"CREATE TABLE genresUnsorted (genre TEXT UNIQUE)"];
	[databaseControls.genresDb executeUpdate:@"CREATE TABLE genresLayout (md5 TEXT, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
	/*[databaseControls.genresDb executeUpdate:@"CREATE UNIQUE INDEX md5 ON genresLayout (md5)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX layoutGenre ON genresLayout (genre)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX seg1 ON genresLayout (seg1)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX seg2 ON genresLayout (seg2)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX seg3 ON genresLayout (seg3)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX seg4 ON genresLayout (seg4)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX seg5 ON genresLayout (seg5)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX seg6 ON genresLayout (seg6)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX seg7 ON genresLayout (seg7)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX seg8 ON genresLayout (seg8)"];
	[databaseControls.genresDb executeUpdate:@"CREATE INDEX seg9 ON genresLayout (seg9)"];*/
	
	[autoreleasePool release];
}

- (void)loadAlbumFolder
{	
	// Check if loading should stop
	if (viewObjects.cancelLoading)
	{
		viewObjects.cancelLoading = NO;
		viewObjects.isAlbumsLoading = NO;
		viewObjects.isSongsLoading = NO;
		[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:[NSString stringWithFormat:@"%@isAllAlbumsLoading", [SavedSettings sharedInstance].urlString]];
		[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:[NSString stringWithFormat:@"%@isAllSongsLoading", settings.urlString]];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[self performSelectorInBackground:@selector(hideLoadingScreen) withObject:nil];
		return;
	}
	
	if (iteration == -1)
	{
		self.currentArtist = [rootFolders artistForPosition:currentRow];
		DLog(@"current artist: %@", currentArtist.name);
		
		[self sendArtistNotification:currentArtist.name];
	}
	else
	{
		if (iteration == 0)
			self.currentAlbum = [databaseControls albumFromDbRow:currentRow inTable:@"allAlbumsUnsorted" inDatabase:databaseControls.allAlbumsDb];
		else
			self.currentAlbum = [databaseControls albumFromDbRow:currentRow inTable:[NSString stringWithFormat:@"subalbums%i", iteration] inDatabase:databaseControls.allAlbumsDb];
		DLog(@"current album: %@", currentAlbum.title);
		
		self.currentArtist = [Artist artistWithName:currentAlbum.artistName andArtistId:currentAlbum.artistId];
		
		[self sendAlbumNotification:currentAlbum.title];
	}
	
	NSString *urlString = nil;
	if (iteration == -1)
		urlString = [NSString stringWithFormat:@"%@%@", [self getBaseUrlString:@"getMusicDirectory.view"], currentArtist.artistId];
	else
		urlString = [NSString stringWithFormat:@"%@%@", [self getBaseUrlString:@"getMusicDirectory.view"], currentAlbum.albumId];
	//DLog(@"loading url: %@", urlString);
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kLoadingTimeout];
	connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
		receivedData = [[NSMutableData data] retain];
	} 
	else 
	{
		if (iteration == -1)
		{
			DLog(@"%@", [NSString stringWithFormat:@"There was an error grabbing the song list for artist: %@", currentArtist.name]);
		}
		else
		{
			DLog(@"%@", [NSString stringWithFormat:@"There was an error grabbing the song list for album: %@", currentAlbum.title]);
		}
	}
}

- (void)loadSort
{
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	//[viewObjects.allSongsLoadingScreen performSelectorOnMainThread:@selector(setAllMessagesText:) withObject:[NSArray arrayWithObjects:@"Sorting Table", @"", @"", @"", nil] waitUntilDone:NO];
	
	// Sort the tables
	[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE IF EXISTS allAlbums"];
	[databaseControls.allAlbumsDb executeUpdate:@"CREATE VIRTUAL TABLE allAlbums USING FTS3(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT, tokenize=porter)"];
	DLog(@"sorting allAlbums");
	[databaseControls.allAlbumsDb executeUpdate:@"INSERT INTO allAlbums SELECT * FROM allAlbumsUnsorted ORDER BY title COLLATE NOCASE"];
	
	[databaseControls.allSongsDb executeUpdate:@"DROP TABLE IF EXISTS allSongs"];
	[databaseControls.allSongsDb executeUpdate:@"CREATE VIRTUAL TABLE allSongs USING FTS3 (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER, tokenize=porter)"];
	DLog(@"sorting allSongs");
	[databaseControls.allSongsDb executeUpdate:@"INSERT INTO allSongs SELECT * FROM allSongsUnsorted ORDER BY title COLLATE NOCASE"];
	
	[databaseControls.genresDb executeUpdate:@"DROP TABLE IF EXISTS genres"];
	[databaseControls.genresDb executeUpdate:@"CREATE TABLE genres (genre TEXT UNIQUE)"];
	DLog(@"sorting genres");
	[databaseControls.genresDb executeUpdate:@"INSERT INTO genres SELECT * FROM genresUnsorted ORDER BY genre COLLATE NOCASE"];
	
	// Add the keys
	
	// Clean up the tables
	[databaseControls.allSongsDb executeUpdate:@"UPDATE resumeLoad SET albumNum = ?, iteration = ?", [NSNumber numberWithInt:0], [NSNumber numberWithInt:5]];
	[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE allAlbumsUnsorted"];
	[databaseControls.allSongsDb executeUpdate:@"DROP TABLE allSongsUnsorted"];
	[databaseControls.genresDb executeUpdate:@"DROP TABLE genresUnsorted"];
	[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE allAlbumsTemp"];
	[databaseControls.allSongsDb executeUpdate:@"DROP TABLE allSongsTemp"];
	[databaseControls.genresDb executeUpdate:@"DROP TABLE genresTemp"];

	DLog(@"calling loadFinish");
	[self loadFinish];
	
	[autoreleasePool release];
}

- (void)loadFinish
{
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	 
    // Check if loading should stop
    if (viewObjects.cancelLoading)
    {
        viewObjects.cancelLoading = NO;
        viewObjects.isAlbumsLoading = NO;
        viewObjects.isSongsLoading = NO;
        [self performSelectorInBackground:@selector(hideLoadingScreen) withObject:nil];
        return;
    }
    
    /*// Create the section info array
    self.sectionInfo = [databaseControls sectionInfoFromTable:@"allSongs" inDatabase:databaseControls.allSongsDb withColumn:@"title"];
    [databaseControls.allSongsDb executeUpdate:@"DROP TABLE sectionInfo"];
    [databaseControls.allSongsDb executeUpdate:@"CREATE TABLE sectionInfo (title TEXT, row INTEGER)"];
    for (NSArray *section in sectionInfo)
    {
        [databaseControls.allSongsDb executeUpdate:@"INSERT INTO sectionInfo (title, row) VALUES (?, ?)", [section objectAtIndex:0], [section objectAtIndex:1]];
    }*/
    
    // Check if loading should stop
    if (viewObjects.cancelLoading)
    {
        viewObjects.cancelLoading = NO;
        viewObjects.isSongsLoading = NO;
        [self performSelectorInBackground:@selector(hideLoadingScreen) withObject:nil];
        return;
    }
    // Count the table
    NSUInteger allSongsCount = [databaseControls.allSongsDb intForQuery:@"SELECT COUNT (*) FROM allSongs"];
    [databaseControls.allSongsDb executeUpdate:@"INSERT INTO allSongsCount VALUES (?)", [NSNumber numberWithInt:allSongsCount]];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSDate date] forKey:[NSString stringWithFormat:@"%@songsReloadTime", settings.urlString]];
    [defaults synchronize];
    
    [databaseControls.allSongsDb executeUpdate:@"UPDATE resumeLoad SET albumNum = ?, iteration = ?", [NSNumber numberWithInt:0], [NSNumber numberWithInt:6]];
    
    [self performSelectorOnMainThread:@selector(loadData2) withObject:nil waitUntilDone:NO];
    
    [autoreleasePool release];
}

- (void) loadData2
{
	DLog(@"loadData2 called");
	// Check if loading should stop
	if (viewObjects.cancelLoading)
	{
		viewObjects.cancelLoading = NO;
		viewObjects.isSongsLoading = NO;
		
		//TODO: call delegate's error method with "user canceled" message
		//[self hideLoadingScreen];
		return;
	}
	viewObjects.isSongsLoading = NO;
	[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:[NSString stringWithFormat:@"%@isAllSongsLoading", settings.urlString]];
	[[NSUserDefaults standardUserDefaults] synchronize];
		
	/*[self addCount];
	
	self.tableView.backgroundColor = [UIColor clearColor];
	
	// Hide the loading screen
	[self hideLoadingScreen];
	
	if(musicControls.streamer || musicControls.showNowPlayingIcon)
	{
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}*/
	
	[databaseControls.allSongsDb executeUpdate:@"DROP TABLE resumeLoad"];
    
    [delegate loadingFinished:self];
}


- (NSArray *)createSectionInfo
{
	NSMutableArray *sections = [[NSMutableArray alloc] init];
	FMResultSet *result = [databaseControls.allSongsDb executeQuery:@"SELECT * FROM sectionInfo"];
	
	while ([result next])
	{
		[sections addObject:[NSArray arrayWithObjects:[NSString stringWithString:[result stringForColumnIndex:0]], 
							 [NSNumber numberWithInt:[result intForColumnIndex:1]], nil]];
	}
	
	NSArray *returnArray = [NSArray arrayWithArray:sections];
	[sections release];
	
	return returnArray;
}

- (void)sendArtistNotification:(NSString *)artistName
{
	if ([[NSDate date] timeIntervalSinceDate:notificationTimeArtist] > .5)
	{
		self.notificationTimeArtist = [NSDate date];
		[[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_ARTIST_NAME object:artistName];
	}
}

- (void)sendAlbumNotification:(NSString *)albumTitle
{
	if ([[NSDate date] timeIntervalSinceDate:notificationTimeAlbum] > .5)
	{
		self.notificationTimeAlbum = [NSDate date];
		[[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_ALBUM_NAME object:albumTitle];
	}
}

- (void)sendSongNotification:(NSString *)songTitle
{
	if ([[NSDate date] timeIntervalSinceDate:notificationTimeSong] > .5)
	{
		self.notificationTimeSong = [NSDate date];
		[[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_SONG_NAME object:songTitle];
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
	// Load the same folder
	//
	[self loadAlbumFolder];
	
	[theConnection release];
	[receivedData release];	
}	

static NSString *kName_Directory = @"directory";
static NSString *kName_Child = @"child";
static NSString *kName_Error = @"error";

- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	/*CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:appDelegate cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	 alert.tag = 1;
	 [alert show];
	 [alert release];*/
	DLog(@"Subsonic error %@:  %@", errorCode, message);
}

- (void)parseData:(NSURLConnection*)theConnection
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	/*if (iteration == -1)
	{
		DLog(@"parsing data for artist: %@", currentArtist.name);
	}
	else
	{
		DLog(@"parsing data for album: %@", currentAlbum.title);
	}*/
	
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
		
        TBXMLElement *directory = [TBXML childElementNamed:kName_Directory parentElement:root];
        if (directory) 
		{
			//NSDate *startTime = [NSDate date];
            TBXMLElement *child = [TBXML childElementNamed:kName_Child parentElement:directory];
            while (child != nil) 
			{
				NSAutoreleasePool *pool2 = [[NSAutoreleasePool alloc] init];
				if ([[TBXML valueOfAttributeNamed:@"isDir" forElement:child] isEqualToString:@"true"])
				{
					//Initialize the Album.
					Album *anAlbum = [[Album alloc] initWithTBXMLElement:child artistId:currentArtist.artistId artistName:currentArtist.name];
					
					// Skip if it's .AppleDouble, otherwise process it
					if (![anAlbum.title isEqualToString:@".AppleDouble"])
					{
						if (iteration == -1)
						{
							// Add the album to the allAlbums table
							[databaseControls insertAlbum:anAlbum intoTable:@"allAlbumsTemp" inDatabase:databaseControls.allAlbumsDb];
							tempAlbumsCount++;
							totalAlbumsProcessed++;
							
							if (tempAlbumsCount == WRITE_BUFFER_AMOUNT)
							{
								NSDate *startTime3 = [NSDate date];
								// Flush the records to disk
								[databaseControls.allAlbumsDb executeUpdate:@"INSERT INTO allAlbumsUnsorted SELECT * FROM allAlbumsTemp"];
								//[databaseControls.allAlbumsDb executeUpdate:@"DELETE * FROM allAlbumsTemp"];
								[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE IF EXISTS allAlbumsTemp"];
								[databaseControls.allAlbumsDb executeUpdate:@"CREATE TEMPORARY TABLE allAlbumsTemp(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
								tempAlbumsCount = 0;
								DLog(@"allAlbumsTemp flush time: %f  total records: %i", [[NSDate date] timeIntervalSinceDate:startTime3], totalAlbumsProcessed);
							}
						}
						else
						{
							//Add album object to the subalbums table to be processed in the next iteration
							[databaseControls insertAlbum:anAlbum intoTable:[NSString stringWithFormat:@"subalbums%i", (iteration + 1)] inDatabase:databaseControls.allAlbumsDb];
						}
					}
					
					// Update the loading screen message
					if (iteration == -1)
					{
						[self sendAlbumNotification:anAlbum.title];
					}
					
					[anAlbum release];
				}
				else
				{
					//Initialize the Song.
					Song *aSong = [[Song alloc] initWithTBXMLElement:child];
					
					// Add song object to the allSongs and genre databases
					if (![aSong.title isEqualToString:@".AppleDouble"])
					{
						// Process it if it has a path
						if (aSong.path)
						{
							// Add the song to the allSongs table
							[databaseControls insertSong:aSong intoTable:@"allSongsTemp" inDatabase:databaseControls.allSongsDb];
							tempSongsCount++;
							totalSongsProcessed++;
							
							if (tempSongsCount == WRITE_BUFFER_AMOUNT)
							{
								NSDate *startTime3 = [NSDate date];
								// Flush the records to disk
								[databaseControls.allSongsDb executeUpdate:@"INSERT INTO allSongsUnsorted SELECT * FROM allSongsTemp"];
								//[databaseControls.allSongsDb executeUpdate:@"DELETE * FROM allSongsTemp"];
								[databaseControls.allSongsDb executeUpdate:@"DROP TABLE IF EXISTS allSongsTemp"];
								[databaseControls.allSongsDb executeUpdate:@"CREATE TEMPORARY TABLE allSongsTemp (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
								tempSongsCount = 0;
								DLog(@"allSongsTemp flush time: %f  total records: %i", [[NSDate date] timeIntervalSinceDate:startTime3], totalSongsProcessed);
							}
							
							// If it has a genre, process that
							if (aSong.genre)
							{
								// Add the genre to the genre table
								[databaseControls.genresDb executeUpdate:@"INSERT INTO genresTemp (genre) VALUES (?)", aSong.genre];
								tempGenresCount++;
								
								if (tempGenresCount == WRITE_BUFFER_AMOUNT)
								{
									NSDate *startTime3 = [NSDate date];
									// Flush the records to disk
									[databaseControls.genresDb executeUpdate:@"INSERT OR IGNORE INTO genresUnsorted SELECT * FROM genresTemp"];
									//[databaseControls.genresDb executeUpdate:@"DELETE * FROM genresTemp"];
									[databaseControls.genresDb executeUpdate:@"DROP TABLE IF EXISTS genresTemp"];
									[databaseControls.genresDb executeUpdate:@"CREATE TEMPORARY TABLE genresTemp (genre TEXT)"];
									tempGenresCount = 0;
									DLog(@"genresTemp flush time: %f", [[NSDate date] timeIntervalSinceDate:startTime3]);
								}
								
								// Insert the song into the genresLayout table
								NSArray *splitPath = [aSong.path componentsSeparatedByString:@"/"];
								if ([splitPath count] <= 9)
								{
									NSMutableArray *segments = [[NSMutableArray alloc] initWithArray:splitPath];
									while ([segments count] < 9)
									{
										[segments addObject:@""];
									}
									
									NSString *query = @"INSERT INTO genresLayoutTemp (md5, genre, segs, seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8, seg9) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
									[databaseControls.genresDb executeUpdate:query, [NSString md5:aSong.path], aSong.genre, [NSNumber numberWithInt:[splitPath count]], [segments objectAtIndex:0], [segments objectAtIndex:1], [segments objectAtIndex:2], [segments objectAtIndex:3], [segments objectAtIndex:4], [segments objectAtIndex:5], [segments objectAtIndex:6], [segments objectAtIndex:7], [segments objectAtIndex:8]];
									tempGenresLayoutCount++;
									
									if (tempGenresLayoutCount == WRITE_BUFFER_AMOUNT)
									{
										NSDate *startTime3 = [NSDate date];
										// Flush the records to disk
										[databaseControls.genresDb executeUpdate:@"INSERT OR IGNORE INTO genresLayout SELECT * FROM genresLayoutTemp"];
										//[databaseControls.genresDb executeUpdate:@"DELETE * FROM genresLayoutTemp"];
										[databaseControls.genresDb executeUpdate:@"DROP TABLE IF EXISTS genresLayoutTemp"];
										[databaseControls.genresDb executeUpdate:@"CREATE TEMPORARY TABLE genresLayoutTemp (md5 TEXT, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
										tempGenresLayoutCount = 0;
										DLog(@"genresLayoutTemp flush time: %f", [[NSDate date] timeIntervalSinceDate:startTime3]);
									}
									
									[segments release];
								}
							}
						}
					}
					
					// Update the loading screen message
					if (iteration != -1)
					{
						[self sendSongNotification:aSong.title];
					}
					
					[aSong release];					
				}
				
				child = [TBXML nextSiblingNamed:kName_Child searchFromElement:child];
				
				[pool2 release];
            }
			//DLog(@"artist or album folder processing time: %f", [[NSDate date] timeIntervalSinceDate:startTime]);
        }
    }
    [tbxml release];
	
	// Close the connection
	//
	[theConnection release];
	[receivedData release];
	
	// Handle the iteration
	//
	currentRow++;
	//DLog(@"currentRow: %i", currentRow);
	
	if (iteration == -1)
	{
		// Processing artist folders
		if (currentRow == artistCount)
		{
			// Done loading artist folders
			currentRow = 1;
			iteration++;
			[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE resumeLoad"];
			
			// Flush the records to disk
			[databaseControls.allAlbumsDb executeUpdate:@"INSERT INTO allAlbumsUnsorted SELECT * FROM allAlbumsTemp"];
			[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE IF EXISTS allAlbumsTemp"];
			[databaseControls.allAlbumsDb executeUpdate:@"CREATE TEMPORARY TABLE allAlbumsTemp(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
			//[databaseControls.allAlbumsDb executeUpdate:@"DELETE * FROM allAlbumsTemp"];
			tempAlbumsCount = 0;
			
			// Flush the records to disk
			[databaseControls.allSongsDb executeUpdate:@"INSERT INTO allSongsUnsorted SELECT * FROM allSongsTemp"];
			//[databaseControls.allSongsDb executeUpdate:@"DELETE * FROM allSongsTemp"];
			[databaseControls.allSongsDb executeUpdate:@"DROP TABLE IF EXISTS allSongsTemp"];
			[databaseControls.allSongsDb executeUpdate:@"CREATE TEMPORARY TABLE allSongsTemp (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
			tempSongsCount = 0;
			
			// Flush the records to disk
			[databaseControls.genresDb executeUpdate:@"INSERT OR IGNORE INTO genresUnsorted SELECT * FROM genresTemp"];
			//[databaseControls.genresDb executeUpdate:@"DELETE * FROM genresTemp"];
			[databaseControls.genresDb executeUpdate:@"DROP TABLE IF EXISTS genresTemp"];
			[databaseControls.genresDb executeUpdate:@"CREATE TEMPORARY TABLE genresTemp (genre TEXT)"];
			tempGenresCount = 0;
			
			// Flush the records to disk
			[databaseControls.genresDb executeUpdate:@"INSERT OR IGNORE INTO genresLayout SELECT * FROM genresLayoutTemp"];
			//[databaseControls.genresDb executeUpdate:@"DELETE * FROM genresLayoutTemp"];
			[databaseControls.genresDb executeUpdate:@"DROP TABLE IF EXISTS genresLayoutTemp"];
			[databaseControls.genresDb executeUpdate:@"CREATE TEMPORARY TABLE genresLayoutTemp (md5 TEXT, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
			tempGenresLayoutCount = 0;
			
			NSUInteger count = [databaseControls.allAlbumsDb intForQuery:@"SELECT COUNT(*) FROM allAlbumsUnsorted"];
			[databaseControls.allAlbumsDb executeUpdate:@"INSERT INTO allAlbumsUnsortedCount VALUES (?)", [NSNumber numberWithInt:count]];
			
			[self startLoad];
		}
		else
		{
			[databaseControls.allAlbumsDb executeUpdate:@"UPDATE resumeLoad SET artistNum = ?", [NSNumber numberWithInt:currentRow]];
            
            // Load the next folder
            //
            if (iteration < 4)
            {
                [self loadAlbumFolder];
            }
            else if (iteration == 4)
            {
                DLog(@"calling loadSort");
                [self performSelectorInBackground:@selector(loadSort) withObject:nil];
            }
		}
	}
	else
	{
		// Processing album folders
		if (currentRow == albumCount)
		{
			// This iteration is done
			currentRow = 0;
			iteration++;
			[databaseControls.allSongsDb executeUpdate:@"UPDATE resumeLoad SET albumNum = ?, iteration = ?", [NSNumber numberWithInt:0], [NSNumber numberWithInt:iteration]];
			
			// Flush the records to disk
			[databaseControls.allAlbumsDb executeUpdate:@"INSERT INTO allAlbumsUnsorted SELECT * FROM allAlbumsTemp"];
			[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE IF EXISTS allAlbumsTemp"];
			[databaseControls.allAlbumsDb executeUpdate:@"CREATE TEMPORARY TABLE allAlbumsTemp(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
			//[databaseControls.allAlbumsDb executeUpdate:@"DELETE * FROM allAlbumsTemp"];
			tempAlbumsCount = 0;
			
			// Flush the records to disk
			[databaseControls.allSongsDb executeUpdate:@"INSERT INTO allSongsUnsorted SELECT * FROM allSongsTemp"];
			//[databaseControls.allSongsDb executeUpdate:@"DELETE * FROM allSongsTemp"];
			[databaseControls.allSongsDb executeUpdate:@"DROP TABLE IF EXISTS allSongsTemp"];
			[databaseControls.allSongsDb executeUpdate:@"CREATE TEMPORARY TABLE allSongsTemp (title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER)"];
			tempSongsCount = 0;
			
			// Flush the records to disk
			[databaseControls.genresDb executeUpdate:@"INSERT OR IGNORE INTO genresUnsorted SELECT * FROM genresTemp"];
			//[databaseControls.genresDb executeUpdate:@"DELETE * FROM genresTemp"];
			[databaseControls.genresDb executeUpdate:@"DROP TABLE IF EXISTS genresTemp"];
			[databaseControls.genresDb executeUpdate:@"CREATE TEMPORARY TABLE genresTemp (genre TEXT)"];
			tempGenresCount = 0;
			
			// Flush the records to disk
			[databaseControls.genresDb executeUpdate:@"INSERT INTO genresLayout SELECT * FROM genresLayoutTemp"];
			//[databaseControls.genresDb executeUpdate:@"DELETE * FROM genresLayoutTemp"];
			[databaseControls.genresDb executeUpdate:@"DROP TABLE IF EXISTS genresLayoutTemp"];
			[databaseControls.genresDb executeUpdate:@"CREATE TEMPORARY TABLE genresLayoutTemp (md5 TEXT, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
			tempGenresLayoutCount = 0;
			
			[self startLoad];
		}
		else
		{
			[databaseControls.allSongsDb executeUpdate:@"UPDATE resumeLoad SET albumNum = ?", [NSNumber numberWithInt:currentRow]];
            
            // Load the next folder
            //
            if (iteration < 4)
            {
                [self loadAlbumFolder];
            }
            else if (iteration == 4)
            {
                DLog(@"calling loadSort");
                [self performSelectorInBackground:@selector(loadSort) withObject:nil];
            }
		}
	}
	
	[pool release];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	//NSString *xmlResponse = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
	//DLog(@"%@", xmlResponse);
	//[self performSelectorInBackground:@selector(parseData:) withObject:theConnection];
	[self parseData:theConnection];
}


@end
