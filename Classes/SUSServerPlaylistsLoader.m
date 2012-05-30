//
//  SUSServerPlaylistLoader.m
//  iSub
//
//  Created by Benjamin Baron on 11/6/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSServerPlaylistsLoader.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueueAdditions.h"
#import "DatabaseSingleton.h"
#import "TBXML.h"
#import "SUSServerPlaylist.h"

@implementation SUSServerPlaylistsLoader
@synthesize serverPlaylists;

#pragma mark - Lifecycle

- (void)setup
{
	[super setup];
}


- (FMDatabaseQueue *)dbQueue
{
    return databaseS.localPlaylistsDbQueue;
}

- (SUSLoaderType)type
{
    return SUSLoaderType_ServerPlaylist;
}

#pragma mark - Private DB Methods

#pragma mark - Loader Methods

- (void)startLoad
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getPlaylists" andParameters:nil];
    
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		self.receivedData = [NSMutableData data];
        self.serverPlaylists = nil;
	} 
	else 
	{
		NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
		[self informDelegateLoadingFailed:error];
	}
}

#pragma mark - Connection Delegate

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
    // Parse the data
	//
	NSError *error;
    TBXML *tbxml = [[TBXML alloc] initWithXMLData:self.receivedData error:&error];
	if (error)
	{
		[self informDelegateLoadingFailed:error];
	}
	else
	{
		TBXMLElement *root = tbxml.rootXMLElement;
		
		TBXMLElement *error = [TBXML childElementNamed:@"error" parentElement:root];
		if (error)
		{
			NSString *code = [TBXML valueOfAttributeNamed:@"code" forElement:error];
			NSString *message = [TBXML valueOfAttributeNamed:@"message" forElement:error];
			[self subsonicErrorCode:[code intValue] message:message];
			
			// Inform the delegate that loading failed
			[self informDelegateLoadingFailed:nil];
		}
		else
		{
			TBXMLElement *playlists = [TBXML childElementNamed:@"playlists" parentElement:root];
			if (playlists)
			{
                NSMutableArray *tempArray = [NSMutableArray arrayWithCapacity:0];
                
				TBXMLElement *playlist = [TBXML childElementNamed:@"playlist" parentElement:playlists];
				while (playlist != nil)
				{
					@autoreleasepool 
					{
						SUSServerPlaylist *serverPlaylist = [[SUSServerPlaylist alloc] initWithTBXMLElement:playlist];
						[tempArray addObject:serverPlaylist];
						
						// Get the next message
						playlist = [TBXML nextSiblingNamed:@"playlist" searchFromElement:playlist];
					}
				}
                
                // Sort the array
                self.serverPlaylists = [tempArray sortedArrayUsingSelector:@selector(compare:)];
			}
            
            // Notify the delegate that the loading is finished
			[self informDelegateLoadingFinished];
		}
	}
	
	self.receivedData = nil;
	self.connection = nil;
}

@end
