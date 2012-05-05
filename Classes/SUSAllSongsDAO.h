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

@interface SUSAllSongsDAO : NSObject <SUSLoaderManager, SUSLoaderDelegate>
{
	__strong NSArray *index;
}
@property (unsafe_unretained) id<SUSLoaderDelegate> delegate;

@property (readonly) NSUInteger count;
@property (readonly) NSUInteger searchCount;
@property (unsafe_unretained, readonly) NSArray *index;
@property (readonly) BOOL isDataLoaded;

@property (strong) SUSAllSongsLoader *loader;

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