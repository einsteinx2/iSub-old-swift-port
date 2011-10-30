//
//  SUSRootFoldersDAO.h
//  iSub
//
//  Created by Ben Baron on 8/21/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "Loader.h"
#import "LoaderDelegate.h"
#import "LoaderManager.h"

@class Artist, FMDatabase, SUSRootFoldersLoader;

@interface SUSRootFoldersDAO : Loader <LoaderManager>
{		
	NSUInteger count;
	NSUInteger searchCount;
	
	NSNumber *selectedFolderId;
	
	NSUInteger tempRecordCount;
}

@property (readonly) FMDatabase *db;

@property (nonatomic, retain) SUSRootFoldersLoader *loader;

@property (readonly) NSUInteger count;
@property (readonly) NSUInteger searchCount;
@property (readonly) NSArray *indexNames;
@property (readonly) NSArray *indexPositions;
@property (readonly) NSArray *indexCounts;

@property (readonly) NSString *tableModifier;

@property (nonatomic, retain) NSNumber *selectedFolderId;
@property (readonly) BOOL isRootFolderIdCached;

+ (void)setFolderDropdownFolders:(NSDictionary *)folders;
+ (NSDictionary *)folderDropdownFolders;

- (Artist *)artistForPosition:(NSUInteger)position;
- (void)clearSearchTable;
- (void)searchForFolderName:(NSString *)name;
- (Artist *)artistForPositionInSearch:(NSUInteger)position;
- (void)clearSearchTable;

- (id)initWithDelegate:(id <LoaderDelegate>)theDelegate;
- (void)startLoad;
- (void)cancelLoad;

@end
