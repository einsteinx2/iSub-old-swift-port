//
//  MoreTableViewDataSource.m
//  iSub
//
//  Created by Ben Baron on 12/22/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "MoreTableViewDataSource.h"
#import "ViewObjectsSingleton.h"

@implementation MoreTableViewDataSource

@synthesize originalDataSource;

- (MoreTableViewDataSource *)initWithDataSource:(id<UITableViewDataSource>) dataSource
{
    originalDataSource = dataSource;
    [super init];
	
    return self;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
    return [originalDataSource tableView:table numberOfRowsInSection:section];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [originalDataSource tableView:tableView cellForRowAtIndexPath:indexPath];
    cell.backgroundView = [[ViewObjectsSingleton sharedInstance] createCellBackground:indexPath.row];
	//cell.textColor = [UIColor whiteColor];
    return cell;
}


@end
