//
//  AudioEngine.m
//  iSub
//
//  Created by Ben Baron on 11/16/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "AudioEngine.h"
#import "Song.h"
#import "PlaylistSingleton.h"
#import "NSString+cStringUTF8.h"
#import "BassParamEqValue.h"
#import "NSNotificationCenter+MainThread.h"
#include <AudioToolbox/AudioToolbox.h>
#include "MusicSingleton.h"
#import "BassEffectDAO.h"
#import <sys/stat.h>
#import "BassStream.h"
#import "SavedSettings.h"
#import "ISMSStreamManager.h"
#import "NSMutableURLRequest+SUS.h"
#import "MusicSingleton.h"
#import "SocialSingleton.h"
#import "ViewObjectsSingleton.h"
#import "iSubAppDelegate.h"
#import "DDLog.h"

@implementation AudioEngine
@synthesize shouldResumeFromInterruption;
@synthesize player;
@synthesize startByteOffset, startSecondsOffset;

static const int ddLogLevel = LOG_LEVEL_INFO;

// Singleton object
static AudioEngine *sharedInstance = nil;

void interruptionListenerCallback(void *inUserData, UInt32 interruptionState) 
{
    if (interruptionState == kAudioSessionBeginInterruption) 
	{
		DDLogCVerbose(@"audio session begin interruption");
		if (sharedInstance.player.isPlaying)
		{
			sharedInstance.shouldResumeFromInterruption = YES;
			[sharedInstance.player pause];
		}
		else
		{
			sharedInstance.shouldResumeFromInterruption = NO;
		}
    } 
	else if (interruptionState == kAudioSessionEndInterruption) 
	{
        DDLogCVerbose(@"audio session interruption ended, isPlaying: %@   isMainThread: %@", NSStringFromBOOL(sharedInstance.player.isPlaying), NSStringFromBOOL([NSThread isMainThread]));
		if (sharedInstance.shouldResumeFromInterruption)
		{
			[sharedInstance.player playPause];
			
			// Reset the shouldResumeFromInterruption value
			sharedInstance.shouldResumeFromInterruption = NO;
		}
    }
}

- (void)startWithOffsetInBytes:(NSNumber *)byteOffset orSeconds:(NSNumber *)seconds
{
	// Dispose of the old player
	[self.player stop];
	self.player = nil;
	
	// Create a new player
	self.player = [[BassGaplessPlayer alloc] init];
	[self.player startWithOffsetInBytes:byteOffset orSeconds:seconds];
}

- (void)start
{
	[self startWithOffsetInBytes:[NSNumber numberWithInt:0] orSeconds:nil];
}

- (BassEqualizer *)equalizer
{
	return self.player.equalizer;
}

- (BassVisualizer *)visualizer
{
	return self.player.visualizer;
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
	DDLogError(@"received memory warning");
}

#pragma mark - Singleton methods

- (void)setup
{	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
	
	AudioSessionInitialize(NULL, NULL, interruptionListenerCallback, NULL);
}

+ (id)sharedInstance
{
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
