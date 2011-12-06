//
//  BassEffectDAO.h
//  iSub
//
//  Created by Benjamin Baron on 12/4/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

typedef enum 
{
	BassEffectType_ParametricEQ = 1
} BassEffectType;

@class BassEffectValue;
@interface BassEffectDAO : NSObject
{
	NSUInteger selectedPresetIndex;
}

@property BassEffectType type;
@property (nonatomic, retain) NSArray *presets;

@property NSUInteger selectedPresetIndex;
@property (readonly) NSDictionary *selectedPreset;
@property (readonly) NSArray *selectedPresetValues;

- (id)initWithType:(BassEffectType)effectType;
- (void)setup;

- (BassEffectValue *)valueForIndex:(NSInteger)index;
- (void)selectPresetAtIndex:(NSUInteger)presetIndex;

@end