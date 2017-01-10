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

- (void)handleInterruption:(NSNotification *)notification
{
    NSNumber *interruptionType = notification.userInfo[AVAudioSessionInterruptionTypeKey];
    if (interruptionType.integerValue == AVAudioSessionInterruptionTypeBegan) {
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
    } else {
        NSNumber *interruptionOption = notification.userInfo[AVAudioSessionInterruptionOptionKey];
        BOOL shouldResume = interruptionOption.integerValue == AVAudioSessionInterruptionOptionShouldResume;
        
        DDLogVerbose(@"[AudioEngine] audio session interruption ended, isPlaying: %@   isMainThread: %@", NSStringFromBOOL(sharedInstance.player.isPlaying), NSStringFromBOOL([NSThread isMainThread]));
        if (self.shouldResumeFromInterruption && shouldResume)
        {
            [self.player playPause];
        }
        
        // Reset the shouldResumeFromInterruption value
        self.shouldResumeFromInterruption = NO;
    }
}

- (void)routeChanged:(NSNotification *)notification {
    DDLogInfo(@"[AudioEngine] audioRouteChangeListenerCallback called, isMainThread: %@", NSStringFromBOOL([NSThread isMainThread]));
    
    if (self.player.isPlaying)
    {
        NSNumber *routeChangeReason = notification.userInfo[AVAudioSessionRouteChangeReasonKey];
        if (routeChangeReason.integerValue == AVAudioSessionRouteChangeReasonOldDeviceUnavailable)
        {
            [self.player playPause];
        }
    }
}

- (void)startSong:(nonnull ISMSSong *)song index:(NSInteger)index
{
    [self startSong:song index:index byteOffset:0];
}

- (void)startSong:(ISMSSong *)song index:(NSInteger)index byteOffset:(NSInteger)bytes
{
	// Stop the player
	[self.player stop];
    
    // Start the new song
    [self.player startSong:song atIndex:index byteOffset:bytes];
    
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

#pragma mark - Singleton methods

- (void)setup
{
    [[AVAudioSession sharedInstance] setActive:YES error: nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(handleInterruption:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(routeChanged:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];

    _delegate = PlayQueue.si;
    [self startEmptyPlayer];
}

+ (instancetype)si
{
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
	});
    return sharedInstance;
}

@end
