//
//  SUSSubFolderDAO.m
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSSubFolderDAO.h"
#import "DatabaseSingleton.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMResultSet.h"
#import "SUSSubFolderLoader.h"
#import "NSString+md5.h"
#import "Album.h"
#import "Song.h"
#import "MusicSingleton.h"
#import "SavedSettings.h"

@interface SUSSubFolderDAO (Private) 
- (NSUInteger)findFirstAlbumRow;
- (NSUInteger)findFirstSongRow;
- (NSUInteger)findAlbumsCount;
- (NSUInteger)findSongsCount;
- (NSUInteger)findFolderLength;
@end

@implementation SUSSubFolderDAO
@synthesize delegate, loader, myId, myArtist;
@synthesize albumsCount, songsCount, folderLength;

#pragma mark - Lifecycle

- (void)setup
{
    albumStartRow = [self findFirstAlbumRow];
    songStartRow = [self findFirstSongRow];
    albumsCount = [self findAlbumsCount];
    songsCount = [self findSongsCount];
    folderLength = [self findFolderLength];
	//DLog(@"albumsCount: %i", albumsCount);
	//DLog(@"songsCount: %i", songsCount);
}

- (id)init
{
    if ((self = [super init])) 
	{
		[self setup];
    }
    
    return self;
}

- (id)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate
{
    if ((self = [super init])) 
	{
		self.delegate = theDelegate;
		[self setup];
    }
    
    return self;
}

- (id)initWithDelegate:(id<SUSLoaderDelegate>)theDelegate andId:(NSString *)folderId andArtist:(Artist *)anArtist
{
	if ((self = [super init])) 
	{
		self.delegate = theDelegate;
        self.myId = folderId;
		self.myArtist = anArtist;
		[self setup];
    }
    
    return self;
}

- (void)dealloc
{
	[myId release]; myId = nil;
	[myArtist release]; myArtist = nil;
	loader.delegate = nil;
	[loader release]; loader = nil;
	[super dealloc];
}

- (FMDatabase *)db
{
    return [[DatabaseSingleton sharedInstance] albumListCacheDb]; 
}

#pragma mark - Private DB Methods

- (NSUInteger)findFirstAlbumRow
{
    return [self.db intForQuery:@"SELECT rowid FROM albumsCache WHERE folderId = ? LIMIT 1", [self.myId md5]];
}

- (NSUInteger)findFirstSongRow
{
    return [self.db intForQuery:@"SELECT rowid FROM songsCache WHERE folderId = ? LIMIT 1", [self.myId md5]];
}

- (NSUInteger)findAlbumsCount
{
    return [self.db intForQuery:@"SELECT count FROM albumsCacheCount WHERE folderId = ?", [self.myId md5]];
}

- (NSUInteger)findSongsCount
{
    return [self.db intForQuery:@"SELECT count FROM songsCacheCount WHERE folderId = ?", [self.myId md5]];
}

- (NSUInteger)findFolderLength
{
    return [self.db intForQuery:@"SELECT length FROM folderLength WHERE folderId = ?", [self.myId md5]];
}

- (Album *)findAlbumForDbRow:(NSUInteger)row
{
    Album *anAlbum = [[Album alloc] init];
	FMResultSet *result = [self.db executeQuery:[NSString stringWithFormat:@"SELECT * FROM albumsCache WHERE ROWID = %i", row]];
	[result next];
	if ([self.db hadError]) 
	{
		DLog(@"Err %d: %@", [self.db lastErrorCode], [self.db lastErrorMessage]);
	}
	else
	{
		if ([result stringForColumn:@"title"] != nil)
			anAlbum.title = [NSString stringWithString:[result stringForColumn:@"title"]];
		if ([result stringForColumn:@"albumId"] != nil)
			anAlbum.albumId = [NSString stringWithString:[result stringForColumn:@"albumId"]];
		if ([result stringForColumn:@"coverArtId"] != nil)
			anAlbum.coverArtId = [NSString stringWithString:[result stringForColumn:@"coverArtId"]];
		if ([result stringForColumn:@"artistName"] != nil)
			anAlbum.artistName = [NSString stringWithString:[result stringForColumn:@"artistName"]];
		if ([result stringForColumn:@"artistId"] != nil)
			anAlbum.artistId = [NSString stringWithString:[result stringForColumn:@"artistId"]];
	}
	[result close];
	
	return [anAlbum autorelease];

}

- (Song *)findSongForDbRow:(NSUInteger)row
{
    Song *aSong = [[Song alloc] init];
	FMResultSet *result = [self.db executeQuery:[NSString stringWithFormat:@"SELECT * FROM songsCache WHERE ROWID = %i", row]];
	[result next];
	if ([self.db hadError]) 
	{
		DLog(@"Err %d: %@", [self.db lastErrorCode], [self.db lastErrorMessage]);
	}
	else
	{
		if ([result stringForColumn:@"title"] != nil)
			aSong.title = [NSString stringWithString:[result stringForColumn:@"title"]];
		if ([result stringForColumn:@"songId"] != nil)
			aSong.songId = [NSString stringWithString:[result stringForColumn:@"songId"]];
		if ([result stringForColumn:@"artist"] != nil)
			aSong.artist = [NSString stringWithString:[result stringForColumn:@"artist"]];
		if ([result stringForColumn:@"album"] != nil)
			aSong.album = [NSString stringWithString:[result stringForColumn:@"album"]];
		if ([result stringForColumn:@"genre"] != nil)
			aSong.genre = [NSString stringWithString:[result stringForColumn:@"genre"]];
		if ([result stringForColumn:@"coverArtId"] != nil)
			aSong.coverArtId = [NSString stringWithString:[result stringForColumn:@"coverArtId"]];
		if ([result stringForColumn:@"path"] != nil)
			aSong.path = [NSString stringWithString:[result stringForColumn:@"path"]];
		if ([result stringForColumn:@"suffix"] != nil)
			aSong.suffix = [NSString stringWithString:[result stringForColumn:@"suffix"]];
		if ([result stringForColumn:@"transcodedSuffix"] != nil)
			aSong.transcodedSuffix = [NSString stringWithString:[result stringForColumn:@"transcodedSuffix"]];
		aSong.duration = [NSNumber numberWithInt:[result intForColumn:@"duration"]];
		aSong.bitRate = [NSNumber numberWithInt:[result intForColumn:@"bitRate"]];
		aSong.track = [NSNumber numberWithInt:[result intForColumn:@"track"]];
		aSong.year = [NSNumber numberWithInt:[result intForColumn:@"year"]];
		aSong.size = [NSNumber numberWithInt:[result intForColumn:@"size"]];
	}
	
	[result close];
	
	if (aSong.path == nil)
	{
		[aSong release];
		return nil;
	}
	else
	{
		return [aSong autorelease];
	}
}

- (void)playSongAtDbRow:(NSUInteger)row
{
	MusicSingleton *musicControls = [MusicSingleton sharedInstance];
	
	// Clear the current playlist
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
		[[DatabaseSingleton sharedInstance] resetJukeboxPlaylist];
	else
		[[DatabaseSingleton sharedInstance] resetCurrentPlaylistDb];
	
	// Add the songs to the playlist
	NSMutableArray *songIds = [[NSMutableArray alloc] init];
	for (int i = self.albumsCount; i < self.totalCount; i++)
	{
		@autoreleasepool 
		{
			Song *aSong = [self songForTableViewRow:i];
			//DLog(@"adding song to playlist: %@", aSong);
			[aSong addToPlaylistQueue];
			
			// In jukebox mode, collect the song ids to send to the server
			if ([SavedSettings sharedInstance].isJukeboxEnabled)
				[songIds addObject:aSong.songId];
		}
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
	[musicControls playSongAtPosition:(row - songStartRow)];
}

#pragma mark - Public DAO Methods

- (BOOL)hasLoaded
{
    if (albumsCount > 0 || songsCount > 0)
        return YES;
    
    return NO;
}

- (NSUInteger)totalCount
{
    return albumsCount + songsCount;
}

- (Album *)albumForTableViewRow:(NSUInteger)row
{
    NSUInteger dbRow = albumStartRow + row;
    
    return [self findAlbumForDbRow:dbRow];
}

- (Song *)songForTableViewRow:(NSUInteger)row
{
    NSUInteger dbRow = songStartRow + (row - albumsCount);
    
    return [self findSongForDbRow:dbRow];
}

- (void)playSongAtTableViewRow:(NSUInteger)row
{
	NSUInteger dbRow = songStartRow + (row - albumsCount);
	[self playSongAtDbRow:dbRow];
}

- (NSArray *)sectionInfo
{
	// Create the section index
	if (albumsCount > 10)
	{
		[self.db executeUpdate:@"DROP TABLE IF EXISTS albumIndex"];
		[self.db executeUpdate:@"CREATE TEMPORARY TABLE albumIndex (title TEXT)"];
		
		[self.db executeUpdate:@"INSERT INTO albumIndex SELECT title FROM albumsCache WHERE rowid >= ? LIMIT ?", [NSNumber numberWithInt:albumStartRow], [NSNumber numberWithInt:albumsCount]];
		
		DLog(@"albumStartRow: %@    albumsCount: %@", [NSNumber numberWithInt:albumStartRow], [NSNumber numberWithInt:albumsCount]);
		DLog(@"total table count: %i", [self.db intForQuery:@"SELECT count(title) FROM albumsCache"]);
		DLog(@"count in table: %i", [self.db intForQuery:@"SELECT count(title) FROM albumsCache WHERE rowid >= ? LIMIT ?", [NSNumber numberWithInt:albumStartRow], [NSNumber numberWithInt:albumsCount]]);
		DLog(@"albumIndex count: %i", [self.db intForQuery:@"SELECT COUNT(*) FROM albumIndex"]);
		NSArray *sectionInfo = [[DatabaseSingleton sharedInstance] sectionInfoFromTable:@"albumIndex" inDatabase:self.db withColumn:@"title"];
		DLog(@"sectionInfo: %@", sectionInfo);
		if (sectionInfo)
		{
			if ([sectionInfo count] < 5)
				return nil;
			else
				return sectionInfo;
		}
		
		[self.db executeUpdate:@"DROP TABLE IF EXISTS albumIndex"];
	}
	
	return nil;
}

#pragma mark - Loader Manager Methods

- (void)restartLoad
{
    [self startLoad];
}

- (void)startLoad
{	
    self.loader = [[[SUSSubFolderLoader alloc] initWithDelegate:self] autorelease];
    loader.myId = self.myId;
    loader.myArtist = self.myArtist;
    [loader startLoad];
}

- (void)cancelLoad
{
    [loader cancelLoad];
    self.loader = nil;
}

#pragma mark - Loader Delegate Methods

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error
{
	theLoader.delegate = nil;
	[self.delegate loadingFailed:theLoader withError:error];
}

- (void)loadingFinished:(SUSLoader*)theLoader
{
	theLoader.delegate = nil;
    [self setup];
	[self.delegate loadingFinished:theLoader];
}

@end
