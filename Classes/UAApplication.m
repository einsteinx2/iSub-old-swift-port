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
	MusicSingleton *musicControls = [MusicSingleton sharedInstance];
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		if (musicControls.jukeboxIsPlaying)
			[musicControls jukeboxStop];
		else
			[musicControls jukeboxPlay];
	}
	else
	{
		[musicControls playPauseSong];
	}
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event 
{
	//DLog(@"remoteControlReceivedWithEvent: %d", event.subtype);
	MusicSingleton *musicControls = [MusicSingleton sharedInstance];
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
			[musicControls nextSong];
			break;
		case UIEventSubtypeRemoteControlPreviousTrack:
			//DLog(@"UIEventSubtypeRemoteControlPreviousTrack");
			[musicControls prevSong];
			break;
		default:
			return;
	}	
}


@end
