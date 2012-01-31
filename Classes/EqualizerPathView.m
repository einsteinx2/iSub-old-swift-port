//
//  EqualizerPathView.m
//  iSub
//
//  Created by Ben Baron on 1/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "EqualizerPathView.h"
#import "UIBezierPath+Smoothing.h"
#import "BassParamEqValue.h"

@implementation EqualizerPathView

@synthesize path;

- (NSString *)stringFromFrequency:(NSUInteger)frequency
{
	if (frequency < 1000)
		return [NSString stringWithFormat:@"%i", frequency];

	return [NSString stringWithFormat:@"%ik", frequency/1000];
}

- (NSString *)stringFromGain:(CGFloat)gain
{	
	if ((int)gain == 0)
		return [NSString stringWithFormat:@"%.0fdB", gain];
	if (gain == (int)gain)
		return [NSString stringWithFormat:@"%.0f", gain];
	
	return [NSString stringWithFormat:@"%.1f", gain];
}

- (void)drawTextLabelAtPoint:(CGPoint)point withString:(NSString *)string
{	
	CGContextShowTextAtPoint(UIGraphicsGetCurrentContext(), 
							 point.x, 
							 point.y, 
							 [string cStringUsingEncoding:NSMacOSRomanStringEncoding], 
							 [string lengthOfBytesUsingEncoding:NSMacOSRomanStringEncoding]);
}

- (void)drawRect:(CGRect)rect 
{
	// Set the draw color
	[[UIColor colorWithWhite:1.0 alpha:0.5] setStroke];
	[[UIColor colorWithWhite:1.0 alpha:0.5] setFill];
	
	// Set font properties
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetTextMatrix(context, CGAffineTransformMake(1.0,0.0, 0.0, -1.0, 0.0, 0.0));
	CGContextSelectFont(context, "Arial", 10.0f, kCGEncodingMacRoman);
	CGContextSetTextDrawingMode(context, kCGTextFill);

	// Create freq ticks and labels
	CGFloat bottom = self.frame.size.height;
	CGFloat tickHeight = self.frame.size.height / 30.0;
	CGFloat tickGap = self.frame.size.width / RANGE_OF_EXPONENTS;
	UIBezierPath *bottomTicksPath = [UIBezierPath bezierPath];
	NSString *freqString = nil;
	for (int i = 0; i <= RANGE_OF_EXPONENTS; i++)
	{
		[bottomTicksPath moveToPoint:CGPointMake(i*tickGap, bottom)];
		[bottomTicksPath addLineToPoint:CGPointMake(i*tickGap, bottom - tickHeight)];
		
		freqString = [self stringFromFrequency:(MIN_FREQUENCY * (int)pow(2,i))];
		[self drawTextLabelAtPoint:CGPointMake(i*tickGap+2.0, bottom-2.0) withString:freqString];
	}
	freqString = [self stringFromFrequency:MIN_FREQUENCY * (int)pow(2,RANGE_OF_EXPONENTS)];
	[self drawTextLabelAtPoint:CGPointMake(RANGE_OF_EXPONENTS*tickGap-18.0, bottom-2.0) withString:freqString];
	bottomTicksPath.lineWidth = 1;
	[bottomTicksPath stroke];
	
	// Create the decibel ticks and labels
	UIBezierPath *leftTicksPath = [UIBezierPath bezierPath];
	CGFloat leftTickGap = self.frame.size.height / 4.0;
	CGFloat decibelGap = MAX_GAIN / 2.0;
	NSString *decibelString = nil;
	for (int i = 0; i <= 4; i++)
	{
		[leftTicksPath moveToPoint:CGPointMake(0.0, i*leftTickGap)];
		[leftTicksPath addLineToPoint:CGPointMake(tickHeight, i*leftTickGap)];
		
		decibelString = [self stringFromGain:MAX_GAIN - (decibelGap*i)];
		[self drawTextLabelAtPoint:CGPointMake(0.0, i*leftTickGap+10.0) withString:decibelString];
	}
	leftTicksPath.lineWidth = 1;
	[leftTicksPath stroke];
	
	// Smooth and draw the eq path
    UIBezierPath *smoothPath = [path smoothedPathWithGranularity:20];
	smoothPath.lineWidth = 2;
	[smoothPath stroke];
}

@end
