//
//  SUSRootFoldersDAO.h
//  iSub
//
//  Created by Ben Baron on 8/21/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

//#import <Foundation/Foundation.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER
#import "Loader.h"

#define TEMP_FLUSH_AMOUNT 400

@class Artist, FMDatabase;

@interface SUSRootFoldersDAO : Loader
{	
	FMDatabase *db;
	
	NSUInteger count;
	NSUInteger searchCount;
	NSArray *indexNames;
	NSArray *indexPositions;
	NSArray *indexCounts;
	
	NSNumber *selectedFolderId;
	
	NSUInteger tempRecordCount;
}

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

@end
