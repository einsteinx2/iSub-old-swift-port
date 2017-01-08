//
//  ISMSMediaFolder.m
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSMediaFolder.h"
#import "Imports.h"

@interface ISMSFolder (Internal)
- (void)_assignPropertiesFromResultSet:(FMResultSet *)resultSet;
@end

@implementation ISMSMediaFolder

- (instancetype)initWithRXMLElement:(RXMLElement *)element serverId:(NSInteger)serverId
{
    if (self = [super init])
    {
        self.mediaFolderId = @([[element attribute:@"id"] integerValue]);
        self.serverId = @(serverId);
        NSString *nameString = [element attribute:@"name"];
        if (nameString)
            self.name = [nameString cleanString];
    }
    
    return self;
}

- (instancetype)initWithItemId:(NSInteger)itemId serverId:(NSInteger)serverId
{
    return [self initWithMediaFolderId:itemId serverId:serverId];
}

- (instancetype)initWithMediaFolderId:(NSInteger)mediaFolderId serverId:(NSInteger)serverId
{
    if (self = [super init])
    {
        __block BOOL foundRecord = NO;
        
        [DatabaseSingleton.si.songModelReadDbPool inDatabase:^(FMDatabase *db) {
            NSString *query = @"SELECT m.mediaFolderId, m.name "
                              @"FROM mediaFolders AS m "
                              @"WHERE m.mediaFolderId = ? AND serverId = ?";
            
            FMResultSet *r = [db executeQuery:query, @(mediaFolderId), @(serverId)];
            if ([r next])
            {
                foundRecord = YES;
                _mediaFolderId = [r objectForColumnIndex:0];
                _serverId = [r objectForColumnIndex:1];
                _name = [r stringForColumnIndex:2];
            }
            [r close];
        }];
        
        return foundRecord ? self : nil;
    }
    
    return nil;
}

- (BOOL)isPersisted {
    NSString *query = @"SELECT COUNT(*) FROM mediaFolders WHERE mediaFolderId = ? AND serverId = ?";
    return [DatabaseSingleton.si.songModelReadDbPool boolForQuery:query, self.mediaFolderId, self.serverId];
}

- (BOOL)_insertModel:(BOOL)replace
{
    __block BOOL success = NO;
    [DatabaseSingleton.si.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *insertType = replace ? @"REPLACE" : @"INSERT";
         NSString *query = [insertType stringByAppendingString:@" INTO mediaFolders VALUES (?, ?, ?)"];
         
         success = [db executeUpdate:query, self.mediaFolderId, self.serverId, self.name];
     }];
    return success;
}

- (BOOL)insertModel
{
    return [self _insertModel:NO];
}

- (BOOL)replaceModel
{
    return [self _insertModel:YES];
}

- (BOOL)cacheModel
{
    // Not supported
    return NO;
}

- (BOOL)deleteModel
{
    if (!self.mediaFolderId)
        return NO;
    
    __block BOOL success = NO;
    [DatabaseSingleton.si.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *query = @"DELETE FROM mediaFolders WHERE mediaFolderId = ? AND serverId = ?";
         success = [db executeUpdate:query, self.mediaFolderId, self.serverId];
     }];
    return success;
}

- (NSArray<ISMSFolder*> *)rootFolders
{
    NSMutableArray<ISMSFolder*> *rootFolders = [[NSMutableArray alloc] init];
    
    [DatabaseSingleton.si.songModelReadDbPool inDatabase:^(FMDatabase *db) {
        NSString *query = @"SELECT f.* "
                          @"FROM mediaFolders AS m "
                          @"JOIN folders AS f ON f.mediaFolderId = m.mediaFolderId "
                          @"WHERE m.mediaFolderId = ? AND f.serverId = ? AND f.parentFolderId IS NULL";
        FMResultSet *r = [db executeQuery:query, self.mediaFolderId, self.serverId];
        while ([r next])
        {
            ISMSFolder *folder = [[ISMSFolder alloc] init];
            [folder _assignPropertiesFromResultSet:r];
            
            [rootFolders addObject:folder];
        }
        [r close];
    }];
    
    return rootFolders;
}

- (BOOL)deleteRootFolders
{
    __block BOOL success = NO;
    [DatabaseSingleton.si.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *query = @"DELETE FROM folders WHERE mediaFolderId = ? AND serverId = ? AND parentFolderId IS NULL";
         success = [db executeUpdate:query, self.mediaFolderId, self.serverId];
     }];
    return success;
}

+ (BOOL)deleteAllMediaFoldersWithServerId:(NSNumber *)serverId
{
    __block BOOL success = NO;
    [DatabaseSingleton.si.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         if (serverId) {
             NSString *query = @"DELETE FROM mediaFolders WHERE serverId = ?";
             success = [db executeUpdate:query, serverId];
         } else {
             NSString *query = @"DELETE FROM mediaFolders";
             success = [db executeUpdate:query];
         }
         
     }];
    return success;
}

+ (NSArray<ISMSFolder*> *)allRootFoldersWithServerId:(NSNumber *)serverId
{
    NSArray *ignoredArticles = DatabaseSingleton.si.ignoredArticles;

    NSMutableArray<ISMSFolder*> *rootFolders = [[NSMutableArray alloc] init];
    NSMutableArray *rootFoldersNumbers = [[NSMutableArray alloc] init];
    
    [DatabaseSingleton.si.songModelReadDbPool inDatabase:^(FMDatabase *db) {
        NSString *query = @"SELECT * FROM folders WHERE parentFolderId IS NULL";
        
        FMResultSet *r = nil;
        if (serverId) {
            query = [query stringByAppendingString:@" AND serverId = ?"];
            r = [db executeQuery:query, serverId];
        } else {
            r = [db executeQuery:query];
        }
        
        while ([r next])
        {
            ISMSFolder *folder = [[ISMSFolder alloc] init];
            [folder _assignPropertiesFromResultSet:r];
            
            if (folder.name.length > 0) {
                NSString *name = [DatabaseSingleton.si name:folder.name ignoringArticles:ignoredArticles];
                if (isalpha([name characterAtIndex:0])) {
                    [rootFolders addObject:folder];
                } else {
                    [rootFoldersNumbers addObject:folder];
                }
            }
        }
        [r close];
    }];
    
    // Sort objects without indefinite articles (try to match Subsonic's sorting)
    [rootFolders sortUsingComparator:^NSComparisonResult(ISMSFolder *obj1, ISMSFolder *obj2) {
        NSString *name1 = [DatabaseSingleton.si name:obj1.name ignoringArticles:ignoredArticles];
        name1 = [name1 stringByReplacingOccurrencesOfString:@" " withString:@""];
        name1 = [name1 stringByReplacingOccurrencesOfString:@"-" withString:@""];
        
        NSString *name2 = [DatabaseSingleton.si name:obj2.name ignoringArticles:ignoredArticles];
        name2 = [name2 stringByReplacingOccurrencesOfString:@" " withString:@""];
        name2 = [name2 stringByReplacingOccurrencesOfString:@"-" withString:@""];
        
        return [name1 caseInsensitiveCompare:name2];
    }];
    
    [rootFolders addObjectsFromArray:rootFoldersNumbers];
    return rootFolders;
}

+ (NSArray<ISMSMediaFolder*> *)allMediaFoldersWithServerId:(NSNumber *)serverId
{
    NSMutableArray<ISMSMediaFolder*> *mediaFolders = [[NSMutableArray alloc] init];
   
    [DatabaseSingleton.si.songModelReadDbPool inDatabase:^(FMDatabase *db) {
        NSString *query = @"SELECT mediaFolderId, name "
                          @"FROM mediaFolders";
        
        FMResultSet *r = nil;
        if (serverId) {
            query = [query stringByAppendingString:@" WHERE serverId = ? ORDER BY name COLLATE NOCASE ASC"];
            r = [db executeQuery:query, serverId];
        } else {
            query = [query stringByAppendingString:@" ORDER BY name COLLATE NOCASE ASC"];
            r = [db executeQuery:query];
        }
        
        while ([r next])
        {
            ISMSMediaFolder *mediaFolder = [[ISMSMediaFolder alloc] init];
            mediaFolder.mediaFolderId = [r objectForColumnIndex:0];
            mediaFolder.serverId = [r objectForColumnIndex:1];
            mediaFolder.name = [r objectForColumnIndex:2];
            [mediaFolders addObject:mediaFolder];
        }
        [r close];
    }];
    
    return mediaFolders;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ - %@ - %@ - %@", [super description], self.mediaFolderId, self.serverId, self.name];
}

- (void)reloadSubmodels
{
    // TODO: implement this
}

#pragma mark - ISMSItem -

- (NSNumber *)itemId
{
    return self.mediaFolderId;
}

- (NSString *)itemName
{
    return [self.name copy];
}

#pragma mark - NSCoding -

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.mediaFolderId forKey:@"mediaFolderId"];
    [encoder encodeObject:self.serverId      forKey:@"serverId"];
    [encoder encodeObject:self.name          forKey:@"name"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if ((self = [super init]))
    {
        _mediaFolderId = [decoder decodeObjectForKey:@"mediaFolderId"];
        _serverId      = [decoder decodeObjectForKey:@"serverId"];
        _name          = [decoder decodeObjectForKey:@"name"];
    }
    return self;
}

#pragma mark - NSCopying -

- (instancetype)copyWithZone:(NSZone *)zone
{
    ISMSMediaFolder *mediaFolder = [[ISMSMediaFolder alloc] init];
    mediaFolder.mediaFolderId    = self.mediaFolderId;
    mediaFolder.serverId         = self.serverId;
    mediaFolder.name             = self.name;
    return mediaFolder;
}

@end
