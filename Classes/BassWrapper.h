//
//  BassWrapper.h
//  Anghami
//
//  Created by Ben Baron on 6/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "bass.h"
#import "bass_fx.h"
#import "bassflac.h"
#import "basswv.h"
#import "bass_mpc.h"
#import "bass_ape.h"
#import "bassmix.h"
#include <AudioToolbox/AudioToolbox.h>
#import "BassStream.h"

@interface BassWrapper : NSObject

+ (void)logError;
+ (void)printChannelInfo:(HSTREAM)channel;
+ (NSString *)formatForChannel:(HCHANNEL)channel;
+ (NSString *)stringFromErrorCode:(NSInteger)errorCode;
+ (NSUInteger)estimateBitrate:(BassStream *)bassStream;
+ (NSInteger)audioSessionSampleRate;
+ (void)setAudioSessionSampleRate:(NSInteger)audioSessionSampleRate;

@end
