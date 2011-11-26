//
//  SUSCurrentPlaylistDAO.h
//  iSub
//
//  Created by Ben Baron on 11/14/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

@class Song, FMDatabase;
@interface SUSCurrentPlaylistDAO : NSObject

+ (SUSCurrentPlaylistDAO *)dataModel;

- (Song *)songForIndex:(NSUInteger)index;
- (NSInteger)incrementIndex;
// Convenience properties
@property (readonly) Song *currentSong;
@property (readonly) Song *nextSong;

@property NSInteger currentIndex;
@property (readonly) NSUInteger count;

@property (readonly) FMDatabase *db;

@end
