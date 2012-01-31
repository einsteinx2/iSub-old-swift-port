//
//  UIApplication+StatusBar.m
//  iSub
//
//  Created by Ben Baron on 1/29/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "UIApplication+StatusBar.h"

@implementation UIApplication (StatusBar)

+ (void)setStatusBarHidden:(BOOL)hidden withAnimation:(BOOL)animation
{
	if ([[UIApplication sharedApplication] respondsToSelector:@selector(setStatusBarHidden:withAnimation:)]) 
	{
		[[UIApplication sharedApplication] setStatusBarHidden:hidden withAnimation:animation];
	} 
	else
	{ 
		// Deprecated in iOS 3.2+.
		id sharedApp = [UIApplication sharedApplication];  // Get around deprecation warnings.
		[sharedApp setStatusBarHidden:hidden animated:animation];
	}
}

@end
