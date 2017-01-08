//
//  ISMSFolder.m
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSFolder.h"
#import "Imports.h"

static NSArray *_ignoredArticles = nil;

@interface ISMSFolder()
{
    NSArray<ISMSFolder*> *_subfolders;
    NSArray<ISMSSong*> *_songs;
}
@end

@implementation ISMSFolder

- (instancetype)initWithRXMLElement:(RXMLElement *)element serverId:(NSInteger)serverId mediaFolderId:(NSInteger)mediaFolderId
{
    if (self = [super init])
    {
        self.folderId = @([[element attribute:@"id"] integerValue]);
        self.serverId = @(serverId);
        NSString *parentString = [element attribute:@"parent"];
        if (parentString)
            self.parentFolderId = @([parentString integerValue]);
        self.mediaFolderId = @(mediaFolderId);
        self.coverArtId = [element attribute:@"coverArt"];
        NSString *titleString = [element attribute:@"title"];
        if (titleString)
            self.name = [titleString cleanString];
        NSString *nameString = [element attribute:@"name"];
        if (nameString)
            self.name = [nameString cleanString];
    }
    
    return self;
}

- (instancetype)initWithFolderId:(NSInteger)folderId serverId:(NSInteger)serverId loadSubmodels:(BOOL)loadSubmodels
{
    if (self = [super init])
    {
        __block BOOL foundRecord = NO;
        
        BOOL (^runQuery)(FMDatabase*, NSString*) = ^BOOL(FMDatabase *db, NSString *table) {
            NSString *query = @"SELECT * FROM %@ WHERE folderId = ? AND serverId = ?";
            query = [NSString stringWithFormat:query, table];
            FMResultSet *result = [db executeQuery:query, @(folderId), @(serverId)];
            query = [NSString stringWithFormat:query, table];

            if ([result next])
            {
                foundRecord = YES;
                [self _assignPropertiesFromResultSet:result];
            }
            [result close];
            
            return foundRecord;
        };
        
        [databaseS.songModelReadDbPool inDatabase:^(FMDatabase *db) {
            if (!runQuery(db, @"folders")) {
                runQuery(db, @"cachedFolders");
            }
        }];
        
        if (foundRecord && loadSubmodels) {
            [self reloadSubmodels];
        }
        
        return foundRecord ? self : nil;
    }
    
    return nil;
}

- (void)_assignPropertiesFromResultSet:(FMResultSet *)resultSet
{
    _folderId = N2n([resultSet objectForColumnIndex:0]);
    _serverId = N2n([resultSet objectForColumnIndex:1]);
    _parentFolderId = N2n([resultSet objectForColumnIndex:2]);
    _mediaFolderId = N2n([resultSet objectForColumnIndex:3]);
    _coverArtId = N2n([resultSet objectForColumnIndex:4]);
    _name = N2n([resultSet objectForColumnIndex:5]);
}

+ (void)loadIgnoredArticles
{
    NSMutableArray *ignoredArticles = [[NSMutableArray alloc] init];
    
    [databaseS.songModelReadDbPool inDatabase:^(FMDatabase *db) {
        FMResultSet *r = [db executeQuery:@"SELECT name FROM ignoredArticles"];
        while ([r next])
        {
            [ignoredArticles addObject:[r stringForColumnIndex:0]];
        }
    }];
    
    _ignoredArticles = ignoredArticles;
}

- (BOOL)hasCachedSongs {
    NSString *query = @"SELECT COUNT(*) FROM cachedSongs WHERE folderId = ?";
    return [databaseS.songModelReadDbPool boolForQuery:query, self.folderId];
}

+ (BOOL)isPersisted:(NSNumber *)folderId serverId:(NSNumber *)serverId {
    NSString *query = @"SELECT COUNT(*) FROM folders WHERE folderId = ? AND serverId = ?";
    return [databaseS.songModelReadDbPool boolForQuery:query, folderId, serverId];
}

- (BOOL)isPersisted {
    return [self.class isPersisted:self.folderId serverId:self.serverId];
}

- (BOOL)_existsInCache {
    NSString *query = @"SELECT COUNT(*) FROM cachedFolders WHERE folderId = ? AND serverId = ?";
    return [databaseS.songModelReadDbPool boolForQuery:query, self.folderId, self.serverId];
}

- (BOOL)_insertModel:(BOOL)replace cachedTable:(BOOL)cachedTable
{
    __block BOOL success = NO;
    [databaseS.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *insertType = replace ? @"REPLACE" : @"INSERT";
         NSString *table = cachedTable ? @"cachedFolders" : @"folders";
         NSString *query = @"%@ INTO %@ (folderId, serverId, parentFolderId, mediaFolderId, coverArtId, name) VALUES (?, ?, ?, ?, ?, ?)";
         query = [NSString stringWithFormat:query, insertType, table];
         
         success = [db executeUpdate:query, self.folderId, self.serverId, self.parentFolderId, self.mediaFolderId, self.coverArtId, self.name];
     }];
    return success;
}

- (BOOL)insertModel
{
    return [self _insertModel:NO cachedTable:NO];
}

- (BOOL)replaceModel
{
    BOOL success = [self _insertModel:YES cachedTable:NO];
    
    BOOL songsExistInCache = NO;
    for (ISMSSong *song in self.songs) {
        if (song.existsInCache) {
            songsExistInCache = YES;
            break;
        }
    }
    
    if ([self _existsInCache] || songsExistInCache) {
        success = success && [self cacheModel];
    }
    
    return success;
}

- (BOOL)cacheModel
{
    return [self _insertModel:YES cachedTable:YES];
}

- (BOOL)deleteModel
{
    if (!self.folderId)
        return NO;
    
    __block BOOL success = NO;
    [databaseS.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *query = @"DELETE FROM folders WHERE folderId = ? AND serverId = ?";
         success = [db executeUpdate:query, self.folderId, self.serverId];
     }];
    return success;
}

- (void)reloadSubmodels
{
    @synchronized(self)
    {
        NSInteger folderId = self.folderId.integerValue;
        _subfolders = [self.class foldersInFolder:folderId serverId:self.serverId.integerValue];
        _songs = [ISMSSong songsInFolder:folderId serverId:self.serverId.integerValue];
    }
}

- (NSArray<ISMSFolder*> *)folders
{
    @synchronized(self)
    {
        if (!_subfolders)
        {
            [self reloadSubmodels];
        }
        
        return _subfolders;
    }
}

- (NSArray<ISMSSong*> *)songs
{
    @synchronized(self)
    {
        if (!_songs)
        {
            [self reloadSubmodels];
        }
        
        return _songs;
    }
}

+ (NSArray<ISMSFolder*> *)foldersInFolder:(NSInteger)folderId serverId:(NSInteger)serverId
{
    NSMutableArray<ISMSFolder*> *folders = [[NSMutableArray alloc] init];
    
    [databaseS.songModelReadDbPool inDatabase:^(FMDatabase *db) {
        NSString *query = @"SELECT * FROM folders WHERE parentFolderId = ? AND serverId = ?";
        
        FMResultSet *r = [db executeQuery:query, @(folderId), @(serverId)];
        while ([r next])
        {
            ISMSFolder *folder = [[ISMSFolder alloc] init];
            [folder _assignPropertiesFromResultSet:r];
            [folders addObject:folder];
        }
        [r close];
    }];
    
    return folders;
}

+ (NSArray<ISMSFolder*> *)topLevelCachedFolders
{
    NSMutableArray<ISMSFolder*> *folders = [[NSMutableArray alloc] init];
    
    [databaseS.songModelReadDbPool inDatabase:^(FMDatabase *db) {
        NSString *query = @"SELECT cf.*, cf.folderId FROM cachedFolders cf "
                          @"WHERE (SELECT COUNT(*) FROM cachedFolders WHERE parentFolderId = cf.folderId) = 0";
        
        FMResultSet *r = [db executeQuery:query];
        while ([r next])
        {
            ISMSFolder *folder = [[ISMSFolder alloc] init];
            [folder _assignPropertiesFromResultSet:r];
            [folders addObject:folder];
        }
        [r close];
    }];
    
    return folders;
}

#pragma mark - ISMSItem -

- (instancetype)initWithItemId:(NSInteger)itemId serverId:(NSInteger)serverId
{
    return [self initWithFolderId:itemId serverId:serverId loadSubmodels:NO];
}

- (NSNumber *)itemId
{
    return self.folderId;
}

- (NSString *)itemName
{
    return [_name copy];
}

#pragma mark - NSCoding -

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.folderId       forKey:@"folderId"];
    [encoder encodeObject:self.serverId       forKey:@"serverId"];
    [encoder encodeObject:self.parentFolderId forKey:@"parentFolderId"];
    [encoder encodeObject:self.mediaFolderId  forKey:@"mediaFolderId"];
    [encoder encodeObject:self.coverArtId     forKey:@"coverArtId"];
    [encoder encodeObject:self.name           forKey:@"name"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if ((self = [super init]))
    {
        _folderId       = [decoder decodeObjectForKey:@"folderId"];
        _serverId       = [decoder decodeObjectForKey:@"serverId"];
        _parentFolderId = [decoder decodeObjectForKey:@"parentFolderId"];
        _mediaFolderId  = [decoder decodeObjectForKey:@"mediaFolderId"];
        _coverArtId     = [decoder decodeObjectForKey:@"coverArtId"];
        _name           = [decoder decodeObjectForKey:@"name"];
    }
    
    return self;
}

#pragma mark - NSCopying -

- (instancetype)copyWithZone:(NSZone *)zone
{
    ISMSFolder *folder    = [[ISMSFolder alloc] init];
    folder.folderId       = self.folderId;
    folder.serverId       = self.serverId;
    folder.parentFolderId = self.parentFolderId;
    folder.mediaFolderId  = self.mediaFolderId;
    folder.coverArtId     = self.coverArtId;
    folder.name           = self.name;
    return folder;
}

@end
