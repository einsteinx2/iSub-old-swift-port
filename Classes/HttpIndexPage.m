//
//  HttpIndexPage.m
//  iSub
//
//  Created by Ben Baron on 3/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "HttpIndexPage.h"
#import "DatabaseSingleton.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

@interface HttpIndexPage (Private) 



@end

@implementation HttpIndexPage

@synthesize documentsDirectory;

- (id)init
{
	if ((self = [super init]))
	{
		databaseControls = [DatabaseSingleton sharedInstance];
		
		// Find documents directory
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		self.documentsDirectory = [paths objectAtIndex:0];
	}
	
	return self;
}

- (void)dealloc
{
	[documentsDirectory release];
	[super dealloc];
}

#pragma mark -

- (NSString *)createIndexPage
{
	NSMutableArray *listOfArtists = [NSMutableArray arrayWithCapacity:1];
	
	// Fix for slow load problem
	[databaseControls.inMemoryDb executeUpdate:@"DROP TABLE cachedSongsArtistList"];
	[databaseControls.inMemoryDb executeUpdate:@"CREATE TABLE cachedSongsArtistList (artist TEXT UNIQUE)"];
	[databaseControls.inMemoryDb executeUpdate:@"ATTACH DATABASE ? AS songCacheDb", [NSString stringWithFormat:@"%@/songCache.db", databaseControls.databaseFolderPath]];
	if ([databaseControls.inMemoryDb hadError]) { DLog(@"Err attaching the songCacheDb %d: %@", [databaseControls.inMemoryDb lastErrorCode], [databaseControls.inMemoryDb lastErrorMessage]); }
	[databaseControls.inMemoryDb executeUpdate:@"INSERT OR IGNORE INTO cachedSongsArtistList SELECT seg1 FROM cachedSongsLayout"];
	[databaseControls.inMemoryDb executeUpdate:@"DETACH DATABASE songCacheDb"];

	FMResultSet *result = [databaseControls.inMemoryDb executeQuery:@"SELECT artist FROM cachedSongsArtistList ORDER BY artist COLLATE NOCASE"];
	while ([result next])
	{
		//
		// Cover up for blank insert problem
		//
		if ([[result stringForColumnIndex:0] length] > 0)
			[listOfArtists addObject:[NSString stringWithString:[result stringForColumnIndex:0]]]; 
	}
	
	return @"";
}



@end
