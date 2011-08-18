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

-(id) copyWithZone: (NSZone *) zone
{
	ChatMessage *newChatMessage = [[ChatMessage alloc] init];
	newChatMessage.timestamp = timestamp;
	newChatMessage.user = [[user copy] autorelease];
	newChatMessage.message = [[message copy] autorelease];
	
	return newChatMessage;
}


- (void) dealloc 
{
	[user release]; user = nil;
	[message release]; message = nil;
	[super dealloc];
}


@end
