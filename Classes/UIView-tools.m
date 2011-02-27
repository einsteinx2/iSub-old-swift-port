//
//  UIView-tools.m
//  iSub
//
//  Created by Ben Baron on 12/22/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "UIView-tools.h"


@implementation UIView (tools)

- (void)addX:(float)x
{
	CGRect newFrame = self.frame;
	newFrame.origin.x += x;
	self.frame = newFrame;
}

- (void)addY:(float)y
{
	CGRect newFrame = self.frame;
	newFrame.origin.y += y;
	self.frame = newFrame;
}

- (void)addWidth:(float)width
{
	CGRect newFrame = self.frame;
	newFrame.size.width += width;
	self.frame = newFrame;
}

- (void)addHeight:(float)height
{
	CGRect newFrame = self.frame;
	newFrame.size.height += height;
	self.frame = newFrame;
}


- (void)newX:(float)x
{
	CGRect newFrame = self.frame;
	newFrame.origin.x = x;
	self.frame = newFrame;
}

- (void)newY:(float)y
{
	CGRect newFrame = self.frame;
	newFrame.origin.y = y;
	self.frame = newFrame;
}

- (void)newWidth:(float)width
{
	CGRect newFrame = self.frame;
	newFrame.size.width = width;
	self.frame = newFrame;
}

- (void)newHeight:(float)height
{
	CGRect newFrame = self.frame;
	newFrame.size.height = height;
	self.frame = newFrame;
}

@end
