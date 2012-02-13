//
//  Song.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "Song.h"
#import "GTMNSString+HTML.h"
#import "NSString+md5.h"
#import "SavedSettings.h"

@implementation Song

@synthesize title, songId, parentId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix;
@synthesize duration, bitRate, track, year, size;

- (id)initWithTBXMLElement:(TBXMLElement *)element
{
	if ((self = [super init]))
	{
		title = nil;
		songId = nil;
		parentId = nil;
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
		if ([TBXML valueOfAttributeNamed:@"parent" forElement:element])
			self.parentId = [TBXML valueOfAttributeNamed:@"parent" forElement:element];
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
		
		DLog(@"title: %@", self.title);
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
		DLog(@"size: %llu   size: %f", [size unsignedLongLongValue], [size doubleValue]);
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
		parentId = nil;
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
		
		if ([attributeDict objectForKey:@"parent"])
			self.parentId = [attributeDict objectForKey:@"parent"];
		
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

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:title forKey:@"title"];
	[encoder encodeObject:songId forKey:@"songId"];
	[encoder encodeObject:parentId forKey:@"parentId"];
	[encoder encodeObject:artist forKey:@"artist"];
	[encoder encodeObject:album forKey:@"album"];
	[encoder encodeObject:genre forKey:@"genre"];
	[encoder encodeObject:coverArtId forKey:@"coverArtId"];
	[encoder encodeObject:path forKey:@"path"];
	[encoder encodeObject:suffix forKey:@"suffix"];
	[encoder encodeObject:transcodedSuffix forKey:@"transcodedSuffix"];
	[encoder encodeObject:duration forKey:@"duration"];
	[encoder encodeObject:bitRate forKey:@"bitRate"];
	[encoder encodeObject:track forKey:@"track"];
	[encoder encodeObject:year forKey:@"year"];
	[encoder encodeObject:size forKey:@"size"];
}


- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		title = nil;
		songId = nil;
		parentId = nil;
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
		
		// Check if this object is using the new encoding
		if ([decoder containsValueForKey:@"songId"])
		{
			title = [[decoder decodeObjectForKey:@"title"] retain];
			songId = [[decoder decodeObjectForKey:@"songId"] retain];
			parentId = [[decoder decodeObjectForKey:@"parentId"] retain];
			artist = [[decoder decodeObjectForKey:@"artist"] retain];
			album = [[decoder decodeObjectForKey:@"album"] retain];
			genre = [[decoder decodeObjectForKey:@"genre"] retain];
			coverArtId = [[decoder decodeObjectForKey:@"coverArtId"] retain];
			path = [[decoder decodeObjectForKey:@"path"] retain];
			suffix = [[decoder decodeObjectForKey:@"suffix"] retain];
			transcodedSuffix = [[decoder decodeObjectForKey:@"transcodedSuffix"] retain];
			duration =[[decoder decodeObjectForKey:@"duration"] retain];
			bitRate = [[decoder decodeObjectForKey:@"bitRate"] retain];
			track = [[decoder decodeObjectForKey:@"track"] retain];
			year = [[decoder decodeObjectForKey:@"year"] retain];
			size = [[decoder decodeObjectForKey:@"size"] retain];
		}
		else
		{
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
	}
	
	return self;
}


-(id)copyWithZone:(NSZone *)zone
{
	Song *newSong = [[Song alloc] init];

	// Can directly assign because properties have "copy" type
	newSong.title = self.title;
	newSong.songId = self.songId;
	newSong.parentId = self.parentId;
	newSong.artist = self.artist;
	newSong.album = self.album;
	newSong.genre = self.genre;
	newSong.coverArtId = self.coverArtId;
	newSong.path = self.path;
	newSong.suffix = self.suffix;
	newSong.transcodedSuffix = self.transcodedSuffix;
	newSong.duration = self.duration;
	newSong.bitRate = self.bitRate;
	newSong.track = self.track;
	newSong.year = self.year;
	newSong.size = self.size;
	
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
	return [[SavedSettings sharedInstance].songCachePath stringByAppendingPathComponent:fileName];
}

- (NSString *)localTempPath
{
	NSString *fileName = fileName = [[path md5] stringByAppendingPathExtension:self.localSuffix];
	return [[SavedSettings sharedInstance].tempCachePath stringByAppendingPathComponent:fileName];
}

- (NSString *)currentPath
{
	return self.isTempCached ? self.localTempPath : self.localPath;
}

- (BOOL)isTempCached
{	
	// If the song is fully cached, then it doesn't matter if there is a temp cache file
	if (self.isFullyCached)
		return NO;
	
	// Return YES if the song exists in the temp folder
	return [[NSFileManager defaultManager] fileExistsAtPath:self.localTempPath];
}

- (unsigned long long)localFileSize
{
	return [[[NSFileManager defaultManager] attributesOfItemAtPath:self.currentPath error:NULL] fileSize];
}

- (NSUInteger)estimatedBitrate
{	
	SavedSettings *settings = [SavedSettings sharedInstance];
	
	// Default to 128 if there is no bitrate for this song object (should never happen)
	int rate = self.bitRate ? [self.bitRate intValue] : 128;
	
	// Check if this is being transcoded to the best of our knowledge
	if (self.transcodedSuffix)
	{
		// This is probably being transcoded, so attempt to determine the bitrate
		if (rate > 128 && settings.currentMaxBitrate == 0)
			rate = 128; // Subsonic default transcoding bitrate
		else if (rate > settings.currentMaxBitrate && settings.currentMaxBitrate != 0)
			rate = settings.currentMaxBitrate;
	}
	else
	{
		// This is not being transcoded between formats, however bitrate limiting may be active
		if (rate > settings.currentMaxBitrate && settings.currentMaxBitrate != 0)
			rate = settings.currentMaxBitrate;
	}

	DLog(@"estimated bitrate: %i", rate);
	return rate;
}

@end
