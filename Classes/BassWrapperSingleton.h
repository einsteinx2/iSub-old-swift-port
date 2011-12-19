//
//  BassWrapperSingleton.h
//  iSub
//
//  Created by Ben Baron on 11/16/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "bass.h"
#import "bassflac.h"
#import "bass_fx.h"
#import "bassmix.h"

#define ISMS_BASSBufferSize 1500

@class Song, BassParamEqValue, SUSCurrentPlaylistDAO;
@interface BassWrapperSingleton : NSObject

+ (BassWrapperSingleton *)sharedInstance;

// Playback methods
//
- (void)startWithOffsetInBytes:(NSNumber *)byteOffset;
- (void)seekToPositionInBytes:(QWORD)bytes inStream:(HSTREAM)stream;
- (void)seekToPositionInBytes:(QWORD)bytes;
- (void)seekToPositionInSeconds:(NSUInteger)seconds inStream:(HSTREAM)stream;
- (void)seekToPositionInSeconds:(NSUInteger)seconds;
- (void)start;
- (void)stop;
- (void)playPause;

// BASS methods
//
- (unsigned long long)preSilenceLengthForSong:(Song *)aSong;
- (void)bassInit;
- (BOOL)bassFree;
- (void)prepareNextSongStreamInBackground;
- (void)prepareNextSongStream;
- (void)clearEqualizer;
- (void)applyEqualizer:(NSArray *)values;
- (BOOL)toggleEqualizer;
- (void)updateEqParameter:(BassParamEqValue *)value;
- (BassParamEqValue *)addEqualizerValue:(BASS_DX8_PARAMEQ)value;
- (NSArray *)removeEqualizerValue:(BassParamEqValue *)value;
- (void)removeAllEqualizerValues;

- (void)readEqData;

@property (readonly) BOOL isPlaying;
@property (readonly) NSUInteger bitRate;
@property (readonly) QWORD currentByteOffset;
@property (readonly) double progress;
@property (readonly) BOOL isEqualizerOn;
@property (readonly) NSArray *equalizerValues;
@property QWORD startByteOffset;
@property BOOL isTempDownload;

@property (readonly) HSTREAM currentStream;
@property (readonly) HSTREAM nextStream;

@property (nonatomic, retain) SUSCurrentPlaylistDAO *currPlaylistDAO;

- (float)fftData:(NSUInteger)index;
- (short)lineSpecData:(NSUInteger)index;

const char *GetCTypeString(DWORD ctype, HPLUGIN plugin);

@end

typedef struct
{
	const char *localPath;
	FILE *file;
} ISMS_BASS_USERINFO;
