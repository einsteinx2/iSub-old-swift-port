//
//  Artist.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ISMSArtist.h"
#import "Imports.h"

@interface ISMSArtist()
{
    NSArray<ISMSAlbum*> *_albums;
}
@end

@implementation ISMSArtist

- (instancetype)initWithArtistId:(NSInteger)artistId serverId:(NSInteger)serverId loadSubmodels:(BOOL)loadSubmodels
{
    if (self = [super init])
    {
        __block BOOL foundRecord = NO;
        
        BOOL (^runQuery)(FMDatabase*, NSString*) = ^BOOL(FMDatabase *db, NSString *table) {
            NSString *query = @"SELECT * FROM %@ WHERE artistId = ? AND serverId = ?";
            query = [NSString stringWithFormat:query, table];

            FMResultSet *result = [db executeQuery:query, @(artistId), @(serverId)];
            if ([result next])
            {
                foundRecord = YES;
                [self _assignPropertiesFromResultSet:result];
            }
            [result close];
            
            return foundRecord;
        };
        
        [databaseS.songModelReadDbPool inDatabase:^(FMDatabase *db) {
            if (!runQuery(db, @"artists")) {
                runQuery(db, @"cachedArtists");
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
    _artistId = N2n([resultSet objectForColumnIndex:0]);
    _serverId = N2n([resultSet objectForColumnIndex:1]);
    _name = N2n([resultSet objectForColumnIndex:2]);
    _coverArtId = N2n([resultSet objectForColumnIndex:3]);
    _albumCount = N2n([resultSet objectForColumnIndex:4]);
}

- (instancetype)initWithRXMLElement:(RXMLElement *)element serverId:(NSInteger)serverId
{
    if ((self = [super init]))
    {
        _serverId = @(serverId);
        _artistId = @([[element attribute:@"id"] integerValue]);
        _name = [element attribute:@"name"];
        _coverArtId = [element attribute:@"coverArt"];
        _albumCount = @([[element attribute:@"albumCount"] integerValue]);
    }
    
    return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@: name: %@, serverId: %@, artistId: %@, albumCount: %li", [super description], self.name, self.serverId, self.artistId, (long)self.albumCount];
}

- (BOOL)hasCachedSongs {
    NSString *query = @"SELECT COUNT(*) FROM cachedSongs WHERE artistId = ?";
    return [databaseS.songModelReadDbPool boolForQuery:query, self.artistId];
}

+ (BOOL)isPersisted:(NSNumber *)artistId serverId:(NSNumber *)serverId {
    NSString *query = @"SELECT COUNT(*) FROM artists WHERE artistId = ? AND serverId = ?";
    return [databaseS.songModelReadDbPool boolForQuery:query, artistId, serverId];
}

- (BOOL)isPersisted {
    return [self.class isPersisted:self.artistId serverId:self.serverId];
}

- (BOOL)_existsInCache {
    NSString *query = @"SELECT COUNT(*) FROM cachedArtists WHERE artistId = ? AND serverId = ?";
    return [databaseS.songModelReadDbPool boolForQuery:query, self.artistId, self.serverId];
}

- (BOOL)_insertModel:(BOOL)replace cachedTable:(BOOL)cachedTable
{
    __block BOOL success = NO;
    [databaseS.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *insertType = replace ? @"REPLACE" : @"INSERT";
         NSString *table = cachedTable ? @"cachedArtists" : @"artists";
         
         NSString *query = @"%@ INTO %@ (artistId, serverId, name, coverArtId, albumCount) VALUES (?, ?, ?, ?, ?)";
         query = [NSString stringWithFormat:query, insertType, table];
         
         success = [db executeUpdate:query, self.artistId, self.serverId, self.name, self.coverArtId, self.albumCount];
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
    
    if ([self _existsInCache]) {
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
    if (!self.artistId)
        return NO;
    
    __block BOOL success = NO;
    [databaseS.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *query = @"DELETE FROM artists WHERE artistId = ? AND serverId = ?";
         success = [db executeUpdate:query, self.artistId, self.serverId];
     }];
    return success;
}

- (void)reloadSubmodels
{
    @synchronized(self)
    {
        _albums = [ISMSAlbum albumsInArtist:self.artistId.integerValue serverId:self.serverId.integerValue cachedTable:NO];
    }
}

- (NSArray<ISMSAlbum*> *)albums
{
    @synchronized(self)
    {
        if (!_albums)
        {
            [self reloadSubmodels];
        }
        
        return _albums;
    }
}

+ (NSArray<ISMSArtist*> *)allArtistsWithServerId:(NSNumber *)serverId
{
    NSMutableArray *artists = [[NSMutableArray alloc] init];
    NSMutableArray *artistsNumbers = [[NSMutableArray alloc] init];
    
    [databaseS.songModelReadDbPool inDatabase:^(FMDatabase *db) {
        NSString *query = @"SELECT * FROM artists";

        FMResultSet *r = nil;
        if (serverId) {
            query = [query stringByAppendingString:@" WHERE serverId = ?"];
            r = [db executeQuery:query, serverId];
        } else {
            r = [db executeQuery:query];
        }
 
        while ([r next])
        {
            ISMSArtist *artist = [[ISMSArtist alloc] init];
            [artist _assignPropertiesFromResultSet:r];
            
            if (artist.name.length > 0 && isnumber([artist.name characterAtIndex:0]))
                [artistsNumbers addObject:artist];
            else
                [artists addObject:artist];
        }
        [r close];
    }];
    
    NSArray *ignoredArticles = databaseS.ignoredArticles;
    
    // Sort objects without indefinite articles (try to match Subsonic's sorting)
    [artists sortUsingComparator:^NSComparisonResult(ISMSArtist *obj1, ISMSArtist *obj2) {
        NSString *name1 = [databaseS name:obj1.name ignoringArticles:ignoredArticles];
        name1 = [name1 stringByReplacingOccurrencesOfString:@" " withString:@""];
        name1 = [name1 stringByReplacingOccurrencesOfString:@"-" withString:@""];
        
        NSString *name2 = [databaseS name:obj2.name ignoringArticles:ignoredArticles];
        name2 = [name2 stringByReplacingOccurrencesOfString:@" " withString:@""];
        name2 = [name2 stringByReplacingOccurrencesOfString:@"-" withString:@""];
        
        return [name1 caseInsensitiveCompare:name2];
    }];
    
    [artists addObjectsFromArray:artistsNumbers];
    return artists;
}

+ (NSArray<ISMSArtist*> *)allCachedArtists
{
    NSMutableArray *artists = [[NSMutableArray alloc] init];
    NSMutableArray *artistsNumbers = [[NSMutableArray alloc] init];
    
    [databaseS.songModelReadDbPool inDatabase:^(FMDatabase *db) {
        NSString *query = @"SELECT * FROM cachedArtists";
        
        FMResultSet *r = [db executeQuery:query];
        while ([r next])
        {
            ISMSArtist *artist = [[ISMSArtist alloc] init];
            [artist _assignPropertiesFromResultSet:r];
            
            if (artist.name.length > 0 && isnumber([artist.name characterAtIndex:0]))
                [artistsNumbers addObject:artist];
            else
                [artists addObject:artist];
        }
        [r close];
    }];
    
    NSArray *ignoredArticles = databaseS.ignoredArticles;
    
    // Sort objects without indefinite articles (try to match Subsonic's sorting)
    [artists sortUsingComparator:^NSComparisonResult(ISMSArtist *obj1, ISMSArtist *obj2) {
        NSString *name1 = [databaseS name:obj1.name ignoringArticles:ignoredArticles];
        name1 = [name1 stringByReplacingOccurrencesOfString:@" " withString:@""];
        name1 = [name1 stringByReplacingOccurrencesOfString:@"-" withString:@""];
        
        NSString *name2 = [databaseS name:obj2.name ignoringArticles:ignoredArticles];
        name2 = [name2 stringByReplacingOccurrencesOfString:@" " withString:@""];
        name2 = [name2 stringByReplacingOccurrencesOfString:@"-" withString:@""];
        
        return [name1 caseInsensitiveCompare:name2];
    }];
    
    [artists addObjectsFromArray:artistsNumbers];
    return artists;
}

+ (BOOL)deleteAllArtistsWithServerId:(NSNumber *)serverId
{
    __block BOOL success = NO;
    [databaseS.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         if (serverId) {
             NSString *query = @"DELETE FROM artists WHERE serverId = ?";
             success = [db executeUpdate:query, serverId];
         } else {
             NSString *query = @"DELETE FROM artists";
             success = [db executeUpdate:query];
         }
     }];
    return success;
}

#pragma mark - ISMSItem -

- (instancetype)initWithItemId:(NSInteger)itemId serverId:(NSInteger)serverId
{
    return [self initWithArtistId:itemId serverId:serverId loadSubmodels:NO];
}

- (NSNumber *)itemId
{
    return self.artistId;
}

- (NSString *)itemName
{
    return [_name copy];
}

#pragma mark - NSCoding -

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.artistId    forKey:@"artistId"];
    [encoder encodeObject:self.serverId    forKey:@"serverId"];
    [encoder encodeObject:self.name        forKey:@"name"];
    [encoder encodeObject:self.coverArtId  forKey:@"coverArtId"];
    [encoder encodeObject:self.albumCount  forKey:@"albumCount"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if ((self = [super init]))
    {
        _artistId   = [decoder decodeObjectForKey:@"artistId"];
        _serverId   = [decoder decodeObjectForKey:@"serverId"];
        _name       = [decoder decodeObjectForKey:@"name"];
        _coverArtId = [decoder decodeObjectForKey:@"coverArtId"];
        _albumCount = [decoder decodeObjectForKey:@"albumCount"];
    }
    
    return self;
}

#pragma mark - NSCopying -

- (id)copyWithZone:(NSZone *)zone
{
    ISMSArtist *anArtist = [[ISMSArtist alloc] init];
    anArtist.artistId    = self.artistId;
    anArtist.serverId    = self.serverId;
    anArtist.name        = self.name;
    anArtist.coverArtId  = self.coverArtId;
    anArtist.albumCount  = self.albumCount;
    
    return anArtist;
}

@end
