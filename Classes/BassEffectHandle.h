//
//  BassEffectHandle.h
//  iSub
//
//  Created by Ben Baron on 11/19/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "bass.h"

@interface BassEffectHandle : NSObject

@property HFX effectHandle;

- (id)initWithEffectHandle:(HFX)handle;
+ (BassEffectHandle *)handleWithEffectHandle:(HFX)handle;

@end
