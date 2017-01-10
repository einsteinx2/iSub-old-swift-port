//
//  BassGaplessPlayer.h
//  Anghami
//
//  Created by Ben Baron on 6/29/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "bass.h"
#import "bass_fx.h"
#import "bassmix.h"
#import <AudioToolbox/AudioToolbox.h>
#import "BassWrapper.h"
#import "BassStream.h"
#import "BassEqualizer.h"
#import "BassVisualizer.h"
#import "BassGaplessPlayerDelegate.h"

@class EX2RingBuffer, SUSRegisterActionLoader;
@interface BassGaplessPlayer : NSObject

@property (weak) id<BassGaplessPlayerDelegate> delegate;

@property dispatch_queue_t streamGcdQueue;

// Ring Buffer
@property (strong) EX2RingBuffer *ringBuffer;
@property (strong) NSThread *ringBufferFillThread;

// BASS streams
@property (strong) NSMutableArray *streamQueue;
@property (readonly) BassStream *currentStream;
@property (copy) ISMSSong *previousSongForProgress;
@property (nonatomic) HSTREAM outStream;
@property (nonatomic) HSTREAM mixerStream;

@property BOOL isPlaying;
@property (readonly) BOOL isStarted;
@property (readonly) NSInteger bitRate;
@property (readonly) QWORD currentByteOffset;
@property (readonly) double progress;
@property (readonly) double progressPercent;
@property (strong) BassStream *waitLoopStream;
@property NSInteger startByteOffset;

@property (strong) BassEqualizer *equalizer;
@property (strong) BassVisualizer *visualizer;

@property NSInteger currentPlaylistIndex;
        
- (id)initWithDelegate:(id<BassGaplessPlayerDelegate>)theDelegate;

// BASS methods
//
- (DWORD)bassGetOutputData:(void *)buffer length:(DWORD)length;
- (void)startSong:(ISMSSong *)aSong atIndex:(NSInteger)index byteOffset:(NSInteger)byteOffset;

+ (NSInteger)bytesToBufferForKiloBitrate:(NSInteger)rate speedInBytesPerSec:(NSInteger)speedInBytesPerSec;

// Playback methods
//
- (void)stop;
- (void)play;
- (void)pause;
- (void)playPause;
- (void)seekToPositionInBytes:(QWORD)bytes fadeVolume:(BOOL)fadeVolume;
- (void)seekToPositionInSeconds:(double)seconds fadeVolume:(BOOL)fadeVolume;
- (void)seekToPositionInPercent:(double)percent fadeVolume:(BOOL)fadeVolume;

- (BOOL)testStreamForSong:(ISMSSong *)aSong;
- (BassStream *)prepareStreamForSong:(ISMSSong *)aSong;

@end
