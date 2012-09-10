//
//  Song.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "TBXML.h"
#import "MediaItem.h"

@interface Song : NSObject <NSCoding, NSCopying, MediaItem>

@property (copy) NSString *title;
@property (copy) NSString *songId;
@property (copy) NSString *parentId;
@property (copy) NSString *artist;
@property (copy) NSString *album;
@property (copy) NSString *genre;
@property (copy) NSString *coverArtId;
@property (copy) NSString *path;
@property (copy) NSString *suffix;
@property (copy) NSString *transcodedSuffix;
@property (copy) NSNumber *duration;
@property (copy) NSNumber *bitRate;
@property (copy) NSNumber *track;
@property (copy) NSNumber *year;
@property (copy) NSNumber *size;
@property BOOL isVideo;

- (NSString *)localSuffix;
- (NSString *)localPath;
- (NSString *)localTempPath;
- (NSString *)currentPath;
@property (readonly) BOOL isTempCached;
@property (readonly) unsigned long long localFileSize;
@property (readonly) NSUInteger estimatedBitrate;

- (void)encodeWithCoder:(NSCoder *)encoder;
- (id)initWithCoder:(NSCoder *)decoder;

- (id)copyWithZone:(NSZone *)zone;

- (id)initWithPMSDictionary:(NSDictionary *)dictionary;
- (id)initWithTBXMLElement:(TBXMLElement *)element;
- (id)initWithAttributeDict:(NSDictionary *)attributeDict;

- (BOOL)isEqualToSong:(Song	*)otherSong;

@end

#import "Song+DAO.h"