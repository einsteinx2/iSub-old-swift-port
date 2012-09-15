//
//  BassGaplessPlayerDelegate.h
//  Anghami
//
//  Created by Ben Baron on 9/8/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

@class Song;
@protocol BassGaplessPlayerDelegate <NSObject>

@optional
- (void)bassSeekToPositionStarted;
- (void)bassSeekToPositionSuccess;
- (void)bassStopped;
- (void)bassFirstStreamStarted;
- (void)bassSongEndedCalled;
- (void)bassSongEndedPlaylistIncremented:(ISMSSong *)endedSong;
- (void)bassSongEndedFinishedIsPlaying;

@end
