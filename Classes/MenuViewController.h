//
//  MenuViewController.h
//  StackScrollView
//
//  Created by Reefaq on 2/24/11.
//  Copyright 2011 raw engineering . All rights reserved.
//

#import <UIKit/UIKit.h> 

@class iPhoneStreamingPlayerViewController;
@interface MenuViewController : UIViewController <UITableViewDelegate, UITableViewDataSource> 

@property (strong) UITableView *tableView;
@property (strong) UIView *playerHolder;
@property (strong) UINavigationController *playerNavController;
@property (strong) iPhoneStreamingPlayerViewController *playerController;
@property (strong) NSMutableArray *cellContents;
@property BOOL isFirstLoad;
@property NSUInteger lastSelectedRow;

- (id)initWithFrame:(CGRect)frame;
- (void)loadCellContents;
- (UIView *)createHeaderView:(BOOL)withImage;
- (UIView *)createFooterView;
- (void)showHome;
- (void)showSettings;

- (void)toggleOfflineMode;

@end
