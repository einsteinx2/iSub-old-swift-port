//
//  ISMSMediaFolder.h
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSPersistedModel.h"

@class ISMSFolder;
@interface ISMSMediaFolder : NSObject <ISMSPersistedModel, NSCoding, NSCopying>

@property (nullable, strong) NSNumber *mediaFolderId;
@property (nullable, strong) NSNumber *serverId;
@property (nullable, copy) NSString *name;

- (nullable instancetype)initWithMediaFolderId:(NSInteger)mediaFolderId serverId:(NSInteger)serverId;

- (nonnull NSArray<ISMSFolder*> *)rootFolders;
- (BOOL)deleteRootFolders;

// nil server id for all root folders
+ (BOOL)deleteAllMediaFoldersWithServerId:(nullable NSNumber *)serverId;
+ (nonnull NSArray<ISMSFolder*> *)allRootFoldersWithServerId:(nullable NSNumber *)serverId; // Sorted alphabetically
+ (nonnull NSArray<ISMSMediaFolder*> *)allMediaFoldersWithServerId:(nullable NSNumber *)serverId; // Sorted alphabetically

@end
