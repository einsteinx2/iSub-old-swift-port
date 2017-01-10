//
//  BassVisualizer.h
//  Anghami
//
//  Created by Ben Baron on 6/29/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "bass.h"

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
- (short)lineSpecData:(NSUInteger)index;
- (float)fftData:(NSUInteger)index;

@end
