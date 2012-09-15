//
//  PMSRootFoldersLoader.m
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "PMSRootFoldersLoader.h"
#import "TBXML.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueueAdditions.h"
#import "SBJson.h"

@implementation PMSRootFoldersLoader

#pragma mark Data loading

- (NSURLRequest *)createRequest
{
    NSString *action = @"folders";
    
	if (self.selectedFolderId != nil && [self.selectedFolderId intValue] != -1)
	{
        return [NSMutableURLRequest requestWithPMSAction:action itemId:self.selectedFolderId.stringValue];
	}
    
    return [NSMutableURLRequest requestWithPMSAction:action];
}

- (void)processResponse
{			
	// Clear the database
	[self resetRootFolderCache];
	
	// Create the temp table to store records
	[self resetRootFolderTempTable];
	
	//NSDate *startTime = [NSDate date];
	
	NSString *responseString = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
    DLog(@"%@", [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);
	
	NSDictionary *response = [responseString JSONValue];
	
	/*// Check for an error response
	if ([response objectForKey:@"error"])
	{
		// Do something
	}*/
	
	NSArray *folders = [response objectForKey:@"folders"];
	for (NSDictionary *folder in folders)
	{
		@autoreleasepool 
		{
			NSString *folderId = [folder objectForKey:@"folderId"];
			NSString *folderName = [folder objectForKey:@"folderName"];
			[self addRootFolderToTempCache:folderId name:folderName];
		}
	}
	
	/*// Treat artists as folders for now
	NSArray *artists = [response objectForKey:@"artists"];
	for (NSDictionary *artist in artists)
	{
		@autoreleasepool 
		{
			NSString *artistId = [artist objectForKey:@"artistId"];
			NSString *artistName = [artist objectForKey:@"artistName"];
			[self addRootFolderToTempCache:artistId name:artistName];
		}
	}*/
	
	[self moveRootFolderTempTableRecordsToMainCache];
	[self resetRootFolderTempTable];
	
	// Update the count
	NSInteger totalCount = [self rootFolderUpdateCount];
    
	NSString *tableName = [NSString stringWithFormat:@"rootFolderNameCache%@", self.tableModifier];
	NSArray *indexes = [databaseS sectionInfoFromTable:tableName inDatabaseQueue:self.dbQueue withColumn:@"name"];
    DLog(@"indexes: %@", indexes);
	for (int i = 0; i < indexes.count; i++)
	{
		NSArray *index = [indexes objectAtIndex:i];
		NSArray *nextIndex = [indexes objectAtIndexSafe:i+1];
		
		NSString *name = [index objectAtIndex:0];
		NSInteger row = [[index objectAtIndex:1] intValue] + 1; // Add 1 to compensate for sqlite row numbering
		NSInteger count = nextIndex ? [[nextIndex objectAtIndex:1] intValue] - row : totalCount - row;
        DLog(@"name: %@  row: %i  count: %i", name, row, count);
		[self addRootFolderIndexToCache:row count:count name:name];
	}
	//[self addRootFolderIndexToCache:1 count:totalCount name:@"All"];
	
	// Save the reload time
	[settingsS setRootFoldersReloadTime:[NSDate date]];
	
	// Notify the delegate that the loading is finished
	[self informDelegateLoadingFinished];
		
	// Clean up the connection
	self.connection = nil;
	self.receivedData = nil;
}

@end
