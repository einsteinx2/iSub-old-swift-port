//
//  MoreTableViewDataSource.m
//  iSub
//
//  Created by Ben Baron on 12/22/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "MoreTableViewDataSource.h"

@implementation MoreTableViewDataSource

- (MoreTableViewDataSource *)initWithDataSource:(id<UITableViewDataSource>) dataSource
{
    _originalDataSource = dataSource;
    self = [super init];
	
    return self;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
    return [self.originalDataSource tableView:table numberOfRowsInSection:section];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.originalDataSource tableView:tableView cellForRowAtIndexPath:indexPath];
    cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
	//cell.textColor = [UIColor whiteColor];
    return cell;
}


@end
