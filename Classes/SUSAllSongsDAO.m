//
//  SUSAllSongsDAO.m
//  iSub
//
//  Created by Ben Baron on 9/23/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSAllSongsDAO.h"
#import "SUSAllSongsLoader.h"
#import "Index.h"
#import "Song.h"
#import "DatabaseSingleton.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

@implementation SUSAllSongsDAO

@synthesize loader, delegate;

- (void)setup
{
	delegate = nil;
	loader = nil;
	index = nil;
}

- (id)init
{
    if ((self = [super init]))
	{
        [self setup];
    }
    
    return self;
}

- (id)initWithDelegate:(NSObject <SUSLoaderDelegate> *)theDelegate
{
    if ((self = [super init]))
	{
		[self setup];
		delegate = theDelegate;
    }
    
    return self;
}

- (void)dealloc
{
	loader.delegate = nil;
	[loader release]; loader = nil;
	[index release]; index = nil;
	
	[super dealloc];
}

- (FMDatabase *)db
{
    return [[DatabaseSingleton sharedInstance] allSongsDb]; 
}

#pragma mark - Private Methods

- (NSUInteger)allSongsCount
{
	NSUInteger value = 0;
	
	if ([self.db tableExists:@"allSongsCount"] && [self.db intForQuery:@"SELECT COUNT(*) FROM allSongsCount"] > 0)
	{
		value = [self.db intForQuery:@"SELECT count FROM allSongsCount LIMIT 1"];
	}
	
	return value;
}

- (NSUInteger)allSongsSearchCount
{
	NSUInteger value = [self.db intForQuery:@"SELECT count(*) FROM allSongsNameSearch"];
	
	return value;
}

- (NSArray *)allSongsIndex
{
	NSMutableArray *indexItems = [NSMutableArray arrayWithCapacity:0];
	
	FMResultSet *result = [self.db executeQuery:@"SELECT * FROM allSongsIndexCache"];
	while ([result next])
	{
		Index *item = [[Index alloc] init];
		item.name = [result stringForColumn:@"name"];
		item.position = [result intForColumn:@"position"];
		item.count = [result intForColumn:@"count"];
		[indexItems addObject:item];
		[item release];
	}
	[result close];
	
	return [NSArray arrayWithArray:indexItems];
}

- (Song *)allSongsSongForPosition:(NSUInteger)position
{
	return [Song songFromDbRow:position-1 inTable:@"allSongs" inDatabase:self.db];
	
	/*Song *aSong = [[Song alloc] init];
	FMResultSet *result = [self.db executeQuery:@"SELECT * FROM allSongs WHERE ROWID = ?", [NSNumber numberWithInt:position]];
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
		[aSong release]; aSong = nil;
	}
	
	return [aSong autorelease];*/
}

- (Song *)allSongsSongForPositionInSearch:(NSUInteger)position
{
	NSUInteger rowId = [self.db intForQuery:@"SELECT rowIdInAllSongs FROM allSongsNameSearch WHERE ROWID = ?", [NSNumber numberWithInt:position]];
	return [self allSongsSongForPosition:rowId];
}

- (void)allSongsClearSearch
{
	[self.db executeUpdate:@"DELETE FROM allSongsNameSearch"];
}

- (void)allSongsPerformSearch:(NSString *)name
{
	// Inialize the search DB
	[self.db executeUpdate:@"DROP TABLE IF EXISTS allSongsNameSearch"];
	[self.db executeUpdate:@"CREATE TEMPORARY TABLE allSongsNameSearch (rowIdInAllSongs INTEGER)"];
	
	// Perform the search
	NSString *query = @"INSERT INTO allSongsNameSearch SELECT ROWID FROM allSongs WHERE title LIKE ? LIMIT 100";
	[self.db executeUpdate:query, [NSString stringWithFormat:@"%%%@%%", name]];
	if ([self.db hadError]) {
		DLog(@"Err %d: %@", [self.db lastErrorCode], [self.db lastErrorMessage]);
	}
}

- (BOOL)allSongsIsDataLoaded
{
	BOOL isLoaded = NO;
	
	if ([self.db tableExists:@"allSongsCount"] && [self.db intForQuery:@"SELECT COUNT(*) FROM allSongsCount"] > 0)
	{
		isLoaded = YES;
	}
	
	return isLoaded;
}

#pragma mark - Public DAO Methods

- (NSUInteger)count
{
	return [self allSongsCount];
}

- (NSUInteger)searchCount
{
	return [self allSongsSearchCount];
}

- (NSArray *)index
{
	if (index == nil)
	{
		index = [[self allSongsIndex] retain];
	}
	
	return index;
}

- (Song *)songForPosition:(NSUInteger)position
{
	return [self allSongsSongForPosition:position];
}

- (Song *)songForPositionInSearch:(NSUInteger)position
{
	return [self allSongsSongForPositionInSearch:position];
}

- (void)clearSearchTable
{
	[self allSongsClearSearch];
}

- (void)searchForSongName:(NSString *)name
{
	[self allSongsPerformSearch:name];
}

- (BOOL)isDataLoaded
{
	return [self allSongsIsDataLoaded];
}

- (void)allSongsRestartLoad
{
	[self.db executeUpdate:@"CREATE TABLE restartLoad (a INTEGER)"];
}

#pragma mark - Loader Manager Methods

- (void)restartLoad
{
	if (![SUSAllSongsLoader isLoading])
	{
		[self allSongsRestartLoad];
		[self startLoad];
	}
}

- (void)startLoad
{
	if (![SUSAllSongsLoader isLoading])
	{
		[index release]; index = nil;
		self.loader = [[[SUSAllSongsLoader alloc] initWithDelegate:delegate] autorelease];
		[loader startLoad];
	}
}

- (void)cancelLoad
{
	if ([SUSAllSongsLoader isLoading])
	{
		[loader cancelLoad];
		loader.delegate = nil;
        self.loader = nil;
	}
}

#pragma mark - Loader Delegate Methods

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error
{	
	loader.delegate = nil;
	self.loader = nil;
	
	if ([delegate respondsToSelector:@selector(loadingFailed:withError:)])
	{
		[self.delegate loadingFailed:nil withError:error];
	}
}

- (void)loadingFinished:(SUSLoader*)theLoader
{	
	loader.delegate = nil;
	self.loader = nil;
	
	if ([delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[self.delegate loadingFinished:nil];
	}
}

@end