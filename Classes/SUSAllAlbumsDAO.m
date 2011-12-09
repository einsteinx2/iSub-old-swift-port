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
	NSUInteger value = NSUIntegerMax;
	
	if ([self.db tableExists:@"allAlbumsCount"] && [self.db intForQuery:@"SELECT COUNT(*) FROM allAlbumsCount"] > 0)
	{
		value = [self.db intForQuery:@"SELECT count FROM allAlbumsCount LIMIT 1"];
	}
	
	return value;
}

- (NSUInteger)allAlbumsSearchCount
{
	NSUInteger value = NSUIntegerMax;
	
	if ([self.db tableExists:@"allAlbumsNameSearch"])
	{
		value = [self.db intForQuery:@"SELECT count(*) FROM allAlbumsNameSearch"];
	}
	
	return value;
}

- (NSArray *)allAlbumsIndex
{
	NSMutableArray *indexItems = [NSMutableArray arrayWithCapacity:0];
	
	FMResultSet *result = [self.db executeQuery:@"SELECT * FROM allAlbumsIndexCache"];
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
	FMResultSet *result = [self.db executeQuery:@"SELECT * FROM allAlbums WHERE ROWID = ?", [NSNumber numberWithInt:position]];
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
	FMResultSet *result = [self.db executeQuery:@"SELECT * FROM allAlbumsNameSearch WHERE ROWID = ?", [NSNumber numberWithInt:position]];
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
	[self.db executeUpdate:@"DELETE FROM allAlbumsNameSearch"];
}

- (void)allAlbumsPerformSearch:(NSString *)name
{
	// Inialize the search DB
	[self.db executeUpdate:@"DROP TABLE IF EXISTS allAlbumsNameSearch"];
	[self.db executeUpdate:@"CREATE TEMPORARY TABLE allAlbumsNameSearch (id TEXT PRIMARY KEY, name TEXT)"];
	
	// Perform the search
	NSString *query = @"INSERT INTO allAlbumsNameSearch SELECT * FROM allAlbums WHERE name LIKE ? LIMIT 100";
	[self.db executeUpdate:query, [NSString stringWithFormat:@"%%%@%%", name]];
	if ([self.db hadError]) {
		DLog(@"Err %d: %@", [self.db lastErrorCode], [self.db lastErrorMessage]);
	}
}

- (BOOL)allAlbumsIsDataLoaded
{
	BOOL isLoaded = NO;
	
	if ([self.db tableExists:@"allAlbumsCount"] && [self.db intForQuery:@"SELECT COUNT(*) FROM allAlbumsCount"] > 0)
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
