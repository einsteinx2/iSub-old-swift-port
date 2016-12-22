//
//  ISMSAlbumLoader.h
//  libSub
//
//  Created by Benjamin Baron on 5/16/16.
//
//

#import "ISMSAbstractItemLoader.h"

@interface ISMSAlbumLoader : ISMSAbstractItemLoader

@property (nullable, copy) NSNumber *albumId;

@property (nullable, readonly) NSArray<id<ISMSItem>> *items;

@end