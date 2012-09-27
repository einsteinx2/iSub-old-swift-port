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

- (id)init
{
    if ((self = [super init]))
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(grabCurrentPlaylistIndex:) name:ISMSNotification_CurrentPlaylistOrderChanged object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(grabCurrentPlaylistIndex:) name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)grabCurrentPlaylistIndex:(NSNotification *)notification
{
    
}

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

- (NSUInteger)bassCurrentPlaylistIndex:(BassGaplessPlayer *)player
{
    return playlistS.currentIndex;
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
