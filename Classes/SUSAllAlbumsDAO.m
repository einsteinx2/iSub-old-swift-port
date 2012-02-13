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
#import "FMDatabaseAdditions.h"
#import "DatabaseSingleton.h"

@implementation SUSAllAlbumsDAO

- (void)setup
{
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

- (FMDatabase *)db
{
    return [DatabaseSingleton sharedInstance].allAlbumsDb; 
}

#pragma mark - Private Methods

- (NSUInteger)allAlbumsCount
{
	NSUInteger value = 0;
	
	if ([self.db tableExists:@"allAlbumsCount"] && [self.db synchronizedIntForQuery:@"SELECT COUNT(*) FROM allAlbumsCount"] > 0)
	{
		value = [self.db synchronizedIntForQuery:@"SELECT count FROM allAlbumsCount LIMIT 1"];
	}
	
	return value;
}

- (NSUInteger)allAlbumsSearchCount
{
	[self.db synchronizedExecuteUpdate:@"CREATE TEMPORARY TABLE IF NOT EXISTS allAlbumsNameSearch (rowIdInAllAlbums INTEGER)"];
	NSUInteger value = [self.db synchronizedIntForQuery:@"SELECT count(*) FROM allAlbumsNameSearch"];
	
	DLog(@"allAlbumsNameSearch count: %i   value: %i", [self.db synchronizedIntForQuery:@"SELECT count(*) FROM allAlbumsNameSearch"], value);
	return value;
}

- (NSArray *)allAlbumsIndex
{
	NSMutableArray *indexItems = [NSMutableArray arrayWithCapacity:0];
	
	FMResultSet *result = [self.db synchronizedExecuteQuery:@"SELECT * FROM allAlbumsIndexCache"];
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

- (Album *)allAlbumsAlbumForPosition:(NSUInteger)position
{
	Album *anAlbum = [[[Album alloc] init] autorelease];
	FMResultSet *result = [self.db synchronizedExecuteQuery:@"SELECT * FROM allAlbums WHERE ROWID = ?", [NSNumber numberWithInt:position]];
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
	NSUInteger rowId = [self.db synchronizedIntForQuery:@"SELECT rowIdInAllAlbums FROM allAlbumsNameSearch WHERE ROWID = ?", [NSNumber numberWithInt:position]];
	return [self allAlbumsAlbumForPosition:rowId];
}

- (void)allAlbumsClearSearch
{
	[self.db synchronizedExecuteUpdate:@"DELETE FROM allAlbumsNameSearch"];
}

- (void)allAlbumsPerformSearch:(NSString *)name
{
	// Inialize the search DB
	[self.db synchronizedExecuteUpdate:@"DROP TABLE IF EXISTS allAlbumsNameSearch"];
	[self.db synchronizedExecuteUpdate:@"CREATE TEMPORARY TABLE allAlbumsNameSearch (rowIdInAllAlbums INTEGER)"];
	
	// Perform the search
	NSString *query = @"INSERT INTO allAlbumsNameSearch SELECT ROWID FROM allAlbums WHERE title LIKE ? LIMIT 100";
	[self.db executeUpdate:query, [NSString stringWithFormat:@"%%%@%%", name]];
	if ([self.db hadError]) {
		DLog(@"Err %d: %@", [self.db lastErrorCode], [self.db lastErrorMessage]);
	}
	DLog(@"allAlbumsNameSearch count: %i", [self.db synchronizedIntForQuery:@"SELECT count(*) FROM allAlbumsNameSearch"]);
}

- (BOOL)allAlbumsIsDataLoaded
{
	BOOL isLoaded = NO;

	if ([self.db synchronizedIntForQuery:@"SELECT COUNT(*) FROM allAlbumsCount"] > 0)
	{
		isLoaded = YES;
	}
	
	return isLoaded;
}


#pragma mark - Public DAO Methods

- (NSUInteger)count
{
	return [self allAlbumsCount];
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
