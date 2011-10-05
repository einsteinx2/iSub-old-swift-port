//
//  SUSAllSongsDAO.h
//  iSub
//
//  Created by Ben Baron on 9/23/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "LoaderDelegate.h"
#import "LoaderManager.h"

@class FMDatabase, Song, SUSAllSongsLoader;

@interface SUSAllSongsDAO : NSObject <LoaderManager>
{
	id<LoaderDelegate> delegate;
	
	FMDatabase *db;
	
	NSUInteger count;
	NSArray *index;
	
	SUSAllSongsLoader *loader;
	
	BOOL isLoading;
}

@property (readonly) NSUInteger count;
@property (readonly) NSUInteger searchCount;
@property (readonly) NSArray *index;
@property (readonly) BOOL isDataLoaded;
@property (readonly) BOOL isLoading;

@property (nonatomic, retain) SUSAllSongsLoader *loader;

- (id)initWithDelegate:(id <LoaderDelegate>)theDelegate;
- (void)restartLoad;
- (void)startLoad;
- (void)cancelLoad;

- (Song *)songForPosition:(NSUInteger)position;
- (void)clearSearchTable;
- (void)searchForSongName:(NSString *)name;
- (Song *)songForPositionInSearch:(NSUInteger)position;
- (void)clearSearchTable;

@end