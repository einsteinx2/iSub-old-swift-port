//
//  Song.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "Song.h"
#import "GTMNSString+HTML.h"
#import "NSString-md5.h"
#import "MusicSingleton.h"

@implementation Song

@synthesize title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix;
@synthesize duration, bitRate, track, year, size;

- (id)initWithTBXMLElement:(TBXMLElement *)element
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
		
		self.title = [[TBXML valueOfAttributeNamed:@"title" forElement:element] gtm_stringByUnescapingFromHTML];
		self.songId = [TBXML valueOfAttributeNamed:@"id" forElement:element];
		self.artist = [[TBXML valueOfAttributeNamed:@"artist" forElement:element] gtm_stringByUnescapingFromHTML];
		if([TBXML valueOfAttributeNamed:@"album" forElement:element])
			self.album = [[TBXML valueOfAttributeNamed:@"album" forElement:element] gtm_stringByUnescapingFromHTML];
		if([TBXML valueOfAttributeNamed:@"genre" forElement:element])
			self.genre = [[TBXML valueOfAttributeNamed:@"genre" forElement:element] gtm_stringByUnescapingFromHTML];
		if([TBXML valueOfAttributeNamed:@"coverArt" forElement:element])
			self.coverArtId = [TBXML valueOfAttributeNamed:@"coverArt" forElement:element];
		self.path = [TBXML valueOfAttributeNamed:@"path" forElement:element];
		self.suffix = [TBXML valueOfAttributeNamed:@"suffix" forElement:element];
		if ([TBXML valueOfAttributeNamed:@"transcodedSuffix" forElement:element])
			self.transcodedSuffix = [TBXML valueOfAttributeNamed:@"transcodedSuffix" forElement:element];
		
		NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
		if([TBXML valueOfAttributeNamed:@"duration" forElement:element])
			self.duration = [numberFormatter numberFromString:[TBXML valueOfAttributeNamed:@"duration" forElement:element]];
		if([TBXML valueOfAttributeNamed:@"bitRate" forElement:element])
			self.bitRate = [numberFormatter numberFromString:[TBXML valueOfAttributeNamed:@"bitRate" forElement:element]];
		if([TBXML valueOfAttributeNamed:@"track" forElement:element])
			self.track = [numberFormatter numberFromString:[TBXML valueOfAttributeNamed:@"track" forElement:element]];
		if([TBXML valueOfAttributeNamed:@"year" forElement:element])
			self.year = [numberFormatter numberFromString:[TBXML valueOfAttributeNamed:@"year" forElement:element]];
		if([TBXML valueOfAttributeNamed:@"size" forElement:element])
			self.size = [numberFormatter numberFromString:[TBXML valueOfAttributeNamed:@"size" forElement:element]];
		
		[numberFormatter release];
	}
	
	return self;
}

- (id)initWithAttributeDict:(NSDictionary *)attributeDict
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
	//return [NSString stringWithFormat:@"%@: title: %@, songId: %@", [super description], title, songId];
	return [NSString stringWithFormat:@"%@  title: %@", [super description], title];
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

- (NSUInteger)hash
{
	return [songId hash];
}

- (BOOL)isEqualToSong:(Song	*)otherSong 
{
    if (self == otherSong)
        return YES;
	
	if (!songId || !otherSong.songId || !path || !otherSong.path)
		return NO;
	
	if (([songId isEqualToString:otherSong.songId] || (songId == nil && otherSong.songId == nil)) &&
		([path isEqualToString:otherSong.path] || (path == nil && otherSong.path == nil)) &&
		([title isEqualToString:otherSong.title] || (title == nil && otherSong.title == nil)) &&
		([artist isEqualToString:otherSong.artist] || (artist == nil && otherSong.artist == nil)) &&
		([album isEqualToString:otherSong.album] || (album == nil && otherSong.album == nil)) &&
		([genre isEqualToString:otherSong.genre] || (genre == nil && otherSong.genre == nil)) &&
		([coverArtId isEqualToString:otherSong.coverArtId] || (coverArtId == nil && otherSong.coverArtId == nil)) &&
		([suffix isEqualToString:otherSong.suffix] || (suffix == nil && otherSong.suffix == nil)) &&
		([transcodedSuffix isEqualToString:otherSong.transcodedSuffix] || (transcodedSuffix == nil && otherSong.transcodedSuffix == nil)) &&
		([duration isEqualToNumber:otherSong.duration] || (duration == nil && otherSong.duration == nil)) &&
		([bitRate isEqualToNumber:otherSong.bitRate] || (bitRate == nil && otherSong.bitRate == nil)) &&
		([track isEqualToNumber:otherSong.track] || (track == nil && otherSong.track == nil)) &&
		([year isEqualToNumber:otherSong.year] || (year == nil && otherSong.year == nil)) &&
		([size isEqualToNumber:otherSong.size] || (size == nil && otherSong.size == nil)))
		return YES;
	
	return NO;
}

- (BOOL)isEqual:(id)other 
{
    if (other == self)
        return YES;
	
    if (!other || ![other isKindOfClass:[self class]])
        return NO;
	
    return [self isEqualToSong:other];
}

- (NSString *)localSuffix
{
	if (transcodedSuffix)
		return transcodedSuffix;
	
	return suffix;
}

- (NSString *)localPath
{
	NSString *fileName = fileName = [[path md5] stringByAppendingPathExtension:self.localSuffix];
	return [[MusicSingleton sharedInstance].audioFolderPath stringByAppendingPathComponent:fileName];
}

- (unsigned long long)localFileSize
{
	return [[[NSFileManager defaultManager] attributesOfItemAtPath:self.localPath error:NULL] fileSize];
}

@end
