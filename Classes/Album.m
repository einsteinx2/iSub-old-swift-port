//
//  Album.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "Album.h"
#import "Artist.h"

@implementation Album

@synthesize title, albumId, coverArtId, artistName, artistId;

- (id)initWithAttributeDict:(NSDictionary *)attributeDict
{
	if ((self = [super init]))
	{
		title = nil;
		albumId = nil;
		coverArtId = nil;
		artistName = nil;
		artistId = nil;
		
		if([attributeDict objectForKey:@"title"])
			self.title = [attributeDict objectForKey:@"title"];
		
		if([attributeDict objectForKey:@"id"])
			self.albumId = [attributeDict objectForKey:@"id"];
		
		if([attributeDict objectForKey:@"coverArt"])
			self.coverArtId = [attributeDict objectForKey:@"coverArt"];
		
		if([attributeDict objectForKey:@"artist"])
			self.artistName = [attributeDict objectForKey:@"artist"];
		
		if([attributeDict objectForKey:@"parent"])
			self.artistId = [attributeDict objectForKey:@"parent"];
	}
	
	return self;
}


- (id)initWithAttributeDict:(NSDictionary *)attributeDict artist:(Artist *)myArtist
{
	if (self = [super init])
	{
		title = nil;
		albumId = nil;
		coverArtId = nil;
		artistName = nil;
		artistId = nil;
		
		if([attributeDict objectForKey:@"title"])
			self.title = [attributeDict objectForKey:@"title"];
		
		if([attributeDict objectForKey:@"id"])
			self.albumId = [attributeDict objectForKey:@"id"];
		
		if([attributeDict objectForKey:@"coverArt"])
			self.coverArtId = [attributeDict objectForKey:@"coverArt"];
		
		if (myArtist)
		{
			self.artistName = myArtist.name;
			self.artistId = myArtist.artistId;
		}
	}
	
	return self;
}

-(void) encodeWithCoder: (NSCoder *) encoder
{
	[encoder encodeObject: title];
	[encoder encodeObject: albumId];
	[encoder encodeObject: coverArtId];
	[encoder encodeObject: artistName];
	[encoder encodeObject: artistId];
}


-(id) initWithCoder: (NSCoder *) decoder
{
	if (self = [super init])
	{
		title = nil;
		albumId = nil;
		coverArtId = nil;
		artistName = nil;
		artistId = nil;
		
		title = [[decoder decodeObject] retain];
		albumId = [[decoder decodeObject] retain];
		coverArtId = [[decoder decodeObject] retain];
		artistName = [[decoder decodeObject] retain];
		artistId = [[decoder decodeObject] retain];
	}
	
	return self;
}


-(id) copyWithZone: (NSZone *) zone
{
	Album *newAlbum = [[Album alloc] init];
	
	newAlbum.title = nil;
	newAlbum.albumId = nil;
	newAlbum.coverArtId = nil;
	newAlbum.artistName = nil;
	newAlbum.artistId = nil;
	
	newAlbum.title = [title copy];
	newAlbum.albumId = [albumId copy];
	newAlbum.coverArtId = [coverArtId copy];
	newAlbum.artistName = [artistName copy];
	newAlbum.artistId = [artistId copy];
	
	return newAlbum;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@: title: %@, albumId: %@, coverArtId: %@, artistName: %@, artistId: %@", [super description], title, albumId, coverArtId, artistName, artistId];
}


- (void) dealloc {
	
	[title release];
	[albumId release];
	[coverArtId release];
	[artistName release];
	[artistId release];
	[super dealloc];
}

@end
