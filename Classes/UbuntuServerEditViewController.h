//
//  UbuntuServerEditViewController.h
//  iSub
//
//  Created by Ben Baron on 1/15/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, DatabaseSingleton, ServerTypeViewController;

@interface UbuntuServerEditViewController : UIViewController 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	
	IBOutlet UITextField *usernameField;
	IBOutlet UITextField *passwordField;
	IBOutlet UIButton *cancelButton;
	IBOutlet UIButton *saveButton;
	
	ServerTypeViewController *parentController;
}

@property (assign) ServerTypeViewController *parentController;

- (IBAction) cancelButtonPressed:(id)sender;
- (IBAction) saveButtonPressed:(id)sender;

@end
