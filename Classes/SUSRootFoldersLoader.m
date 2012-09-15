//
//  SUSRootFoldersLoader.m
//  iSub
//
//  Created by Benjamin Baron on 10/28/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSRootFoldersLoader.h"

@implementation SUSRootFoldersLoader

#pragma mark Data loading

- (NSURLRequest *)createRequest
{
	//DLog(@"Starting load");
    NSDictionary *parameters = nil;
	if (self.selectedFolderId != nil && [self.selectedFolderId intValue] != -1)
	{
        parameters = [NSDictionary dictionaryWithObject:n2N([self.selectedFolderId stringValue]) forKey:@"musicFolderId"];
	}
    
    return [NSMutableURLRequest requestWithSUSAction:@"getIndexes" parameters:parameters];
}

- (void)processResponse
{			
	// Clear the database
	[self resetRootFolderCache];
	
	// Create the temp table to store records
	[self resetRootFolderTempTable];
	
	//NSDate *startTime = [NSDate date];
	
	//DLog(@"%@", [[[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding] autorelease]);
	NSError *error;
    TBXML *tbxml = [[TBXML alloc] initWithXMLData:self.receivedData error:&error];
	if (error)
	{
		[self informDelegateLoadingFailed:error];
	}
	else
	{
		// Check for an error response
		TBXMLElement *errorElement = [TBXML childElementNamed:@"error" parentElement:tbxml.rootXMLElement];
		if (errorElement)
		{
			NSString *code = [TBXML valueOfAttributeNamed:@"code" forElement:errorElement];
			NSString *message = [TBXML valueOfAttributeNamed:@"message" forElement:errorElement];
			[self subsonicErrorCode:[code intValue] message:message];
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
				@autoreleasepool
				{
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
				}
			}
			
			if (rowIndex > 0)
			{
				[self addRootFolderIndexToCache:rowIndex count:sectionCount name:@"★"];
				//DLog(@"Adding shortcut to index table, count %i", sectionCount);
			}
			
			// Parse the letter indexes
			TBXMLElement *indexElement = [TBXML childElementNamed:@"index" parentElement:indexesElement];
			while (indexElement != nil)
			{
				@autoreleasepool 
				{
					NSTimeInterval dbInserts = 0;
					sectionCount = 0;
					rowIndex = rowCount + 1;
					
					// Loop through the artist elements
					TBXMLElement *artistElement = [TBXML childElementNamed:@"artist" parentElement:indexElement];
					while (artistElement != nil)
					{
						@autoreleasepool 
						{
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
						
						}
					}
					
					NSString *indexName = [TBXML valueOfAttributeNamed:@"name" forElement:indexElement];
					[self addRootFolderIndexToCache:rowIndex count:sectionCount name:indexName];
					//BOOL success = [self addRootFolderIndexToCache:rowIndex count:sectionCount name:indexName];
					//DLog(@"Adding index %@  count: %i  success: %i", indexName, sectionCount, success);
					
					// Get the next index
					indexElement = [TBXML nextSiblingNamed:@"index" searchFromElement:indexElement];
				
				}
			}
		}
		
		// Move any remaining temp records to main cache
		[self moveRootFolderTempTableRecordsToMainCache];
		[self resetRootFolderTempTable];
		
		// Release the XML parser
		
		//DLog(@"Folders load time: %f", [[NSDate date] timeIntervalSinceDate:startTime]);
		
		// Update the count
		[self rootFolderUpdateCount];
		
		// Save the reload time
		[settingsS setRootFoldersReloadTime:[NSDate date]];
		
		// Notify the delegate that the loading is finished
		[self informDelegateLoadingFinished];
	}
	
	// Clean up the connection
	self.connection = nil;
	self.receivedData = nil;
}

@end
