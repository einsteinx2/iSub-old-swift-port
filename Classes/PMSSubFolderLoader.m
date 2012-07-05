//
//  PMSSubFolderLoader.m
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "PMSSubFolderLoader.h"
#import "SBJson.h"
#import "Album.h"
#import "Song.h"

@implementation PMSSubFolderLoader

#pragma mark - Loader Methods

- (void)startLoad
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithPMSAction:@"folders" item:self.myId];
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
	NSString *responseString = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
	DLog(@"%@", [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);
	
	NSDictionary *response = [responseString JSONValue];
	
	//NSArray *albums = [response objectForKey:@"albums"];
	
	NSArray *folders = [response objectForKey:@"folders"];
	NSArray *songs = [response objectForKey:@"songs"];

	self.albumsCount = folders.count;
	for (NSDictionary *folder in folders)
	{
		@autoreleasepool 
		{
			Album *anAlbum = [[Album alloc] initWithPMSDictionary:folder];
			[self insertAlbumIntoFolderCache:anAlbum];
		}
	}
	
	self.songsCount = songs.count;
	self.folderLength = 0;
	for (NSDictionary *song in songs)
	{
		@autoreleasepool 
		{
			Song *aSong = [[Song alloc] initWithPMSDictionary:song];
			DLog(@"aSong: %@", aSong);
			self.folderLength += aSong.duration.intValue;
			[self insertSongIntoFolderCache:aSong];
		}
	}
	
	[self insertAlbumsCount];
	[self insertSongsCount];
	[self insertFolderLength];
	
	self.receivedData = nil;
	self.connection = nil;
	
	// Notify the delegate that the loading is finished
	[self informDelegateLoadingFinished];
}


@end
