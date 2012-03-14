//
//  ServerListViewController.h
//  iSub
//
//  Created by Ben Baron on 3/31/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SUSServerChecker.h"

@class SettingsTabViewController, HelpTabViewController;

@interface ServerListViewController : UITableViewController <SUSServerURLCheckerDelegate>
{
	BOOL isEditing;
	
	UIView *headerView;
	UISegmentedControl *segmentedControl;
	
	//SettingsTabViewController *settingsTabViewController;
	//HelpTabViewController *helpTabViewController;
}

- (void)addAction:(id)sender;
- (void)segmentAction:(id)sender;

@property (retain) NSString *theNewRedirectionUrl;

@property (retain) SettingsTabViewController *settingsTabViewController;
@property (retain) HelpTabViewController *helpTabViewController;

@end
