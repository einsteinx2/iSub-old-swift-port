//
//  BassEffectValue.m
//  Anghami
//
//  Created by Benjamin Baron on 12/4/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "BassEffectValue.h"

@implementation BassEffectValue

@synthesize type, percentX, percentY, isDefault;

- (id)init
{
	if ((self = [super init]))
	{
		type = 0;
		percentX = 0.;
		percentY = 0.;
		isDefault = YES;
	}
	
	return self;
}

@end
