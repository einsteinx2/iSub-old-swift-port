//
//  MenuViewController.h
//  StackScrollView
//
//  Created by Reefaq on 2/24/11.
//  Copyright 2011 raw engineering . All rights reserved.
//

#import <UIKit/UIKit.h> 

@class MenuHeaderView;

@interface MenuViewController : UIViewController <UITableViewDelegate, UITableViewDataSource> {
	UITableView*  _tableView;
	NSMutableArray* _cellContents;
	MenuHeaderView* _menuHeader;
}
- (id)initWithFrame:(CGRect)frame;

@property(nonatomic, retain)UITableView* tableView;

@end
