//
//  BassEffectDAO.h
//  Anghami
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
@property (unsafe_unretained, readonly) NSArray *presetsArray;
@property (strong) NSDictionary *presets;
@property (unsafe_unretained, readonly) NSArray *userPresetsArray;
@property (unsafe_unretained, readonly) NSArray *userPresetsArrayMinusCustom;
@property (unsafe_unretained, readonly) NSDictionary *userPresets;
@property (unsafe_unretained, readonly) NSDictionary *defaultPresets;

@property (readonly) NSUInteger userPresetsCount;
@property (readonly) NSUInteger defaultPresetsCount;

@property (readonly) NSUInteger selectedPresetIndex;
@property NSUInteger selectedPresetId;
@property (unsafe_unretained, readonly) NSDictionary *selectedPreset;
@property (unsafe_unretained, readonly) NSArray *selectedPresetValues;

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