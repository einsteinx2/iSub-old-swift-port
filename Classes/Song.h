//
//  Song.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "TBXML.h"

@interface Song : NSObject <NSCoding, NSCopying> 
{
	NSString *title;
	NSString *songId;
	NSString *artist;
	NSString *album;
	NSString *genre;
	NSString *coverArtId;
	NSString *path;
	NSString *suffix;
	NSString *transcodedSuffix;
	NSNumber *duration;
	NSNumber *bitRate;
	NSNumber *track;
	NSNumber *year;
	NSNumber *size;
}

@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *songId;
@property (nonatomic, retain) NSString *artist;
@property (nonatomic, retain) NSString *album;
@property (nonatomic, retain) NSString *genre;
@property (nonatomic, retain) NSString *coverArtId;
@property (nonatomic, retain) NSString *path;
@property (nonatomic, retain) NSString *suffix;
@property (nonatomic, retain) NSString *transcodedSuffix;
@property (nonatomic, retain) NSNumber *duration;
@property (nonatomic, retain) NSNumber *bitRate;
@property (nonatomic, retain) NSNumber *track;
@property (nonatomic, retain) NSNumber *year;
@property (nonatomic, retain) NSNumber *size;

- (void)encodeWithCoder:(NSCoder *)encoder;
- (id)initWithCoder:(NSCoder *)decoder;

- (id)copyWithZone:(NSZone *)zone;

- (id)initWithTBXMLElement:(TBXMLElement *)element;
- (id)initWithAttributeDict:(NSDictionary *)attributeDict;

@end
