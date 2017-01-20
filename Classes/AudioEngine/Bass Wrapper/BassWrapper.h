//
//  BassWrapper.h
//  Anghami
//
//  Created by Ben Baron on 6/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "bass.h"
#import "bass_ape.h"
#import "bass_fx.h"
#import "bass_mpc.h"
#import "bass_tta.h"
#import "bassdsd.h"
#import "bassflac.h"
#import "bassmix.h"
#import "bassopus.h"
#import "basswv.h"
#import <AudioToolbox/AudioToolbox.h>

@class BassStream;
@interface BassWrapper : NSObject

+ (NSInteger)bassOutputBufferLengthMillis;

+ (void)bassInit:(NSInteger)sampleRate;
+ (void)bassInit;

+ (void)logError;
+ (void)printChannelInfo:(HSTREAM)channel;
+ (NSString *)formatForChannel:(HCHANNEL)channel;
+ (NSString *)stringFromErrorCode:(NSInteger)errorCode;
+ (NSInteger)estimateBitrate:(BassStream *)bassStream;

+ (double)audioSessionSampleRate;
+ (BOOL)setAudioSessionSampleRate:(double)sampleRate;

@end
