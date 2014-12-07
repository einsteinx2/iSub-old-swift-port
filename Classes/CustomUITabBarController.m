//
//  CustomUITabBarController.m
//  iSub
//
//  Created by Benjamin Baron on 10/18/13.
//  Copyright (c) 2013 Ben Baron. All rights reserved.
//

#import "CustomUITabBarController.h"

@interface CustomUITabBarController ()

@end

@implementation CustomUITabBarController

- (BOOL)shouldAutorotate
{
    return [self shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)[UIDevice currentDevice].orientation];
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation
{
	if (settingsS.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

@end
