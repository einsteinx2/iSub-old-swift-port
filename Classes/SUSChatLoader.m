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

- (void)setup
{
    [super setup];
	chatMessages = nil;
}

- (void)dealloc
{
	[chatMessages release]; chatMessages = nil;
	[super dealloc];
}

- (SUSLoaderType)type
{
    return SUSLoaderType_Chat;
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
		[self.delegate loadingFailed:self withError:error]; 
		
		/*// Inform the user that the connection failed.
		 CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error retreiving the chat messages.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		 alert.tag = 2;
		 [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		 [alert release];
		 
		 [self dataSourceDidFinishLoadingNewData];*/
	}
}

#pragma mark - Connection Delegate

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	[self.delegate loadingFailed:self withError:error];
	
	[super connection:theConnection didFailWithError:error];
	
	/*// Inform the user that the connection failed.
	NSString *message = [NSString stringWithFormat:@"There was an error retreiving the chat messages.\n\nError %i: %@", [error code], [error localizedDescription]];
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	alert.tag = 2;
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
	[alert release];
	
	[theConnection release];
	[receivedData release];
	
	[viewObjects hideLoadingScreen];
	[self dataSourceDidFinishLoadingNewData];*/
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
			TBXMLElement *chatMessagesElement = [TBXML childElementNamed:@"chatMessages" parentElement:root];
			if (chatMessagesElement)
			{
				// Loop through the chat messages
				TBXMLElement *chatMessage = [TBXML childElementNamed:@"chatMessage" parentElement:chatMessagesElement];
				while (chatMessage != nil)
				{
					NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
					
					// Create the chat message object and add it to the array
					ChatMessage *aChatMessage = [[ChatMessage alloc] initWithTBXMLElement:chatMessage];
					[chatMessages addObject:aChatMessage];
					[aChatMessage release];
					
					// Get the next message
					chatMessage = [TBXML nextSiblingNamed:@"chatMessage" searchFromElement:chatMessage];
					
					[pool release];
				}
			}
		}
	}
	[tbxml release];
	
	[super connectionDidFinishLoading:theConnection];

	
	/*viewObjects.chatMessages = [NSMutableArray arrayWithCapacity:1];
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
	 [receivedData release];*/
}

@end
