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
	__strong NSArray *index;
}

@property (readonly) NSUInteger count;
@property (readonly) NSUInteger searchCount;
@property (readonly) BOOL isDataLoaded;

- (NSArray *)index;

- (Album *)albumForPosition:(NSUInteger)position;
- (void)clearSearchTable;
- (void)searchForAlbumName:(NSString *)name;
- (Album *)albumForPositionInSearch:(NSUInteger)position;
- (void)clearSearchTable;

@end