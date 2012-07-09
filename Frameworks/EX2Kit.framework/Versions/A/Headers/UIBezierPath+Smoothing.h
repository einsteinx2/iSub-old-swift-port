//
//  UIBezierCurve+Smoothing.h
//  iSub
//
//  Created by Ben Baron on 1/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

@interface UIBezierPath (Smoothing)

- (UIBezierPath *)smoothedPathWithGranularity:(NSInteger)granularity;

@end
