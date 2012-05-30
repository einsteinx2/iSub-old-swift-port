//
//  SUSRootFoldersDAO.m
//  iSub
//
//  Created by Ben Baron on 8/21/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSRootFoldersDAO.h"
#import "DatabaseSingleton.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueueAdditions.h"
#import "TBXML.h"
#import "Artist.h"
#import "Index.h"
#import "SavedSettings.h"
#import "SUSRootFoldersLoader.h"
#import "Song+DAO.h"

@implementation SUSRootFoldersDAO

@synthesize indexNames, indexPositions, indexCounts, loader, delegate, selectedFolderId;

#pragma mark - Lifecycle

- (id)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate
{
    if ((self = [super init]))
	{
		delegate = theDelegate;
    }    
    return self;
}

- (void)dealloc
{
	[loader cancelLoad];
	loader.delegate = nil;
}

#pragma mark - Properties

- (FMDatabaseQueue *)dbQueue
{
    return databaseS.albumListCacheDbQueue; 
}

- (NSString *)tableModifier
{
	NSString *tableModifier = @"_all";
	if (selectedFolderId != nil && [self.selectedFolderId intValue] != -1)
	{
		tableModifier = [NSString stringWithFormat:@"_%@", [self.selectedFolderId stringValue]];
	}
	return tableModifier;
}

#pragma mark - Private Methods

- (BOOL)addRootFolderToCache:(NSString*)folderId name:(NSString*)name
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		NSString *query = [NSString stringWithFormat:@"INSERT INTO rootFolderNameCache%@ VALUES (?, ?)", self.tableModifier];
		[db executeUpdate:query, folderId, [name cleanString]];
		hadError = [db hadError];
	}];
	return !hadError;
}

- (NSUInteger)rootFolderCount
{
	NSString *query = [NSString stringWithFormat:@"SELECT count FROM rootFolderCount%@ LIMIT 1", self.tableModifier];
	return [self.dbQueue intForQuery:query];
}

- (NSUInteger)rootFolderSearchCount
{
	NSString *query = @"SELECT count(*) FROM rootFolderNameSearch";
	return [self.dbQueue intForQuery:query];
}

- (NSArray *)rootFolderIndexNames
{
	__block NSMutableArray *names = [NSMutableArray arrayWithCapacity:0];
	
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		NSString *query = [NSString stringWithFormat:@"SELECT * FROM rootFolderIndexCache%@", self.tableModifier];
		FMResultSet *result = [db executeQuery:query];
		while ([result next])
		{
			NSString *name = [result stringForColumn:@"name"];
			[names addObject:name];
		}
		[result close];
	}];
	
	return [NSArray arrayWithArray:names];
}

- (NSArray *)rootFolderIndexPositions
{	
	__block NSMutableArray *positions = [NSMutableArray arrayWithCapacity:0];
	
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		NSString *query = [NSString stringWithFormat:@"SELECT * FROM rootFolderIndexCache%@", self.tableModifier];
		FMResultSet *result = [db executeQuery:query];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSNumber *position = [NSNumber numberWithInt:[result intForColumn:@"position"]];
				[positions addObject:position];
			}
		}
		[result close];
	}];
		
	if (positions.count == 0)
		return nil;
	else
		return [NSArray arrayWithArray:positions];
}

- (NSArray *)rootFolderIndexCounts
{	
	__block NSMutableArray *counts = [NSMutableArray arrayWithCapacity:0];
	
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		NSString *query = [NSString stringWithFormat:@"SELECT * FROM rootFolderIndexCache%@", self.tableModifier];
		FMResultSet *result = [db executeQuery:query];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSNumber *folderCount = [NSNumber numberWithInt:[result intForColumn:@"count"]];
				[counts addObject:folderCount];
			}
		}
		[result close];
	}];
		
	if (counts.count == 0)
		return nil;
	else
		return [NSArray arrayWithArray:counts];
}

- (Artist *)rootFolderArtistForPosition:(NSUInteger)position
{
	__block Artist *anArtist = nil;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		NSString *query = [NSString stringWithFormat:@"SELECT * FROM rootFolderNameCache%@ WHERE ROWID = ?", self.tableModifier];
		FMResultSet *result = [db executeQuery:query, [NSNumber numberWithInt:position]];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSString *name = [result stringForColumn:@"name"];
				NSString *folderId = [result stringForColumn:@"id"];
				anArtist = [Artist artistWithName:name andArtistId:folderId];
			}
		}
		[result close];
	}];
	
	return anArtist;
}

- (Artist *)rootFolderArtistForPositionInSearch:(NSUInteger)position
{
	__block Artist *anArtist = nil;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		NSString *query = @"SELECT * FROM rootFolderNameSearch WHERE ROWID = ?";
		FMResultSet *result = [db executeQuery:query, [NSNumber numberWithInt:position]];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSString *name = [result stringForColumn:@"name"];
				NSString *folderId = [result stringForColumn:@"id"];
				anArtist = [Artist artistWithName:name andArtistId:folderId];
			}
		}
		[result close];
	}];
	
	return anArtist;
}

- (void)rootFolderClearSearch
{
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		NSString *query = [NSString stringWithFormat:@"DELETE FROM rootFolderNameSearch", self.tableModifier];
		[db executeUpdate:query];
	}];
}

- (void)rootFolderPerformSearch:(NSString *)name
{
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		// Inialize the search DB
		NSString *query = @"DROP TABLE IF EXISTS rootFolderNameSearch";
		[db executeUpdate:query];
		query = @"CREATE TEMPORARY TABLE rootFolderNameSearch (id TEXT PRIMARY KEY, name TEXT)";
		[db executeUpdate:query];
		
		// Perform the search
		query = [NSString stringWithFormat:@"INSERT INTO rootFolderNameSearch SELECT * FROM rootFolderNameCache%@ WHERE name LIKE ? LIMIT 100", self.tableModifier];
		[db executeUpdate:query, [NSString stringWithFormat:@"%%%@%%", name]];
		if ([db hadError]) {
			DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
		}
	}];
}

- (BOOL)rootFolderIsFolderCached
{
	NSString *query = [NSString stringWithFormat:@"rootFolderIndexCache%@", self.tableModifier];
	return [self.dbQueue tableExists:query];
}

#pragma mark - Public DAO Methods

+ (void)setFolderDropdownFolders:(NSDictionary *)folders
{
	[databaseS.albumListCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"DROP TABLE IF EXISTS rootFolderDropdownCache (id INTEGER, name TEXT)"];
		[db executeUpdate:@"CREATE TABLE rootFolderDropdownCache (id INTEGER, name TEXT)"];
		
		for (NSNumber *folderId in [folders allKeys])
		{
			NSString *folderName = [folders objectForKey:folderId];
			[db executeUpdate:@"INSERT INTO rootFolderDropdownCache VALUES (?, ?)", folderId, folderName];
		}
	}];
}

+ (NSDictionary *)folderDropdownFolders
{
	if (![databaseS.albumListCacheDbQueue tableExists:@"rootFolderDropdownCache"])
		return nil;
	
	__block NSMutableDictionary *folders = [NSMutableDictionary dictionaryWithCapacity:0];

	[databaseS.albumListCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:@"SELECT * FROM rootFolderDropdownCache"];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSNumber *folderId = [NSNumber numberWithInt:[result intForColumn:@"id"]];
				NSString *folderName = [result stringForColumn:@"name"];
				[folders setObject:folderName forKey:folderId];
			}
		}
		[result close];
	}];
	
	return [NSDictionary dictionaryWithDictionary:folders];
}

- (NSNumber *)selectedFolderId
{
	@synchronized(self)
	{
		if (selectedFolderId == nil)
			return [NSNumber numberWithInt:-1];
		else
			return selectedFolderId;
	}
}

- (void)setSelectedFolderId:(NSNumber *)newSelectedFolderId
{
	@synchronized(self)
	{
		selectedFolderId = newSelectedFolderId;
		indexNames = nil;
		indexCounts = nil;
		indexPositions = nil;
	}
}

- (BOOL)isRootFolderIdCached
{
	return [self rootFolderIsFolderCached];
}

- (NSUInteger)count
{
	return [self rootFolderCount];
}

- (NSUInteger)searchCount
{
	return [self rootFolderSearchCount];
}

- (NSArray *)indexNames
{
	if (indexNames == nil || [indexNames count] == 0)
	{
		indexNames = [self rootFolderIndexNames];
	}
	
	return indexNames;
}

- (NSArray *)indexPositions
{
	if (indexPositions == nil || [indexPositions count] == 0)
	{
		indexPositions = [self rootFolderIndexPositions];
	}
	return indexPositions;
}

- (NSArray *)indexCounts
{
	if (indexCounts == nil)
	{
		indexCounts = [self rootFolderIndexCounts];
	}
	
	return indexCounts;
}

- (Artist *)artistForPosition:(NSUInteger)position
{
	return [self rootFolderArtistForPosition:position];
}

- (Artist *)artistForPositionInSearch:(NSUInteger)position
{
	return [self rootFolderArtistForPositionInSearch:position];
}

- (void)clearSearchTable
{
	[self rootFolderClearSearch];
}

- (void)searchForFolderName:(NSString *)name
{
	[self rootFolderPerformSearch:name];
}

#pragma mark - Loader Manager Methods

- (void)restartLoad
{
    [self startLoad];
}

- (void)startLoad
{
    self.loader = [[SUSRootFoldersLoader alloc] initWithDelegate:self];
	self.loader.selectedFolderId = self.selectedFolderId;
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
		
	indexNames = nil;
	indexPositions = nil;
	indexCounts = nil;
	
	// Force all subfolders to reload
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"DROP TABLE IF EXISTS albumListCache"];
		[db executeUpdate:@"DROP TABLE IF EXISTS albumsCache"];
		[db executeUpdate:@"DROP TABLE IF EXISTS albumsCacheCount"];
		[db executeUpdate:@"DROP TABLE IF EXISTS songsCacheCount"];
		[db executeUpdate:@"DROP TABLE IF EXISTS folderLength"];
		[db executeUpdate:@"CREATE TABLE albumListCache (id TEXT PRIMARY KEY, data BLOB)"];
		[db executeUpdate:@"CREATE TABLE albumsCache (folderId TEXT, title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
		[db executeUpdate:@"CREATE INDEX albumsFolderId ON albumsCache (folderId)"];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE songsCache (folderId TEXT, %@)", [Song standardSongColumnSchema]]];
		[db executeUpdate:@"CREATE INDEX songsFolderId ON songsCache (folderId)"];
		[db executeUpdate:@"CREATE TABLE albumsCacheCount (folderId TEXT, count INTEGER)"];
		[db executeUpdate:@"CREATE INDEX albumsCacheCountFolderId ON albumsCacheCount (folderId)"];
		[db executeUpdate:@"CREATE TABLE songsCacheCount (folderId TEXT, count INTEGER)"];
		[db executeUpdate:@"CREATE INDEX songsCacheCountFolderId ON songsCacheCount (folderId)"];
		[db executeUpdate:@"CREATE TABLE folderLength (folderId TEXT, length INTEGER)"];
		[db executeUpdate:@"CREATE INDEX folderLengthFolderId ON folderLength (folderId)"];
	}];
	
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[self.delegate loadingFinished:nil];
	}
}

@end
