//
//  SubsonicServerEditViewController.h
//  iSub
//
//  Created by Ben Baron on 3/3/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SUSServerChecker.h"

@class ServerTypeViewController, ServerListViewController;

@interface SubsonicServerEditViewController : UIViewController <SUSServerURLCheckerDelegate>
{
	
	IBOutlet UITextField *urlField;
	IBOutlet UITextField *usernameField;
	IBOutlet UITextField *passwordField;
	IBOutlet UIButton *cancelButton;
	IBOutlet UIButton *saveButton;
		
	ServerTypeViewController *parentController;
}

@property (assign) ServerTypeViewController *parentController;
@property (retain) NSString *theNewRedirectUrl;

- (IBAction) cancelButtonPressed:(id)sender;
- (IBAction) saveButtonPressed:(id)sender;

@end
