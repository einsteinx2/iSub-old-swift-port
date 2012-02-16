//
//  ServerListViewController.h
//  iSub
//
//  Created by Ben Baron on 3/31/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SUSServerChecker.h"

@class iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, DatabaseSingleton, SettingsTabViewController, HelpTabViewController, SavedSettings;

@interface ServerListViewController : UITableViewController <SUSServerURLCheckerDelegate>
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	SavedSettings *settings;
	
	BOOL isEditing;
	
	UIView *headerView;
	UISegmentedControl *segmentedControl;
	
	//SettingsTabViewController *settingsTabViewController;
	//HelpTabViewController *helpTabViewController;
}

- (void)addAction:(id)sender;
- (void)segmentAction:(id)sender;

@property (retain) NSString *theNewRedirectionUrl;

@end
