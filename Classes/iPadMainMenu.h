//
//  iPadMainMenu.h
//  iSub
//
//  Created by bbaron on 10/21/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class iSubAppDelegate;

@interface iPadMainMenu : UITableViewController 
{
	iSubAppDelegate *appDelegate;
	
	NSArray *rowNames;
	
	NSUInteger lastSelectedRow;
}

- (void)loadTable;
- (void)showSettings;

@end
