//
//  SUSCurrentPlaylistDAO.h
//  iSub
//
//  Created by Ben Baron on 11/14/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

typedef enum
{
	ISMSRepeatMode_Normal,
	ISMSRepeatMode_RepeatOne,
	ISMSRepeatMode_RepeatAll
} ISMSRepeatMode;

@class Song, FMDatabase;
@interface SUSCurrentPlaylistDAO : NSObject

+ (SUSCurrentPlaylistDAO *)dataModel;

- (Song *)songForIndex:(NSUInteger)index;
- (NSInteger)incrementIndex;
// Convenience properties
@property (readonly) Song *prevSong;
@property (readonly) Song *currentDisplaySong;
@property (readonly) Song *currentSong;
@property (readonly) Song *nextSong;

@property NSInteger currentIndex;
@property (readonly) NSInteger nextIndex;
@property (readonly) NSUInteger count;

@property (readonly) FMDatabase *db;

@property ISMSRepeatMode repeatMode;

- (void)deleteSongs:(NSArray *)indexes;
- (void)shuffleToggle;

@end
