//
//  SUSRootFoldersDAO.h
//  iSub
//
//  Created by Ben Baron on 8/21/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoaderDelegate.h"
#import "ISMSLoaderManager.h"

@class Artist, FMDatabase, ISMSRootFoldersLoader;

@interface SUSRootFoldersDAO : NSObject <ISMSLoaderManager, ISMSLoaderDelegate>
{		
	NSUInteger _tempRecordCount;
    NSArray *_indexNames;
    NSArray *_indexPositions;
    NSArray *_indexCounts;
}

@property (unsafe_unretained) id<ISMSLoaderDelegate> delegate;

@property (strong) ISMSRootFoldersLoader *loader;

@property (readonly) NSUInteger count;
@property (readonly) NSUInteger searchCount;
@property (readonly) NSArray *indexNames;
@property (readonly) NSArray *indexPositions;
@property (readonly) NSArray *indexCounts;

- (NSString *)tableModifier;

@property (strong) NSNumber *selectedFolderId;
@property (readonly) BOOL isRootFolderIdCached;

+ (void)setFolderDropdownFolders:(NSDictionary *)folders;
+ (NSDictionary *)folderDropdownFolders;

- (id)initWithDelegate:(id <ISMSLoaderDelegate>)theDelegate;

- (Artist *)artistForPosition:(NSUInteger)position;
- (void)clearSearchTable;
- (void)searchForFolderName:(NSString *)name;
- (Artist *)artistForPositionInSearch:(NSUInteger)position;

- (id)initWithDelegate:(id <ISMSLoaderDelegate>)theDelegate;
- (void)startLoad;
- (void)cancelLoad;

@end
