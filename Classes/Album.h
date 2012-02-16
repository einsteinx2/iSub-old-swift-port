//
//  Album.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "TBXML.h"

@class Artist;

@interface Album : NSObject <NSCoding, NSCopying> 
{
	NSString *title;
	NSString *albumId;
	NSString *coverArtId;
	NSString *artistName;
	NSString *artistId;
}

@property (retain) NSString *title;
@property (retain) NSString *albumId;
@property (retain) NSString *coverArtId;
@property (retain) NSString *artistName;
@property (retain) NSString *artistId;

- (void)encodeWithCoder:(NSCoder *)encoder;
- (id)initWithCoder:(NSCoder *)decoder;

- (id)copyWithZone:(NSZone *)zone;

- (id)initWithAttributeDict:(NSDictionary *)attributeDict;
- (id)initWithAttributeDict:(NSDictionary *)attributeDict artist:(Artist *)myArtist;
- (id)initWithTBXMLElement:(TBXMLElement *)element artistId:(NSString *)artistIdToSet artistName:(NSString *)artistNameToSet;
@end
