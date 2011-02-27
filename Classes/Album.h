//
//  Album.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@class Artist;

@interface Album : NSObject <NSCoding, NSCopying> 
{
	NSString *title;
	NSString *albumId;
	NSString *coverArtId;
	NSString *artistName;
	NSString *artistId;
}

@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *albumId;
@property (nonatomic, retain) NSString *coverArtId;
@property (nonatomic, retain) NSString *artistName;
@property (nonatomic, retain) NSString *artistId;

- (void)encodeWithCoder:(NSCoder *)encoder;
- (id)initWithCoder:(NSCoder *)decoder;

- (id)copyWithZone:(NSZone *)zone;

- (id)initWithAttributeDict:(NSDictionary *)attributeDict;
- (id)initWithAttributeDict:(NSDictionary *)attributeDict artist:(Artist *)myArtist;

@end
