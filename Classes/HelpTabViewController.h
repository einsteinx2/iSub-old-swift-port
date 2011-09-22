//
//  HelpTabViewController.h
//  iSub
//
//  Created by Ben Baron on 6/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <UIKit/UIKit.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

@class iSubAppDelegate;

@interface HelpTabViewController : UIViewController 
{
	iSubAppDelegate *appDelegate;
	
	IBOutlet UIWebView *helpWebView;
}

@property (nonatomic, retain) UIWebView *helpWebView;

@end
