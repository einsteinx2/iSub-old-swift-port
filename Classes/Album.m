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

- (id)initWithPMSDictionary:(NSDictionary *)dictionary
{
	if ((self = [super init]))
	{
		//title = [dictionary objectForKey:@"albumName"];
		//albumId = [dictionary objectForKey:@"albumId"];
		// albums are folders for now
		_title = N2n([dictionary objectForKey:@"folderName"]);
		_albumId = N2n([dictionary objectForKey:@"folderId"]);
		_coverArtId = N2n([dictionary objectForKey:@"artId"]);
		_artistName = N2n([dictionary objectForKey:@"artistName"]);
		_artistId = N2n([dictionary objectForKey:@"artistId"]);
	}
	return self;
}

- (id)initWithTBXMLElement:(TBXMLElement *)element artistId:(NSString *)artistIdToSet artistName:(NSString *)artistNameToSet
{
	if ((self = [super init]))
	{
		_title = [[TBXML valueOfAttributeNamed:@"title" forElement:element] cleanString];
		_albumId = [TBXML valueOfAttributeNamed:@"id" forElement:element];
		_coverArtId = [TBXML valueOfAttributeNamed:@"coverArt" forElement:element];
		_artistId = [NSString stringWithString:artistIdToSet];
		_artistName = [artistNameToSet cleanString];
	}
	
	return self;
}

- (id)initWithAttributeDict:(NSDictionary *)attributeDict
{
	if ((self = [super init]))
	{
		_title = [attributeDict objectForKey:@"title"];
		_albumId = [attributeDict objectForKey:@"id"];
		_coverArtId = [attributeDict objectForKey:@"coverArt"];
		_artistName = [attributeDict objectForKey:@"artist"];
		_artistId = [attributeDict objectForKey:@"parent"];
	}
	
	return self;
}


- (id)initWithAttributeDict:(NSDictionary *)attributeDict artist:(Artist *)myArtist
{
	if ((self = [super init]))
	{
		_title = [attributeDict objectForKey:@"title"];
		_albumId = [attributeDict objectForKey:@"id"];
		_coverArtId = [attributeDict objectForKey:@"coverArt"];
		
		if (myArtist)
		{
			_artistName = myArtist.name;
			_artistId = myArtist.artistId;
		}
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:self.title];
	[encoder encodeObject:self.albumId];
	[encoder encodeObject:self.coverArtId];
	[encoder encodeObject:self.artistName];
	[encoder encodeObject:self.artistId];
}


- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		_title = [decoder decodeObject];
		_albumId = [decoder decodeObject];
		_coverArtId = [decoder decodeObject];
		_artistName = [decoder decodeObject];
		_artistId = [decoder decodeObject];
	}
	
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	Album *anAlbum = [[Album alloc] init];
	
	anAlbum.title = [self.title copy];
	anAlbum.albumId = [self.albumId copy];
	anAlbum.coverArtId = [self.coverArtId copy];
	anAlbum.artistName = [self.artistName copy];
	anAlbum.artistId = [self.artistId copy];
	
	return anAlbum;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@: title: %@, albumId: %@, coverArtId: %@, artistName: %@, artistId: %@", [super description], self.title, self.self.albumId, self.coverArtId, self.artistName, self.artistId];
}



@end
