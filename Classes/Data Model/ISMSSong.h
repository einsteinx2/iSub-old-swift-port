//
//  ISMSSong.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2015 Ben Baron. All rights reserved.
//

#import "ISMSPersistedModel.h"
#import <CoreGraphics/CGBase.h>

@class ISMSFolder, ISMSArtist, ISMSAlbum, ISMSGenre, ISMSContentType, RXMLElement;

@interface ISMSSong : NSObject <ISMSPersistedModel, NSCoding, NSCopying>

// Main Properties
@property (nullable, strong) NSNumber *songId;
@property (nullable, strong) NSNumber *serverId;
@property (nullable, strong) NSNumber *contentTypeId;
@property (nullable, strong) NSNumber *transcodedContentTypeId;
@property (nullable, strong) NSNumber *mediaFolderId;
@property (nullable, strong) NSNumber *folderId;
@property (nullable, strong) NSNumber *artistId;
@property (nullable, copy) NSString *artistName;
@property (nullable, strong) NSNumber *albumId;
@property (nullable, copy) NSString *albumName;
@property (nullable, strong) NSNumber *genreId;
@property (nullable, strong) NSString *coverArtId;
@property (nullable, copy) NSString *title;
@property (nullable, strong) NSNumber *duration;
@property (nullable, strong) NSNumber *bitrate;
@property (nullable, strong) NSNumber *trackNumber;
@property (nullable, strong) NSNumber *discNumber;
@property (nullable, strong) NSNumber *year;
@property (nullable, strong) NSNumber *size;
@property (nullable, copy) NSString *path;

// Submodels
@property (nullable, readonly) ISMSFolder *folder;
@property (nullable, readonly) ISMSArtist *artist;
@property (nullable, readonly) ISMSAlbum *album;
@property (nullable, readonly) ISMSGenre *genre;
@property (nullable, readonly) ISMSContentType *contentType;
@property (nullable, readonly) ISMSContentType *transcodedContentType;

// Automatically chooses either the artist/album model name or uses the song property if it's not available
// NOTE: Not every song has an Artist or Album object in Subsonic. So when folder browsing this is especially
// important. Also, we need to have some background process to load albums and artists that don't exist in the
// local db whenever we browse in Folder mode.
@property (nullable, readonly) NSString *artistDisplayName;
@property (nullable, readonly) NSString *albumDisplayName;

@property (nullable, nonatomic, strong) NSDate *lastPlayed;

// Cache info
- (nonnull NSString *)fileName;
- (nonnull NSString *)localPath;
- (nonnull NSString *)localTempPath;
- (nonnull NSString *)currentPath;
@property (readonly) BOOL isTempCached;
@property (readonly) unsigned long long localFileSize;
@property (readonly) NSInteger estimatedBitrate;

// Returns an instance if it exists in the db, otherwise nil
- (nullable instancetype)initWithSongId:(NSInteger)songId serverId:(NSInteger)serverId;

- (nonnull instancetype)initWithRXMLElement:(nonnull RXMLElement *)element serverId:(NSInteger)serverId;

+ (nonnull NSArray<ISMSSong*> *)songsInFolder:(NSInteger)folderId serverId:(NSInteger)serverId cachedTable:(BOOL)cachedTable;
+ (nonnull NSArray<ISMSSong*> *)songsInAlbum:(NSInteger)albumId serverId:(NSInteger)serverId cachedTable:(BOOL)cachedTable;
+ (nonnull NSArray<ISMSSong*> *)rootSongsInMediaFolder:(NSInteger)mediaFolderId serverId:(NSInteger)serverId;
+ (nonnull NSArray<ISMSSong*> *)allCachedSongs;

- (BOOL)isEqualToSong:(nullable ISMSSong *)otherSong;

@property BOOL isPartiallyCached;
@property BOOL isFullyCached;
- (void)removeFromCache;
- (void)removeFromCachedSongsTable;

@property (readonly) CGFloat downloadProgress;
@property (readonly) BOOL fileExists;

- (BOOL)existsInCache;

@end
