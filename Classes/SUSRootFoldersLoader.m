//
//  SUSRootFoldersLoader.m
//  iSub
//
//  Created by Benjamin Baron on 10/28/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSRootFoldersLoader.h"
#import "TBXML.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "DatabaseSingleton.h"
#import "GTMNSString+HTML.h"
#import "SavedSettings.h"

@implementation SUSRootFoldersLoader

@synthesize selectedFolderId;

- (void)setup
{

}

- (id)init
{
    if ((self = [super init]))
	{
		[self setup];
	}
    
    return self;
}

- (id)initWithDelegate:(id <LoaderDelegate>)theDelegate
{
	if ((self = [super initWithDelegate:theDelegate]))
	{
		[self setup];
	}
	
	return self;
}

- (void)dealloc
{
	[super dealloc];
}

#pragma mark - Properties

- (FMDatabase *)db
{
    return [[DatabaseSingleton sharedInstance] albumListCacheDb]; 
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

- (void)resetRootFolderTempTable
{
	[self.db executeUpdate:@"DROP TABLE IF EXISTS rootFolderNameCacheTemp"];
	[self.db executeUpdate:@"CREATE TEMPORARY TABLE rootFolderNameCacheTemp (id TEXT, name TEXT)"];
	
	tempRecordCount = 0;
}

- (BOOL)clearRootFolderTempTable
{
	[self.db executeUpdate:@"DELETE FROM rootFolderNameCacheTemp"];
	
	return ![self.db hadError];
}

- (NSUInteger)rootFolderUpdateCount
{
	NSString *query = [NSString stringWithFormat:@"DELETE FROM rootFolderCount%@", self.tableModifier];
	[self.db executeUpdate:query];
	
	query = [NSString stringWithFormat:@"SELECT COUNT(*) FROM rootFolderNameCache%@", self.tableModifier];
	NSNumber *folderCount = [NSNumber numberWithInt:[self.db intForQuery:query]];
	
	query = [NSString stringWithFormat:@"INSERT INTO rootFolderCount%@ VALUES (?)", self.tableModifier];
	[self.db executeUpdate:query, folderCount];
	
	return [folderCount intValue];
}

- (BOOL)moveRootFolderTempTableRecordsToMainCache
{
	NSString *query = @"INSERT INTO rootFolderNameCache%@ SELECT * FROM rootFolderNameCacheTemp";
	[self.db executeUpdate:[NSString stringWithFormat:query, self.tableModifier]];
	
	return ![self.db hadError];
}

- (void)resetRootFolderCache
{    
	// Delete the old tables
	[self.db executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS rootFolderIndexCache%@", self.tableModifier]];
	[self.db executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS rootFolderNameCache%@", self.tableModifier]];
	[self.db executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS rootFolderCount%@", self.tableModifier]];
	//[self.db executeUpdate:@"VACUUM"]; // Removed because it takes waaaaaay too long, maybe make a button in settings?
	
	// Create the new tables
	NSString *query;
	query = @"CREATE TABLE rootFolderIndexCache%@ (name TEXT PRIMARY KEY, position INTEGER, count INTEGER)";
	[self.db executeUpdate:[NSString stringWithFormat:query, self.tableModifier]];
	query = @"CREATE VIRTUAL TABLE rootFolderNameCache%@ USING FTS3 (id TEXT PRIMARY KEY, name TEXT, tokenize=porter)";
	[self.db executeUpdate:[NSString stringWithFormat:query, self.tableModifier]];
	query = @"CREATE INDEX name ON rootFolderNameCache%@ (name ASC)";
	[self.db executeUpdate:[NSString stringWithFormat:query, self.tableModifier]];
	query = @"CREATE TABLE rootFolderCount%@ (count INTEGER)";
	[self.db executeUpdate:[NSString stringWithFormat:query, self.tableModifier]];
}

- (BOOL)addRootFolderIndexToCache:(NSUInteger)position count:(NSUInteger)folderCount name:(NSString*)name
{
	NSString *query = [NSString stringWithFormat:@"INSERT INTO rootFolderIndexCache%@ VALUES (?, ?, ?)", self.tableModifier];
	[self.db executeUpdate:query, [name gtm_stringByUnescapingFromHTML], [NSNumber numberWithInt:position], [NSNumber numberWithInt:folderCount]];
	return ![self.db hadError];
}

- (BOOL)addRootFolderToTempCache:(NSString*)folderId name:(NSString*)name
{
	BOOL hadError = NO;
	
	// Add the shortcut to the DB
	if (folderId != nil && name != nil)
	{
		NSString *query = @"INSERT INTO rootFolderNameCacheTemp VALUES (?, ?)";
		hadError = [self.db executeUpdate:query, folderId, [name gtm_stringByUnescapingFromHTML]];
		tempRecordCount++;
	}
	
	// Flush temp records to main cache if necessary
	if (tempRecordCount == TEMP_FLUSH_AMOUNT)
	{
		if (![self moveRootFolderTempTableRecordsToMainCache])
			hadError = YES;
		
		[self resetRootFolderTempTable];
		
		tempRecordCount = 0;
	}
    
	return !hadError;
}

#pragma mark Data loading

- (void)startLoad
{
	DLog(@"Starting load");
	NSString *urlString = @"";
	if (selectedFolderId == nil || [selectedFolderId intValue] == -1)
	{
		urlString = [self getBaseUrlString:@"getIndexes.view"];
	}
	else
	{
		urlString = [NSString stringWithFormat:@"%@&musicFolderId=%i", [self getBaseUrlString:@"getIndexes.view"], [selectedFolderId intValue]];
	}
	//DLog(@"urlString: %@", urlString);
	
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kLoadingTimeout];
	connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
		// Create the NSMutableData to hold the received data.
		// receivedData is an instance variable declared elsewhere.
		receivedData = [[NSMutableData data] retain];
	} 
	else 
	{
		// Inform the delegate that the loading failed.
		[delegate loadingFailed:self];
	}
}

- (void)cancelLoad
{
	// Clean up connection objects
	[connection cancel];
	[connection release]; connection = nil;
	[receivedData release]; receivedData = nil;
	[delegate release];
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
	DLog(@"did receive response");
	[receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
	DLog("received data");
    [receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	DLog("connection failed");
	// Clean up the connection
	[theConnection release]; theConnection = nil;
	[receivedData release]; receivedData = nil;
	
	// Inform the delegate that loading failed
	[delegate loadingFailed:self];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{		
	DLog("connection finished");
	
	// Clear the database
	[self resetRootFolderCache];
	
	// Create the temp table to store records
	[self resetRootFolderTempTable];
	
	NSDate *startTime = [NSDate date];
	
	TBXML *tbxml = [[TBXML alloc] initWithXMLData:receivedData];
	if (tbxml.rootXMLElement)
	{
		// Check for an error response
		TBXMLElement *errorElement = [TBXML childElementNamed:@"error" parentElement:tbxml.rootXMLElement];
		if (errorElement)
		{
			NSString *code = [TBXML valueOfAttributeNamed:@"code" forElement:errorElement];
			NSString *message = [TBXML valueOfAttributeNamed:@"message" forElement:errorElement];
			[self subsonicErrorCode:code message:message];
		}
		
		NSUInteger rowCount = 0;
		NSUInteger sectionCount = 0;
		NSUInteger rowIndex = 0;
		
		TBXMLElement *indexesElement = [TBXML childElementNamed:@"indexes" parentElement:tbxml.rootXMLElement];
		if (indexesElement)
		{
			// Parse the shortcuts if they exist
			TBXMLElement *shortcutElement = [TBXML childElementNamed:@"shortcut" parentElement:indexesElement];
			while (shortcutElement != nil)
			{
				NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
				
				rowIndex = 1;
				rowCount++;
				sectionCount++;
                
				// Parse the shortcut
				NSString *folderId = [TBXML valueOfAttributeNamed:@"id" forElement:shortcutElement];
				NSString *name = [TBXML valueOfAttributeNamed:@"name" forElement:shortcutElement];
				//DLog(@"id: %@  name: %@", folderId, name);
				
				// Add the record to the cache
				[self addRootFolderToTempCache:folderId name:name];
				
				// Get the next shortcut
				shortcutElement = [TBXML nextSiblingNamed:@"shortcut" searchFromElement:shortcutElement];
				
				[pool release];
			}
			
			if (rowIndex > 0)
			{
				[self addRootFolderIndexToCache:rowIndex count:sectionCount name:@"★"];
				DLog(@"Adding shortcut to index table, count %i", sectionCount);
			}
			
			// Parse the letter indexes
			TBXMLElement *indexElement = [TBXML childElementNamed:@"index" parentElement:indexesElement];
			while (indexElement != nil)
			{
				NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
				
				NSDate *startTime2 = [NSDate date];
				NSTimeInterval dbInserts = 0;
				sectionCount = 0;
				rowIndex = rowCount + 1;
				
				// Loop through the artist elements
				TBXMLElement *artistElement = [TBXML childElementNamed:@"artist" parentElement:indexElement];
				while (artistElement != nil)
				{
					NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
					
					rowCount++;
					sectionCount++;
					
					// Create the artist object and add it to the 
					// array for this section if not named .AppleDouble
					if (![[TBXML valueOfAttributeNamed:@"name" forElement:artistElement] isEqualToString:@".AppleDouble"])
					{
						// Parse the top level folder
						NSString *folderId = [TBXML valueOfAttributeNamed:@"id" forElement:artistElement];
						NSString *name = [TBXML valueOfAttributeNamed:@"name" forElement:artistElement];
						//DLog(@"id: %@  name: %@", folderId, name);
						
						// Add the folder to the DB
						NSDate *startTime3 = [NSDate date];
						[self addRootFolderToTempCache:folderId name:name];
						dbInserts += [[NSDate date] timeIntervalSinceDate:startTime3];
					}
					
					// Get the next artist
					artistElement = [TBXML nextSiblingNamed:@"artist" searchFromElement:artistElement];
					
					[pool release];
				}
				
				NSString *indexName = [TBXML valueOfAttributeNamed:@"name" forElement:indexElement];
				[self addRootFolderIndexToCache:rowIndex count:sectionCount name:indexName];
				//BOOL success = [self addRootFolderIndexToCache:rowIndex count:sectionCount name:indexName];
				//DLog(@"Adding index %@  count: %i  success: %i", indexName, sectionCount, success);
				DLog(@"Processing index %@ time: %f dbTime: %f", indexName, [[NSDate date] timeIntervalSinceDate:startTime2], dbInserts);
				
				// Get the next index
				indexElement = [TBXML nextSiblingNamed:@"index" searchFromElement:indexElement];
				
				[pool release];
			}
		}
	}
	
	// Move any remaining temp records to main cache
	[self moveRootFolderTempTableRecordsToMainCache];
	[self resetRootFolderTempTable];
	
	// Release the XML parser
	[tbxml release];
	
	DLog(@"Folders load time: %f", [[NSDate date] timeIntervalSinceDate:startTime]);
	
	// Clean up the connection
	[theConnection release]; theConnection = nil;
	[receivedData release]; receivedData = nil;
	
	// Update the count
	[self rootFolderUpdateCount];
	
	// Save the reload time
	[[SavedSettings sharedInstance] setRootFoldersReloadTime:[NSDate date]];
	
	// Notify the delegate that the loading is finished
	[delegate loadingFinished:self];
}

@end
