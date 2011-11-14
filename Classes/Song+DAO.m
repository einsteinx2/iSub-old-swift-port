//
//  Song+DAO.m
//  iSub
//
//  Created by Ben Baron on 11/14/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "Song+DAO.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "DatabaseSingleton.h"
#import "NSString-md5.h"

@implementation Song (DAO)

- (FMDatabase *)db
{
	return [DatabaseSingleton sharedInstance].songCacheDb;
}

- (BOOL)fileExists
{
	return [self.db boolForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE md5 = ?", [self.songId md5]];
}

- (BOOL)isFullyCached
{
	return [self.db boolForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", [self.songId md5]];
}

@end
