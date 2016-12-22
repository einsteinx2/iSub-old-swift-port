//
//  AudioEngine.h
//  iSub
//
//  Created by Ben Baron on 11/16/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#ifndef iSub_AudioEngine_h
#define iSub_AudioEngine_h

#import "bass.h"
#import "bass_fx.h"
#import "bassmix.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "BassWrapper.h"
#import "BassStream.h"
#import "BassEqualizer.h"
#import "BassVisualizer.h"
#import "BassGaplessPlayer.h"
#import <AVFoundation/AVFoundation.h>

#define audioEngineS ((AudioEngine *)[AudioEngine sharedInstance])

@class ISMSSong, BassParamEqValue, BassStream, SUSRegisterActionLoader, EX2RingBuffer;
@interface AudioEngine : NSObject <AVAudioSessionDelegate>

+ (nonnull instancetype)sharedInstance;

@property BOOL shouldResumeFromInterruption;

@property (readonly) BassEqualizer * _Nonnull equalizer;
@property (readonly) BassVisualizer * _Nonnull visualizer;
@property (strong) BassGaplessPlayer *_Nullable player;

@property NSUInteger startByteOffset;
@property NSUInteger startSecondsOffset;

@property (strong) id<BassGaplessPlayerDelegate> _Nonnull delegate;

// BASS methods
//
- (void)startSong:(nonnull ISMSSong *)song index:(NSInteger)index;
- (void)startSong:(nonnull ISMSSong *)song index:(NSInteger)index offsetInBytes:(NSInteger)bytesOffset;
- (void)startSong:(nonnull ISMSSong *)song index:(NSInteger)index offsetInSeconds:(NSInteger)secondsOffset;
- (void)startEmptyPlayer;

// Player control (no longer directly touch the BassGaplessPlayer from outside the audio engine
//
- (void)play;
- (void)pause;
- (void)playPause;
- (void)stop;
- (BOOL)isStarted;
- (BOOL)isPlaying;
- (void)seekToPositionInBytes:(QWORD)bytes fadeVolume:(BOOL)fadeVolume;
- (void)seekToPositionInSeconds:(double)seconds fadeVolume:(BOOL)fadeVolume;
- (double)progress;

@end

#endif
