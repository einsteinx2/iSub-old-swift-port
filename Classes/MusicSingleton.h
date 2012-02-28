//
//  musicSSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#define musicS [MusicSingleton sharedInstance]

#import "SUSLoaderDelegate.h"

@class Song;

@interface MusicSingleton : NSObject
{		
	BOOL isAutoNextNotificationOn;
}

@property (readonly) BOOL showPlayerIcon;

+ (MusicSingleton*)sharedInstance;

- (void)startSongAtOffsetInBytes:(unsigned long long)bytes andSeconds:(double)seconds;
- (void)startSong;
- (void)playSongAtPosition:(NSInteger)position;
- (void)nextSong;
- (void)prevSong;
- (void)resumeSong;
- (void)showPlayer;
- (void)updateLockScreenInfo;

@end
