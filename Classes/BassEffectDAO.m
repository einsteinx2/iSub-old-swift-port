//
//  BassEffectDAO.m
//  iSub
//
//  Created by Benjamin Baron on 12/4/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "BassEffectDAO.h"
#import "BassEffectValue.h"

@implementation BassEffectDAO
@synthesize type, presets, selectedPresetValues, currentValueIndex, currentPresetCount;

#pragma mark - Lifecycle

- (id)initWithType:(BassEffectType)effectType
{
	if ((self = [super init]))
	{
		type = effectType;
		[self setup];
	}
	
	return self;
}

- (void)setup
{
	NSString *key = [NSString stringWithFormat:@"BassEffectSelectedPresets", type];
	self.selectedPresetIndex = [[NSUserDefaults standardUserDefaults] integerForKey:key];
	
	key = [NSString stringWithFormat:@"BassEffectPresets%i", type];
	presets = [[[NSUserDefaults standardUserDefaults] arrayForKey:key] retain];
}

#pragma mark - Public DAO Methods

- (NSUInteger)selectedPresetIndex
{
	return selectedPresetIndex;
}

- (void)setSelectedPresetIndex:(NSUInteger)preset
{
	if (preset != selectedPresetIndex)
		currentValueIndex = -1;
	
	selectedPresetIndex = preset;
	NSString *key = [NSString stringWithFormat:@"BassEffectSelectedPreset%i", type];
	[[NSUserDefaults standardUserDefaults] setInteger:selectedPresetIndex forKey:key];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSArray *)selectedPresetValues
{
	if (self.selectedPresetIndex >= self.numberOfPresets)
		return nil;

	return [presets objectAtIndex:selectedPresetIndex];
}

- (BassEffectValue *)valueForIndex:(NSInteger)valueIndex
{
	if (valueIndex < 0)
		return nil;
	
	if (!self.selectedPresetValues)
		return nil;
	
	if (valueIndex >= [selectedPresetValues count])
		return nil;
	
	NSDictionary *valueDict = [selectedPresetValues objectAtIndex:valueIndex];
	
	BassEffectValue  *value = [[BassEffectValue alloc] init];
	value.type = self.type;
	value.percentX = [[valueDict objectForKey:@"percentX"] floatValue];
	value.percentY = [[valueDict objectForKey:@"percentY"] floatValue];
	value.isDefault = [[valueDict objectForKey:@"isDefault"] boolValue];
	
	return [value autorelease];
}

- (NSUInteger)numberOfPresets
{
	return [presets count];
}

/*NSUInteger currentIndex = 0;
- (BassEffectValue)nextValue
{
	if (self.count == 0)
		return nil;
	
	if (currentIndex < self.count)
	{
		// Return the current value
		BassEffectValue value = [self valueForIndex:currentIndex];
		currentIndex++;
		return value;
	}
	else
	{
		// Return nil to signify end of array
		currentIndex = 0;
		return nil;
	}
}*/

- (BOOL)next
{
	if (![selectedPresetValues count])
		return NO;
	
	if (currentValueIndex < [selectedPresetValues count])
	{
		// Return YES because there is a value
		currentValueIndex++;
		return YES;
	}
	else
	{
		// Return NO to signify end of array
		currentValueIndex = -1;
		return NO;
	}
}

- (BassEffectValue *)currentValue
{
	return [self valueForIndex:currentValueIndex];
}

@end
