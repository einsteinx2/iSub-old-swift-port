//
//  iSubBassGaplessPlayerDelegate.m
//  iSub
//
//  Created by Ben Baron on 9/8/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "iSubBassGaplessPlayerDelegate.h"
#import "BassGaplessPlayer.h"

@implementation iSubBassGaplessPlayerDelegate

- (void)bassSeekToPositionStarted:(BassGaplessPlayer*)player
{
    
}

- (void)bassSeekToPositionSuccess:(BassGaplessPlayer*)player
{
    
}

- (void)bassStopped:(BassGaplessPlayer*)player
{
    
}

- (void)bassFirstStreamStarted:(BassGaplessPlayer*)player
{
    
}

- (void)bassSongEndedCalled:(BassGaplessPlayer*)player
{
    // Increment current playlist index
    [playlistS incrementIndex];
}

- (void)bassFreed:(BassGaplessPlayer *)player
{
    //[socialS playerHandleSocial];
    //[socialS playerClearSocial];
}

- (NSUInteger)bassNextIndex:(BassGaplessPlayer*)player
{
    return [playlistS indexForOffset:1 fromIndex:player.currentPlaylistIndex];
}

- (Song *)bassSongForIndex:(NSUInteger)index player:(BassGaplessPlayer *)player
{
    return [playlistS songForIndex:index];
}

- (void)bassRetrySongPlay:(BassGaplessPlayer *)player
{
    [EX2Dispatch runInMainThread:^
     {
         [musicS playSongAtPosition:playlistS.currentIndex];
     }];
}

@end
