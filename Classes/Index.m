//
//  Index.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "Index.h"


@implementation Index

@synthesize name;

- (void) dealloc 
{
	[name release];
	[super dealloc];
}

@end
