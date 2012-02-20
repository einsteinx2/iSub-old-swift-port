//
//  EqualizerPathView.m
//  iSub
//
//  Created by Ben Baron on 1/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "EqualizerPathView.h"
//#import "UIBezierPath+Smoothing.h"
#import "BassParamEqValue.h"

static CGColorRef drawColor;

@implementation EqualizerPathView

@synthesize points, numberOfPoints;

+ (void)initialize
{
	UIColor *color = [[UIColor alloc] initWithWhite:1.0 alpha:0.5];
	drawColor = color.CGColor;
}

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
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextShowTextAtPoint(context, 
							 point.x, 
							 point.y, 
							 [string cStringUsingEncoding:NSMacOSRomanStringEncoding], 
							 [string lengthOfBytesUsingEncoding:NSMacOSRomanStringEncoding]);
}

- (void)drawTicksAndLabels
{	
	// Set font properties
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetTextMatrix(context, CGAffineTransformMake(1.0,0.0, 0.0, -1.0, 0.0, 0.0));
	CGContextSelectFont(context, "Arial", 10.0f, kCGEncodingMacRoman);
	CGContextSetTextDrawingMode(context, kCGTextFill);
	
	// Set drawing properties
    CGContextSetStrokeColorWithColor(context, drawColor);
	CGContextSetFillColorWithColor(context, drawColor);
    CGContextSetLineWidth(context, 1);
	
	// Create freq ticks and labels
	CGFloat bottom = self.frame.size.height;
	CGFloat tickHeight = self.frame.size.height / 30.0;
	CGFloat tickGap = self.frame.size.width / RANGE_OF_EXPONENTS;
	
	NSString *freqString = nil;
	for (int i = 0; i <= RANGE_OF_EXPONENTS; i++)
	{
		CGContextMoveToPoint(context, i*tickGap, bottom);
		CGContextAddLineToPoint(context, i*tickGap, bottom - tickHeight);
				
		freqString = [self stringFromFrequency:(MIN_FREQUENCY * (int)pow(2,i))];
		[self drawTextLabelAtPoint:CGPointMake(i*tickGap+2.0, bottom-2.0) withString:freqString];
	}
	freqString = [self stringFromFrequency:MIN_FREQUENCY * (int)pow(2,RANGE_OF_EXPONENTS)];
	[self drawTextLabelAtPoint:CGPointMake(RANGE_OF_EXPONENTS*tickGap-18.0, bottom-2.0) withString:freqString];
	
	// Create the decibel ticks and labels
	CGFloat leftTickGap = self.frame.size.height / 4.0;
	CGFloat decibelGap = MAX_GAIN / 2.0;
	NSString *decibelString = nil;
	for (int i = 0; i <= 4; i++)
	{
		CGContextMoveToPoint(context, 0.0, i*leftTickGap);
		CGContextAddLineToPoint(context, tickHeight, i*leftTickGap);
				
		decibelString = [self stringFromGain:MAX_GAIN - (decibelGap*i)];
		[self drawTextLabelAtPoint:CGPointMake(0.0, i*leftTickGap+10.0) withString:decibelString];
	}
	CGContextStrokePath(context);
}

- (void)drawCurve
{	
	return; 
	/*for (int i = 0; i < self.numberOfPoints; i++)
	{
		DLog(@"knot %i = %@", i, NSStringFromCGPoint(self.points[i]));
	}
	NSLog(@"    ");
	
	CGPoint firstControlPoints[self.numberOfPoints - 1];
	CGPoint secondControlPoints[self.numberOfPoints - 1];
	
	GetCurveControlPoints(self.points, self.numberOfPoints, firstControlPoints, secondControlPoints);
	
	for (int i = 0; i < self.numberOfPoints - 1; i++)
	{
		DLog(@"firstControlPoint %i = %@", i, NSStringFromCGPoint(firstControlPoints[i]));
	}
	NSLog(@"    ");
	
	for (int i = 0; i < self.numberOfPoints - 1; i++)
	{
		DLog(@"secondControlPoint %i = %@", i, NSStringFromCGPoint(secondControlPoints[i]));
	}
	NSLog(@"    ");*/
	
	CGPoint firstControlPoints[self.numberOfPoints - 1];
	CGPoint secondControlPoints[self.numberOfPoints - 1];
	
	GetCurveControlPoints(self.points, self.numberOfPoints, firstControlPoints, secondControlPoints);
	
	// Set drawing properties
	CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, drawColor);
	CGContextSetFillColorWithColor(context, drawColor);
    CGContextSetLineWidth(context, 2);
	
	CGContextMoveToPoint(context, self.points[0].x, self.points[0].y);
	
	for (int i = 1; i < self.numberOfPoints; i++)
	{
		DLog(@"knot %i = %@", i, NSStringFromCGPoint(self.points[i]));
		
		CGContextAddCurveToPoint (context,
								  firstControlPoints[i-1].x,
								  firstControlPoints[i-1].y,
								  secondControlPoints[i-1].x,
								  secondControlPoints[i-1].y,
								  self.points[i].x,
								  self.points[i].y
								  );
		//CGContextAddLineToPoint(context, self.points[i].x, self.points[i].y);
	}
	CGContextStrokePath(context);
}

- (void)drawRect:(CGRect)rect 
{
	// Draw the axis labels
	[self drawTicksAndLabels];
	
	// Smooth and draw the eq path
	[self drawCurve];
}

/////////////////////////////////

// ControlPoints arrays are knotsLength - 1 long
static void GetCurveControlPoints(CGPoint knots[], int knotsLength, CGPoint firstControlPoints[], CGPoint secondControlPoints[])
{
	if (knots == NULL)
		return;
	
	int n = knotsLength - 1;
	if (n < 1)
		return;
	
	if (n == 1)
	{ 
		// Special case: Bezier curve should be a straight line.
		// 3P1 = 2P0 + P3
		firstControlPoints[0].x = (2 * knots[0].x + knots[1].x) / 3;
		firstControlPoints[0].y = (2 * knots[0].y + knots[1].y) / 3;
		
		// P2 = 2P1 – P0
		secondControlPoints[0].x = 2 * firstControlPoints[0].x - knots[0].x;
		secondControlPoints[0].y = 2 * firstControlPoints[0].y - knots[0].y;
		return;
	}
	
	// Calculate first Bezier control points
	// Right hand side vector
	double rhs[n];
	
	// Set right hand side X values
	for (int i = 1; i < n - 1; ++i)
		rhs[i] = 4 * knots[i].x + 2 * knots[i + 1].x;
	rhs[0] = knots[0].x + 2 * knots[1].x;
	rhs[n - 1] = (8 * knots[n - 1].x + knots[n].x) / 2.0;
	// Get first control points X-values
	double x[n];
	GetFirstControlPoints(rhs, x, n);
	
	// Set right hand side Y values
	for (int i = 1; i < n - 1; ++i)
		rhs[i] = 4 * knots[i].y + 2 * knots[i + 1].y;
	rhs[0] = knots[0].y + 2 * knots[1].y;
	rhs[n - 1] = (8 * knots[n - 1].y + knots[n].y) / 2.0;
	// Get first control points Y-values
	double y[n];
	GetFirstControlPoints(rhs, y, n);
	
	// Fill output arrays.
	for (int i = 0; i < n; ++i)
	{
		// First control point
		firstControlPoints[i] = CGPointMake(x[i], y[i]);
		
		// Second control point
		if (i < n - 1)
			secondControlPoints[i] = CGPointMake(2 * knots[i + 1].x - x[i + 1], 2 * knots[i + 1].y - y[i + 1]);
		else
			secondControlPoints[i] = CGPointMake((knots[n].x + x[n - 1]) / 2, (knots[n].y + y[n - 1]) / 2);
	}
}

// Solves a tridiagonal system for one of coordinates (x or y) of first Bezier control points.
static void GetFirstControlPoints(double rhs[], double x[], int length)
{
	int n = length;
	//double x[n]; // Solution vector.
	double tmp[n]; // Temp workspace.
	
	double b = 2.0;
	x[0] = rhs[0] / b;
	for (int i = 1; i < n; i++) // Decomposition and forward substitution.
	{
		tmp[i] = 1 / b;
		b = (i < n - 1 ? 4.0 : 3.5) - tmp[i];
		x[i] = (rhs[i] - x[i - 1]) / b;
	}
	
	for (int i = 1; i < n; i++)
	{
		x[n - i - 1] -= tmp[n - i] * x[n - i]; // Backsubstitution.
	}
}

@end
