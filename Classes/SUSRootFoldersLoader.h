//
//  SUSRootFoldersLoader.h
//  iSub
//
//  Created by Benjamin Baron on 10/28/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "Loader.h"

#define TEMP_FLUSH_AMOUNT 400

@class FMDatabase;

@interface SUSRootFoldersLoader : Loader
{
    NSUInteger tempRecordCount;
}

@property (readonly) FMDatabase *db;
@property (readonly) NSString *tableModifier;

@property (nonatomic, retain) NSNumber *selectedFolderId;

@end
