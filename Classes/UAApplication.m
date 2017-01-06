//
//  UAApplication.m
//  iSub
//
//  Created by Ben Baron on 6/13/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "UAApplication.h"
#import "Imports.h"
#import "CocoaLumberjack.h"
#import "iSub-Swift.h"

static const int ddLogLevel = DDLogLevelDebug;

@implementation UAApplication

- (id)init 
{
	if ((self = [super init]))
	{
		[self becomeFirstResponder];
		
		if ([self respondsToSelector:@selector(beginReceivingRemoteControlEvents)])
			[self beginReceivingRemoteControlEvents];
	}
	return self;
}

#pragma mark - UIResponder

-(BOOL)canBecomeFirstResponder 
{
    return YES;
}

#pragma mark - Motion

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

#pragma mark - Remote Control

// TODO: Audit all this and test

- (void)playPauseStop
{
	DDLogVerbose(@"[UAApplication] playPauseStop called");
    if ([PlayQueue sharedInstance].isStarted)
    {
        DDLogVerbose(@"[UAApplication] audio engine player exists, playPauseStop [[PlayQueue sharedInstance] playPause] called");
        [[PlayQueue sharedInstance] playPause];
    }
    else
    {
        DDLogVerbose(@"[UAApplication] audio engine player doesn't exist, playPauseStop [musicS playSongAtPosition:playlistS.currentIndex] called");
        [[PlayQueue sharedInstance] playSongAtIndex:[PlayQueue sharedInstance].currentIndex];
    }
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event 
{
	DDLogVerbose(@"[UAApplication] remoteControlReceivedWithEvent type: %li  subtype: %li  timestamp: %f", (long)event.type, (long)event.subtype, event.timestamp);
	switch(event.subtype) 
	{
		case UIEventSubtypeRemoteControlPlay:
			DDLogVerbose(@"[UAApplication] UIEventSubtypeRemoteControlPlay, calling playPauseStop");
			[self playPauseStop];
			break;
		case UIEventSubtypeRemoteControlPause:
			DDLogVerbose(@"[UAApplication] UIEventSubtypeRemoteControlPause, calling playPauseStop");
			[self playPauseStop];
			break;
		case UIEventSubtypeRemoteControlStop:
			DDLogVerbose(@"[UAApplication] UIEventSubtypeRemoteControlStop, calling playPauseStop");
			[self playPauseStop];
			break;
		case UIEventSubtypeRemoteControlTogglePlayPause:
			DDLogVerbose(@"[UAApplication] UIEventSubtypeRemoteControlTogglePlayPause, calling playPauseStop");
			[self playPauseStop];
			break;
		case UIEventSubtypeRemoteControlNextTrack:
			DDLogVerbose(@"UIEventSubtypeRemoteControlNextTrack, calling nextSong");
            [[PlayQueue sharedInstance] playNextSong];
			break;
		case UIEventSubtypeRemoteControlPreviousTrack:
			DDLogVerbose(@"[UAApplication] UIEventSubtypeRemoteControlPreviousTrack, calling prevSong");
            [[PlayQueue sharedInstance] playPreviousSong];
			break;
		default:
			return;
	}	
}

@end
