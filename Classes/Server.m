//
//  Server.m
//  iSub
//
//  Created by Ben Baron on 12/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "Server.h"

@implementation Server

@synthesize url, username, password, type;

- (id) init
{
	if ((self = [super init]))
	{
		url = nil;
		username = nil;
		password = nil;
		type = nil;
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:url];
	[encoder encodeObject:username];
	[encoder encodeObject:password];
	[encoder encodeObject:type];
}


- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		url = [[decoder decodeObject] retain];
		username = [[decoder decodeObject] retain];
		password = [[decoder decodeObject] retain];
		type = [[decoder decodeObject] retain];
	}
	
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@  type: %@", [super description], type];
}


- (void)dealloc
{
	[url release];
	[username release];
	[password release];
	[type release];
	
	[super dealloc];
}

@end
