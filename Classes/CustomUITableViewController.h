//
//  CustomUITableViewController.h
//  iSub
//
//  Created by Benjamin Baron on 10/9/13.
//  Copyright (c) 2013 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CustomUITableViewController : UITableViewController

#pragma mark - UI -

#pragma mark Navigation Items
- (void)setupLeftBarButton;
- (void)setupRightBarButton;

#pragma mark Pull to Refresh
- (BOOL)shouldSetupRefreshControl; // Override and return YES to use pull to refresh, otherwise implemented automatically
- (void)setupRefreshControl;
- (void)didPullToRefresh; // Override to perform an action after user pulls to refresh

#pragma mark - Actions -

- (void)settingsAction:(id)sender;
- (void)nowPlayingAction:(id)sender;

@end
