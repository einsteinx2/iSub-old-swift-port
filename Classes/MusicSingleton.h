//
//  musicSSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#define musicS ((MusicSingleton *)[MusicSingleton sharedInstance])

#import "ISMSLoaderDelegate.h"

@class Song, MPMoviePlayerController;
@interface MusicSingleton : NSObject

@property BOOL isAutoNextNotificationOn;
@property (readonly) BOOL showPlayerIcon;
@property (strong) MPMoviePlayerController *moviePlayer;

+ (id)sharedInstance;

- (void)startSongAtOffsetInBytes:(unsigned long long)bytes andSeconds:(double)seconds;
- (void)startSong;
- (Song *)playSongAtPosition:(NSInteger)position;
- (void)nextSong;
- (void)prevSong;
- (void)resumeSong;
- (void)showPlayer;
- (void)updateLockScreenInfo;

@end
