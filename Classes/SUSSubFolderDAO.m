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
#import "NSString-md5.h"
#import "Album.h"
#import "Song.h"

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
		[self setup];
        self.delegate = theDelegate;
    }
    
    return self;
}

- (void)dealloc
{
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
	[self.delegate loadingFailed:theLoader withError:error];
}

- (void)loadingFinished:(SUSLoader*)theLoader
{
    [self setup];
	[self.delegate loadingFinished:theLoader];
}

@end
