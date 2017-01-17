//
//  BassVisualizer.h
//  Anghami
//
//  Created by Ben Baron on 6/29/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "bass.h"

typedef NS_ENUM(NSInteger, ISMSBassVisualType)
{
    ISMSBassVisualType_none      = 0,
    ISMSBassVisualType_line      = 1,
    ISMSBassVisualType_skinnyBar = 2,
    ISMSBassVisualType_fatBar    = 3,
    ISMSBassVisualType_aphexFace = 4,
    ISMSBassVisualType_maxValue  = 5
};

typedef NS_ENUM(NSInteger, BassVisualizerType)
{
	BassVisualizerTypeNone = 0,
	BassVisualizerTypeFFT,
	BassVisualizerTypeLine
};

@interface BassVisualizer : NSObject

@property BassVisualizerType type;
@property HSTREAM channel;

- (id)initWithChannel:(HCHANNEL)theChannel;

- (void)readAudioData;
- (short)lineSpecData:(NSInteger)index;
- (float)fftData:(NSInteger)index;

@end
