//
//  Song.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "Song.h"
#include <sys/stat.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation Song

- (id)initWithPMSDictionary:(NSDictionary *)dictionary
{
	if ((self = [super init]))
	{
		NSString *songName = [dictionary objectForKey:@"songName"];
		NSString *titleKey = !songName || songName.length == 0  ? @"fileName" : @"songName";
		_title = [dictionary objectForKey:titleKey];
		_songId = N2n([dictionary objectForKey:@"itemId"]);
		_parentId = N2n([dictionary objectForKey:@"folderId"]);
		_artist = N2n([dictionary objectForKey:@"artistName"]);
		_album = N2n([dictionary objectForKey:@"albumName"]);
		_genre = N2n([dictionary objectForKey:@"genreName"]);
		_coverArtId = N2n([dictionary objectForKey:@"artId"]);
		_suffix = N2n([dictionary objectForKey:@"fileType"]);
		_duration = N2n([dictionary objectForKey:@"duration"]);
		_bitRate = N2n([dictionary objectForKey:@"bitrate"]);
		_track = N2n([dictionary objectForKey:@"trackNumber"]);
		_year = N2n([dictionary objectForKey:@"year"]);
		_size = N2n([dictionary objectForKey:@"fileSize"]);
		 
		// Generate "path" from artist, album and song name
		NSString *artistName = _artist ? _artist : @"Unknown";
		NSString *albumName = _album ? _album : @"Unknown";
		_path = [NSString stringWithFormat:@"%@/%@/%@", artistName, albumName, _title];
	}
	return self;
}

- (id)initWithTBXMLElement:(TBXMLElement *)element
{
	if ((self = [super init]))
	{
		self.title = [[TBXML valueOfAttributeNamed:@"title" forElement:element] cleanString];
		self.songId = [TBXML valueOfAttributeNamed:@"id" forElement:element];
		self.parentId = [TBXML valueOfAttributeNamed:@"parent" forElement:element];
		self.artist = [[TBXML valueOfAttributeNamed:@"artist" forElement:element] cleanString];
		self.album = [[TBXML valueOfAttributeNamed:@"album" forElement:element] cleanString];
		self.genre = [[TBXML valueOfAttributeNamed:@"genre" forElement:element] cleanString];
		self.coverArtId = [TBXML valueOfAttributeNamed:@"coverArt" forElement:element];
		self.path = [[TBXML valueOfAttributeNamed:@"path" forElement:element] cleanString];
		self.suffix = [TBXML valueOfAttributeNamed:@"suffix" forElement:element];
		self.transcodedSuffix = [TBXML valueOfAttributeNamed:@"transcodedSuffix" forElement:element];
		
        NSString *durationString = [TBXML valueOfAttributeNamed:@"duration" forElement:element];
		if(durationString) self.duration = @(durationString.intValue);
        
        NSString *bitRateString = [TBXML valueOfAttributeNamed:@"bitRate" forElement:element];
		if(bitRateString) self.bitRate = @(bitRateString.intValue);

        NSString *trackString = [TBXML valueOfAttributeNamed:@"track" forElement:element];
		if(trackString) self.track = @(trackString.intValue);
        
        NSString *yearString = [TBXML valueOfAttributeNamed:@"year" forElement:element];
		if(yearString) self.year = @(yearString.intValue);
        
        NSString *sizeString = [TBXML valueOfAttributeNamed:@"size" forElement:element];
        if (sizeString) self.size = @(sizeString.longLongValue);
        
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
	[encoder encodeObject:self.title forKey:@"title"];
	[encoder encodeObject:self.songId forKey:@"songId"];
	[encoder encodeObject:self.parentId forKey:@"parentId"];
	[encoder encodeObject:self.artist forKey:@"artist"];
	[encoder encodeObject:self.album forKey:@"album"];
	[encoder encodeObject:self.genre forKey:@"genre"];
	[encoder encodeObject:self.coverArtId forKey:@"coverArtId"];
	[encoder encodeObject:self.path forKey:@"path"];
	[encoder encodeObject:self.suffix forKey:@"suffix"];
	[encoder encodeObject:self.transcodedSuffix forKey:@"transcodedSuffix"];
	[encoder encodeObject:self.duration forKey:@"duration"];
	[encoder encodeObject:self.bitRate forKey:@"bitRate"];
	[encoder encodeObject:self.track forKey:@"track"];
	[encoder encodeObject:self.year forKey:@"year"];
	[encoder encodeObject:self.size forKey:@"size"];
    [encoder encodeBool:self.isVideo forKey:@"isVideo"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		// Check if this object is using the new encoding
		if ([decoder containsValueForKey:@"songId"])
		{
			_title = [decoder decodeObjectForKey:@"title"];
			_songId = [decoder decodeObjectForKey:@"songId"];
			_parentId = [decoder decodeObjectForKey:@"parentId"];
			_artist = [decoder decodeObjectForKey:@"artist"];
			_album = [decoder decodeObjectForKey:@"album"];
			_genre = [decoder decodeObjectForKey:@"genre"];
			_coverArtId = [decoder decodeObjectForKey:@"coverArtId"];
			_path = [decoder decodeObjectForKey:@"path"];
			_suffix = [decoder decodeObjectForKey:@"suffix"];
			_transcodedSuffix = [decoder decodeObjectForKey:@"transcodedSuffix"];
			_duration =[decoder decodeObjectForKey:@"duration"];
			_bitRate = [decoder decodeObjectForKey:@"bitRate"];
			_track = [decoder decodeObjectForKey:@"track"];
			_year = [decoder decodeObjectForKey:@"year"];
			_size = [decoder decodeObjectForKey:@"size"];
            _isVideo = [decoder decodeBoolForKey:@"isVideo"];
		}
		else
		{
			_title = [decoder decodeObject];
			_songId = [decoder decodeObject];
			_artist = [decoder decodeObject];
			_album = [decoder decodeObject];
			_genre = [decoder decodeObject];
			_coverArtId = [decoder decodeObject];
			_path = [decoder decodeObject];
			_suffix = [decoder decodeObject];
			_transcodedSuffix = [decoder decodeObject];
			_duration = [decoder decodeObject];
			_bitRate = [decoder decodeObject];
			_track = [decoder decodeObject];
			_year = [decoder decodeObject];
			_size = [decoder decodeObject];
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
	return [NSString stringWithFormat:@"%@  title: %@", [super description], self.title];
}

- (NSUInteger)hash
{
	return self.songId.hash;
}

- (BOOL)isEqualToSong:(Song	*)otherSong 
{
    if (self == otherSong)
        return YES;
	
	if (!self.songId || !otherSong.songId || !self.path || !otherSong.path)
		return NO;
	
	if (([self.songId isEqualToString:otherSong.songId] || (self.songId == nil && otherSong.songId == nil)) &&
		([self.path isEqualToString:otherSong.path] || (self.path == nil && otherSong.path == nil)) &&
		([self.title isEqualToString:otherSong.title] || (self.title == nil && otherSong.title == nil)) &&
		([self.artist isEqualToString:otherSong.artist] || (self.artist == nil && otherSong.artist == nil)) &&
		([self.album isEqualToString:otherSong.album] || (self.album == nil && otherSong.album == nil)) &&
		([self.genre isEqualToString:otherSong.genre] || (self.genre == nil && otherSong.genre == nil)) &&
		([self.coverArtId isEqualToString:otherSong.coverArtId] || (self.coverArtId == nil && otherSong.coverArtId == nil)) &&
		([self.suffix isEqualToString:otherSong.suffix] || (self.suffix == nil && otherSong.suffix == nil)) &&
		([self.transcodedSuffix isEqualToString:otherSong.transcodedSuffix] || (self.transcodedSuffix == nil && otherSong.transcodedSuffix == nil)) &&
		([self.duration isEqualToNumber:otherSong.duration] || (self.duration == nil && otherSong.duration == nil)) &&
		([self.bitRate isEqualToNumber:otherSong.bitRate] || (self.bitRate == nil && otherSong.bitRate == nil)) &&
		([self.track isEqualToNumber:otherSong.track] || (self.track == nil && otherSong.track == nil)) &&
		([self.year isEqualToNumber:otherSong.year] || (self.year == nil && otherSong.year == nil)) &&
		([self.size isEqualToNumber:otherSong.size] || (self.size == nil && otherSong.size == nil)) &&
        self.isVideo == otherSong.isVideo)
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
	if (self.transcodedSuffix)
		return self.transcodedSuffix;
	
	return self.suffix;
}

- (NSString *)localPath
{
	NSString *fileName = self.localSuffix ? [self.path.md5 stringByAppendingPathExtension:self.localSuffix] : nil;
	return fileName ? [settingsS.songCachePath stringByAppendingPathComponent:fileName] : nil;
}

- (NSString *)localTempPath
{
	NSString *fileName = self.localSuffix ? [self.path.md5 stringByAppendingPathExtension:self.localSuffix] : nil;
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
