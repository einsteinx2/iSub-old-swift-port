//
//  Server.m
//  iSub
//
//  Created by Ben Baron on 12/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "Server.h"

@implementation Server

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:self.url];
	[encoder encodeObject:self.username];
	[encoder encodeObject:self.password];
	[encoder encodeObject:self.type];
}


- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		_url = [decoder decodeObject];
		_username = [decoder decodeObject];
		_password = [decoder decodeObject];
		_type = [decoder decodeObject];
	}
	
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@  type: %@", [super description], self.type];
}



@end
