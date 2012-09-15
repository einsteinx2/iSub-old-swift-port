//
//  Artist.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "Artist.h"

@implementation Artist

+ (Artist *)artistWithName:(NSString *)theName andArtistId:(NSString *)theId
{
	Artist *anArtist = [[Artist alloc] init];
	anArtist.name = theName;
	anArtist.artistId = theId;
	
	return anArtist;
}

- (id)initWithAttributeDict:(NSDictionary *)attributeDict
{
	if ((self = [super init]))
	{
		self.name = [attributeDict objectForKey:@"name"];
		self.artistId = [attributeDict objectForKey:@"id"];
	}
	
	return self;
}

- (id) initWithTBXMLElement:(TBXMLElement *)element
{
	if ((self = [super init]))
	{
		self.name = [TBXML valueOfAttributeNamed:@"name" forElement:element];
		self.artistId = [TBXML valueOfAttributeNamed:@"id" forElement:element];
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:self.name];
	[encoder encodeObject:self.artistId];
}


- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		_name = [decoder decodeObject];
		_artistId = [decoder decodeObject];
	}
	
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	Artist *anArtist = [[Artist alloc] init];
	
	anArtist.name = [self.name copy];
	anArtist.artistId = [self.artistId copy];
	
	return anArtist;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@: name: %@, artistId: %@", [super description], self.name, self.artistId];
}


@end
