//
//  SUSSubFolderLoader.m
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSSubFolderLoader.h"
#import "TBXML.h"
#import "Album.h"
#import "Song.h"
#import "Artist.h"

@implementation SUSSubFolderLoader

#pragma mark - Loader Methods

- (void)startLoad
{
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(self.myId) forKey:@"id"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getMusicDirectory" andParameters:parameters];
    
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
		self.receivedData = [NSMutableData data];
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
	DLog(@"%@", [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);
	
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
		}
		else
		{
			TBXMLElement *directory = [TBXML childElementNamed:@"directory" parentElement:root];
			if (directory)
			{
                [self resetDb];
                self.albumsCount = 0;
                self.songsCount = 0;
                self.folderLength = 0;
                
                // Loop through the chat messages
				TBXMLElement *child = [TBXML childElementNamed:@"child" parentElement:directory];
				while (child != nil)
				{
					@autoreleasepool 
					{
						if ([[TBXML valueOfAttributeNamed:@"isDir" forElement:child] boolValue])
						{
							Album *anAlbum = [[Album alloc] initWithTBXMLElement:child artistId:self.myArtist.artistId artistName:self.myArtist.name];
							if (![anAlbum.title isEqualToString:@".AppleDouble"])
							{
								[self insertAlbumIntoFolderCache:anAlbum];
								self.albumsCount++;
							}
						}
						else
						{
							BOOL isVideo = [[TBXML valueOfAttributeNamed:@"isVideo" forElement:child] boolValue]; 
							if (!isVideo)
							{
								Song *aSong = [[Song alloc] initWithTBXMLElement:child];
								if (aSong.path)
								{
									[self insertSongIntoFolderCache:aSong];
									self.songsCount++;
									self.folderLength += [aSong.duration intValue];
								}
							}
						}
						
						// Get the next message
						child = [TBXML nextSiblingNamed:@"child" searchFromElement:child];
					}
				}
                
                [self insertAlbumsCount];
                [self insertSongsCount];
                [self insertFolderLength];
			}
            else
            {
                // TODO create error
                //NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NoLyricsElement];
                [self informDelegateLoadingFailed:nil];
            }
		}
	}
	
	self.receivedData = nil;
	self.connection = nil;
	
	// Notify the delegate that the loading is finished
	[self informDelegateLoadingFinished];
}


@end
