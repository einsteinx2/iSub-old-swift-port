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

- (id)initWithPMSDictionary:(NSDictionary *)dictionary
{
	if ((self = [super init]))
	{
		//title = [dictionary objectForKey:@"albumName"];
		//albumId = [dictionary objectForKey:@"albumId"];
		// albums are folders for now
		title = N2n([dictionary objectForKey:@"folderName"]);
		albumId = N2n([dictionary objectForKey:@"folderId"]);
		coverArtId = N2n([dictionary objectForKey:@"artId"]);
		artistName = N2n([dictionary objectForKey:@"artistName"]);
		artistId = N2n([dictionary objectForKey:@"artistId"]);
	}
	return self;
}

- (id)initWithTBXMLElement:(TBXMLElement *)element artistId:(NSString *)artistIdToSet artistName:(NSString *)artistNameToSet
{
	if ((self = [super init]))
	{
		title = [[TBXML valueOfAttributeNamed:@"title" forElement:element] cleanString];
		albumId = [TBXML valueOfAttributeNamed:@"id" forElement:element];
		coverArtId = [TBXML valueOfAttributeNamed:@"coverArt" forElement:element];
		artistId = [NSString stringWithString:artistIdToSet];
		self.artistName = [artistNameToSet cleanString];
	}
	
	return self;
}

- (id)initWithAttributeDict:(NSDictionary *)attributeDict
{
	if ((self = [super init]))
	{
		title = [attributeDict objectForKey:@"title"];
		albumId = [attributeDict objectForKey:@"id"];
		coverArtId = [attributeDict objectForKey:@"coverArt"];
		artistName = [attributeDict objectForKey:@"artist"];
		artistId = [attributeDict objectForKey:@"parent"];
	}
	
	return self;
}


- (id)initWithAttributeDict:(NSDictionary *)attributeDict artist:(Artist *)myArtist
{
	if ((self = [super init]))
	{
		title = [attributeDict objectForKey:@"title"];
		albumId = [attributeDict objectForKey:@"id"];
		coverArtId = [attributeDict objectForKey:@"coverArt"];
		
		if (myArtist)
		{
			artistName = myArtist.name;
			artistId = myArtist.artistId;
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
	if ((self = [super init]))
	{
		title = [decoder decodeObject];
		albumId = [decoder decodeObject];
		coverArtId = [decoder decodeObject];
		artistName = [decoder decodeObject];
		artistId = [decoder decodeObject];
	}
	
	return self;
}


-(id) copyWithZone: (NSZone *) zone
{
	Album *anAlbum = [[Album alloc] init];
	
	anAlbum.title = [title copy];
	anAlbum.albumId = [albumId copy];
	anAlbum.coverArtId = [coverArtId copy];
	anAlbum.artistName = [artistName copy];
	anAlbum.artistId = [artistId copy];
	
	return anAlbum;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@: title: %@, albumId: %@, coverArtId: %@, artistName: %@, artistId: %@", [super description], title, albumId, coverArtId, artistName, artistId];
}



@end
