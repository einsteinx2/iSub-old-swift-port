//
//  BassEqualizer.m
//  Anghami
//
//  Created by Ben Baron on 6/29/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "BassEqualizer.h"
#import "SavedSettings.h"
#import "DDLog.h"

#define ISMS_EqualizerGainReduction 0.35

@interface BassEqualizer()
@property (nonatomic, strong) NSMutableArray *eqHandles;
@property (nonatomic, strong) NSMutableArray *eqValues;
@property HFX volumeFx;
@end

static const int ddLogLevel = LOG_LEVEL_INFO;

@implementation BassEqualizer
@synthesize channel, volumeFx, eqHandles, eqValues, isEqActive, gain;

- (id)initWithChannel:(HCHANNEL)theChannel
{
	if ((self = [super init]))
	{
		channel = channel;
		eqValues = [[NSMutableArray alloc] initWithCapacity:4];
		eqHandles = [[NSMutableArray alloc] initWithCapacity:4];
	}
	return self;
}

- (HCHANNEL)channel
{
	return channel;
}

- (void)setChannel:(HCHANNEL)theChannel
{
	if (channel != theChannel)
	{
		// Remove any EQ points
		[self removeAllEqualizerValues];
		
		// Set the channel
		channel = theChannel;
	}

}

- (void)clearEqualizerValues
{
	int i = 0;
	for (NSNumber *handle in self.eqHandles)
	{
		BASS_ChannelRemoveFX(channel, handle.unsignedIntValue);
		i++;
	}
	
	for (BassParamEqValue *value in self.eqValues)
	{
		value.handle = 0;
	}
	
	//DLog(@"removed %i effect channels", i);
	[self.eqHandles removeAllObjects];
	isEqActive = NO;
}

- (void)applyEqualizerValues
{
	[self applyEqualizerValues:self.eqValues];
}

- (void)applyEqualizerValues:(NSArray *)values
{
	if (values == nil)
		return;
	else if ([values count] == 0)
		return;
	
	for (BassParamEqValue *value in self.eqValues)
	{
		HFX handle = BASS_ChannelSetFX(channel, BASS_FX_DX8_PARAMEQ, 0);
		BASS_DX8_PARAMEQ p = value.parameters;
		BASS_FXSetParameters(handle, &p);
		
		value.handle = handle;
		
		[self.eqHandles addObject:[NSNumber numberWithUnsignedInt:handle]];
	}
	isEqActive = YES;
}

- (void)updateEqParameter:(BassParamEqValue *)value
{
	[self.eqValues replaceObjectAtIndex:value.arrayIndex withObject:value]; 
	
	if (isEqActive)
	{
		BASS_DX8_PARAMEQ p = value.parameters;
		DDLogVerbose(@"updating eq for handle: %i   new freq: %f   new gain: %f", value.handle, p.fCenter, p.fGain);
		BASS_FXSetParameters(value.handle, &p);
	}
}

- (BassParamEqValue *)addEqualizerValue:(BASS_DX8_PARAMEQ)value
{
	NSUInteger index = [self.eqValues count];
	BassParamEqValue *eqValue = [BassParamEqValue valueWithParams:value arrayIndex:index];
	[self.eqValues addObject:eqValue];
	
	if (isEqActive)
	{
		HFX handle = BASS_ChannelSetFX(channel, BASS_FX_DX8_PARAMEQ, 0);
		BASS_FXSetParameters(handle, &value);
		eqValue.handle = handle;
		
		[self.eqHandles addObject:[NSNumber numberWithUnsignedInt:handle]];
	}
	
	return eqValue;
}

- (NSArray *)removeEqualizerValue:(BassParamEqValue *)value
{
	if (isEqActive)
	{
		// Disable the effect channel
		BASS_ChannelRemoveFX(channel, value.handle);
	}
	
	// Remove the handle
	[self.eqHandles removeObject:[NSNumber numberWithUnsignedInt:value.handle]];
	
	// Remove the value
	[self.eqValues removeObject:value];
	for (int i = value.arrayIndex; i < [self.eqValues count]; i++)
	{
		// Adjust the arrayIndex values for the other objects
		BassParamEqValue *aValue = [self.eqValues objectAtIndexSafe:i];
		aValue.arrayIndex = i;
	}
	
	return self.equalizerValues;
}

- (void)removeAllEqualizerValues
{
	[self clearEqualizerValues];
	
	[self.eqValues removeAllObjects];
	
	isEqActive = NO;
}

- (BOOL)toggleEqualizer
{
	if (isEqActive)
	{
		[self clearEqualizerValues];
		self.gain = settingsS.gainMultiplier;
		return NO;
	}
	else
	{
		[self applyEqualizerValues:self.eqValues];
		self.gain = settingsS.gainMultiplier;
		return YES;
	}
}

- (NSArray *)equalizerValues
{
	return [NSArray arrayWithArray:self.eqValues];
}

- (void)createVolumeFx
{
	if (self.volumeFx)
	{
		BASS_ChannelRemoveFX(channel, self.volumeFx);
	}
	
	self.volumeFx = BASS_ChannelSetFX(channel, BASS_FX_BFX_VOLUME, 1);
}

- (void)setGain:(float)theGain
{
	gain = theGain;
	
	CGFloat modifiedGainValue = self.isEqActive ? gain - ISMS_EqualizerGainReduction : gain;
	modifiedGainValue = modifiedGainValue < 0. ? 0. : modifiedGainValue;
	
	BASS_BFX_VOLUME volumeParamsInit = {0, modifiedGainValue};
	BASS_BFX_VOLUME *volumeParams = &volumeParamsInit;
	BASS_FXSetParameters(self.volumeFx, volumeParams);
}

- (float)gain
{
	return gain;
}

- (void)dealloc
{
	[self removeAllEqualizerValues];
}


@end
