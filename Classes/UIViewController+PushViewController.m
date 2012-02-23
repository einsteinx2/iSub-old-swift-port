//
//  UIViewController+PushViewController.m
//  iSub
//
//  Created by Ben Baron on 2/20/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "UIViewController+PushViewController.h"
#import "iSubAppDelegate.h"
#import "iPadRootViewController.h"
#import "StackScrollViewController.h"
#import "UIView+Tools.h"

@implementation UIViewController (PushViewController)

- (void)pushViewController:(UIViewController *)viewController
{
	if (IS_IPAD())
	{
		viewController.view.width = ISMSiPadViewWidth;
		viewController.view.layer.cornerRadius = ISMSiPadCornerRadius;
		viewController.view.layer.masksToBounds = YES;
		StackScrollViewController *stack = [iSubAppDelegate sharedInstance].ipadRootViewController.stackScrollViewController;
		[stack addViewInSlider:viewController invokeByController:self isStackStartView:NO];
	}
	else
	{
		[self.navigationController pushViewController:viewController animated:YES];
	}
}

- (void)pushViewControllerWithNavControllerOnIpad:(UIViewController *)viewController
{
	if (IS_IPAD())
	{
		UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:viewController];
		nav.navigationBar.tintColor = [UIColor blackColor];
		
		viewController.view.width = ISMSiPadViewWidth;
		[self pushViewController:nav];
		[nav release];
	}
	else
	{
		[self pushViewController:viewController];
	}
}

@end
