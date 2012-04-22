//
//  EqualizerValue.m
//  iSub
//
//  Created by Ben Baron on 11/19/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "BassParamEqValue.h"

@implementation BassParamEqValue
@synthesize parameters, handle, arrayIndex;

- (id)initWithParameters:(BASS_DX8_PARAMEQ)params handle:(HFX)theHandle arrayIndex:(NSUInteger)index
{
	if ((self = [super init]))
	{
		parameters = params;
		handle = theHandle;
		arrayIndex = index;
	}
	
	return self;
}

+ (BassParamEqValue *)valueWithParams:(BASS_DX8_PARAMEQ)params handle:(HFX)theHandle arrayIndex:(NSUInteger)index
{
	return [[BassParamEqValue alloc] initWithParameters:params handle:theHandle arrayIndex:index];
}

- (id)initWithParameters:(BASS_DX8_PARAMEQ)params
{
	return [self initWithParameters:params handle:0 arrayIndex:NSUIntegerMax];
}

+ (BassParamEqValue *)valueWithParams:(BASS_DX8_PARAMEQ)params
{
	return [[BassParamEqValue alloc] initWithParameters:params handle:0 arrayIndex:NSUIntegerMax];
}

- (id)initWithParameters:(BASS_DX8_PARAMEQ)params arrayIndex:(NSUInteger)index
{
	return [self initWithParameters:params handle:0 arrayIndex:index];
}

+ (BassParamEqValue *)valueWithParams:(BASS_DX8_PARAMEQ)params arrayIndex:(NSUInteger)index
{
	return [[BassParamEqValue alloc] initWithParameters:params handle:0 arrayIndex:index];
}

- (float)frequency
{
	return parameters.fCenter;
}

- (void)setFrequency:(float)frequency
{
	parameters.fCenter = frequency;
}

- (float)gain
{
	return parameters.fGain;
}

- (void)setGain:(float)gain
{
	parameters.fGain = gain;
}

- (float)bandwidth
{
	return parameters.fBandwidth;
}

- (void)setBandwidth:(float)bandwidth
{
	parameters.fBandwidth = bandwidth;
}

BASS_DX8_PARAMEQ BASS_DX8_PARAMEQMake(float center, float gain, float bandwidth)
{
	BASS_DX8_PARAMEQ p;
	p.fCenter = center;
	p.fGain = gain;
	p.fBandwidth = bandwidth;
	
	return p;
}

BASS_DX8_PARAMEQ BASS_DX8_PARAMEQFromPoint(float percentX, float percentY, float bandwidth)
{	
	BASS_DX8_PARAMEQ p;
	p.fCenter = exp2f((percentX * RANGE_OF_EXPONENTS) + 5);
	p.fGain = (.5 - percentY) * (CGFloat)(MAX_GAIN * 2);;
	p.fBandwidth = bandwidth;
	
	return p;
}

- (NSUInteger)hash
{
	return abs(parameters.fCenter) + abs(parameters.fGain) + abs(parameters.fBandwidth) + abs(handle);
}

- (BOOL)isEqualToBassParamEqValue:(BassParamEqValue *)otherValue
{
	if (self == otherValue)
        return YES;
	
	if (parameters.fCenter == otherValue.parameters.fCenter &&
		parameters.fGain == otherValue.parameters.fGain &&
		parameters.fBandwidth == otherValue.parameters.fBandwidth &&
		handle == otherValue.handle)
		return YES;
	
	return NO;
}

- (BOOL)isEqual:(id)other
{
	if (other == self)
        return YES;
	
    if (!other || ![other isKindOfClass:[self class]])
        return NO;
	
    return [self isEqualToBassParamEqValue:other];
}

@end
