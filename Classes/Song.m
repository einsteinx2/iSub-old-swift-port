//
//  Song.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "Song.h"
#import "SavedSettings.h"
#include <sys/stat.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation Song

@synthesize title, songId, parentId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix;
@synthesize duration, bitRate, track, year, size, isVideo;

- (id)initWithPMSDictionary:(NSDictionary *)dictionary
{
	if ((self = [super init]))
	{
		NSString *songName = [dictionary objectForKey:@"songName"];
		NSString *titleKey = !songName || songName.length == 0  ? @"fileName" : @"songName";
		title = [dictionary objectForKey:titleKey];
		songId = N2n([dictionary objectForKey:@"itemId"]);
		parentId = N2n([dictionary objectForKey:@"folderId"]);
		artist = N2n([dictionary objectForKey:@"artistName"]);
		album = N2n([dictionary objectForKey:@"albumName"]);
		genre = N2n([dictionary objectForKey:@"genreName"]);
		coverArtId = N2n([dictionary objectForKey:@"artId"]);
		suffix = N2n([dictionary objectForKey:@"fileType"]);
		duration = N2n([dictionary objectForKey:@"duration"]);
		bitRate = N2n([dictionary objectForKey:@"bitrate"]);
		track = N2n([dictionary objectForKey:@"trackNumber"]);
		year = N2n([dictionary objectForKey:@"year"]);
		size = N2n([dictionary objectForKey:@"fileSize"]);
		 
		// Generate "path" from artist, album and song name
		NSString *artistName = artist ? artist : @"Unknown";
		NSString *albumName = album ? album : @"Unknown";
		path = [NSString stringWithFormat:@"%@/%@/%@", artistName, albumName, title];
	}
	return self;
}

- (id)initWithTBXMLElement:(TBXMLElement *)element
{
	if ((self = [super init]))
	{
		self.title = [[TBXML valueOfAttributeNamed:@"title" forElement:element] cleanString];
		self.songId = [TBXML valueOfAttributeNamed:@"id" forElement:element];
		if ([TBXML valueOfAttributeNamed:@"parent" forElement:element])
			self.parentId = [TBXML valueOfAttributeNamed:@"parent" forElement:element];
		self.artist = [[TBXML valueOfAttributeNamed:@"artist" forElement:element] cleanString];
		if([TBXML valueOfAttributeNamed:@"album" forElement:element])
			self.album = [[TBXML valueOfAttributeNamed:@"album" forElement:element] cleanString];
		if([TBXML valueOfAttributeNamed:@"genre" forElement:element])
			self.genre = [[TBXML valueOfAttributeNamed:@"genre" forElement:element] cleanString];
		if([TBXML valueOfAttributeNamed:@"coverArt" forElement:element])
			self.coverArtId = [TBXML valueOfAttributeNamed:@"coverArt" forElement:element];
		self.path = [[TBXML valueOfAttributeNamed:@"path" forElement:element] cleanString];
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
        if([TBXML valueOfAttributeNamed:@"isVideo" forElement:element])
            self.isVideo = [[TBXML valueOfAttributeNamed:@"isVideo" forElement:element] boolValue];
	}
	
	return self;
}

- (id)initWithAttributeDict:(NSDictionary *)attributeDict
{
	if ((self = [super init]))
	{
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
        
        if ([attributeDict objectForKey:@"isVideo"])
			self.isVideo = [[attributeDict objectForKey:@"isVideo"] boolValue];
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
    [encoder encodeBool:isVideo forKey:@"isVideo"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		// Check if this object is using the new encoding
		if ([decoder containsValueForKey:@"songId"])
		{
			title = [decoder decodeObjectForKey:@"title"];
			songId = [decoder decodeObjectForKey:@"songId"];
			parentId = [decoder decodeObjectForKey:@"parentId"];
			artist = [decoder decodeObjectForKey:@"artist"];
			album = [decoder decodeObjectForKey:@"album"];
			genre = [decoder decodeObjectForKey:@"genre"];
			coverArtId = [decoder decodeObjectForKey:@"coverArtId"];
			path = [decoder decodeObjectForKey:@"path"];
			suffix = [decoder decodeObjectForKey:@"suffix"];
			transcodedSuffix = [decoder decodeObjectForKey:@"transcodedSuffix"];
			duration =[decoder decodeObjectForKey:@"duration"];
			bitRate = [decoder decodeObjectForKey:@"bitRate"];
			track = [decoder decodeObjectForKey:@"track"];
			year = [decoder decodeObjectForKey:@"year"];
			size = [decoder decodeObjectForKey:@"size"];
            isVideo = [decoder decodeBoolForKey:@"isVideo"];
		}
		else
		{
			title = [decoder decodeObject];
			songId = [decoder decodeObject];
			artist = [decoder decodeObject];
			album = [decoder decodeObject];
			genre = [decoder decodeObject];
			coverArtId = [decoder decodeObject];
			path = [decoder decodeObject];
			suffix = [decoder decodeObject];
			transcodedSuffix = [decoder decodeObject];
			duration = [decoder decodeObject];
			bitRate = [decoder decodeObject];
			track = [decoder decodeObject];
			year = [decoder decodeObject];
			size = [decoder decodeObject];
		}
	}
	
	return self;
}

- (id)copyWithZone:(NSZone *)zone
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
    newSong.isVideo = self.isVideo;
	
	return newSong;
}

- (NSString *)description
{
	//return [NSString stringWithFormat:@"%@: title: %@, songId: %@", [super description], title, songId];
	return [NSString stringWithFormat:@"%@  title: %@", [super description], title];
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
		([size isEqualToNumber:otherSong.size] || (size == nil && otherSong.size == nil)) &&
        isVideo == otherSong.isVideo)
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

- (NSString *)itemId
{
    return self.songId;
}

- (void)setItemId:(NSString *)itemId
{
    self.songId = itemId;
}

- (NSString *)localSuffix
{
	if (transcodedSuffix)
		return transcodedSuffix;
	
	return suffix;
}

- (NSString *)localPath
{
	NSString *fileName = self.localSuffix ? [[path md5] stringByAppendingPathExtension:self.localSuffix] : nil;
	return fileName ? [settingsS.songCachePath stringByAppendingPathComponent:fileName] : nil;
}

- (NSString *)localTempPath
{
	NSString *fileName = self.localSuffix ? [[path md5] stringByAppendingPathExtension:self.localSuffix] : nil;
	return fileName ? [settingsS.tempCachePath stringByAppendingPathComponent:fileName] : nil;
}

- (NSString *)currentPath
{
	return self.isTempCached ? self.localTempPath : self.localPath;
}

- (BOOL)isTempCached
{	
	// If the song is fully cached, then it doesn't matter if there is a temp cache file
	//if (self.isFullyCached)
	//	return NO;
	
	// Return YES if the song exists in the temp folder
	return [[NSFileManager defaultManager] fileExistsAtPath:self.localTempPath];
}

- (unsigned long long)localFileSize
{
	// Using C instead of Cocoa because of a weird crash on iOS 5 devices in the audio engine
	// Asked question here: http://stackoverflow.com/questions/10289536/sigsegv-segv-accerr-crash-in-nsfileattributes-dealloc-when-autoreleasepool-is-dr
	// Still waiting for an answer on what the crash could be, so this is my temporary "solution"
	struct stat st;
	stat(self.currentPath.cStringUTF8, &st);
	return st.st_size;
	
	//return [[[NSFileManager defaultManager] attributesOfItemAtPath:self.currentPath error:NULL] fileSize];
}

- (NSUInteger)estimatedBitrate
{	
	NSInteger currentMaxBitrate = settingsS.currentMaxBitrate;
	
	// Default to 128 if there is no bitrate for this song object (should never happen)
	int rate = (!self.bitRate || [self.bitRate intValue] == 0) ? 128 : [self.bitRate intValue];
	
	// Check if this is being transcoded to the best of our knowledge
	if (self.transcodedSuffix)
	{
		// This is probably being transcoded, so attempt to determine the bitrate
		if (rate > 128 && currentMaxBitrate == 0)
			rate = 128; // Subsonic default transcoding bitrate
		else if (rate > currentMaxBitrate && currentMaxBitrate != 0)
			rate = currentMaxBitrate;
	}
	else
	{
		// This is not being transcoded between formats, however bitrate limiting may be active
		if (rate > currentMaxBitrate && currentMaxBitrate != 0)
			rate = currentMaxBitrate;
	}

	return rate;
}

@end
