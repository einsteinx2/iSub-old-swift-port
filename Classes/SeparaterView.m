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
	
	CGContextRef context = UIGraphicsGetCurrentContext(); 
    CGContextSetStrokeColorWithColor(context, [UIColor grayColor].CGColor);
    CGContextSetLineWidth(context, 1);
    CGContextMoveToPoint(context, 0, 0);
    CGContextAddLineToPoint(context, self.bounds.size.width, 0);
    CGContextStrokePath(context);
	
	CGContextSetStrokeColorWithColor(context, lightGray.CGColor);
    CGContextSetLineWidth(context, 1);
    CGContextMoveToPoint(context, 0, 1);
    CGContextAddLineToPoint(context, self.bounds.size.width, 1);
    CGContextStrokePath(context);
}


@end
