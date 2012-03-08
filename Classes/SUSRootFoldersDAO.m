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
#import "NSString+Additions.h"
#import "TBXML.h"
#import "Artist.h"
#import "Index.h"
#import "SavedSettings.h"
#import "SUSRootFoldersLoader.h"

@implementation SUSRootFoldersDAO

@synthesize indexNames, indexPositions, indexCounts, loader, delegate;

#pragma mark - Lifecycle

- (void)setup
{
	indexNames = nil;
	indexPositions = nil;
	indexCounts = nil;
	selectedFolderId = nil;
}

- (id)init
{
    self = [super init];
    if (self) 
	{
		[self setup];
    }
    
    return self;
}

- (id)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate
{
    if ((self = [super init]))
	{
		delegate = theDelegate;
		[self setup];
    }
    
    return self;
}

- (void)dealloc
{
	[indexNames release]; indexNames = nil;
	[indexPositions release]; indexPositions = nil;
	[indexCounts release]; indexCounts = nil;
	[selectedFolderId release]; selectedFolderId = nil;
	[self cancelLoad];
	[super dealloc];
}

#pragma mark - Properties

- (FMDatabase *)db
{
    return [databaseS albumListCacheDb]; 
}

- (NSString *)tableModifier
{
	NSString *tableModifier = @"_all";
	
	if (selectedFolderId != nil && [selectedFolderId intValue] != -1)
	{
		tableModifier = [NSString stringWithFormat:@"_%@", [selectedFolderId stringValue]];
	}
	
	return tableModifier;
}

#pragma mark - Private Methods

- (BOOL)addRootFolderToCache:(NSString*)folderId name:(NSString*)name
{
	NSString *query = [NSString stringWithFormat:@"INSERT INTO rootFolderNameCache%@ VALUES (?, ?)", self.tableModifier];
	[self.db executeUpdate:query, folderId, [name cleanString]];
	return ![self.db hadError];
}

- (NSUInteger)rootFolderCount
{
	NSString *query = [NSString stringWithFormat:@"SELECT count FROM rootFolderCount%@ LIMIT 1", self.tableModifier];
	return [self.db intForQuery:query];
}

- (NSUInteger)rootFolderSearchCount
{
	NSString *query = @"SELECT count(*) FROM rootFolderNameSearch";
	return [self.db intForQuery:query];
}

- (NSArray *)rootFolderIndexNames
{
	NSMutableArray *names = [NSMutableArray arrayWithCapacity:0];
	
	NSString *query = [NSString stringWithFormat:@"SELECT * FROM rootFolderIndexCache%@", self.tableModifier];
	FMResultSet *result = [self.db executeQuery:query];
	while ([result next])
	{
		NSString *name = [result stringForColumn:@"name"];
		//DLog(@"name: %@", name);
		[names addObject:name];
	}
	[result close];
	
	return [NSArray arrayWithArray:names];
}

- (NSArray *)rootFolderIndexPositions
{	
	NSMutableArray *positions = [NSMutableArray arrayWithCapacity:0];
	
	NSString *query = [NSString stringWithFormat:@"SELECT * FROM rootFolderIndexCache%@", self.tableModifier];
	//DLog(@"query: %@", query);
	FMResultSet *result = [self.db executeQuery:query];
	while ([result next])
	{
		NSNumber *position = [NSNumber numberWithInt:[result intForColumn:@"position"]];
		//DLog(@"position: %i", [position intValue]);
		[positions addObject:position];
	}
	[result close];
	
	//DLog(@"positions: %i", [positions count]);
	
	if ([positions count] == 0)
		return nil;
	else
		return [NSArray arrayWithArray:positions];
}

- (NSArray *)rootFolderIndexCounts
{	
	NSMutableArray *counts = [NSMutableArray arrayWithCapacity:0];
	
	NSString *query = [NSString stringWithFormat:@"SELECT * FROM rootFolderIndexCache%@", self.tableModifier];
	//DLog(@"query: %@", query);
	FMResultSet *result = [self.db executeQuery:query];
	while ([result next])
	{
		NSNumber *folderCount = [NSNumber numberWithInt:[result intForColumn:@"count"]];
		//DLog(@"folderCount: %i", [folderCount intValue]);
		[counts addObject:folderCount];
	}
	[result close];
	
	//DLog(@"counts count: %i", [counts count]);
	
	if ([counts count] == 0)
		return nil;
	else
		return [NSArray arrayWithArray:counts];
}

- (Artist *)rootFolderArtistForPosition:(NSUInteger)position
{
	Artist *anArtist = nil;
	NSString *query = [NSString stringWithFormat:@"SELECT * FROM rootFolderNameCache%@ WHERE ROWID = ?", self.tableModifier];
	//DLog(@"query: %@", query);
	FMResultSet *result = [self.db executeQuery:query, [NSNumber numberWithInt:position]];
	while ([result next])
	{
		NSString *name = [result stringForColumn:@"name"];
		NSString *folderId = [result stringForColumn:@"id"];
		//DLog(@"name: %@   folderId: %@", name, folderId);
		anArtist = [Artist artistWithName:name andArtistId:folderId];
	}
	[result close];
	
	return anArtist;
}

- (Artist *)rootFolderArtistForPositionInSearch:(NSUInteger)position
{
	Artist *anArtist = nil;
	NSString *query = @"SELECT * FROM rootFolderNameSearch WHERE ROWID = ?";
	FMResultSet *result = [self.db executeQuery:query, [NSNumber numberWithInt:position]];
	while ([result next])
	{
		NSString *name = [result stringForColumn:@"name"];
		NSString *folderId = [result stringForColumn:@"id"];
		anArtist = [Artist artistWithName:name andArtistId:folderId];
	}
	[result close];
	
	return anArtist;
}

- (void)rootFolderClearSearch
{
	NSString *query = [NSString stringWithFormat:@"DELETE FROM rootFolderNameSearch", self.tableModifier];
	[self.db executeUpdate:query];
	//[self.db executeUpdate:@"VACUUM"];
}

- (void)rootFolderPerformSearch:(NSString *)name
{
	// Inialize the search DB
	NSString *query = @"DROP TABLE IF EXISTS rootFolderNameSearch";
	[self.db executeUpdate:query];
	query = @"CREATE TEMPORARY TABLE rootFolderNameSearch (id TEXT PRIMARY KEY, name TEXT)";
	[self.db executeUpdate:query];
	
	// Perform the search
	query = [NSString stringWithFormat:@"INSERT INTO rootFolderNameSearch SELECT * FROM rootFolderNameCache%@ WHERE name LIKE ? LIMIT 100", self.tableModifier];
	//NSLog(@"query: %@", query);
	[self.db executeUpdate:query, [NSString stringWithFormat:@"%%%@%%", name]];
	if ([self.db hadError]) {
		DLog(@"Err %d: %@", [self.db lastErrorCode], [self.db lastErrorMessage]);
	}
}

- (BOOL)rootFolderIsFolderCached
{
	NSString *query = [NSString stringWithFormat:@"rootFolderIndexCache%@", self.tableModifier];
	return [self.db tableExists:query];
}

#pragma mark - Public DAO Methods

+ (void)setFolderDropdownFolders:(NSDictionary *)folders
{
	FMDatabase *database = [databaseS albumListCacheDb];
	[database executeUpdate:@"DROP TABLE IF EXISTS rootFolderDropdownCache (id INTEGER, name TEXT)"];
	[database executeUpdate:@"CREATE TABLE rootFolderDropdownCache (id INTEGER, name TEXT)"];
	
	for (NSNumber *folderId in [folders allKeys])
	{
		NSString *folderName = [folders objectForKey:folderId];
		[database executeUpdate:@"INSERT INTO rootFolderDropdownCache VALUES (?, ?)", folderId, folderName];
	}
}

+ (NSDictionary *)folderDropdownFolders
{
	FMDatabase *database = [databaseS albumListCacheDb];
	if (![database tableExists:@"rootFolderDropdownCache"])
		return nil;
	
	NSMutableDictionary *folders = [NSMutableDictionary dictionaryWithCapacity:0];
	FMResultSet *result = [database executeQuery:@"SELECT * FROM rootFolderDropdownCache"];
	while ([result next])
	{
		NSNumber *folderId = [NSNumber numberWithInt:[result intForColumn:@"id"]];
		NSString *folderName = [result stringForColumn:@"name"];
		[folders setObject:folderName forKey:folderId];
	}
	[result close];
	
	return [NSDictionary dictionaryWithDictionary:folders];
}

- (NSNumber *)selectedFolderId
{
	if (selectedFolderId == nil)
		return [NSNumber numberWithInt:-1];
	else
		return selectedFolderId;
}

- (void)setSelectedFolderId:(NSNumber *)newSelectedFolderId
{
	selectedFolderId = newSelectedFolderId;
	[indexNames release]; indexNames = nil;
	[indexCounts release]; indexCounts = nil;
	[indexPositions release]; indexPositions = nil;
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
		[indexNames release];
		indexNames = [[self rootFolderIndexNames] retain];
	}
	
	return indexNames;
}

- (NSArray *)indexPositions
{
	if (indexPositions == nil || [indexPositions count] == 0)
	{
		[indexPositions release];
		indexPositions = [[self rootFolderIndexPositions] retain];
	}
	return indexPositions;
}

- (NSArray *)indexCounts
{
	if (indexCounts == nil)
	{
		indexCounts = [[self rootFolderIndexCounts] retain];
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
    self.loader = [[[SUSRootFoldersLoader alloc] initWithDelegate:self] autorelease];
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
		
	[indexNames release]; indexNames = nil;
    [indexPositions release]; indexPositions = nil;
    [indexCounts release]; indexCounts = nil;
	
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[self.delegate loadingFinished:nil];
	}
}

@end
