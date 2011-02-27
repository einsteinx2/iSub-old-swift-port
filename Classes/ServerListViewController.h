//
//  ServerListViewController.h
//  iSub
//
//  Created by Ben Baron on 3/31/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class iSubAppDelegate, ViewObjectsSingleton, MusicControlsSingleton, DatabaseControlsSingleton, SettingsTabViewController, HelpTabViewController;

@interface ServerListViewController : UITableViewController 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicControlsSingleton *musicControls;
	DatabaseControlsSingleton *databaseControls;
	
	BOOL isEditing;
	
	UIView *headerView;
	UISegmentedControl *segmentedControl;
	
	//SettingsTabViewController *settingsTabViewController;
	//HelpTabViewController *helpTabViewController;
}

- (void) addAction:(id)sender;
- (void) segmentAction:(id)sender;

@end
