//
//  SnappySlider.m
//  snappyslider
//
//  Created by Aaron Brethorst on 3/13/11.
//  Copyright (c) 2011 Aaron Brethorst
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "SnappySlider.h"

@implementation SnappySlider
@synthesize detents, snapDistance;

- (id)initWithFrame:(CGRect)aFrame
{
	if ((self = [super initWithFrame:aFrame]))
	{
		rawDetents = NULL;
		detents = nil;
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if ((self = [super initWithCoder:aDecoder]))
	{
		rawDetents = NULL;
		detents = nil;
	}
	return self;
}

- (void)setDetents:(NSArray *)v
{
	if (detents == v)
	{
		return;
	}
	
	NSArray *newDetents = [[v sortedArrayUsingSelector:@selector(compare:)] copy];
	
	[detents release];
	detents = newDetents;
	
	if (nil != rawDetents)
	{
		free(rawDetents);
	}
	
	rawDetents = malloc(sizeof(CGFloat) * [detents count]);
	
	for (int i=0; i<[detents count]; i++)
	{
		rawDetents[i] = [[detents objectAtIndex:i] floatValue];
	}
}

- (void)setValue:(float)value animated:(BOOL)animated
{
	CGFloat bestDistance = CGFLOAT_MAX;
	CGFloat bestFit = CGFLOAT_MAX;
	
	for (int i = 0; i < [detents count]; i++)
	{
		CGFloat candidate = rawDetents[i];
		CGFloat candidateDistance = fabs(candidate - value);
		
		if (candidateDistance < bestDistance)
		{
			bestFit = candidate;
			bestDistance = candidateDistance;
		}
	}
	
	if (bestDistance <= snapDistance)
		[super setValue:bestFit animated:animated];
	else 
		[super setValue:value animated:animated];
}

- (void)dealloc
{
	self.detents = nil;
	free(rawDetents);
	[super dealloc];
}

@end
