//
//  SUSRootFoldersLoader.h
//  iSub
//
//  Created by Benjamin Baron on 10/28/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLoader.h"

#define TEMP_FLUSH_AMOUNT 400

@class FMDatabase;

@interface SUSRootFoldersLoader : SUSLoader
{
    NSUInteger tempRecordCount;
}

@property (readonly) FMDatabase *db;
@property (readonly) NSString *tableModifier;

@property (retain) NSNumber *selectedFolderId;

@end
