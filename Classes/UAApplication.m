//
//  UAApplication.m
//  iSub
//
//  Created by Ben Baron on 6/13/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "UAApplication.h"
#import "MusicSingleton.h"
#import "iSubAppDelegate.h"
#import "SavedSettings.h"
#import "AudioEngine.h"
#import "JukeboxSingleton.h"

static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation UAApplication

- (id) init 
{
	self = [super init];
	if (self != nil) 
	{
		[self becomeFirstResponder];
		
		if ([self respondsToSelector:@selector(beginReceivingRemoteControlEvents)])
			[self beginReceivingRemoteControlEvents];
	}
	return self;
}

#pragma mark -
#pragma mark UIResponder
-(BOOL)canBecomeFirstResponder 
{
    return YES;
}

#pragma mark -
#pragma mark Motion
- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event 
{
	
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event 
{
	if (motion == UIEventSubtypeMotionShake) 
	{
	//DLog(@"oh ya, shake it now!");
	}
}

- (void)motionCancelled:(UIEventSubtype)motion withEvent:(UIEvent *)event 
{ 
	
}

#pragma mark -
#pragma mark Remote Control

- (void)playPauseStop
{
	DDLogVerbose(@"playPauseStop called");
	if (settingsS.isJukeboxEnabled)
	{
		DDLogVerbose(@"playPauseStop jukebox is enabled");
		if (jukeboxS.jukeboxIsPlaying)
		{
			DDLogVerbose(@"jukebox is playing, playPauseStop jukeboxStop called");
			[jukeboxS jukeboxStop];
		}
		else
		{
			DDLogVerbose(@"jukebox NOT playing, playPauseStop jukeboxPlay called");
			[jukeboxS jukeboxPlay];
		}
	}
	else
	{
		DDLogVerbose(@"playPauseStop jukebox NOT enabled");
        if (audioEngineS.player)
		{
			DDLogVerbose(@"audio engine player exists, playPauseStop [audioEngineS.player playPause] called");
			[audioEngineS.player playPause];
		}
		else
		{
			DDLogVerbose(@"audio engine player doesn't exist, playPauseStop [musicS startSong] called");
			[musicS startSong];
		}
	}
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event 
{
	//DLog(@"remoteControlReceivedWithEvent: %d", event.subtype);
	switch(event.subtype) 
	{
		case UIEventSubtypeRemoteControlPlay:
			DDLogVerbose(@"UIEventSubtypeRemoteControlPlay, calling playPauseStop");
			[self playPauseStop];
			break;
		case UIEventSubtypeRemoteControlPause:
			DDLogVerbose(@"UIEventSubtypeRemoteControlPause, calling playPauseStop");
			[self playPauseStop];
			break;
		case UIEventSubtypeRemoteControlStop:
			DDLogVerbose(@"UIEventSubtypeRemoteControlStop, calling playPauseStop");
			[self playPauseStop];
			break;
		case UIEventSubtypeRemoteControlTogglePlayPause:
			DDLogVerbose(@"UIEventSubtypeRemoteControlTogglePlayPause, calling playPauseStop");
			[self playPauseStop];
			break;
		case UIEventSubtypeRemoteControlNextTrack:
			DDLogVerbose(@"UIEventSubtypeRemoteControlNextTrack, calling nextSong");
			[musicS nextSong];
			break;
		case UIEventSubtypeRemoteControlPreviousTrack:
			DDLogVerbose(@"UIEventSubtypeRemoteControlPreviousTrack, calling prevSong");
			[musicS prevSong];
			break;
		default:
			return;
	}	
}


@end
