//
//  SUSChatLoader.m
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSChatLoader.h"
#import "TBXML.h"
#import "ChatMessage.h"

@implementation SUSChatLoader

@synthesize chatMessages;

#pragma mark - Lifecycle

- (ISMSLoaderType)type
{
    return ISMSLoaderType_Chat;
}

#pragma mark - Loader Methods

- (void)startLoad
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getChatMessages" andParameters:nil];
    
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		// Create the NSMutableData to hold the received data.
		// receivedData is an instance variable declared elsewhere.
		self.receivedData = [NSMutableData data];
		self.chatMessages = [NSMutableArray arrayWithCapacity:0];
	} 
	else 
	{
		NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
		[self informDelegateLoadingFailed:error];
		
		/*// Inform the user that the connection failed.
		 CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error retreiving the chat messages.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		 [alert show];
		 [alert release];
		 
		 [self dataSourceDidFinishLoadingNewData];*/
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
	[self informDelegateLoadingFailed:error];
	
	self.receivedData = nil;
	self.connection = nil;
	
	// Inform the delegate that loading failed
	[self informDelegateLoadingFailed:error];
	
	/*// Inform the user that the connection failed.
	NSString *message = [NSString stringWithFormat:@"There was an error retreiving the chat messages.\n\nError %i: %@", [error code], [error localizedDescription]];
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	[alert release];
	
	[theConnection release];
	[receivedData release];
	
	[viewObjectsS hideLoadingScreen];
	[self dataSourceDidFinishLoadingNewData];*/
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
		}
		else
		{
			TBXMLElement *chatMessagesElement = [TBXML childElementNamed:@"chatMessages" parentElement:root];
			if (chatMessagesElement)
			{
				// Loop through the chat messages
				TBXMLElement *chatMessage = [TBXML childElementNamed:@"chatMessage" parentElement:chatMessagesElement];
				while (chatMessage != nil)
				{
					@autoreleasepool
					{
						// Create the chat message object and add it to the array
						ChatMessage *aChatMessage = [[ChatMessage alloc] initWithTBXMLElement:chatMessage];
						[self.chatMessages addObject:aChatMessage];
						
						// Get the next message
						chatMessage = [TBXML nextSiblingNamed:@"chatMessage" searchFromElement:chatMessage];
					}
				}
			}
		}
		// Notify the delegate that the loading is finished
		[self informDelegateLoadingFinished];
	}

	self.receivedData = nil;
	self.connection = nil;
}

@end
