//
//  ChatMessage.m
//  iSub
//
//  Created by bbaron on 8/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ChatMessage.h"

@implementation ChatMessage

@synthesize timestamp, user, message;

- (id)initWithTBXMLElement:(TBXMLElement *)element
{
	if ((self = [super init]))
	{
		timestamp = NSIntegerMin;
		user = nil;
		message = nil;
		
		if ([TBXML valueOfAttributeNamed:@"time" forElement:element])
			self.timestamp = [[[TBXML valueOfAttributeNamed:@"time" forElement:element] substringToIndex:10] intValue];
		
		if ([TBXML valueOfAttributeNamed:@"user" forElement:element])
			self.user = [TBXML valueOfAttributeNamed:@"user" forElement:element];
		
		if ([TBXML valueOfAttributeNamed:@"message" forElement:element])
			self.message = [TBXML valueOfAttributeNamed:@"message" forElement:element];
	}
	
	return self;
}

-(id)copyWithZone: (NSZone *) zone
{
	ChatMessage *newChatMessage = [[ChatMessage alloc] init];
	newChatMessage.timestamp = timestamp;
	newChatMessage.user = [[user copy] autorelease];
	newChatMessage.message = [[message copy] autorelease];
	
	return newChatMessage;
}


- (void)dealloc 
{
	[user release]; user = nil;
	[message release]; message = nil;
	[super dealloc];
}


@end
