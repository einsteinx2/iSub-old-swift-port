//
//  ServerTypeViewController.h
//  iSub
//
//  Created by Ben Baron on 1/13/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

@interface ServerTypeViewController : UIViewController 
{
	IBOutlet UIButton *subsonicButton;
	IBOutlet UIButton *ubuntuButton;
	IBOutlet UIButton *cancelButton;
}

- (IBAction) buttonAction:(id)sender;

@end
