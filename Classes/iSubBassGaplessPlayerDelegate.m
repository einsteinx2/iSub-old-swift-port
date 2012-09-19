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

- (NSUInteger)bassIndexAtOffset:(NSInteger)offset fromIndex:(NSUInteger)index player:(BassGaplessPlayer *)player
{
    return [playlistS indexForOffset:offset fromIndex:index];
}

- (ISMSSong *)bassSongForIndex:(NSUInteger)index player:(BassGaplessPlayer *)player
{
    return [playlistS songForIndex:index];
}

- (void)bassRetrySongAtIndex:(NSUInteger)index player:(BassGaplessPlayer*)player;
{
    [EX2Dispatch runInMainThread:^
     {
         [musicS playSongAtPosition:index];
     }];
}

- (void)bassUpdateLockScreenInfo:(BassGaplessPlayer *)player
{
	[musicS updateLockScreenInfo];
}

- (void)bassRetrySongAtOffsetInBytes:(NSUInteger)bytes andSeconds:(NSUInteger)seconds player:(BassGaplessPlayer*)player
{
    [musicS startSongAtOffsetInBytes:bytes andSeconds:seconds];
}

@end
