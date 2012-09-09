//
//  SubsonicServerEditViewController.h
//  iSub
//
//  Created by Ben Baron on 3/3/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ISMSLoaderDelegate.h"

@class ServerTypeViewController, ServerListViewController;

@interface SubsonicServerEditViewController : UIViewController <ISMSLoaderDelegate>

@property (nonatomic, strong) IBOutlet UITextField *urlField;
@property (nonatomic, strong) IBOutlet UITextField *usernameField;
@property (nonatomic, strong) IBOutlet UITextField *passwordField;
@property (nonatomic, strong) IBOutlet UIButton *cancelButton;
@property (nonatomic, strong) IBOutlet UIButton *saveButton;
@property (nonatomic, unsafe_unretained) ServerTypeViewController *parentController;
@property (nonatomic, copy) NSString *theNewRedirectUrl;

- (IBAction) cancelButtonPressed:(id)sender;
- (IBAction) saveButtonPressed:(id)sender;

@end
