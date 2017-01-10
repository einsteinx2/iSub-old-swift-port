//
//  DatabaseSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#ifndef iSub_DatabaseSingleton_h
#define iSub_DatabaseSingleton_h

@class FMDatabase, FMDatabasePool, FMDatabaseQueue, ISMSArtist, ISMSAlbum, ISMSSong, ISMSQueueAllLoader;

@interface DatabaseSingleton : NSObject 

@property (nonnull, strong) NSString *databaseFolderPath;

// Uses WAL for reading concurrently with writes
//
// Write using the FMDatabaseQueue so that all writes are sequential
@property (nonnull, strong) FMDatabaseQueue *songModelWritesDbQueue;
// Read from the FMDatabase concurrently on any thread.
@property (nonnull, strong) FMDatabasePool *songModelReadDbPool;

@property (nonnull, strong) FMDatabaseQueue *bookmarksDbQueue;

@property (nonnull, strong) ISMSQueueAllLoader *queueAll;

+ (nonnull instancetype)si;

- (void)setupDatabases;
- (void)closeAllDatabases;
- (void)resetFolderCache;

- (void)setAllSongsToBackup;
- (void)setAllSongsToNotBackup;

- (nonnull NSArray<NSString*> *)ignoredArticles;
- (nonnull NSString *)name:(nonnull NSString *)name ignoringArticles:(nullable NSArray *)articles;

@end

#endif
