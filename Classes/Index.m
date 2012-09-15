//
//  Index.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "Index.h"

@implementation Index

- (id)init
{
	if ((self = [super init]))
	{
		_position = NSUIntegerMax;
		_count = NSUIntegerMax;
	}
	
	return self;
}

@end
