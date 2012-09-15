//
//  SUSSubFolderLoader.m
//  iSub
//
//  Created by Benjamin Baron on 11/6/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSSubFolderLoader.h"
#import "SUSSubFolderLoader.h"
#import "PMSSubFolderLoader.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueueAdditions.h"
#import "TBXML.h"
#import "NSMutableURLRequest+SUS.h"
#import "Album.h"
#import "Song.h"
#import "Artist.h"

@implementation ISMSSubFolderLoader

+ (id)loaderWithDelegate:(NSObject<ISMSLoaderDelegate> *)theDelegate
{
	if ([settingsS.serverType isEqualToString:SUBSONIC] || [settingsS.serverType isEqualToString:UBUNTU_ONE])
	{
		return [[SUSSubFolderLoader alloc] initWithDelegate:theDelegate];
	}
	else if ([settingsS.serverType isEqualToString:WAVEBOX]) 
	{
		return [[PMSSubFolderLoader alloc] initWithDelegate:theDelegate];
	}
	return nil;
}

#pragma mark - Lifecycle

- (FMDatabaseQueue *)dbQueue
{
    return databaseS.albumListCacheDbQueue;
}

- (ISMSLoaderType)type
{
    return ISMSLoaderType_SubFolders;
}

#pragma mark - Private DB Methods

- (BOOL)resetDb
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		//Initialize the arrays.
		[db beginTransaction];
		[db executeUpdate:@"DELETE FROM albumsCache WHERE folderId = ?", self.myId.md5];
		[db executeUpdate:@"DELETE FROM songsCache WHERE folderId = ?", self.myId.md5];
		[db executeUpdate:@"DELETE FROM albumsCacheCount WHERE folderId = ?", self.myId.md5];
		[db executeUpdate:@"DELETE FROM songsCacheCount WHERE folderId = ?", self.myId.md5];
		[db executeUpdate:@"DELETE FROM folderLength WHERE folderId = ?", self.myId.md5];
		[db commit];
		
		hadError = [db hadError];
		if (hadError)
			DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
    
	return !hadError;
}

- (BOOL)insertAlbumIntoFolderCache:(Album *)anAlbum
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"INSERT INTO albumsCache (folderId, title, albumId, coverArtId, artistName, artistId) VALUES (?, ?, ?, ?, ?, ?)", self.myId.md5, [anAlbum.title cleanString], anAlbum.albumId, anAlbum.coverArtId, [anAlbum.artistName cleanString], anAlbum.artistId];
		
		hadError = [db hadError];
		if (hadError)
			DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
	
	return !hadError;
}

- (BOOL)insertSongIntoFolderCache:(Song *)aSong
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		//DLog(@"aSong.title: %@  clean: %@", aSong.title, [aSong.title cleanString]);
		[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO songsCache (folderId, %@) VALUES (?, %@)", [Song standardSongColumnNames], [Song standardSongColumnQMarks]], self.myId.md5, [aSong.title cleanString], aSong.songId, [aSong.artist cleanString], [aSong.album cleanString], [aSong.genre cleanString], aSong.coverArtId, aSong.path, aSong.suffix, aSong.transcodedSuffix, aSong.duration, aSong.bitRate, aSong.track, aSong.year, aSong.size, aSong.parentId, NSStringFromBOOL(aSong.isVideo)];
		
		hadError = [db hadError];
		if (hadError)
			DLog(@"Err inserting song %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
	
	return !hadError;
}

- (BOOL)insertAlbumsCount
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"INSERT INTO albumsCacheCount (folderId, count) VALUES (?, ?)", self.myId.md5, [NSNumber numberWithInt:self.albumsCount]];
		
		hadError = [db hadError];
		if ([db hadError])
			DLog(@"Err inserting album count %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
    
	return !hadError;
}

- (BOOL)insertSongsCount
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"INSERT INTO songsCacheCount (folderId, count) VALUES (?, ?)", self.myId.md5, [NSNumber numberWithInt:self.songsCount]];
		
		hadError = [db hadError];
		if (hadError)
			DLog(@"Err inserting song count %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
    	
	return !hadError;
}

- (BOOL)insertFolderLength
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"INSERT INTO folderLength (folderId, length) VALUES (?, ?)", self.myId.md5, [NSNumber numberWithInt:self.folderLength]];
		
		hadError = [db hadError];
		if ([db hadError])
			DLog(@"Err inserting folder length %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
   
	return !hadError;
}
@end
