//
//  BassEffectDAO.m
//  Anghami
//
//  Created by Benjamin Baron on 12/4/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "AudioEngine.h"
#import "BassEffectDAO.h"
#import "BassEffectValue.h"
#import "BassParamEqValue.h"
#import "NSArray+FirstObject.h"
#import "NSNotificationCenter+MainThread.h"
#import "SavedSettings.h"

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
	NSString *errorString = nil;  
	NSPropertyListFormat format;  
	id plist;  
	
	NSString *localizedPath = [[NSBundle mainBundle] pathForResource:fileName ofType:@"plist"];  
	plistData = [NSData dataWithContentsOfFile:localizedPath];   
	
	plist = [NSPropertyListSerialization propertyListFromData:plistData mutabilityOption:0 format:&format errorDescription:&errorString];
	if (!plist) 
	{  
		NSLog(@"Error reading plist from file '%@', error = '%@'", localizedPath, errorString);  
	}  
	
	return plist;  
}  

- (void)setup
{
	//DLog(@"default presets: %@", self.defaultPresets);
	//DLog(@"user presets: %@", self.userPresets);
	NSMutableDictionary *presetsDict = [NSMutableDictionary dictionaryWithCapacity:0];
	
	[presetsDict addEntriesFromDictionary:self.defaultPresets];
	NSDictionary *userPresets = self.userPresets;
	if (userPresets)
		[presetsDict addEntriesFromDictionary:userPresets];

	presets = [[NSDictionary alloc] initWithDictionary:presetsDict];
}

#pragma mark - Public DAO Methods

NSInteger presetSort(id preset1, id preset2, void *context)
{
    NSUInteger presetId1 = [[preset1 objectForKey:@"presetId"] intValue];
	NSUInteger presetId2 = [[preset2 objectForKey:@"presetId"] intValue];
	
    if (presetId1 < presetId2)
        return NSOrderedAscending;
    else if (presetId1 > presetId2)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
}

- (NSArray *)presetsArray
{
	NSMutableArray *presetsArray = [NSMutableArray arrayWithCapacity:0];
	for (NSString *key in [self.presets allKeys])
	{
		[presetsArray addObject:[self.presets objectForKey:key]];
	}
	
	return [presetsArray sortedArrayUsingFunction:presetSort context:NULL];
}

- (NSDictionary *)userPresets
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	return [[defaults objectForKey:@"BassEffectUserPresets"] objectForKey:[[NSNumber numberWithInt:type] stringValue]];
}

- (NSArray *)userPresetsArray
{
	NSMutableArray *presetsArray = [NSMutableArray arrayWithCapacity:0];
	NSDictionary *userPresets = self.userPresets;
	for (NSString *key in [userPresets allKeys])
	{
		[presetsArray addObject:[userPresets objectForKey:key]];
	}

	return [presetsArray sortedArrayUsingFunction:presetSort context:NULL];
}

- (NSArray *)userPresetsArrayMinusCustom
{
	NSMutableArray *presetsArray = [NSMutableArray arrayWithCapacity:0];
	NSDictionary *userPresets = self.userPresets;
		
	for (NSString *key in [userPresets allKeys])
	{
		if ([[[userPresets objectForKey:key] objectForKey:@"presetId"] intValue] != BassEffectTempCustomPresetId)
			[presetsArray addObject:[userPresets objectForKey:key]];
	}
	
	return [presetsArray count] ? [presetsArray sortedArrayUsingFunction:presetSort context:NULL] : nil;
}

- (NSDictionary *)defaultPresets
{
	// Load default presets
	return [[self readPlist:@"BassEffectDefaultPresets"] objectForKey:[[NSNumber numberWithInt:type] stringValue]];
}

- (NSUInteger)userPresetsCount
{
	if (self.userPresets)
		return [[self.userPresets allKeys] count]; 
	
	return 0;
}

- (NSUInteger)defaultPresetsCount
{
	if (self.defaultPresets)
		return [[self.defaultPresets allKeys] count];
	
	return 0;
}

- (NSUInteger)selectedPresetIndex
{
	return [self.presetsArray indexOfObject:self.selectedPreset];
}

- (NSUInteger)selectedPresetId
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	return [[[defaults objectForKey:@"BassEffectSelectedPresetId"] objectForKey:[[NSNumber numberWithInt:type] stringValue]] intValue];
}

- (void)setSelectedPresetId:(NSUInteger)preset
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *selectedPresetIds = [NSMutableDictionary dictionaryWithCapacity:0];
	if ([defaults objectForKey:@"BassEffectSelectedPresetId"])
		[selectedPresetIds addEntriesFromDictionary:[defaults objectForKey:@"BassEffectSelectedPresetId"]];
	
	[selectedPresetIds setObject:[NSNumber numberWithInt:preset] forKey:[[NSNumber numberWithInt:type] stringValue]];
	[defaults setObject:selectedPresetIds forKey:@"BassEffectSelectedPresetId"];
	[defaults synchronize];
}

- (NSDictionary *)selectedPreset
{
	return [self.presets objectForKey:[[NSNumber numberWithInt:self.selectedPresetId] stringValue]];
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
	
	CGPoint point = CGPointFromString([self.selectedPresetValues objectAtIndexSafe:valueIndex]);
	BassEffectValue  *value = [[BassEffectValue alloc] init];
	value.type = self.type;
	value.percentX = point.x;
	value.percentY = point.y;
	value.isDefault = [[self.selectedPreset objectForKey:@"isDefault"] boolValue];
	
	return value;
}

- (void)selectPresetId:(NSUInteger)presetId
{
	self.selectedPresetId = presetId;
		
	if (type == BassEffectType_ParametricEQ)
	{
		[audioEngineS.equalizer removeAllEqualizerValues];
		
		for (int i = 0; i < [self.selectedPresetValues count]; i++)
		{
			BassEffectValue *value = [self valueForIndex:i];
			[audioEngineS.equalizer addEqualizerValue:BASS_DX8_PARAMEQFromPoint(value.percentX, value.percentY, DEFAULT_BANDWIDTH)];
		}
		
		if (settingsS.isEqualizerOn)
			[audioEngineS.equalizer toggleEqualizer];
	}
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_BassEffectPresetLoaded];
}

- (void)selectPresetAtIndex:(NSUInteger)presetIndex
{
	if (presetIndex >= [self.presets count])
		return;
	
	self.selectedPresetId = [[[self.presetsArray objectAtIndexSafe:presetIndex] objectForKey:@"presetId"] intValue];
	
	[self selectPresetId:self.selectedPresetId];
}

- (void)deleteCustomPresetForId:(NSUInteger)presetId
{
	if (presetId == self.selectedPresetId)
		self.selectedPresetId = 0;
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *allUserPresets = [defaults objectForKey:[NSString stringWithFormat:@"BassEffectUserPresets"]];
	NSMutableDictionary *mutableAllUserPresets = [NSMutableDictionary dictionaryWithCapacity:0];
	if (allUserPresets)
		[mutableAllUserPresets addEntriesFromDictionary:allUserPresets];
	
	NSMutableDictionary *mutableUserPresets = [NSMutableDictionary dictionaryWithCapacity:0];
	if (self.userPresets)
		[mutableUserPresets addEntriesFromDictionary:self.userPresets];
	
	[mutableUserPresets removeObjectForKey:[[NSNumber numberWithInt:presetId] stringValue]];
	[mutableAllUserPresets setObject:mutableUserPresets forKey:[[NSNumber numberWithInt:type] stringValue]];
	[defaults setObject:mutableAllUserPresets forKey:@"BassEffectUserPresets"];
	[defaults synchronize];
	
	[self setup];
}

- (void)deleteCustomPresetForIndex:(NSUInteger)presetIndex
{
	NSUInteger presetId = [[[self.presetsArray objectAtIndexSafe:presetIndex] objectForKey:@"presetId"] intValue];
	[self deleteCustomPresetForId:presetId];
}

- (void)deleteTempCustomPreset
{
	[self deleteCustomPresetForId:BassEffectTempCustomPresetId];
}

- (void)saveCustomPreset:(NSArray *)arrayOfPoints name:(NSString *)name presetId:(NSUInteger)presetId	
{
	if (!name || !arrayOfPoints)
		return;
	
	self.selectedPresetId = presetId;
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *allUserPresets = [defaults objectForKey:[NSString stringWithFormat:@"BassEffectUserPresets"]];
	NSMutableDictionary *mutableAllUserPresets = [NSMutableDictionary dictionaryWithCapacity:0];
	if (allUserPresets)
		[mutableAllUserPresets addEntriesFromDictionary:allUserPresets];
	
	NSMutableDictionary *mutableUserPresets = [NSMutableDictionary dictionaryWithCapacity:0];
	if (self.userPresets)
		[mutableUserPresets addEntriesFromDictionary:self.userPresets];
	
	// Add new temp custom preset
	NSMutableDictionary *newPresetDict = [NSMutableDictionary dictionaryWithCapacity:0];
	[newPresetDict setObject:[NSNumber numberWithInt:presetId] forKey:@"presetId"];
	[newPresetDict setObject:name forKey:@"name"];
	[newPresetDict setObject:arrayOfPoints forKey:@"values"];
	[newPresetDict setObject:[NSNumber numberWithBool:NO] forKey:@"isDefault"];
	[mutableUserPresets setObject:newPresetDict forKey:[[NSNumber numberWithInt:presetId] stringValue]];
	[mutableAllUserPresets setObject:mutableUserPresets forKey:[[NSNumber numberWithInt:type] stringValue]];
	[defaults setObject:mutableAllUserPresets forKey:@"BassEffectUserPresets"];
	[defaults synchronize];
	
	[self setup];
}

- (void)saveCustomPreset:(NSArray *)arrayOfPoints name:(NSString *)name
{
	NSUInteger presetId = BassEffectUserPresetStartId;
	
	NSArray *userPresetsArrayMinusCustom = self.userPresetsArrayMinusCustom;
	if (userPresetsArrayMinusCustom)
	{
		presetId = [[[userPresetsArrayMinusCustom lastObject] objectForKey:@"presetId"] intValue] + 1;
	}
	
	[self saveCustomPreset:arrayOfPoints name:name presetId:presetId];
}

// Takes array of NSStrings containing CGPoints between 0.0 and 1.0
- (void)saveTempCustomPreset:(NSArray *)arrayOfPoints
{
	[self saveCustomPreset:arrayOfPoints name:@"Custom" presetId:BassEffectTempCustomPresetId];
}

@end
