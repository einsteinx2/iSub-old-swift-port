//
//  SUSChatLoader.m
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSChatLoader.h"

@implementation SUSChatLoader

- (void)loadData
{
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[appDelegate getBaseUrl:@"getChatMessages.view"]] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kLoadingTimeout];
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
		// Create the NSMutableData to hold the received data.
		// receivedData is an instance variable declared elsewhere.
		receivedData = [[NSMutableData data] retain];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error retreiving the chat messages.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		alert.tag = 2;
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
        
		[self dataSourceDidFinishLoadingNewData];
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
	[receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	// Inform the user that the connection failed.
	NSString *message = [NSString stringWithFormat:@"There was an error retreiving the chat messages.\n\nError %i: %@", [error code], [error localizedDescription]];
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	alert.tag = 2;
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
	[alert release];
	
	[theConnection release];
	[receivedData release];
	
	[viewObjects hideLoadingScreen];
	[self dataSourceDidFinishLoadingNewData];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	viewObjects.chatMessages = [NSMutableArray arrayWithCapacity:1];
	//viewObjects.chatMessages = nil, viewObjects.chatMessages = [[NSMutableArray alloc] init];
	
	NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:receivedData];
	ChatXMLParser *parser = [[ChatXMLParser alloc] initXMLParser];
	[xmlParser setDelegate:parser];
	[xmlParser parse];
    
	[xmlParser release];
	[parser release];
	
	[self.tableView reloadData]; 
	
	if ([viewObjects.chatMessages count] == 0)
	{
		[self showNoChatMessagesScreen];
	}
	else
	{
		if (isNoChatMessagesScreenShowing == YES)
		{
			isNoChatMessagesScreenShowing = NO;
			[noChatMessagesScreen removeFromSuperview];
		}
	}
	
	[viewObjects hideLoadingScreen];
	[self dataSourceDidFinishLoadingNewData];
	
	[theConnection release];
	[receivedData release];
}

@end
