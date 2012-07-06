//
//  BassVisualizer.m
//  Anghami
//
//  Created by Ben Baron on 6/29/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "BassVisualizer.h"

@interface BassVisualizer()
{
	float *fftData;
	short *lineSpecBuf;
	int lineSpecBufSize;
}
@end

@implementation BassVisualizer
@synthesize channel, type;

- (id)init
{
	if ((self = [super init]))
	{		
		if (SCREEN_SCALE() == 1.0)// && !IS_IPAD())
			lineSpecBufSize = 256 * sizeof(short);
		else
			lineSpecBufSize = 512 * sizeof(short);
		lineSpecBuf = malloc(lineSpecBufSize);
		
		fftData = malloc(sizeof(float) * 1024);
	}
	return self;
}

- (id)initWithChannel:(HCHANNEL)theChannel
{
	if ((self = [self init]))
	{
		channel = theChannel;
	}
	return self;
}

- (void)dealloc
{
	free(lineSpecBuf);
	free(fftData);
}

- (float)fftData:(NSUInteger)index
{
	@synchronized(self)
	{
		return fftData[index];
	}
}

- (short)lineSpecData:(NSUInteger)index
{
	@synchronized(self)
	{
		return lineSpecBuf[index];
	}
}

- (void)readAudioData
{
	dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
	dispatch_async(queue, ^{
		@synchronized(self)
		{
			if (!channel)
				return;
			
			// Get the FFT data for visualizer
			if (self.type == BassVisualizerTypeFFT)
				BASS_ChannelGetData(self.channel, fftData, BASS_DATA_FFT2048);
			
			// Get the data for line spec visualizer
			if (self.type == BassVisualizerTypeLine)
				BASS_ChannelGetData(self.channel, lineSpecBuf, lineSpecBufSize);
		}
	});
}

@end
