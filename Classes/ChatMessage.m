//
//  ChatMessage.m
//  iSub
//
//  Created by bbaron on 8/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ChatMessage.h"

@implementation ChatMessage

- (id)initWithTBXMLElement:(TBXMLElement *)element
{
	if ((self = [super init]))
	{
		_timestamp = NSIntegerMin;

        NSString *time = [TBXML valueOfAttributeNamed:@"time" forElement:element];
		if (time)
			self.timestamp = [[time substringToIndex:10] intValue];
		
		self.user = [[TBXML valueOfAttributeNamed:@"username" forElement:element] cleanString];
		self.message = [[TBXML valueOfAttributeNamed:@"message" forElement:element] cleanString];
	}
	
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	ChatMessage *newChatMessage = [[ChatMessage alloc] init];
	newChatMessage.timestamp = self.timestamp;
	newChatMessage.user = self.user;
	newChatMessage.message = self.message;
	
	return newChatMessage;
}

@end
