//
//  CustomUITabBarController.m
//  iSub
//
//  Created by Ben Baron on 12/22/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITabBarController.h"
#import "MoreTableViewDataSource.h"

@implementation CustomUITabBarController

- (BOOL)shouldAutorotate
{
    return [self shouldAutorotateToInterfaceOrientation:[UIDevice currentDevice].orientation];
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation
{
	if (settingsS.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

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
		
		[tableView addHeaderShadow];
		[tableView addFooterShadow];
    }
}


@end
