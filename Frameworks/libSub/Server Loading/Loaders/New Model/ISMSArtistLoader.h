//
//  ISMSArtistLoader.h
//  libSub
//
//  Created by Benjamin Baron on 5/16/16.
//
//

#import "ISMSAbstractItemLoader.h"

@interface ISMSArtistLoader : ISMSAbstractItemLoader

@property (nullable, copy) NSNumber *artistId;

@property (nullable, readonly) NSArray<id<ISMSItem>> *items;

@end
