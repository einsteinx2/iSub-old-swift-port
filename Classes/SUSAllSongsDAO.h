//
//  SUSAllSongsDAO.h
//  iSub
//
//  Created by Ben Baron on 9/23/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoaderDelegate.h"
#import "ISMSLoaderManager.h"

@class FMDatabase, Song, SUSAllSongsLoader;

@interface SUSAllSongsDAO : NSObject <ISMSLoaderManager, ISMSLoaderDelegate>
{
	__strong NSArray *index;
}

@property (unsafe_unretained) id<ISMSLoaderDelegate> delegate;

@property (readonly) NSUInteger count;
@property (readonly) NSUInteger searchCount;
@property (readonly) BOOL isDataLoaded;

@property (strong) SUSAllSongsLoader *loader;

- (NSArray *)index;

- (id)initWithDelegate:(NSObject <ISMSLoaderDelegate> *)theDelegate;
- (void)restartLoad;
- (void)startLoad;
- (void)cancelLoad;

- (Song *)songForPosition:(NSUInteger)position;
- (void)clearSearchTable;
- (void)searchForSongName:(NSString *)name;
- (Song *)songForPositionInSearch:(NSUInteger)position;
- (void)clearSearchTable;

@end