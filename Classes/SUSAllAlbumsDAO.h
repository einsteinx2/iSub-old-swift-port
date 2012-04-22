//
//  SUSAllAlbumsDAO.h
//  iSub
//
//  Created by Ben Baron on 9/23/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

@class FMDatabase, Album;

@interface SUSAllAlbumsDAO : NSObject
{	
	NSArray *index;
}

@property (unsafe_unretained, readonly) FMDatabase *db;

@property (readonly) NSUInteger count;
@property (readonly) NSUInteger searchCount;
@property (unsafe_unretained, readonly) NSArray *index;
@property (readonly) BOOL isDataLoaded;

- (Album *)albumForPosition:(NSUInteger)position;
- (void)clearSearchTable;
- (void)searchForAlbumName:(NSString *)name;
- (Album *)albumForPositionInSearch:(NSUInteger)position;
- (void)clearSearchTable;

@end