//
//  SUSAllAlbumsDAO.m
//  iSub
//
//  Created by Ben Baron on 9/23/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSAllAlbumsDAO.h"
#import "Index.h"
#import "Album.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "DatabaseSingleton.h"

@implementation SUSAllAlbumsDAO

- (void)setup
{
	count = NSUIntegerMax;
	index = nil;
		
	db = [[DatabaseSingleton sharedInstance] allAlbumsDb]; 
}

- (id)init
{
    if ((self = [super init]))
	{
        [self setup];
    }
    
    return self;
}

#pragma mark - Private Methods

- (NSUInteger)allAlbumsCount
{
	NSUInteger value = NSUIntegerMax;
	
	if ([db tableExists:@"allAlbumsCount"] && [db intForQuery:@"SELECT COUNT(*) FROM allAlbumsCount"] > 0)
	{
		value = [db intForQuery:@"SELECT count FROM allAlbumsCount LIMIT 1"];
	}
	
	return value;
}

- (NSUInteger)allAlbumsSearchCount
{
	NSUInteger value = NSUIntegerMax;
	
	if ([db tableExists:@"allAlbumsNameSearch"])
	{
		value = [db intForQuery:@"SELECT count(*) FROM allAlbumsNameSearch"];
	}
	
	return value;
}

- (NSArray *)allAlbumsIndex
{
	NSMutableArray *indexItems = [NSMutableArray arrayWithCapacity:0];
	
	FMResultSet *result = [db executeQuery:@"SELECT * FROM allAlbumsIndexCache"];
	while ([result next])
	{
		Index *item = [[Index alloc] init];
		item.name = [result stringForColumn:@"name"];
		item.position = [result intForColumn:@"position"];
		item.count = [result intForColumn:@"count"];
		[indexItems addObject:item];
	}
	[result close];
	
	return [NSArray arrayWithArray:indexItems];
}

- (Album *)allAlbumsAlbumForPosition:(NSUInteger)position
{
	Album *anAlbum = [[[Album alloc] init] autorelease];
	FMResultSet *result = [db executeQuery:@"SELECT * FROM allAlbums WHERE ROWID = %i", [NSNumber numberWithInt:position]];
	while ([result next])
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
	
	return anAlbum;
}

- (Album *)allAlbumsAlbumForPositionInSearch:(NSUInteger)position
{
	Album *anAlbum = [[[Album alloc] init] autorelease];
	FMResultSet *result = [db executeQuery:@"SELECT * FROM allAlbumsNameSearch WHERE ROWID = %i", [NSNumber numberWithInt:position]];
	while ([result next])
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
	
	return anAlbum;
}

- (void)allAlbumsClearSearch
{
	[db executeUpdate:@"DELETE FROM allAlbumsNameSearch"];
}

- (void)allAlbumsPerformSearch:(NSString *)name
{
	// Inialize the search DB
	[db executeUpdate:@"DROP TABLE IF EXISTS allAlbumsNameSearch"];
	[db executeUpdate:@"CREATE TEMPORARY TABLE allAlbumsNameSearch (id TEXT PRIMARY KEY, name TEXT)"];
	
	// Perform the search
	NSString *query = @"INSERT INTO allAlbumsNameSearch SELECT * FROM allAlbums WHERE name LIKE ? LIMIT 100";
	[db executeUpdate:query, [NSString stringWithFormat:@"%%%@%%", name]];
	if ([db hadError]) {
		DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
}

- (BOOL)allAlbumsIsDataLoaded
{
	BOOL isLoaded = NO;
	
	if ([db tableExists:@"allAlbumsCount"] && [db intForQuery:@"SELECT COUNT(*) FROM allAlbumsCount"] > 0)
	{
		isLoaded = YES;
	}
	
	return isLoaded;
}


#pragma mark - Public DAO Methods

- (NSUInteger)count
{
	if (count == NSUIntegerMax)
	{
		count = [self allAlbumsCount];
	}
	
	return count;
}

- (NSUInteger)searchCount
{
	return [self allAlbumsSearchCount];
}

- (NSArray *)index
{
	if (index == nil)
	{
		index = [[self allAlbumsIndex] retain];
	}
	
	return index;
}

- (Album *)albumForPosition:(NSUInteger)position
{
	return [self allAlbumsAlbumForPosition:position];
}

- (Album *)albumForPositionInSearch:(NSUInteger)position
{
	return [self allAlbumsAlbumForPositionInSearch:position];
}

- (void)clearSearchTable
{
	[self allAlbumsClearSearch];
}

- (void)searchForAlbumName:(NSString *)name
{
	[self allAlbumsPerformSearch:name];
}

- (BOOL)isDataLoaded
{
	return [self allAlbumsIsDataLoaded];
}


@end
