//
//  UbuntuServerEditViewController.h
//  iSub
//
//  Created by Ben Baron on 1/15/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//


@class ServerTypeViewController;

@interface UbuntuServerEditViewController : UIViewController 
{
	IBOutlet UITextField *usernameField;
	IBOutlet UITextField *passwordField;
	IBOutlet UIButton *cancelButton;
	IBOutlet UIButton *saveButton;	
}

@property (unsafe_unretained) ServerTypeViewController *parentController;

- (IBAction) cancelButtonPressed:(id)sender;
- (IBAction) saveButtonPressed:(id)sender;

@end
