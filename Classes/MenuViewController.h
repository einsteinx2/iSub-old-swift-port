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

@property (retain) UITableView *tableView;
@property (retain) iPhoneStreamingPlayerViewController *playerController;
@property (retain) NSMutableArray *cellContents;
@property BOOL isFirstLoad;
@property NSUInteger lastSelectedRow;

- (id)initWithFrame:(CGRect)frame;
- (void)loadCellContents;
- (UIView *)createHeaderView:(BOOL)withImage;
- (UIView *)createFooterView;
- (void)showHome;

@end
