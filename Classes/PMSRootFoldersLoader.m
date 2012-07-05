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
#import "DatabaseSingleton.h"
#import "SavedSettings.h"
#import "SBJson.h"

@implementation PMSRootFoldersLoader

#pragma mark Data loading

- (void)startLoad
{
	//DLog(@"Starting load");
    NSString *action = @"folders";
	NSString *item;
	if (self.selectedFolderId != nil && [self.selectedFolderId intValue] != -1)
	{
		item = [self.selectedFolderId stringValue];
	}
	
	/*// Treat artists as folders for now
	NSString *action = @"artists";
	NSString *item;*/
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithPMSAction:action item:item];
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		// Create the NSMutableData to hold the received data.
		// receivedData is an instance variable declared elsewhere.
		self.receivedData = [NSMutableData data];
	} 
	else 
	{
		// Inform the delegate that the loading failed.
		NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
		[self informDelegateLoadingFailed:error];
	}
}

#pragma mark Connection Delegate

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [self.receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	self.receivedData = nil;
	self.connection = nil;
	
	// Inform the delegate that loading failed
	[self informDelegateLoadingFailed:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
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
	
	/*NSString *tableName = [NSString stringWithFormat:@"rootFolderNameCache%@", self.tableModifier];
	NSArray *indexes = [databaseS sectionInfoFromTable:tableName inDatabaseQueue:self.dbQueue withColumn:@"name"];
	for (int i = 0; i < indexes.count; i++)
	{
		NSArray *index = [indexes objectAtIndex:0];
		NSArray *nextIndex = [indexes objectAtIndexSafe:i+1];
		
		NSString *name = [index objectAtIndex:0];
		NSInteger row = [[index objectAtIndex:1] intValue];
		NSInteger count = nextIndex ? [[nextIndex objectAtIndex:1] intValue] - row : totalCount - row;
		DLog(@"name: %@  row: %i  count: %i", name, row, count);
		[self addRootFolderIndexToCache:row count:count name:name];
	}*/
	[self addRootFolderIndexToCache:1 count:totalCount name:@"All"];
	
	// Save the reload time
	[settingsS setRootFoldersReloadTime:[NSDate date]];
	
	// Notify the delegate that the loading is finished
	[self informDelegateLoadingFinished];
		
	// Clean up the connection
	self.connection = nil;
	self.receivedData = nil;
}

@end
