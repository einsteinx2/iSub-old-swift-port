//
//  SUSSubFolderDAO.h
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//


#import "SUSLoader.h"

@class FMDatabase, Album;

@interface SUSSubFolderDAO : SUSLoader
{
	
}

@property (readonly) FMDatabase *db;

@end
