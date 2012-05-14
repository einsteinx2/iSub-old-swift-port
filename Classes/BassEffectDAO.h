//
//  BassEffectDAO.h
//  iSub
//
//  Created by Benjamin Baron on 12/4/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#define BassEffectTempCustomPresetId 1000000
#define BassEffectUserPresetStartId 1000

typedef enum 
{
	BassEffectType_ParametricEQ = 1
} BassEffectType;

@class BassEffectValue;
@interface BassEffectDAO : NSObject

@property BassEffectType type;
@property (strong) NSDictionary *presets;
@property NSUInteger selectedPresetId;

- (NSArray *)presetsArray;
- (NSArray *)userPresetsArray;
- (NSArray *)userPresetsArrayMinusCustom;
- (NSDictionary *)userPresets;
- (NSDictionary *)defaultPresets;
- (NSUInteger)userPresetsCount;
- (NSUInteger)defaultPresetsCount;
- (NSUInteger)selectedPresetIndex;
- (NSDictionary *)selectedPreset;
- (NSArray *)selectedPresetValues;

- (id)initWithType:(BassEffectType)effectType;
- (void)setup;

- (BassEffectValue *)valueForIndex:(NSInteger)index;
- (void)selectPresetId:(NSUInteger)presetId;
- (void)selectPresetAtIndex:(NSUInteger)presetIndex;
- (void)saveCustomPreset:(NSArray *)arrayOfPoints name:(NSString *)name presetId:(NSUInteger)presetId;
- (void)saveCustomPreset:(NSArray *)arrayOfPoints name:(NSString *)name;
- (void)saveTempCustomPreset:(NSArray *)arrayOfPoints;

- (void)deleteCustomPresetForId:(NSUInteger)presetId;
- (void)deleteCustomPresetForIndex:(NSUInteger)presetIndex;
- (void)deleteTempCustomPreset;

@end