//
//  AudioEngine.m
//  iSub
//
//  Created by Ben Baron on 11/16/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "AudioEngine.h"
#import "iSub-Swift.h"
#import "BassParamEqValue.h"
#import <AudioToolbox/AudioToolbox.h>
#import "BassEffectDAO.h"
#import <sys/stat.h>
#import "BassStream.h"
#import "ISMSStreamManager.h"
#import <AVFoundation/AVFoundation.h>

@implementation AudioEngine

LOG_LEVEL_ISUB_DEFAULT

// Singleton object
static AudioEngine *sharedInstance = nil;

- (void)beginInterruption
{
    DDLogVerbose(@"[AudioEngine] audio session begin interruption");
    if (self.player.isPlaying)
    {
        self.shouldResumeFromInterruption = YES;
        [sharedInstance.player pause];
    }
    else
    {
        self.shouldResumeFromInterruption = NO;
    }
}

- (void)endInterruptionWithFlags:(NSUInteger)flags
{
    DDLogVerbose(@"[AudioEngine] audio session interruption ended, isPlaying: %@   isMainThread: %@", NSStringFromBOOL(sharedInstance.player.isPlaying), NSStringFromBOOL([NSThread isMainThread]));
    if (self.shouldResumeFromInterruption && flags == AVAudioSessionInterruptionOptionShouldResume)
    {
        [self.player playPause];
    }
    
    // Reset the shouldResumeFromInterruption value
    self.shouldResumeFromInterruption = NO;
}

void audioRouteChangeListenerCallback(void *inUserData, AudioSessionPropertyID inPropertyID, UInt32 inPropertyValueSize, const void *inPropertyValue) 
{			
	DDLogInfo(@"[AudioEngine] audioRouteChangeListenerCallback called, propertyId: %lu  isMainThread: %@", (unsigned long)inPropertyID, NSStringFromBOOL([NSThread isMainThread]));
	
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
		
		DDLogInfo(@"[AudioEngine] route change reason: %li", (long)routeChangeReason);
		
        // "Old device unavailable" indicates that a headset was unplugged, or that the
        // device was removed from a dock connector that supports audio output. This is
        // the recommended test for when to pause audio.
        if (routeChangeReason == kAudioSessionRouteChangeReason_OldDeviceUnavailable) 
		{
			[sharedInstance.player playPause];
			
            DDLogInfo(@"[AudioEngine] Output device removed, so application audio was paused.");
        }
		else 
		{
            DDLogInfo(@"[AudioEngine] A route change occurred that does not require pausing of application audio.");
        }
    }
	else 
	{	
        DDLogInfo(@"[AudioEngine] Audio route change while application audio is stopped.");
        return;
    }
}

- (void)startSong:(nonnull ISMSSong *)song index:(NSInteger)index
{
    [self startSong:song atIndex:index withOffsetInBytes:@0 orSeconds:@0];
}

- (void)startSong:(nonnull ISMSSong *)song index:(NSInteger)index offsetInBytes:(NSInteger)bytes
{
    [self startSong:song atIndex:index withOffsetInBytes:@(bytes) orSeconds:nil];
}

- (void)startSong:(nonnull ISMSSong *)song index:(NSInteger)index offsetInSeconds:(NSInteger)seconds
{
    [self startSong:song atIndex:index withOffsetInBytes:nil orSeconds:@(seconds)];
}

- (void)startSong:(ISMSSong *)song atIndex:(NSUInteger)index withOffsetInBytes:(NSNumber *)bytes orSeconds:(NSNumber *)seconds
{
	// Stop the player
	[self.player stop];
    
    // Start the new song
    [self.player startSong:song atIndex:index withOffsetInBytes:bytes orSeconds:seconds];
    
    // Load the EQ
    BassEffectDAO *effectDAO = [[BassEffectDAO alloc] initWithType:BassEffectType_ParametricEQ];
    [effectDAO selectPresetId:effectDAO.selectedPresetId];
}

- (void)startEmptyPlayer
{    
    // Stop the player if it exists
	[self.player stop];
    
    // Create a new player if needed
    if (!self.player)
    {
        self.player = [[BassGaplessPlayer alloc] initWithDelegate:self.delegate];
    }
}

- (void)play
{
    [self.player play];
}

- (void)pause
{
    [self.player pause];
}

- (void)playPause
{
    [self.player playPause];
}

- (void)stop
{
    [self.player stop];
}

- (BOOL)isStarted
{
    return self.player.isStarted;
}

- (BOOL)isPlaying
{
    return self.player.isPlaying;
}

- (void)seekToPositionInBytes:(QWORD)bytes fadeVolume:(BOOL)fadeVolume
{
    [self.player seekToPositionInBytes:bytes fadeVolume:fadeVolume];
}

- (void)seekToPositionInSeconds:(double)seconds fadeVolume:(BOOL)fadeVolume
{
    [self.player seekToPositionInSeconds:seconds fadeVolume:fadeVolume];
}

- (void)seekToPositionInPercent:(double)percent fadeVolume:(BOOL)fadeVolume
{
    [self.player seekToPositionInPercent:percent fadeVolume:fadeVolume];
}

- (double)progress
{
    return self.player.progress;
}

- (double)progressPercent
{
    return self.player.progressPercent;
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
	DDLogError(@"[AudioEngine] received memory warning");
}

#pragma mark - Singleton methods

- (void)setup
{
#ifdef IOS
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
	
	AudioSessionInitialize(NULL, NULL, NULL, NULL);
    
    [[AVAudioSession sharedInstance] setDelegate:self];
	
	// Add the callbacks for headphone removal and other audio takeover
	AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, audioRouteChangeListenerCallback, NULL);
#pragma clang diagnostic pop
#endif
    
    _delegate = [PlayQueue sharedInstance];
    
    // Run async to prevent potential deadlock from dispatch_once
    [EX2Dispatch runInMainThreadAsync:^{
        [self startEmptyPlayer];
    }];
}

+ (instancetype)si
{
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
