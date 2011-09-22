//
//  IntroViewController.h
//  iSub
//
//  Created by Ben Baron on 1/27/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

//#import <UIKit/UIKit.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER


@interface IntroViewController : UIViewController 
{
	IBOutlet UIButton *introVideo;
	IBOutlet UIButton *testServer;
	IBOutlet UIButton *ownServer;
	
	IBOutlet UIImageView *sunkenLogo;
}

- (IBAction)buttonPress:(id)sender;

@end
