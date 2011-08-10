//
//  Song.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "Song.h"


@implementation Song

@synthesize title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix;
@synthesize duration, bitRate, track, year, size;

- (id)initWithAttributeDict:(NSDictionary*)attributeDict
{
	if ((self = [super init]))
	{
		title = nil;
		songId = nil;
		artist = nil;
		album = nil;
		genre = nil;
		coverArtId = nil;
		path = nil;
		suffix = nil;
		transcodedSuffix = nil;
		duration = nil;
		bitRate = nil;
		track = nil;
		year = nil;
		size = nil;
		
		if ([attributeDict objectForKey:@"title"])
			self.title = [attributeDict objectForKey:@"title"];
		
		if ([attributeDict objectForKey:@"id"])
			self.songId = [attributeDict objectForKey:@"id"];
		
		if ([attributeDict objectForKey:@"artist"])
			self.artist = [attributeDict objectForKey:@"artist"];
		
		if([attributeDict objectForKey:@"album"])
			self.album = [attributeDict objectForKey:@"album"];
		
		if([attributeDict objectForKey:@"genre"])
			self.genre = [attributeDict objectForKey:@"genre"];
		
		if([attributeDict objectForKey:@"coverArt"])
			self.coverArtId = [attributeDict objectForKey:@"coverArt"];
		
		if([attributeDict objectForKey:@"path"])
			self.path = [attributeDict objectForKey:@"path"];
		
		if([attributeDict objectForKey:@"suffix"])
			self.suffix = [attributeDict objectForKey:@"suffix"];
		
		if ([attributeDict objectForKey:@"transcodedSuffix"])
			self.transcodedSuffix = [attributeDict objectForKey:@"transcodedSuffix"];
		
		NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
		if([attributeDict objectForKey:@"duration"])
			self.duration = [numberFormatter numberFromString:[attributeDict objectForKey:@"duration"]];
		
		if([attributeDict objectForKey:@"bitRate"])
			self.bitRate = [numberFormatter numberFromString:[attributeDict objectForKey:@"bitRate"]];
		
		if([attributeDict objectForKey:@"track"])
			self.track = [numberFormatter numberFromString:[attributeDict objectForKey:@"track"]];
		
		if([attributeDict objectForKey:@"year"])
			self.year = [numberFormatter numberFromString:[attributeDict objectForKey:@"year"]];
		
		if ([attributeDict objectForKey:@"size"])
			self.size = [numberFormatter numberFromString:[attributeDict objectForKey:@"size"]];
		[numberFormatter release];
	}
	
	return self;
}

-(void) encodeWithCoder: (NSCoder *) encoder
{
	[encoder encodeObject: title];
	[encoder encodeObject: songId];
	[encoder encodeObject: artist];
	[encoder encodeObject: album];
	[encoder encodeObject: genre];
	[encoder encodeObject: coverArtId];
	[encoder encodeObject: path];
	[encoder encodeObject: suffix];
	[encoder encodeObject: transcodedSuffix];
	[encoder encodeObject: duration];
	[encoder encodeObject: bitRate];
	[encoder encodeObject: track];
	[encoder encodeObject: year];
	[encoder encodeObject: size];
}


-(id) initWithCoder: (NSCoder *) decoder
{
	if ((self = [super init]))
	{
		title = nil;
		songId = nil;
		artist = nil;
		album = nil;
		genre = nil;
		coverArtId = nil;
		path = nil;
		suffix = nil;
		transcodedSuffix = nil;
		duration = nil;
		bitRate = nil;
		track = nil;
		year = nil;
		size = nil;
		
		title = [[decoder decodeObject] retain];
		songId = [[decoder decodeObject] retain];
		artist = [[decoder decodeObject] retain];
		album = [[decoder decodeObject] retain];
		genre = [[decoder decodeObject] retain];
		coverArtId = [[decoder decodeObject] retain];
		path = [[decoder decodeObject] retain];
		suffix = [[decoder decodeObject] retain];
		transcodedSuffix = [[decoder decodeObject] retain];
		duration = [[decoder decodeObject] retain];
		bitRate = [[decoder decodeObject] retain];
		track = [[decoder decodeObject] retain];
		year = [[decoder decodeObject] retain];
		size = [[decoder decodeObject] retain];
	}
	
	return self;
}


-(id) copyWithZone: (NSZone *) zone
{
	Song *newSong = [[Song alloc] init];
	
	newSong.title = nil;
	newSong.songId = nil;
	newSong.artist = nil;
	newSong.album = nil;
	newSong.genre = nil;
	newSong.coverArtId = nil;
	newSong.path = nil;
	newSong.suffix = nil;
	newSong.transcodedSuffix = nil;
	newSong.duration = nil;
	newSong.bitRate = nil;
	newSong.track = nil;
	newSong.year = nil;
	newSong.size = nil;
	
	newSong.title = [[title copy] autorelease];
	newSong.songId = [[songId copy] autorelease];
	newSong.artist = [[artist copy] autorelease];
	newSong.album = [[album copy] autorelease];
	newSong.genre = [[genre copy] autorelease];
	newSong.coverArtId = [[coverArtId copy] autorelease];
	newSong.path = [[path copy] autorelease];
	newSong.suffix = [[suffix copy] autorelease];
	newSong.transcodedSuffix = [[transcodedSuffix copy] autorelease];
	newSong.duration = [[duration copy] autorelease];
	newSong.bitRate = [[bitRate copy] autorelease];
	newSong.track = [[track copy] autorelease];
	newSong.year = [[year copy] autorelease];
	newSong.size = [[size copy] autorelease];
	
	return newSong;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@: title: %@, songId: %@", [super description], title, songId];
}


- (void) dealloc 
{	
	[title release]; title = nil;
	[songId release]; songId = nil;
	[artist release]; artist = nil;
	[album release]; album = nil;
	[genre release]; genre = nil;
	[coverArtId release]; coverArtId = nil;
	[path release]; path = nil;
	[suffix release]; suffix = nil;
	[transcodedSuffix release]; transcodedSuffix = nil;
	[duration release]; duration = nil;
	[bitRate release]; bitRate = nil;
	[track release]; track = nil;
	[year release]; year = nil;
	[size release]; size = nil;
	
	[super dealloc];
}

@end
