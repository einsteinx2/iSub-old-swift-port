//
//  SUSNowPlayingLoader.m
//  iSub
//
//  Created by Ben Baron on 1/24/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSNowPlayingLoader.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "TBXML.h"
#import "DatabaseSingleton.h"
#import "NSMutableURLRequest+SUS.h"
#import "Album.h"
#import "Song.h"
#import "Artist.h"
#import "NSString+md5.h"

@implementation SUSNowPlayingLoader

@synthesize nowPlayingSongDicts;

#pragma mark - Lifecycle

- (void)setup
{
	[super setup];
}

- (void)dealloc
{
	[super dealloc];
}

- (SUSLoaderType)type
{
    return SUSLoaderType_NowPlaying;
}

#pragma mark - Loader Methods

- (void)startLoad
{
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getNowPlaying"
															   andParameters:nil];
    
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
		self.receivedData = [NSMutableData data];
		self.nowPlayingSongDicts = [NSMutableArray arrayWithCapacity:0];
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
		NSURLCredential *cred = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
		[challenge.sender useCredential:cred
			 forAuthenticationChallenge:challenge]; 
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
	TBXML *tbxml = [[TBXML alloc] initWithXMLData:self.receivedData];
    TBXMLElement *root = tbxml.rootXMLElement;
    if (root) 
	{
		TBXMLElement *error = [TBXML childElementNamed:@"error" parentElement:root];
		if (error)
		{
			NSString *code = [TBXML valueOfAttributeNamed:@"code" forElement:error];
			NSString *message = [TBXML valueOfAttributeNamed:@"message" forElement:error];
			[self subsonicErrorCode:[code intValue] message:message];
		}
		else
		{
			TBXMLElement *nowPlaying = [TBXML childElementNamed:@"nowPlaying" parentElement:root];
			if (nowPlaying)
			{
                // Loop through the songs
				TBXMLElement *entry = [TBXML childElementNamed:@"entry" parentElement:nowPlaying];
				while (entry != nil)
				{
					@autoreleasepool 
					{
						NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:0];
						
						Song *aSong = [[Song alloc] initWithTBXMLElement:entry];
						[dict setObject:aSong forKey:@"song"];
						
						NSString *username = [TBXML valueOfAttributeNamed:@"username" forElement:entry];
						if (username)
							[dict setObject:username forKey:@"username"];
						
						NSString *minutesAgo = [TBXML valueOfAttributeNamed:@"minutesAgo" forElement:entry];
						if (minutesAgo)
							[dict setObject:minutesAgo forKey:@"minutesAgo"];
						
						NSString *playerId = [TBXML valueOfAttributeNamed:@"playerId" forElement:entry];
						if (playerId)
							[dict setObject:playerId forKey:@"playerId"];
						
						NSString *playerName = [TBXML valueOfAttributeNamed:@"playerName" forElement:entry];
						if (playerName)
							[dict setObject:playerName forKey:@"playerName"];
						
						[nowPlayingSongDicts addObject:dict];
						
						// Get the next message
						entry = [TBXML nextSiblingNamed:@"entry" searchFromElement:entry];
					}
				}
			}
            else
            {
                // TODO create error
                //NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NoLyricsElement];
                [self informDelegateLoadingFailed:nil];
            }
		}
	}
	[tbxml release];
	
	self.receivedData = nil;
	self.connection = nil;
	
	// Notify the delegate that the loading is finished
	[self informDelegateLoadingFinished];
}

@end
