//
//  Song.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "TBXML.h"

@interface Song : NSObject <NSCoding, NSCopying> 

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *songId;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *album;
@property (nonatomic, copy) NSString *genre;
@property (nonatomic, copy) NSString *coverArtId;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *suffix;
@property (nonatomic, copy) NSString *transcodedSuffix;
@property (nonatomic, copy) NSNumber *duration;
@property (nonatomic, copy) NSNumber *bitRate;
@property (nonatomic, copy) NSNumber *track;
@property (nonatomic, copy) NSNumber *year;
@property (nonatomic, copy) NSNumber *size;

@property (readonly) NSString *localSuffix;
@property (readonly) NSString *localPath;
@property (readonly) unsigned long long localFileSize;

- (void)encodeWithCoder:(NSCoder *)encoder;
- (id)initWithCoder:(NSCoder *)decoder;

- (id)copyWithZone:(NSZone *)zone;

- (id)initWithTBXMLElement:(TBXMLElement *)element;
- (id)initWithAttributeDict:(NSDictionary *)attributeDict;

- (BOOL)isEqualToSong:(Song	*)otherSong;

@end

#import "Song+DAO.h"