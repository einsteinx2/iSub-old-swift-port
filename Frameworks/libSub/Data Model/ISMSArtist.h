//
//  ISMSArtist.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2015 Ben Baron. All rights reserved.
//

#import "ISMSPersistedModel.h"

@class ISMSAlbum, RXMLElement;
@interface ISMSArtist : NSObject <ISMSPersistedModel, NSCoding, NSCopying>

@property (nullable, strong) NSNumber *artistId;
@property (nullable, strong) NSNumber *serverId;
@property (nullable, copy) NSString *name;
@property (nullable, copy) NSString *coverArtId;
@property (nullable, strong) NSNumber *albumCount;

@property (nonnull, strong, readonly) NSArray<ISMSAlbum*> *albums;

// Use nil for serverId to apply to all records
+ (nonnull NSArray<ISMSArtist*> *)allArtistsWithServerId:(nullable NSNumber *)serverId;
+ (BOOL)deleteAllArtistsWithServerId:(nullable NSNumber *)serverId;
+ (nonnull NSArray<ISMSArtist*> *)allCachedArtists;

- (nullable instancetype)initWithArtistId:(NSInteger)artistId serverId:(NSInteger)serverId loadSubmodels:(BOOL)loadSubmodels;
- (nonnull instancetype)initWithRXMLElement:(nonnull RXMLElement *)element serverId:(NSInteger)serverId;

- (BOOL)hasCachedSongs;
+ (BOOL)isPersisted:(nonnull NSNumber *)artistId serverId:(nonnull NSNumber *)serverId;

@end
