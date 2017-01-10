//
//  Album.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ISMSAlbum.h"
#import "ISMSArtist.h"
#import "ISMSGenre.h"
#import "RXMLElement.h"
#import "Imports.h"

@implementation ISMSAlbum
{
    ISMSArtist *_artist;
    ISMSGenre *_genre;
    NSArray<ISMSSong*> *_songs;
}

+ (NSDateFormatter *)createdDateFormatter
{
    static NSDateFormatter *createdDateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        createdDateFormatter = [[NSDateFormatter alloc] init];
        [createdDateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssz"];
    });
    
    return createdDateFormatter;
}

- (instancetype)initWithRXMLElement:(RXMLElement *)element serverId:(NSInteger)serverId
{
    if ((self = [super init]))
    {
        
        _albumId = @([[element attribute:@"id"] integerValue]);
        
        _serverId = @(serverId);
        _artistId = @([[element attribute:@"artistId"] integerValue]);
        _coverArtId = [[element attribute:@"coverArt"] cleanString];
        
        _name = [[element attribute:@"name"] cleanString];
        _songCount = @([[element attribute:@"songCount"] integerValue]);
        _duration = @([[element attribute:@"duration"] integerValue]);
        _year = @([[element attribute:@"year"] integerValue]);
        
        NSString *createdString = [element attribute:@"created"];
        if (createdString.length > 0) {
            _created = [[self.class createdDateFormatter] dateFromString:createdString];
        }
        
        // Retreive genreId
        NSString *genreString = [element attribute:@"genre"];
        if (genreString.length > 0)
        {
            _genre = [[ISMSGenre alloc] initWithName:genreString];
            _genreId = _genre.genreId;
        }
    }
    
    return self;
}

- (instancetype)initWithAlbumId:(NSInteger)albumId serverId:(NSInteger)serverId loadSubmodels:(BOOL)loadSubmodels
{
    if (self = [super init])
    {
        __block BOOL foundRecord = NO;
        
        BOOL (^runQuery)(FMDatabase*, NSString*) = ^BOOL(FMDatabase *db, NSString *table) {
            NSString *query = @"SELECT * FROM %@ WHERE albumId = ? AND serverId = ?";
            query = [NSString stringWithFormat:query, table];
            
            FMResultSet *result = [db executeQuery:query, @(albumId), @(serverId)];
            if ([result next])
            {
                foundRecord = YES;
                [self _assignPropertiesFromResultSet:result];
            }
            [result close];
            
            return foundRecord;
        };
        
        [DatabaseSingleton.si.songModelReadDbPool inDatabase:^(FMDatabase *db) {
            if (!runQuery(db, @"albums")) {
                runQuery(db, @"cachedAlbums");
            }
        }];
        
        if (foundRecord && loadSubmodels)
        {
            // Preload all submodels
            [self reloadSubmodels];
        }
        
        return foundRecord ? self : nil;
    }
    
    return nil;
}

- (void)_assignPropertiesFromResultSet:(FMResultSet *)resultSet
{
    _albumId    = [resultSet objectForColumnIndex:0];
    _serverId   = N2n([resultSet objectForColumnIndex:1]);
    _artistId   = N2n([resultSet objectForColumnIndex:2]);
    _genreId    = N2n([resultSet objectForColumnIndex:3]);
    _coverArtId = N2n([resultSet objectForColumnIndex:4]);
    _name       = N2n([resultSet objectForColumnIndex:5]);
    _songCount  = N2n([resultSet objectForColumnIndex:6]);
    _duration   = N2n([resultSet objectForColumnIndex:7]);
    _year       = N2n([resultSet objectForColumnIndex:8]);
    _created    = N2n([resultSet objectForColumnIndex:9]);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@: name: %@, serverId: %@, albumId: %@, coverArtId: %@, artistName: %@, artistId: %@", [super description], self.name, self.serverId, self.self.albumId, self.coverArtId, self.artist.name, self.artistId];
}

+ (NSArray<ISMSAlbum*> *)albumsInArtist:(NSInteger)artistId serverId:(NSInteger)serverId cachedTable:(BOOL)cachedTable
{
    NSMutableArray<ISMSAlbum*> *albums = [[NSMutableArray alloc] init];
    
    [DatabaseSingleton.si.songModelReadDbPool inDatabase:^(FMDatabase *db) {
        NSString *table = cachedTable ? @"cachedAlbums" : @"albums";
        NSString *query = @"SELECT * FROM %@ WHERE artistId = ? AND serverId = ?";
        query = [NSString stringWithFormat:query, table];
        
        FMResultSet *r = [db executeQuery:query, @(artistId), @(serverId)];
        while ([r next])
        {
            ISMSAlbum *album = [[ISMSAlbum alloc] init];
            [album _assignPropertiesFromResultSet:r];
            [albums addObject:album];
        }
        [r close];
    }];
    
    return albums;
}

+ (NSArray<ISMSAlbum*> *)allAlbumsWithServerId:(NSNumber *)serverId
{
    NSArray *ignoredArticles = DatabaseSingleton.si.ignoredArticles;
    
    NSMutableArray *albums = [[NSMutableArray alloc] init];
    NSMutableArray *albumsNumbers = [[NSMutableArray alloc] init];
    
    [DatabaseSingleton.si.songModelReadDbPool inDatabase:^(FMDatabase *db) {
        NSString *query = @"SELECT * FROM albums";
        
        FMResultSet *r = nil;
        if (serverId) {
            query = [query stringByAppendingString:@" WHERE serverId = ?"];
            r = [db executeQuery:query, serverId];
        } else {
            r = [db executeQuery:query];
        }
        
        while ([r next])
        {
            ISMSAlbum *album = [[ISMSAlbum alloc] init];
            [album _assignPropertiesFromResultSet:r];
            
            if (album.name.length > 0) {
                NSString *name = [DatabaseSingleton.si name:album.name ignoringArticles:ignoredArticles];
                if (isalpha([name characterAtIndex:0])) {
                    [albums addObject:album];
                } else {
                    [albumsNumbers addObject:album];
                }
            }
        }
        [r close];
    }];
    
    // Sort objects without indefinite articles (try to match Subsonic's sorting)
    [albums sortUsingComparator:^NSComparisonResult(ISMSAlbum *obj1, ISMSAlbum *obj2) {
        NSString *name1 = [DatabaseSingleton.si name:obj1.name ignoringArticles:ignoredArticles];
        name1 = [name1 stringByReplacingOccurrencesOfString:@" " withString:@""];
        name1 = [name1 stringByReplacingOccurrencesOfString:@"-" withString:@""];
        
        NSString *name2 = [DatabaseSingleton.si name:obj2.name ignoringArticles:ignoredArticles];
        name2 = [name2 stringByReplacingOccurrencesOfString:@" " withString:@""];
        name2 = [name2 stringByReplacingOccurrencesOfString:@"-" withString:@""];
        
        return [name1 caseInsensitiveCompare:name2];
    }];
    
    [albums addObjectsFromArray:albumsNumbers];
    [albums makeObjectsPerformSelector:@selector(reloadSubmodels)];
    
    return albums;
}

+ (NSArray<ISMSAlbum*> *)allCachedAlbums
{
    NSMutableArray *albums = [[NSMutableArray alloc] init];
    NSMutableArray *albumsNumbers = [[NSMutableArray alloc] init];
    
    [DatabaseSingleton.si.songModelReadDbPool inDatabase:^(FMDatabase *db) {
        NSString *query = @"SELECT * FROM cachedAlbums";
        
        FMResultSet *r = [db executeQuery:query];
        while ([r next])
        {
            ISMSAlbum *album = [[ISMSAlbum alloc] init];
            [album _assignPropertiesFromResultSet:r];
            
            if (album.name.length > 0 && isnumber([album.name characterAtIndex:0]))
                [albumsNumbers addObject:album];
            else
                [albums addObject:album];
        }
        [r close];
    }];
    
    NSArray *ignoredArticles = DatabaseSingleton.si.ignoredArticles;
    
    // Sort objects without indefinite articles (try to match Subsonic's sorting)
    [albums sortUsingComparator:^NSComparisonResult(ISMSAlbum *obj1, ISMSAlbum *obj2) {
        NSString *name1 = [DatabaseSingleton.si name:obj1.name ignoringArticles:ignoredArticles];
        name1 = [name1 stringByReplacingOccurrencesOfString:@" " withString:@""];
        name1 = [name1 stringByReplacingOccurrencesOfString:@"-" withString:@""];
        
        NSString *name2 = [DatabaseSingleton.si name:obj2.name ignoringArticles:ignoredArticles];
        name2 = [name2 stringByReplacingOccurrencesOfString:@" " withString:@""];
        name2 = [name2 stringByReplacingOccurrencesOfString:@"-" withString:@""];
        
        return [name1 caseInsensitiveCompare:name2];
    }];
    
    [albums addObjectsFromArray:albumsNumbers];
    [albums makeObjectsPerformSelector:@selector(reloadSubmodels)];
    
    return albums;
}

+ (BOOL)deleteAllAlbumsWithServerId:(NSNumber *)serverId
{
    __block BOOL success = NO;
    [DatabaseSingleton.si.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         if (serverId) {
             NSString *query = @"DELETE FROM albums WHERE serverId = ?";
             success = [db executeUpdate:query, serverId];
         } else {
             NSString *query = @"DELETE FROM albums";
             success = [db executeUpdate:query];
         }
     }];
    return success;
}

#pragma mark - ISMSItem -

- (instancetype)initWithItemId:(NSInteger)itemId serverId:(NSInteger)serverId
{
    return [self initWithAlbumId:itemId serverId:serverId loadSubmodels:NO];
}

- (NSNumber *)itemId
{
    return self.albumId;
}

- (NSString *)itemName
{
    return [self.name copy];
}

#pragma mark - ISMSPersistedModel -

- (BOOL)hasCachedSongs {
    NSString *query = @"SELECT COUNT(*) FROM cachedSongs WHERE albumId = ?";
    return [DatabaseSingleton.si.songModelReadDbPool boolForQuery:query, self.albumId];
}

+ (BOOL)isPersisted:(NSNumber *)albumId serverId:(NSNumber *)serverId {
    NSString *query = @"SELECT COUNT(*) FROM albums WHERE albumId = ? AND serverId = ?";
    return [DatabaseSingleton.si.songModelReadDbPool boolForQuery:query, albumId, serverId];
}

- (BOOL)isPersisted {
    return [self.class isPersisted:self.albumId serverId:self.serverId];
}

- (BOOL)_existsInCache {
    NSString *query = @"SELECT COUNT(*) FROM cachedAlbums WHERE albumId = ? AND serverId = ?";
    return [DatabaseSingleton.si.songModelReadDbPool boolForQuery:query, self.albumId, self.serverId];
}

- (BOOL)_insertModel:(BOOL)replace cachedTable:(BOOL)cachedTable
{
    __block BOOL success = NO;
    [DatabaseSingleton.si.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *insertType = replace ? @"REPLACE" : @"INSERT";
         NSString *table = cachedTable ? @"cachedAlbums" : @"albums";
         NSString *query = @"%@ INTO %@ VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
         query = [NSString stringWithFormat:query, insertType, table];
         
         success = [db executeUpdate:query, self.albumId, self.serverId, self.artistId, self.genreId, self.coverArtId, self.name, self.songCount, self.duration, self.year, self.created];
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
    if (!self.albumId)
        return NO;
    
    __block BOOL success = NO;
    [DatabaseSingleton.si.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *query = @"DELETE FROM albums WHERE albumId = ? AND serverId = ?";
         success = [db executeUpdate:query, self.albumId, self.serverId];
     }];
    return success;
}

- (void)reloadSubmodels
{
    @synchronized(self)
    {
        _artist = nil;
        if (self.artistId)
        {
            _artist = [[ISMSArtist alloc] initWithArtistId:self.artistId.integerValue serverId:self.serverId.integerValue  loadSubmodels:NO];
        }
        
        _genre = nil;
        if (self.genreId)
        {
            _genre = [[ISMSGenre alloc] initWithGenreId:self.genreId.integerValue];
        }
        
        _songs = [ISMSSong songsInAlbum:self.albumId.integerValue serverId:self.serverId.integerValue cachedTable:NO];
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

#pragma mark - NSCoding -

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.albumId    forKey:@"albumId"];
    
    [encoder encodeObject:self.serverId   forKey:@"serverId"];
    [encoder encodeObject:self.artistId   forKey:@"artistId"];
    [encoder encodeObject:self.genreId    forKey:@"genreId"];
    [encoder encodeObject:self.coverArtId forKey:@"coverArtId"];
    
	[encoder encodeObject:self.name       forKey:@"name"];
    [encoder encodeObject:self.songCount  forKey:@"songCount"];
    [encoder encodeObject:self.duration   forKey:@"duration"];
    [encoder encodeObject:self.year       forKey:@"year"];
    
    [encoder encodeObject:self.created    forKey:@"created"];
}


- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
        _albumId    = [decoder decodeObjectForKey:@"albumId"];
        
        _serverId    = [decoder decodeObjectForKey:@"serverId"];
        _artistId   = [decoder decodeObjectForKey:@"artistId"];
        _genreId    = [decoder decodeObjectForKey:@"genreId"];
        _coverArtId = [decoder decodeObjectForKey:@"coverArtId"];
        
        _name       = [decoder decodeObjectForKey:@"name"];
        _songCount  = [decoder decodeObjectForKey:@"songCount"];
        _duration   = [decoder decodeObjectForKey:@"duration"];
        _year       = [decoder decodeObjectForKey:@"year"];
        
        _created    = [decoder decodeObjectForKey:@"created"];
	}
	
	return self;
}

#pragma mark - NSCopying -

- (id)copyWithZone:(NSZone *)zone
{
	ISMSAlbum *anAlbum = [[ISMSAlbum alloc] init];
	
    anAlbum.albumId    = self.albumId;
    
    anAlbum.serverId   = self.serverId;
    anAlbum.artistId   = self.artistId;
    anAlbum.genreId    = self.genreId;
    anAlbum.coverArtId = self.coverArtId;
    
	anAlbum.name       = self.name;
    anAlbum.songCount  = self.songCount;
    anAlbum.duration   = self.duration;
    anAlbum.year       = self.year;
	
    anAlbum.created    = self.created;
    
	return anAlbum;
}

@end
