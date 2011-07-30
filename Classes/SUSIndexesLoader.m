//
//  SUSIndexesLoader.m
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSIndexesLoader.h"
#import "TBXML.h"
#import "Artist.h"
#import "Index.h"
#import "DefaultSettings.h"

@implementation SUSIndexesLoader

@synthesize folderId;

- (id)init
{
    self = [super init];
    if (self) 
	{
        // Initialization code here.
		connection = nil;
		receivedData = nil;
		folderId = nil;
    }
    
    return self;
}

- (void)dealloc
{
	[folderId release]; folderId = nil;
    [super dealloc];
}

- (void)startLoad
{
	DLog(@"Starting load");
	NSString *urlString = @"";
	if (folderId == nil || [folderId isEqualToString:@"-1"])
	{
		urlString = [self getBaseUrlString:@"getIndexes.view"];
	}
	else
	{
		urlString = [NSString stringWithFormat:@"%@&musicFolderId=%@", [self getBaseUrlString:@"getIndexes.view"], folderId];
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
		[delegate_ loadingFailed:self];
	}
}

- (void)cancelLoad
{
	// Clean up connection objects
	[connection cancel];
	[connection release]; connection = nil;
	[receivedData release]; receivedData = nil;
	[delegate_ release];
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
	[delegate_ loadingFailed:self];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	NSMutableArray *indexes = [NSMutableArray arrayWithCapacity:0];
	NSMutableArray *shortcuts = [NSMutableArray arrayWithCapacity:0];
	NSMutableArray *folders = [NSMutableArray arrayWithCapacity:0];
	
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
		
		TBXMLElement *indexesElement = [TBXML childElementNamed:@"indexes" parentElement:tbxml.rootXMLElement];
		if (indexesElement)
		{
			// Parse the shortcuts if they exist
			TBXMLElement *shortcutElement = [TBXML childElementNamed:@"shortcut" parentElement:indexesElement];
			while (shortcutElement != nil)
			{
				NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
				
				// If this is the first shortcut, add the shortcut index
				if ([shortcuts count] == 0)
					[indexes addObject:@"★"];
				
				// Create the shortcut object (actually an artist object)
				// and add it to the shortcuts array
				Artist *anArtist = [[Artist alloc] initWithTBXMLElement:shortcutElement];
				[shortcuts addObject:anArtist];
				[anArtist release];
				
				// Get the next shortcut
				shortcutElement = [TBXML nextSiblingNamed:@"shortcut" searchFromElement:shortcutElement];
				
				[pool release];
			}
			
			// Add the shortcuts array to artists
			if ([shortcuts count] > 0)
			{
				[folders addObject:shortcuts];
			}
			
			// Parse the letter indexes
			TBXMLElement *indexElement = [TBXML childElementNamed:@"index" parentElement:indexesElement];
			while (indexElement != nil)
			{
				NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
				
				// Initialize the Artist array for this section
				NSMutableArray *artistsArray = [NSMutableArray arrayWithCapacity:0];
				
				// Loop through the artist elements
				TBXMLElement *artistElement = [TBXML childElementNamed:@"artist" parentElement:indexElement];
				while (artistElement != nil)
				{
					NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

					// Create the artist object and add it to the 
					// array for this section if not named .AppleDouble
					if (![[TBXML valueOfAttributeNamed:@"name" forElement:artistElement] isEqualToString:@".AppleDouble"])
					{
						Artist *anArtist = [[Artist alloc] initWithTBXMLElement:artistElement];
						[artistsArray addObject:anArtist];
						[anArtist release];
					}
					
					// Get the next artist
					artistElement = [TBXML nextSiblingNamed:@"artist" searchFromElement:artistElement];
					
					[pool release];
				}
				
				// Add the index and artists to the arrays
				[indexes addObject:[TBXML valueOfAttributeNamed:@"name" forElement:indexElement]];
				[folders addObject:artistsArray];
				
				// Get the next index
				indexElement = [TBXML nextSiblingNamed:@"index" searchFromElement:indexElement];
				
				[pool release];
			}
		}
	}
		
	// Save the results dictionary
	results = [[NSDictionary alloc] initWithObjectsAndKeys:indexes, @"indexes", folders, @"folders", nil];
	
	// Save the defaults
	[[DefaultSettings sharedInstance] saveTopLevelIndexes:indexes folders:folders];
	
	// Release the XML parser
	[tbxml release];
	
	// Clean up the connection
	[theConnection release]; theConnection = nil;
	[receivedData release]; receivedData = nil;
	
	// Notify the delegate that the loading is finished
	[delegate_ loadingFinished:self];
}

@end
