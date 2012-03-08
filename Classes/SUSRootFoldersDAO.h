//
//  SUSRootFoldersDAO.h
//  iSub
//
//  Created by Ben Baron on 8/21/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSLoaderDelegate.h"
#import "SUSLoaderManager.h"

@class Artist, FMDatabase, SUSRootFoldersLoader;

@interface SUSRootFoldersDAO : NSObject <SUSLoaderManager, SUSLoaderDelegate>
{		
	NSUInteger count;
	NSUInteger searchCount;
	
	NSNumber *selectedFolderId;
	
	NSUInteger tempRecordCount;
}

@property (readonly) FMDatabase *db;

@property (assign) id<SUSLoaderDelegate> delegate;

@property (retain) SUSRootFoldersLoader *loader;

@property (readonly) NSUInteger count;
@property (readonly) NSUInteger searchCount;
@property (readonly) NSArray *indexNames;
@property (readonly) NSArray *indexPositions;
@property (readonly) NSArray *indexCounts;

@property (readonly) NSString *tableModifier;

@property (retain) NSNumber *selectedFolderId;
@property (readonly) BOOL isRootFolderIdCached;

+ (void)setFolderDropdownFolders:(NSDictionary *)folders;
+ (NSDictionary *)folderDropdownFolders;

- (id)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate;

- (Artist *)artistForPosition:(NSUInteger)position;
- (void)clearSearchTable;
- (void)searchForFolderName:(NSString *)name;
- (Artist *)artistForPositionInSearch:(NSUInteger)position;

- (id)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate;
- (void)startLoad;
- (void)cancelLoad;

@end
