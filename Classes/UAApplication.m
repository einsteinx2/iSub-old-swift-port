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
		DLog(@"oh ya, shake it now!");
	}
}

- (void)motionCancelled:(UIEventSubtype)motion withEvent:(UIEvent *)event 
{ 
	
}

#pragma mark -
#pragma mark Remote Control

- (void)playPauseStop
{
	if (settingsS.isJukeboxEnabled)
	{
		if (jukeboxS.jukeboxIsPlaying)
			[jukeboxS jukeboxStop];
		else
			[jukeboxS jukeboxPlay];
	}
	else
	{
        if (audioEngineS.player)
		{
			[audioEngineS.player playPause];
		}
		else
		{
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
			//DLog(@"UIEventSubtypeRemoteControlPlay");
			[self playPauseStop];
			break;
		case UIEventSubtypeRemoteControlPause:
			//DLog(@"UIEventSubtypeRemoteControlPause");
			[self playPauseStop];
			break;
		case UIEventSubtypeRemoteControlStop:
			//DLog(@"UIEventSubtypeRemoteControlStop");
			[self playPauseStop];
			break;
		case UIEventSubtypeRemoteControlTogglePlayPause:
			//DLog(@"UIEventSubtypeRemoteControlTogglePlayPause");
			[self playPauseStop];
			break;
		case UIEventSubtypeRemoteControlNextTrack:
			//DLog(@"UIEventSubtypeRemoteControlNextTrack");
			[musicS nextSong];
			break;
		case UIEventSubtypeRemoteControlPreviousTrack:
			//DLog(@"UIEventSubtypeRemoteControlPreviousTrack");
			[musicS prevSong];
			break;
		default:
			return;
	}	
}


@end
