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
- (void)bassSeekToPositionStarted:(BassGaplessPlayer*)player;
- (void)bassSeekToPositionSuccess:(BassGaplessPlayer*)player;
- (void)bassStopped:(BassGaplessPlayer*)player;
- (void)bassFirstStreamStarted:(BassGaplessPlayer*)player;
- (void)bassSongEndedCalled:(BassGaplessPlayer*)player;
- (void)bassFreed:(BassGaplessPlayer *)player;

@required
- (Song *)bassSongForIndex:(NSUInteger)index player:(BassGaplessPlayer *)player;
- (NSUInteger)bassNextIndex:(BassGaplessPlayer*)player;
- (void)bassRetrySongPlay:(BassGaplessPlayer*)player;

@end
