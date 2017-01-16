//
//  BassGaplessPlayerDelegate.h
//  Anghami
//
//  Created by Ben Baron on 9/8/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

@class Song, BassGaplessPlayer;
@protocol BassGaplessPlayerDelegate <NSObject>

@optional
- (void)bassSeekToPositionStarted:(nonnull BassGaplessPlayer*)player;
- (void)bassSeekToPositionSuccess:(nonnull BassGaplessPlayer*)player;
- (void)bassStopped:(nonnull BassGaplessPlayer*)player;
- (void)bassFirstStreamStarted:(nonnull BassGaplessPlayer*)player;
- (void)bassSongEndedCalled:(nonnull BassGaplessPlayer*)player;
- (void)bassFreed:(nonnull BassGaplessPlayer *)player;
- (void)bassUpdateLockScreenInfo:(nonnull BassGaplessPlayer *)player;
- (void)bassFailedToCreateNextStreamForIndex:(NSInteger)index player:(nonnull BassGaplessPlayer *)player;
- (void)bassRetrievingOutputData:(nonnull BassGaplessPlayer *)player;

@required
- (nullable Song *)bassSongForIndex:(NSInteger)index player:(nonnull BassGaplessPlayer *)player;
- (NSInteger)bassIndexAtOffset:(NSInteger)offset fromIndex:(NSInteger)index player:(nonnull BassGaplessPlayer *)player;
- (NSInteger)bassCurrentPlaylistIndex:(nonnull BassGaplessPlayer *)player;
- (void)bassRetrySongAtIndex:(NSInteger)index player:(nonnull BassGaplessPlayer*)player;
- (void)bassRetrySongAtOffsetInBytes:(NSInteger)bytes player:(nonnull BassGaplessPlayer*)player;

@end
