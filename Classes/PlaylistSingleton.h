//
//  SUSCurrentPlaylistDAO.h
//  iSub
//
//  Created by Ben Baron on 11/14/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#define playlistS [PlaylistSingleton sharedInstance]

typedef enum
{
	ISMSRepeatMode_Normal = 0,
	ISMSRepeatMode_RepeatOne = 1,
	ISMSRepeatMode_RepeatAll = 2
} ISMSRepeatMode;

@class Song, FMDatabase;
@interface PlaylistSingleton : NSObject
{
	NSInteger shuffleIndex;
	NSInteger normalIndex;
	ISMSRepeatMode repeatMode;
}

+ (PlaylistSingleton *)sharedInstance;

- (Song *)songForIndex:(NSUInteger)index;
- (NSInteger)decrementIndex;
- (NSInteger)incrementIndex;


- (NSUInteger)indexForOffsetFromCurrentIndex:(NSUInteger)offset;

// Convenience properties
@property (unsafe_unretained, readonly) Song *prevSong;
@property (unsafe_unretained, readonly) Song *currentDisplaySong;
@property (unsafe_unretained, readonly) Song *currentSong;
@property (unsafe_unretained, readonly) Song *nextSong;

@property NSInteger shuffleIndex;
@property NSInteger normalIndex;

@property NSInteger currentIndex;
@property (readonly) NSInteger prevIndex;
@property (readonly) NSInteger nextIndex;
@property (readonly) NSUInteger count;

@property (unsafe_unretained, readonly) FMDatabase *db;

@property ISMSRepeatMode repeatMode;

@property BOOL isShuffle;

- (void)deleteSongs:(NSArray *)indexes;
- (void)shuffleToggle;

@end
