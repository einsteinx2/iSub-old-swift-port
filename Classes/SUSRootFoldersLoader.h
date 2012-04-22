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

@property (unsafe_unretained, readonly) FMDatabase *db;
@property (unsafe_unretained, readonly) NSString *tableModifier;

@property (strong) NSNumber *selectedFolderId;

@end
