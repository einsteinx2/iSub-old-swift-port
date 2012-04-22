//
//  Artist.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "TBXML.h"

@interface Artist : NSObject <NSCoding, NSCopying>

@property (copy) NSString *name;
@property (copy) NSString *artistId;

+ (Artist *) artistWithName:(NSString *)theName andArtistId:(NSString *)theId;

-(void) encodeWithCoder: (NSCoder *) encoder;
-(id) initWithCoder: (NSCoder *) decoder;

- (id) initWithAttributeDict:(NSDictionary *)attributeDict;

- (id) initWithTBXMLElement:(TBXMLElement *)element;

@end
