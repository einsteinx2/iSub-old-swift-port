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

- (void)setupLeftBarButton;
- (void)setupRightBarButton;

#pragma mark - Actions -

- (void)nowPlayingAction:(id)sender;

@end
