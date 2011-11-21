//
//  BassWrapperSingleton.h
//  iSub
//
//  Created by Ben Baron on 11/16/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "bass.h"

@class Song, BassParamEqValue;
@interface BassWrapperSingleton : NSObject

+ (BassWrapperSingleton *)sharedInstance;

// Playback methods
//
- (void)startWithOffsetInBytes:(NSUInteger)byteOffset;
- (void)seekToPositionInBytes:(NSUInteger)bytes;
//- (void)seekToPositionInSeconds:(NSUInteger)seconds;
- (void)start;
- (void)playPause;

// BASS methods
//
- (NSUInteger)preSilenceLengthForSong:(Song *)aSong;
- (BOOL)bassFree;
- (void)prepareNextSongStream;
- (void)clearEqualizer;
- (void)applyEqualizer:(NSArray *)values;
- (BOOL)toggleEqualizer;
- (void)updateEqParameter:(BassParamEqValue *)value;
- (BassParamEqValue *)addEqualizerValue:(BASS_DX8_PARAMEQ)value;
- (NSArray *)removeEqualizerValue:(BassParamEqValue *)value;

@property (readonly) BOOL isPlaying;
@property (readonly) NSUInteger bitRate;
@property (readonly) NSUInteger currentByteOffset;
@property (readonly) float progress;
@property (readonly) BOOL isEqualizerOn;
@property (readonly) NSArray *equalizerValues;

@property (readonly) HSTREAM currentStream;
@property (readonly) HSTREAM nextStream;

- (float)fftData:(NSUInteger)index;

@end
