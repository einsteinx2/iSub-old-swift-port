//
//  SUSSubFolderDAO.h
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//


#import "Loader.h"

@class FMDatabase, Album;

@interface SUSSubFolderDAO : Loader
{
	FMDatabase *db;
}


@end
