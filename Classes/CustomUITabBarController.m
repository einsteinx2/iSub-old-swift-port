//
//  CustomUITabBarController.m
//  iSub
//
//  Created by Ben Baron on 12/22/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITabBarController.h"
#import "MoreTableViewDataSource.h"
#import "ViewObjectsSingleton.h"

@implementation CustomUITabBarController

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
    UINavigationController *moreController = self.moreNavigationController;
    moreController.navigationBar.barStyle = UIBarStyleBlackOpaque;
	
    if ([moreController.topViewController.view isKindOfClass:[UITableView class]])
    {
        UITableView *tableView = (UITableView *)moreController.topViewController.view;
        tableView.backgroundColor = [UIColor clearColor];
		tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        moreTableViewDataSource = [[MoreTableViewDataSource alloc] initWithDataSource:tableView.dataSource];
        tableView.dataSource = moreTableViewDataSource;
		
		// Add the table fade
		UIImageView *fadeTop = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-top.png"]];
		fadeTop.frame =CGRectMake(0, -10, tableView.bounds.size.width, 10);
		fadeTop.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[tableView addSubview:fadeTop];
		[fadeTop release];
		
		UIImageView *fade = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]] autorelease];
		fade.frame = CGRectMake(0, 0, tableView.bounds.size.width, 10);
		fade.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		tableView.tableFooterView = fade;
    }
}


@end
