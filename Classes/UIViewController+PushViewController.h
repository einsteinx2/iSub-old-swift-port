//
//  UIViewController+PushViewController.h
//  iSub
//
//  Created by Ben Baron on 2/20/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

#define ISMSiPadViewWidth 448.

@interface UIViewController (PushViewController)

- (void)pushViewController:(UIViewController *)viewController;
- (void)pushViewControllerWithNavControllerOnIpad:(UIViewController *)viewController;

@end
