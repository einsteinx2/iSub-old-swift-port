//
//  AudioEngine.m
//  iSub
//
//  Created by Ben Baron on 11/16/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "AudioEngine.h"
#import "BassParamEqValue.h"
#include <AudioToolbox/AudioToolbox.h>
#include "MusicSingleton.h"
#import "BassEffectDAO.h"
#import <sys/stat.h>
#import "BassStream.h"
#import "ISMSStreamManager.h"

@implementation AudioEngine

LOG_LEVEL_ISUB_DEFAULT

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

void audioRouteChangeListenerCallback(void *inUserData, AudioSessionPropertyID inPropertyID, UInt32 inPropertyValueSize, const void *inPropertyValue) 
{			
	DDLogCInfo(@"audioRouteChangeListenerCallback called, propertyId: %lu  isMainThread: %@", inPropertyID, NSStringFromBOOL([NSThread isMainThread]));
	
    // ensure that this callback was invoked for a route change
    if (inPropertyID != kAudioSessionProperty_AudioRouteChange) 
		return;
	
	if (sharedInstance.player.isPlaying)
	{
		// Determines the reason for the route change, to ensure that it is not
		// because of a category change.
		CFDictionaryRef routeChangeDictionary = inPropertyValue;
		CFNumberRef routeChangeReasonRef = CFDictionaryGetValue (routeChangeDictionary, CFSTR (kAudioSession_AudioRouteChangeKey_Reason));
		SInt32 routeChangeReason;
		CFNumberGetValue (routeChangeReasonRef, kCFNumberSInt32Type, &routeChangeReason);
		
		DDLogCInfo(@"route change reason: %li", routeChangeReason);
		
        // "Old device unavailable" indicates that a headset was unplugged, or that the
        // device was removed from a dock connector that supports audio output. This is
        // the recommended test for when to pause audio.
        if (routeChangeReason == kAudioSessionRouteChangeReason_OldDeviceUnavailable) 
		{
			[sharedInstance.player playPause];
			
            DDLogCInfo(@"Output device removed, so application audio was paused.");
        }
		else 
		{
            DDLogCInfo(@"A route change occurred that does not require pausing of application audio.");
        }
    }
	else 
	{	
        DDLogCInfo(@"Audio route change while application audio is stopped.");
        return;
    }
}

- (void)startSong:(ISMSSong *)aSong atIndex:(NSUInteger)index withOffsetInBytes:(NSNumber *)byteOffset orSeconds:(NSNumber *)seconds
{
	// Dispose of the old player
	[self.player stop];
	self.player = nil;
	
	// Create a new player
	self.player = [[BassGaplessPlayer alloc] initWithDelegate:self.delegate];
	[self.player startSong:aSong atIndex:index withOffsetInBytes:byteOffset orSeconds:seconds];
    
    // Load the EQ
    BassEffectDAO *effectDAO = [[BassEffectDAO alloc] initWithType:BassEffectType_ParametricEQ];
    [effectDAO selectPresetId:effectDAO.selectedPresetId];
}

- (void)startEmptyPlayer
{
    // Dispose of the old player
	[self.player stop];
	self.player = nil;
    
    // Create a new player and just initialize BASS, but don't play anything
    self.player = [[BassGaplessPlayer alloc] initWithDelegate:self.delegate];
    [self.player bassInit];
    
    // Load the EQ
    //BassEffectDAO *effectDAO = [[BassEffectDAO alloc] initWithType:BassEffectType_ParametricEQ];
    //[effectDAO selectPresetId:effectDAO.selectedPresetId];
    
    // Pause the player
    //BASS_Pause();
    //self.player.isPlaying = NO;
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
	
	// Add the callbacks for headphone removal and other audio takeover
	AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, audioRouteChangeListenerCallback, NULL);
    
    _delegate = [[iSubBassGaplessPlayerDelegate alloc] init];
    
    [self startEmptyPlayer];
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
