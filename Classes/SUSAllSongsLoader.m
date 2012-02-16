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
#import "FMDatabaseAdditions.h"
#import "NSString+md5.h"
#import "Artist.h"
#import "Album.h"
#import "Song.h"
#import "SUSRootFoldersDAO.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSNotificationCenter+MainThread.h"
#import "NSArray+Additions.h"

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

static BOOL isAllSongsLoading = NO;
+ (BOOL)isLoading { return isAllSongsLoading; }
+ (void)setIsLoading:(BOOL)isLoading { isAllSongsLoading = isLoading; }

@synthesize currentArtist, currentAlbum, rootFolders, notificationTimeArtist, notificationTimeAlbum, notificationTimeSong, notificationTimeArtistAlbum;
@synthesize iteration, artistCount, albumCount, currentRow;
@synthesize tempAlbumsCount, tempSongsCount, tempGenresCount, tempGenresLayoutCount;
@synthesize totalAlbumsProcessed, totalSongsProcessed;

- (void)setup
{
    [super setup];
    
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

- (SUSLoaderType)type
{
    return SUSLoaderType_AllSongs;
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
	self.tempAlbumsCount = 0;
	self.tempSongsCount = 0;
	self.tempGenresCount = 0;
	self.tempGenresLayoutCount = 0;
	
	self.totalAlbumsProcessed = 0;
	self.totalSongsProcessed = 0;
	
	[SUSAllSongsLoader setIsLoading:YES];
	
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
		self.iteration = -1;
		
		self.currentRow = [databaseControls.allAlbumsDb intForQuery:@"SELECT artistNum FROM resumeLoad"];
		self.artistCount = [databaseControls.albumListCacheDb intForQuery:@"SELECT count FROM rootFolderCount_all LIMIT 1"];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ISMSNotification_AllSongsLoadingArtists object:nil];
		
		[self loadAlbumFolder];	
	}
	else
	{
		// The songs are still loading or are just starting
		
		self.iteration = [databaseControls.allSongsDb intForQuery:@"SELECT iteration FROM resumeLoad"];
		
		if (self.iteration == 0)
		{
			self.currentRow = [databaseControls.allSongsDb intForQuery:@"SELECT albumNum FROM resumeLoad"];
			self.albumCount = [databaseControls.allAlbumsDb intForQuery:@"SELECT COUNT(*) FROM allAlbumsUnsorted"];
			DLog(@"albumCount: %i", albumCount);
			
			[[NSNotificationCenter defaultCenter] postNotificationName:ISMSNotification_AllSongsLoadingAlbums object:nil];
			
			[self loadAlbumFolder];
		}
		else if (iteration < 4)
		{
			self.currentRow = [databaseControls.allSongsDb intForQuery:@"SELECT albumNum FROM resumeLoad"];
			self.albumCount = [databaseControls.allAlbumsDb intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM subalbums%i", iteration]];
			DLog(@"subalbums%i albumCount: %i", self.iteration, self.albumCount);
			
			if (self.albumCount > 0)
			{
				[[NSNotificationCenter defaultCenter] postNotificationName:ISMSNotification_AllSongsLoadingAlbums object:nil];
				[self loadAlbumFolder];
			}
			else
			{
				// The table is empty so do the load sort
				self.iteration = 4;
				[databaseControls.allSongsDb executeUpdate:@"UPDATE resumeLoad SET albumNum = ?, iteration = ?", [NSNumber numberWithInt:0], [NSNumber numberWithInt:self.iteration]];
				DLog(@"calling loadSort");
				[self performSelectorInBackground:@selector(loadSort) withObject:nil];
			}
		}
		else if (self.iteration == 4)
		{
			DLog(@"calling loadSort");
			[self performSelectorInBackground:@selector(loadSort) withObject:nil];
		}
		else if (self.iteration == 5)
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
	NSString *query = [NSString stringWithFormat:@"CREATE TEMPORARY TABLE allSongsTemp (%@)", [Song standardSongColumnSchema]];
	[databaseControls.allSongsDb executeUpdate:query];
	
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
	NSString *query = [NSString stringWithFormat:@"CREATE VIRTUAL TABLE allSongs USING FTS3 (%@, tokenize=porter)", [Song standardSongColumnSchema]];
	[databaseControls.allSongsDb executeUpdate:query];
	//[databaseControls.allSongsDb executeUpdate:@"CREATE INDEX title ON allSongs (title ASC)"];
	//[databaseControls.allSongsDb executeUpdate:@"CREATE INDEX songGenre ON allSongs (genre)"];
	
	query = [NSString stringWithFormat:@"CREATE TABLE allSongsUnsorted (%@)", [Song standardSongColumnSchema]];
	[databaseControls.allSongsDb executeUpdate:query];
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
		[SUSAllSongsLoader setIsLoading:NO];
		[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:[NSString stringWithFormat:@"%@isAllAlbumsLoading", [SavedSettings sharedInstance].urlString]];
		[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:[NSString stringWithFormat:@"%@isAllSongsLoading", settings.urlString]];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[self informDelegateLoadingFailed:nil];
		return;
	}
	
	if (self.iteration == -1)
	{
		self.currentArtist = [self.rootFolders artistForPosition:self.currentRow];
		DLog(@"current artist: %@", self.currentArtist.name);
		
		[self sendArtistNotification:self.currentArtist.name];
	}
	else
	{
		if (self.iteration == 0)
			self.currentAlbum = [databaseControls albumFromDbRow:self.currentRow inTable:@"allAlbumsUnsorted" inDatabase:databaseControls.allAlbumsDb];
		else
			self.currentAlbum = [databaseControls albumFromDbRow:self.currentRow inTable:[NSString stringWithFormat:@"subalbums%i", self.iteration] inDatabase:databaseControls.allAlbumsDb];
		DLog(@"current album: %@", self.currentAlbum.title);
		
		self.currentArtist = [Artist artistWithName:self.currentAlbum.artistName andArtistId:self.currentAlbum.artistId];
		
		[self sendAlbumNotification:self.currentAlbum.title];
	}
	
	NSString *dirId = nil;
	if (self.iteration == -1)
		dirId = [[self.currentArtist.artistId copy] autorelease];
	else
		dirId = [[self.currentAlbum.albumId copy] autorelease];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:dirId forKey:@"id"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getMusicDirectory" andParameters:parameters];
    
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		self.receivedData = [NSMutableData data];
	} 
	else 
	{
		if (self.iteration == -1)
		{
			DLog(@"%@", [NSString stringWithFormat:@"There was an error grabbing the song list for artist: %@", self.currentArtist.name]);
		}
		else
		{
			DLog(@"%@", [NSString stringWithFormat:@"There was an error grabbing the song list for album: %@", self.currentAlbum.title]);
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
	NSString *query = [NSString stringWithFormat:@"CREATE VIRTUAL TABLE allSongs USING FTS3 (%@, tokenize=porter)", [Song standardSongColumnSchema]];
	[databaseControls.allSongsDb executeUpdate:query];
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
		[SUSAllSongsLoader setIsLoading:NO];
		[self informDelegateLoadingFailed:nil];
        return;
    }
    
    // Create the section info array
	NSArray *sectionInfo = [databaseControls sectionInfoFromTable:@"allAlbums" inDatabase:databaseControls.allAlbumsDb withColumn:@"title"];
    [databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE allAlbumsIndexCache"];
    [databaseControls.allAlbumsDb executeUpdate:@"CREATE TABLE allAlbumsIndexCache (name TEXT, position INTEGER, count INTEGER)"];
	for (int i = 0; i < [sectionInfo count]; i++)
    {
		NSArray *section = [sectionInfo objectAtIndexSafe:i];
		NSArray *nextSection = nil;
		if (i + 1 < [sectionInfo count])
			nextSection = [sectionInfo objectAtIndexSafe:i+1];
		
		NSString *name = [section objectAtIndexSafe:0];
		NSNumber *position = [section objectAtIndexSafe:1];
		DLog(@"position: %i", [position intValue]);
		NSNumber *count = nil;
		if (nextSection)
			count = [NSNumber numberWithInt:([[nextSection objectAtIndexSafe:1] intValue] - [position intValue])];
		else
			count = [NSNumber numberWithInt:[databaseControls.allAlbumsDb intForQuery:@"SELECT COUNT(*) FROM allAlbums WHERE ROWID > ?", position]];
		
        [databaseControls.allAlbumsDb executeUpdate:@"INSERT INTO allAlbumsIndexCache (name, position, count) VALUES (?, ?, ?)", name, position, count];
    }
	
	// Count the table
	NSUInteger allAlbumsCount = 0;
	FMResultSet *result = [databaseControls.allAlbumsDb executeQuery:@"SELECT count FROM allAlbumsIndexCache"];
	while ([result next])
	{
		allAlbumsCount += [result intForColumn:@"count"];
	}
	[result close];
    [databaseControls.allAlbumsDb executeUpdate:@"INSERT INTO allAlbumsCount VALUES (?)", [NSNumber numberWithInt:allAlbumsCount]];

	// Create the section info array
    sectionInfo = [databaseControls sectionInfoFromTable:@"allSongs" inDatabase:databaseControls.allSongsDb withColumn:@"title"];
    [databaseControls.allSongsDb executeUpdate:@"DROP TABLE allSongsIndexCache"];
    [databaseControls.allSongsDb executeUpdate:@"CREATE TABLE allSongsIndexCache (name TEXT, position INTEGER, count INTEGER)"];
	for (int i = 0; i < [sectionInfo count]; i++)
    {
		NSArray *section = [sectionInfo objectAtIndexSafe:i];
		NSArray *nextSection = nil;
		if (i + 1 < [sectionInfo count])
			nextSection = [sectionInfo objectAtIndexSafe:i+1];
		
		NSString *name = [section objectAtIndexSafe:0];
		NSNumber *position = [section objectAtIndexSafe:1];
		NSNumber *count = nil;
		if (nextSection)
			count = [NSNumber numberWithInt:([[nextSection objectAtIndexSafe:1] intValue] - [position intValue])];
		else
			count = [NSNumber numberWithInt:[databaseControls.allSongsDb intForQuery:@"SELECT COUNT(*) FROM allSongs WHERE ROWID > ?", position]];
		
        [databaseControls.allSongsDb executeUpdate:@"INSERT INTO allSongsIndexCache (name, position, count) VALUES (?, ?, ?)", name, position, count];
    }
	
	// Count the table
	NSUInteger allSongsCount = 0;
	result = [databaseControls.allSongsDb executeQuery:@"SELECT count FROM allSongsIndexCache"];
	while ([result next])
	{
		allSongsCount += [result intForColumn:@"count"];
	}
	[result close];
    [databaseControls.allSongsDb executeUpdate:@"INSERT INTO allSongsCount VALUES (?)", [NSNumber numberWithInt:allSongsCount]];
	
	// Check if loading should stop
    if (viewObjects.cancelLoading)
    {
        [SUSAllSongsLoader setIsLoading:NO];
        [self informDelegateLoadingFailed:nil];
        return;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSDate date] forKey:[NSString stringWithFormat:@"%@songsReloadTime", settings.urlString]];
    [defaults synchronize];
    
    [databaseControls.allSongsDb executeUpdate:@"UPDATE resumeLoad SET albumNum = ?, iteration = ?", [NSNumber numberWithInt:0], [NSNumber numberWithInt:6]];
	
	[SUSAllSongsLoader setIsLoading:NO];
	[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:[NSString stringWithFormat:@"%@isAllAlbumsLoading", settings.urlString]];
	[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:[NSString stringWithFormat:@"%@isAllSongsLoading", settings.urlString]];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	[databaseControls.allSongsDb executeUpdate:@"DROP TABLE resumeLoad"];
	
	[self performSelectorOnMainThread:@selector(informDelegateLoadingFinished) withObject:nil waitUntilDone:NO];
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_AllSongsLoadingFinished];
        
    [autoreleasePool release];
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
	if ([[NSDate date] timeIntervalSinceDate:self.notificationTimeArtist] > .5)
	{
		self.notificationTimeArtist = [NSDate date];
		[[NSNotificationCenter defaultCenter] postNotificationName:ISMSNotification_AllSongsArtistName object:artistName];
	}
}

- (void)sendAlbumNotification:(NSString *)albumTitle
{
	if ([[NSDate date] timeIntervalSinceDate:self.notificationTimeAlbum] > .5)
	{
		self.notificationTimeAlbum = [NSDate date];
		[[NSNotificationCenter defaultCenter] postNotificationName:ISMSNotification_AllSongsAlbumName object:albumTitle];
	}
}

- (void)sendSongNotification:(NSString *)songTitle
{
	if ([[NSDate date] timeIntervalSinceDate:self.notificationTimeSong] > .5)
	{
		self.notificationTimeSong = [NSDate date];
		[[NSNotificationCenter defaultCenter] postNotificationName:ISMSNotification_AllSongsSongName object:songTitle];
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
	// Load the same folder
	//
	[self loadAlbumFolder];
	
	self.receivedData = nil;
	self.connection = nil;
	
	// Inform the delegate that loading failed
	[self informDelegateLoadingFailed:error];
}	

static NSString *kName_Directory = @"directory";
static NSString *kName_Child = @"child";
static NSString *kName_Error = @"error";

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
	TBXML *tbxml = [[TBXML alloc] initWithXMLData:self.receivedData];
    TBXMLElement *root = tbxml.rootXMLElement;
    if (root) 
	{
		TBXMLElement *error = [TBXML childElementNamed:kName_Error parentElement:root];
		if (error)
		{
			NSString *code = [TBXML valueOfAttributeNamed:@"code" forElement:error];
			NSString *message = [TBXML valueOfAttributeNamed:@"message" forElement:error];
			[self subsonicErrorCode:[code intValue] message:message];
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
					Album *anAlbum = [[Album alloc] initWithTBXMLElement:child artistId:self.currentArtist.artistId artistName:self.currentArtist.name];
					
					// Skip if it's .AppleDouble, otherwise process it
					if (![anAlbum.title isEqualToString:@".AppleDouble"])
					{
						if (self.iteration == -1)
						{
							// Add the album to the allAlbums table
							[databaseControls insertAlbum:anAlbum intoTable:@"allAlbumsTemp" inDatabase:databaseControls.allAlbumsDb];
							self.tempAlbumsCount++;
							self.totalAlbumsProcessed++;
							
							if (self.tempAlbumsCount == WRITE_BUFFER_AMOUNT)
							{
								// Flush the records to disk
								[databaseControls.allAlbumsDb executeUpdate:@"INSERT INTO allAlbumsUnsorted SELECT * FROM allAlbumsTemp"];
								//[databaseControls.allAlbumsDb executeUpdate:@"DELETE * FROM allAlbumsTemp"];
								[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE IF EXISTS allAlbumsTemp"];
								[databaseControls.allAlbumsDb executeUpdate:@"CREATE TEMPORARY TABLE allAlbumsTemp(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
								self.tempAlbumsCount = 0;
							}
						}
						else
						{
							//Add album object to the subalbums table to be processed in the next iteration
							[databaseControls insertAlbum:anAlbum intoTable:[NSString stringWithFormat:@"subalbums%i", (self.iteration + 1)] inDatabase:databaseControls.allAlbumsDb];
						}
					}
					
					// Update the loading screen message
					if (self.iteration == -1)
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
							[aSong insertIntoTable:@"allSongsTemp" inDatabase:databaseControls.allSongsDb];
							self.tempSongsCount++;
							self.totalSongsProcessed++;
							
							if (self.tempSongsCount == WRITE_BUFFER_AMOUNT)
							{
								// Flush the records to disk
								[databaseControls.allSongsDb executeUpdate:@"INSERT INTO allSongsUnsorted SELECT * FROM allSongsTemp"];
								//[databaseControls.allSongsDb executeUpdate:@"DELETE * FROM allSongsTemp"];
								[databaseControls.allSongsDb executeUpdate:@"DROP TABLE IF EXISTS allSongsTemp"];
								NSString *query = [NSString stringWithFormat:@"CREATE TEMPORARY TABLE allSongsTemp (%@)", [Song standardSongColumnSchema]];
								[databaseControls.allSongsDb executeUpdate:query];
								self.tempSongsCount = 0;
							}
							
							// If it has a genre, process that
							if (aSong.genre)
							{
								// Add the genre to the genre table
								[databaseControls.genresDb executeUpdate:@"INSERT INTO genresTemp (genre) VALUES (?)", aSong.genre];
								self.tempGenresCount++;
								
								if (self.tempGenresCount == WRITE_BUFFER_AMOUNT)
								{
									// Flush the records to disk
									[databaseControls.genresDb executeUpdate:@"INSERT OR IGNORE INTO genresUnsorted SELECT * FROM genresTemp"];
									//[databaseControls.genresDb executeUpdate:@"DELETE * FROM genresTemp"];
									[databaseControls.genresDb executeUpdate:@"DROP TABLE IF EXISTS genresTemp"];
									[databaseControls.genresDb executeUpdate:@"CREATE TEMPORARY TABLE genresTemp (genre TEXT)"];
									self.tempGenresCount = 0;
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
									[databaseControls.genresDb executeUpdate:query, [aSong.path md5], aSong.genre, [NSNumber numberWithInt:[splitPath count]], [segments objectAtIndexSafe:0], [segments objectAtIndexSafe:1], [segments objectAtIndexSafe:2], [segments objectAtIndexSafe:3], [segments objectAtIndexSafe:4], [segments objectAtIndexSafe:5], [segments objectAtIndexSafe:6], [segments objectAtIndexSafe:7], [segments objectAtIndexSafe:8]];
									self.tempGenresLayoutCount++;
									
									if (tempGenresLayoutCount == WRITE_BUFFER_AMOUNT)
									{
										// Flush the records to disk
										[databaseControls.genresDb executeUpdate:@"INSERT OR IGNORE INTO genresLayout SELECT * FROM genresLayoutTemp"];
										//[databaseControls.genresDb executeUpdate:@"DELETE * FROM genresLayoutTemp"];
										[databaseControls.genresDb executeUpdate:@"DROP TABLE IF EXISTS genresLayoutTemp"];
										[databaseControls.genresDb executeUpdate:@"CREATE TEMPORARY TABLE genresLayoutTemp (md5 TEXT, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
										self.tempGenresLayoutCount = 0;
									}
									
									[segments release];
								}
							}
						}
					}
					
					// Update the loading screen message
					if (self.iteration != -1)
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
	self.connection = nil;
	self.receivedData = nil;
	
	// Handle the iteration
	//
	self.currentRow++;
	//DLog(@"currentRow: %i", currentRow);
	
	if (self.iteration == -1)
	{
		// Processing artist folders
		if (self.currentRow == self.artistCount)
		{
			// Done loading artist folders
			self.currentRow = 1;
			self.iteration++;
			[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE resumeLoad"];
			
			// Flush the records to disk
			[databaseControls.allAlbumsDb executeUpdate:@"INSERT INTO allAlbumsUnsorted SELECT * FROM allAlbumsTemp"];
			[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE IF EXISTS allAlbumsTemp"];
			[databaseControls.allAlbumsDb executeUpdate:@"CREATE TEMPORARY TABLE allAlbumsTemp(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
			//[databaseControls.allAlbumsDb executeUpdate:@"DELETE * FROM allAlbumsTemp"];
			self.tempAlbumsCount = 0;
			
			// Flush the records to disk
			[databaseControls.allSongsDb executeUpdate:@"INSERT INTO allSongsUnsorted SELECT * FROM allSongsTemp"];
			//[databaseControls.allSongsDb executeUpdate:@"DELETE * FROM allSongsTemp"];
			[databaseControls.allSongsDb executeUpdate:@"DROP TABLE IF EXISTS allSongsTemp"];
			NSString *query = [NSString stringWithFormat:@"CREATE TEMPORARY TABLE allSongsTemp (%@)", [Song standardSongColumnSchema]];
			[databaseControls.allSongsDb executeUpdate:query];
			self.tempSongsCount = 0;
			
			// Flush the records to disk
			[databaseControls.genresDb executeUpdate:@"INSERT OR IGNORE INTO genresUnsorted SELECT * FROM genresTemp"];
			//[databaseControls.genresDb executeUpdate:@"DELETE * FROM genresTemp"];
			[databaseControls.genresDb executeUpdate:@"DROP TABLE IF EXISTS genresTemp"];
			[databaseControls.genresDb executeUpdate:@"CREATE TEMPORARY TABLE genresTemp (genre TEXT)"];
			self.tempGenresCount = 0;
			
			// Flush the records to disk
			[databaseControls.genresDb executeUpdate:@"INSERT OR IGNORE INTO genresLayout SELECT * FROM genresLayoutTemp"];
			//[databaseControls.genresDb executeUpdate:@"DELETE * FROM genresLayoutTemp"];
			[databaseControls.genresDb executeUpdate:@"DROP TABLE IF EXISTS genresLayoutTemp"];
			[databaseControls.genresDb executeUpdate:@"CREATE TEMPORARY TABLE genresLayoutTemp (md5 TEXT, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
			self.tempGenresLayoutCount = 0;
			
			NSUInteger count = [databaseControls.allAlbumsDb intForQuery:@"SELECT COUNT(*) FROM allAlbumsUnsorted"];
			[databaseControls.allAlbumsDb executeUpdate:@"INSERT INTO allAlbumsUnsortedCount VALUES (?)", [NSNumber numberWithInt:count]];
			
			[self startLoad];
		}
		else
		{
			[databaseControls.allAlbumsDb executeUpdate:@"UPDATE resumeLoad SET artistNum = ?", [NSNumber numberWithInt:self.currentRow]];
            
            // Load the next folder
            //
            if (self.iteration < 4)
            {
                [self loadAlbumFolder];
            }
            else if (self.iteration == 4)
            {
                DLog(@"calling loadSort");
                [self performSelectorInBackground:@selector(loadSort) withObject:nil];
            }
		}
	}
	else
	{
		// Processing album folders
		if (self.currentRow == self.albumCount)
		{
			// This iteration is done
			self.currentRow = 0;
			self.iteration++;
			[databaseControls.allSongsDb executeUpdate:@"UPDATE resumeLoad SET albumNum = ?, iteration = ?", [NSNumber numberWithInt:0], [NSNumber numberWithInt:self.iteration]];
			
			// Flush the records to disk
			[databaseControls.allAlbumsDb executeUpdate:@"INSERT INTO allAlbumsUnsorted SELECT * FROM allAlbumsTemp"];
			[databaseControls.allAlbumsDb executeUpdate:@"DROP TABLE IF EXISTS allAlbumsTemp"];
			[databaseControls.allAlbumsDb executeUpdate:@"CREATE TEMPORARY TABLE allAlbumsTemp(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
			//[databaseControls.allAlbumsDb executeUpdate:@"DELETE * FROM allAlbumsTemp"];
			self.tempAlbumsCount = 0;
			
			// Flush the records to disk
			[databaseControls.allSongsDb executeUpdate:@"INSERT INTO allSongsUnsorted SELECT * FROM allSongsTemp"];
			//[databaseControls.allSongsDb executeUpdate:@"DELETE * FROM allSongsTemp"];
			[databaseControls.allSongsDb executeUpdate:@"DROP TABLE IF EXISTS allSongsTemp"];
			NSString *query = [NSString stringWithFormat:@"CREATE TEMPORARY TABLE allSongsTemp (%@)", [Song standardSongColumnSchema]];
			[databaseControls.allSongsDb executeUpdate:query];
			self.tempSongsCount = 0;
			
			// Flush the records to disk
			[databaseControls.genresDb executeUpdate:@"INSERT OR IGNORE INTO genresUnsorted SELECT * FROM genresTemp"];
			//[databaseControls.genresDb executeUpdate:@"DELETE * FROM genresTemp"];
			[databaseControls.genresDb executeUpdate:@"DROP TABLE IF EXISTS genresTemp"];
			[databaseControls.genresDb executeUpdate:@"CREATE TEMPORARY TABLE genresTemp (genre TEXT)"];
			self.tempGenresCount = 0;
			
			// Flush the records to disk
			[databaseControls.genresDb executeUpdate:@"INSERT INTO genresLayout SELECT * FROM genresLayoutTemp"];
			//[databaseControls.genresDb executeUpdate:@"DELETE * FROM genresLayoutTemp"];
			[databaseControls.genresDb executeUpdate:@"DROP TABLE IF EXISTS genresLayoutTemp"];
			[databaseControls.genresDb executeUpdate:@"CREATE TEMPORARY TABLE genresLayoutTemp (md5 TEXT, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
			self.tempGenresLayoutCount = 0;
			
			[self startLoad];
		}
		else
		{
			[databaseControls.allSongsDb executeUpdate:@"UPDATE resumeLoad SET albumNum = ?", [NSNumber numberWithInt:self.currentRow]];
            
            // Load the next folder
            //
            if (self.iteration < 4)
            {
                [self loadAlbumFolder];
            }
            else if (self.iteration == 4)
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
