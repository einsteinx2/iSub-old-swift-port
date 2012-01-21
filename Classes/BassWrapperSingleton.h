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
#import <AudioToolbox/AudioToolbox.h>

#define ISMS_BASSBufferSizeForeground 200
#define ISMS_BASSBufferSizeBackground 1500

// Failure Retry Values
#define RETRY_DELAY 2.0
#define MIN_FILESIZE_TO_FAIL (1024 * 1024 * 3)

typedef enum
{
	ISMS_BASS_EQ_DATA_TYPE_none,
	ISMS_BASS_EQ_DATA_TYPE_fft,
	ISMS_BASS_EQ_DATA_TYPE_line
} ISMS_BASS_EQ_DATA_TYPE;

enum 
{
	kBufferSizeInFrames = 512,
	kNumBuffers = 4,
	kSampleRate = 44100,
};

@class Song, BassParamEqValue, SUSCurrentPlaylistDAO, BassUserInfo;
@interface BassWrapperSingleton : NSObject
{
	AudioStreamBasicDescription m_outFormat;
    AudioQueueRef m_outAQ;
    
    AudioQueueBufferRef m_buffers[kNumBuffers];
	BOOL m_isInitialised;
	
	
	// Equalizer variables
	NSMutableArray *eqValueArray, *eqHandleArray;
	float fftData[1024];
	short *lineSpecBuf;
	int lineSpecBufSize;
	HSTREAM fftStream;
	ISMS_BASS_EQ_DATA_TYPE eqDataType;
	
	
	// BASS stream variables
	BOOL BASSisFilestream1;
	HSTREAM fileStream1;
	HSTREAM fileStream2;
	HFX volumeFx;
}

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
- (void)bassInit:(NSUInteger)sampleRate;
- (void)bassInit;
- (BOOL)bassFree;
- (void)prepareNextSongStreamInBackground;
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
@property (retain) SUSCurrentPlaylistDAO *currPlaylistDAO;
@property (retain) NSThread *fftDataThread;
@property BOOL isFftDataThreadToTerminate;
@property BOOL isFastForward;

const char *GetCTypeString(DWORD ctype, HPLUGIN plugin);


- (void)readEqDataInternal;

- (void)stopReadingEqData;
- (void)startReadingEqData:(ISMS_BASS_EQ_DATA_TYPE)type;

@end