//
//  ISMSFolderLoader.h
//  libSub
//
//  Created by Benjamin Baron on 12/31/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSAbstractItemLoader.h"

@interface ISMSFolderLoader : ISMSAbstractItemLoader

@property (nullable, copy) NSNumber *folderId;
@property (nullable, copy) NSNumber *mediaFolderId;

@property (nullable, readonly) NSArray<id<ISMSItem>> *items;
@property (nullable, readonly) NSArray<ISMSFolder*> *folders;
@property (nullable, readonly) NSArray<ISMSSong*> *songs;

@end
