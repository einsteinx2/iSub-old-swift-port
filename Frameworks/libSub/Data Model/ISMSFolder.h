//
//  ISMSFolder.h
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSPersistedModel.h"

@class ISMSSong, RXMLElement;
@interface ISMSFolder : NSObject <ISMSPersistedModel, NSCoding, NSCopying>

@property (nullable, strong) NSNumber *folderId;
@property (nullable, strong) NSNumber *serverId;
@property (nullable, strong) NSNumber *parentFolderId;
@property (nullable, strong) NSNumber *mediaFolderId;
@property (nullable, strong) NSString *coverArtId;
@property (nullable, copy) NSString *name;

@property (nonnull, strong, readonly) NSArray<ISMSFolder*> *folders;
@property (nonnull, strong, readonly) NSArray<ISMSSong*> *songs;

+ (void)loadIgnoredArticles;

- (nonnull instancetype)initWithRXMLElement:(nonnull RXMLElement *)element serverId:(NSInteger)serverId mediaFolderId:(NSInteger)mediaFolderId;

// Returns an instance if it exists in the db, otherwise nil
- (nullable instancetype)initWithFolderId:(NSInteger)folderId serverId:(NSInteger)serverId;

+ (nonnull NSArray<ISMSFolder*> *)foldersInFolder:(NSInteger)folderId serverId:(NSInteger)serverId;

@end
