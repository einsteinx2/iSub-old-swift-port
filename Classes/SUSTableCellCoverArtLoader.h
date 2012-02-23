//
//  SUSTableCellCoverArtLoader.h
//  iSub
//
//  Created by Benjamin Baron on 11/1/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLoader.h"

@class FMDatabase;
@interface SUSTableCellCoverArtLoader : SUSLoader
{
}

@property (copy) NSString *coverArtId;
@property (readonly) BOOL isCoverArtCached;
@property (readonly) FMDatabase *db;

@end
