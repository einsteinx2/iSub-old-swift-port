//
//  Artist.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "Artist.h"

@implementation Artist

@synthesize name, artistId;

+ (Artist *) artistWithName:(NSString *)theName andArtistId:(NSString *)theId
{
	Artist *anArtist = [[Artist alloc] init];
	
	anArtist.name = nil;
	anArtist.artistId = nil;
	
	anArtist.name = theName;
	anArtist.artistId = theId;
	
	return anArtist;
}

- (id) initWithAttributeDict:(NSDictionary *)attributeDict
{
	if ((self = [super init]))
	{
		name = nil;
		artistId = nil;
		
		if ([attributeDict objectForKey:@"name"])
			self.name = [attributeDict objectForKey:@"name"];
		
		if ([attributeDict objectForKey:@"id"])
			self.artistId = [attributeDict objectForKey:@"id"];
	}
	
	return self;
}

- (id) initWithTBXMLElement:(TBXMLElement *)element
{
	if ((self = [super init]))
	{
		name = nil;
		artistId = nil;
		
		if ([TBXML valueOfAttributeNamed:@"name" forElement:element])
			self.name = [TBXML valueOfAttributeNamed:@"name" forElement:element];
		
		if ([TBXML valueOfAttributeNamed:@"id" forElement:element])
			self.artistId = [TBXML valueOfAttributeNamed:@"id" forElement:element];
	}
	
	return self;
}

-(void) encodeWithCoder: (NSCoder *) encoder
{
	[encoder encodeObject: name];
	[encoder encodeObject: artistId];
}


-(id) initWithCoder: (NSCoder *) decoder
{
	if ((self = [super init]))
	{
		name = nil;
		artistId = nil;
		
		name = [decoder decodeObject];
		artistId = [decoder decodeObject];
	}
	
	return self;
}

-(id) copyWithZone: (NSZone *) zone
{
	Artist *newArtist = [[Artist alloc] init];
	
	newArtist.name = nil;
	newArtist.artistId = nil;
	
	newArtist.name = [name copy];
	newArtist.artistId = [artistId copy];
	
	return newArtist;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@: name: %@, artistId: %@", [super description], name, artistId];
}


@end
