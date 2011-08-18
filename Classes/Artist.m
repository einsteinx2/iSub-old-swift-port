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
	
	return [anArtist autorelease];
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
		
		name = [[decoder decodeObject] retain];
		artistId = [[decoder decodeObject] retain];
	}
	
	return self;
}

-(id) copyWithZone: (NSZone *) zone
{
	Artist *newArtist = [[Artist alloc] init];
	
	newArtist.name = nil;
	newArtist.artistId = nil;
	
	newArtist.name = [[name copy] autorelease];
	newArtist.artistId = [[artistId copy] autorelease];
	
	return newArtist;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@: name: %@, artistId: %@", [super description], name, artistId];
}

- (void) dealloc 
{	
	[name release]; name = nil;
	[artistId release]; artistId = nil;
	[super dealloc];
}

@end
