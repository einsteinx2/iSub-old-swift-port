//
//  UIView-tools.m
//  iSub
//
//  Created by Ben Baron on 12/22/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "UIView+tools.h"


@implementation UIView (tools)

- (CGFloat)x
{
	return self.frame.origin.x;
}

- (void)setX:(CGFloat)x
{
    if (!isfinite(x))
        return;
    
	CGRect newFrame = self.frame;
	newFrame.origin.x = x;
	self.frame = newFrame;
}

- (CGFloat)y
{
	return self.frame.origin.y;
}

- (void)setY:(CGFloat)y
{
    if (!isfinite(y))
        return;
    
	CGRect newFrame = self.frame;
	newFrame.origin.y = y;
	self.frame = newFrame;
}

- (CGPoint)origin
{
	return self.frame.origin;
}

- (void)setOrigin:(CGPoint)origin
{
	if (!isfinite(origin.x) || !isfinite(origin.y))
		return;
	
	CGRect newFrame = self.frame;
	newFrame.origin = origin;
	self.frame = newFrame;
}

- (CGFloat)width
{
	return self.frame.size.width;
}

- (void)setWidth:(CGFloat)width
{
    if (!isfinite(width))
        return;
    
	CGRect newFrame = self.frame;
	newFrame.size.width = width;
	self.frame = newFrame;
}

- (CGFloat)height
{
	return self.frame.size.height;
}

- (void)setHeight:(CGFloat)height
{
    if (!isfinite(height))
        return;
    
	CGRect newFrame = self.frame;
	newFrame.size.height = height;
	self.frame = newFrame;
}

- (CGSize)size
{
	return self.frame.size;
}

- (void)setSize:(CGSize)size
{
	if (!isfinite(size.width) || !isfinite(size.height))
		return;
	
	CGRect newFrame = self.frame;
	newFrame.size = size;
	self.frame = newFrame;
}

@end
