//
//  SUSSubFolderDAO.m
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSSubFolderDAO.h"
#import "DatabaseSingleton.h"
#import "FMDatabaseAdditions.h"
#import "FMResultSet.h"
#import "SUSSubFolderLoader.h"
#import "NSString+md5.h"
#import "Album.h"
#import "Song.h"
#import "MusicSingleton.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "JukeboxSingleton.h"

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
	[self cancelLoad];
	[super dealloc];
}

- (FMDatabase *)db
{
    return [databaseS albumListCacheDb]; 
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
	return [Song songFromDbRow:row-1 inTable:@"songsCache" inDatabase:self.db];
}

- (void)playSongAtDbRow:(NSUInteger)row
{
	
	// Clear the current playlist
	if (settingsS.isJukeboxEnabled)
		[databaseS resetJukeboxPlaylist];
	else
		[databaseS resetCurrentPlaylistDb];
	
	// Add the songs to the playlist
	NSMutableArray *songIds = [[NSMutableArray alloc] init];
	for (int i = self.albumsCount; i < self.totalCount; i++)
	{
		@autoreleasepool 
		{
			Song *aSong = [self songForTableViewRow:i];
			//DLog(@"song parentId: %@", aSong.parentId);
			//DLog(@"adding song to playlist: %@", aSong);
			[aSong addToCurrentPlaylist];
			
			// In jukebox mode, collect the song ids to send to the server
			if (settingsS.isJukeboxEnabled)
				[songIds addObject:aSong.songId];
		}
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
	[musicS playSongAtPosition:(row - songStartRow)];
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
		NSArray *sectionInfo = [databaseS sectionInfoFromTable:@"albumIndex" inDatabase:self.db withColumn:@"title"];
		
		[self.db executeUpdate:@"DROP TABLE IF EXISTS albumIndex"];
		
		return [sectionInfo count] < 5 ? nil : sectionInfo;
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
    self.loader.myId = self.myId;
    self.loader.myArtist = self.myArtist;
    [self.loader startLoad];
}

- (void)cancelLoad
{
    [self.loader cancelLoad];
	self.loader.delegate = nil;
    self.loader = nil;
}

#pragma mark - Loader Delegate Methods

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error
{
	self.loader.delegate = nil;
	self.loader = nil;
	
	if ([self.delegate respondsToSelector:@selector(loadingFailed:withError:)])
	{
		[self.delegate loadingFailed:nil withError:error];
	}
}

- (void)loadingFinished:(SUSLoader*)theLoader
{
	self.loader.delegate = nil;
	self.loader = nil;
	
    [self setup];
	
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[self.delegate loadingFinished:nil];
	}
}

@end
