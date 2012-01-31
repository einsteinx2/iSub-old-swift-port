//
//  SeparaterView.m
//  iSub
//
//  Created by Ben Baron on 1/30/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SeparaterView.h"

@implementation SeparaterView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) 
	{
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.alpha = 0.7;
		self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
	//UIColor *darkGray =  [UIColor colorWithRed:255./186. green:255./191. blue:255./198. alpha:1.];
	UIColor *lightGray = [UIColor colorWithRed:255./226. green:255./231. blue:255./238. alpha:1.];
	
	[[UIColor grayColor] setStroke];
	UIBezierPath *topPath = [UIBezierPath bezierPath];
	[topPath moveToPoint:CGPointMake(0, 0)];
	[topPath addLineToPoint:CGPointMake(self.bounds.size.width, 0)];
	topPath.lineWidth = 1;
	[topPath stroke];
	
	[lightGray setStroke];
	UIBezierPath *bottomPath = [UIBezierPath bezierPath];
	[bottomPath moveToPoint:CGPointMake(0, 1)];
	[bottomPath addLineToPoint:CGPointMake(self.bounds.size.width, 1)];
	bottomPath.lineWidth = 1;
	[bottomPath stroke];
}


@end
