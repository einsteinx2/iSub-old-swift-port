//
//  AudioEngine.h
//  iSub
//
//  Created by Ben Baron on 11/16/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "bass.h"
#import "bass_fx.h"
#import "bassmix.h"
#import <AudioToolbox/AudioToolbox.h>
#import "BassWrapper.h"
#import "BassStream.h"
#import "BassEqualizer.h"
#import "BassVisualizer.h"
#import "BassEncryptedGaplessPlayer.h"

#define audioEngineS ((AudioEngine *)[AudioEngine sharedInstance])

@class Song, BassParamEqValue, BassStream, GCDTimer, SUSRegisterActionLoader, EX2RingBuffer;
@interface AudioEngine : NSObject

+ (id)sharedInstance;

@property BOOL shouldResumeFromInterruption;

@property (readonly) BassEqualizer *equalizer;
@property (readonly) BassVisualizer *visualizer;
@property (strong) BassEncryptedGaplessPlayer *player;

@property NSUInteger startByteOffset;
@property NSUInteger startSecondsOffset;

// BASS methods
//
- (void)startWithOffsetInBytes:(NSNumber *)byteOffset orSeconds:(NSNumber *)seconds;
- (void)start;

@end
