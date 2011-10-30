//
//  MoreTableViewDataSource.h
//  iSub
//
//  Created by Ben Baron on 12/22/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//




@interface MoreTableViewDataSource : NSObject <UITableViewDataSource>
{
    id<UITableViewDataSource> originalDataSource;
}

@property (retain) id<UITableViewDataSource> originalDataSource;

- (MoreTableViewDataSource *)initWithDataSource:(id<UITableViewDataSource>) dataSource;

@end

