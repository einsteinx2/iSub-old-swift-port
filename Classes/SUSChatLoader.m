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

#pragma mark - Lifecycle

- (ISMSLoaderType)type
{
    return ISMSLoaderType_Chat;
}

#pragma mark - Loader Methods

- (NSURLRequest *)createRequest
{
    return [NSMutableURLRequest requestWithSUSAction:@"getChatMessages" parameters:nil];
}

- (void)processResponse 
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
						[self.chatMessages addObjectSafe:[[ChatMessage alloc] initWithTBXMLElement:chatMessage]];
						
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
