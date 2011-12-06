//
//  BassEffectDAO.m
//  iSub
//
//  Created by Benjamin Baron on 12/4/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "BassWrapperSingleton.h"
#import "BassEffectDAO.h"
#import "BassEffectValue.h"
#import "BassParamEqValue.h"
#import "NSArray+FirstObject.h"
#import "NSNotificationCenter+MainThread.h"

@implementation BassEffectDAO
@synthesize type, presets;

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

- (id)readPlist:(NSString *)fileName 
{  
	NSData *plistData = nil;  
	NSError *error = nil;  
	NSPropertyListFormat format;  
	id plist;  
	
	NSString *localizedPath = [[NSBundle mainBundle] pathForResource:fileName ofType:@"plist"];  
	plistData = [NSData dataWithContentsOfFile:localizedPath];   
	
	plist = [NSPropertyListSerialization propertyListWithData:plistData options:NSPropertyListImmutable format:&format error:&error];  
	if (!plist) {  
		NSLog(@"Error reading plist from file '%s', error = '%s'", [localizedPath UTF8String], [[error localizedDescription] UTF8String]);  
		[error release];  
	}  
	
	return plist;  
}  

- (void)setup
{
	selectedPresetIndex = 0;
	NSArray *defaultPresets = [self readPlist:@"BassEffectDefaultPresets"];
	presets = [[defaultPresets objectAtIndex:type] retain];
	
	//NSString *key = [NSString stringWithFormat:@"BassEffectSelectedPresets", type];
	//self.selectedPresetIndex = [[NSUserDefaults standardUserDefaults] integerForKey:key];
	
	//key = [NSString stringWithFormat:@"BassEffectPresets%i", type];
	//presets = [[[NSUserDefaults standardUserDefaults] arrayForKey:key] retain];
}

/*#pragma mark - Private data methods



- (void)setupBassEffectDefaults
{
	NSArray *defaultEffects = [self readPlist:@"BassEffectDefaultPresets"];
	
	for (int i = 0; i < [effects count]; i++)
	{
		NSString *key = [NSString stringWithFormat:@"BassEffectSelectedPreset%i", i];
		[userDefaults setObject:[NSNumber numberWithInt:0] forKey:key];
		
		
		
		key = [NSString stringWithFormat:@"BassEffectPresets%i", i];
		NSArray *presets = [effects objectAtIndex:i];
		[userDefaults setObject:presets forKey:key];
	}	
	
	[userDefaults synchronize];
}*/

#pragma mark - Public DAO Methods

- (NSUInteger)selectedPresetIndex
{
	return selectedPresetIndex;
}

- (void)setSelectedPresetIndex:(NSUInteger)preset
{
	selectedPresetIndex = preset;
	//NSString *key = [NSString stringWithFormat:@"BassEffectSelectedPreset%i", type];
	//[[NSUserDefaults standardUserDefaults] setInteger:selectedPresetIndex forKey:key];
	//[[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDictionary *)selectedPreset
{
	if (self.selectedPresetIndex >= [self.presets count])
		return nil;

	return [presets objectAtIndex:selectedPresetIndex];
}

- (NSArray *)selectedPresetValues
{
	return [self.selectedPreset objectForKey:@"values"];
}

- (BassEffectValue *)valueForIndex:(NSInteger)valueIndex
{
	if (valueIndex < 0)
		return nil;
	
	if (!self.selectedPresetValues)
		return nil;
	
	if (valueIndex >= [self.selectedPresetValues count])
		return nil;
	
	NSArray *valueArray = [self.selectedPresetValues objectAtIndex:valueIndex];
	
	BassEffectValue  *value = [[BassEffectValue alloc] init];
	value.type = self.type;
	value.percentX = [[valueArray firstObject] floatValue];
	value.percentY = [[valueArray lastObject] floatValue];
	value.isDefault = [[self.selectedPreset objectForKey:@"isDefault"] boolValue];
	
	return [value autorelease];
}

- (void)selectPresetAtIndex:(NSUInteger)presetIndex
{
	self.selectedPresetIndex = presetIndex;
	
	BassWrapperSingleton *wrapper = [BassWrapperSingleton sharedInstance];
	
	if (type == BassEffectType_ParametricEQ)
	{
		BOOL wasEqualizerOn = wrapper.isEqualizerOn;
		[wrapper removeAllEqualizerValues];

		for (int i = 0; i < [self.selectedPresetValues count]; i++)
		{
			BassEffectValue *value = [self valueForIndex:i];
			[wrapper addEqualizerValue:BASS_DX8_PARAMEQFromPoint(value.percentX, value.percentY, DEFAULT_BANDWIDTH)];
		}
				
		if (wasEqualizerOn)
			[wrapper toggleEqualizer];
	}
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_BassEffectPresetLoaded];
}

@end
