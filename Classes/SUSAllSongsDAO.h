//
//  SUSAllSongsDAO.h
//  iSub
//
//  Created by Ben Baron on 9/23/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSLoaderDelegate.h"
#import "SUSLoaderManager.h"

@class FMDatabase, Song, SUSAllSongsLoader;

@interface SUSAllSongsDAO : NSObject <SUSLoaderManager>
{
	id<SUSLoaderDelegate> delegate;
		
	NSUInteger count;
	NSArray *index;
}

@property (readonly) FMDatabase *db;

@property (readonly) NSUInteger count;
@property (readonly) NSUInteger searchCount;
@property (readonly) NSArray *index;
@property (readonly) BOOL isDataLoaded;
@property (readonly) BOOL isLoading;

@property (nonatomic, retain) SUSAllSongsLoader *loader;

- (id)initWithDelegate:(NSObject <SUSLoaderDelegate> *)theDelegate;
- (void)restartLoad;
- (void)startLoad;
- (void)cancelLoad;

- (Song *)songForPosition:(NSUInteger)position;
- (void)clearSearchTable;
- (void)searchForSongName:(NSString *)name;
- (Song *)songForPositionInSearch:(NSUInteger)position;
- (void)clearSearchTable;

@end