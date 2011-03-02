//
//  UAApplication.m
//  iSub
//
//  Created by Ben Baron on 6/13/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "UAApplication.h"
#import "MusicControlsSingleton.h"
#import "ViewObjectsSingleton.h"
#import "iSubAppDelegate.h"
 
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
		NSLog(@"oh ya, shake it now!: %d");
	}
}
- (void)motionCancelled:(UIEventSubtype)motion withEvent:(UIEvent *)event 
{ 
}

#pragma mark -
#pragma mark Remote Control

- (void)playPauseStop
{
	ViewObjectsSingleton *viewObjects = [ViewObjectsSingleton sharedInstance];
	MusicControlsSingleton *musicControls = [MusicControlsSingleton sharedInstance];
	if (viewObjects.isJukebox)
	{
		if (musicControls.isPlaying)
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
	//NSLog(@"remoteControlReceivedWithEvent: %d", event.subtype);
	MusicControlsSingleton *musicControls = [MusicControlsSingleton sharedInstance];
	switch(event.subtype) 
	{
		case UIEventSubtypeRemoteControlPlay:
			//NSLog(@"UIEventSubtypeRemoteControlPlay");
			[self playPauseStop];
			break;
		case UIEventSubtypeRemoteControlPause:
			//NSLog(@"UIEventSubtypeRemoteControlPause");
			[self playPauseStop];
			break;
		case UIEventSubtypeRemoteControlStop:
			//NSLog(@"UIEventSubtypeRemoteControlStop");
			[self playPauseStop];
			break;
		case UIEventSubtypeRemoteControlTogglePlayPause:
			//NSLog(@"UIEventSubtypeRemoteControlTogglePlayPause");
			[self playPauseStop];
			break;
		case UIEventSubtypeRemoteControlNextTrack:
			//NSLog(@"UIEventSubtypeRemoteControlNextTrack");
			[musicControls nextSong];
			break;
		case UIEventSubtypeRemoteControlPreviousTrack:
			//NSLog(@"UIEventSubtypeRemoteControlPreviousTrack");
			[musicControls prevSong];
			break;
		default:
			return;
	}	
}


@end
