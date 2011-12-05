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

/*typedef struct
{
	BassEffectType type;
	CGFloat percentX;
	CGFloat percentY;
	BOOL isDefault;
} BassEffectValue;*/

@class BassEffectValue;
@interface BassEffectDAO : NSObject
{
	NSUInteger selectedPresetIndex;
}

@property BassEffectType type;
@property (nonatomic, retain) NSArray *presets;
@property (readonly) NSUInteger numberOfPresets;

@property NSUInteger selectedPresetIndex;
@property (readonly) NSArray *selectedPresetValues;

@property (readonly) NSInteger currentValueIndex;
@property (readonly) NSUInteger currentPresetCount;

@property (readonly) BOOL next;
@property (readonly) BassEffectValue *currentValue;

- (id)initWithType:(BassEffectType)effectType;
- (void)setup;

- (BassEffectValue *)valueForIndex:(NSInteger)index;

@end