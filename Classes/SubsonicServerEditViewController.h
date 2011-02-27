//
//  SubsonicServerEditViewController.h
//  iSub
//
//  Created by Ben Baron on 3/3/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class iSubAppDelegate, ViewObjectsSingleton, MusicControlsSingleton, DatabaseControlsSingleton, ServerTypeViewController;

@interface SubsonicServerEditViewController : UIViewController
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicControlsSingleton *musicControls;
	DatabaseControlsSingleton *databaseControls;
	
	IBOutlet UITextField *urlField;
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
