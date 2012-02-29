//
//  AudioEngine.h
//  iSub
//
//  Created by Ben Baron on 11/16/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "bass.h"
#import "bassflac.h"
#import "bass_fx.h"
#import "bassmix.h"
#import <AudioToolbox/AudioToolbox.h>

#define audioEngineS [AudioEngine sharedInstance]

#define ISMS_BASSBufferSize 600
#define ISMS_defaultSampleRate 44100

// Stream create failure retry values
#define RETRY_DELAY 2.0
#define MIN_FILESIZE_TO_FAIL (1024 * 1024 * 3)

#define ISMS_NumSecondsToWaitForAudioData 5

typedef enum
{
	ISMS_BASS_EQ_DATA_TYPE_none,
	ISMS_BASS_EQ_DATA_TYPE_fft,
	ISMS_BASS_EQ_DATA_TYPE_line
} ISMS_BASS_EQ_DATA_TYPE;

@class Song, BassParamEqValue, BassUserInfo;
@interface AudioEngine : NSObject
{
	// Equalizer
	float fftData[1024];
	short *lineSpecBuf;
	int lineSpecBufSize;
}

+ (AudioEngine *)sharedInstance;

@property (retain) NSMutableArray *eqValueArray;
@property (retain) NSMutableArray *eqHandleArray;
@property ISMS_BASS_EQ_DATA_TYPE eqDataType;

// BASS streams
@property BOOL BASSisFilestream1;
@property HSTREAM fileStream1;
@property HSTREAM fileStreamTempo1;
@property HSTREAM fileStream2;
@property HSTREAM fileStreamTempo2;
@property HSTREAM outStream;
@property HFX volumeFx;

@property BOOL isPlaying;
@property (readonly) NSInteger bitRate;
@property (readonly) QWORD currentByteOffset;
@property (readonly) double progress;
@property (readonly) NSArray *equalizerValues;

@property BOOL isEqualizerOn;
@property unsigned long long startByteOffset;
@property double startSecondsOffset;
@property HSTREAM currentStream;
@property HSTREAM currentStreamTempo;
@property (readonly) HSTREAM currentReadingStream;
@property HSTREAM nextStream;
@property HSTREAM nextStreamTempo;
@property (readonly) HSTREAM nextReadingStream;
@property HSTREAM presilenceStream;
@property (retain) NSThread *fftDataThread;
@property BOOL isFftDataThreadToTerminate;
@property BOOL isFastForward;
@property NSInteger audioSessionSampleRate;
@property NSInteger bassReinitSampleRate;
@property NSUInteger bufferLengthMillis;
@property NSUInteger bassUpdatePeriod;
@property (retain) NSThread *startSongThread;

@property BOOL shouldResumeFromInterruption;

@property (retain) NSMutableDictionary *bassUserInfoDict;

@property (readonly) Song *currentStreamSong;
@property (readonly) NSString *currentStreamFormat;

@property (retain) NSObject *currentStreamSyncObject;
@property (retain) NSObject *eqReadSyncObject;

const char *GetCTypeString(DWORD ctype, HPLUGIN plugin);

// Playback methods
//
- (void)startWithOffsetInBytes:(NSNumber *)byteOffset orSeconds:(NSNumber *)seconds;
- (void)seekToPositionInBytes:(QWORD)bytes inStream:(HSTREAM)stream;
- (void)seekToPositionInBytes:(QWORD)bytes;
- (void)seekToPositionInSeconds:(double)seconds inStream:(HSTREAM)stream;
- (void)seekToPositionInSeconds:(double)seconds;
- (void)start;
- (void)stop;
- (void)pause;
- (void)playPause;

// BASS methods
//
- (unsigned long long)preSilenceLengthForSong:(Song *)aSong;
- (void)bassInit:(NSUInteger)sampleRate;
- (void)bassInit;
- (BOOL)bassFree;
- (void)prepareNextSongStream;
- (void)clearEqualizerValuesFromStream:(HSTREAM)stream;
- (void)clearEqualizerValues;
- (void)applyEqualizerValues:(NSArray *)values toStream:(HSTREAM)stream;
- (void)applyEqualizerValues:(NSArray *)values;
- (BOOL)toggleEqualizer;
- (void)updateEqParameter:(BassParamEqValue *)value;
- (BassParamEqValue *)addEqualizerValue:(BASS_DX8_PARAMEQ)value;
- (NSArray *)removeEqualizerValue:(BassParamEqValue *)value;
- (void)removeAllEqualizerValues;
- (void)readEqData;
- (float)fftData:(NSUInteger)index;
- (short)lineSpecData:(NSUInteger)index;
- (void)bassSetGainLevel:(float)gain;
- (uint32_t)bassGetOutputData:(void *)buffer length:(uint32_t)length;
- (NSInteger)bassSampleRate;
- (NSInteger)bassStreamSampleRate:(HSTREAM)stream;
- (NSInteger)preferredSampleRate:(NSUInteger)sampleRate;

- (void)readEqDataInternal;
- (void)stopReadingEqData;
- (void)startReadingEqData:(ISMS_BASS_EQ_DATA_TYPE)type;

- (BassUserInfo *)userInfoForStream:(HSTREAM)stream;
- (void)setUserInfo:(BassUserInfo *)userInfo forStream:(HSTREAM)stream;
- (void)removeUserInfoForStream:(HSTREAM)stream;

@end