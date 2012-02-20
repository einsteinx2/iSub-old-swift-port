//
//  EqualizerPathView.h
//  iSub
//
//  Created by Ben Baron on 1/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EqualizerPathView : UIView

@property CGPoint *points;
@property NSUInteger numberOfPoints;


@end

static void GetFirstControlPoints(double rhs[], double x[], int length);
static void GetCurveControlPoints(CGPoint knots[], int knotsLength, CGPoint firstControlPoints[], CGPoint secondControlPoints[]);