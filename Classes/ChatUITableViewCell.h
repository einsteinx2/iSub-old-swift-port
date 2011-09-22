//
//  ChatUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <UIKit/UIKit.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

@class iSubAppDelegate;

@interface ChatUITableViewCell : UITableViewCell 
{
	iSubAppDelegate *appDelegate;
	
	UILabel *userNameLabel;
	UILabel *messageLabel;
}

@property (nonatomic, retain) UILabel *userNameLabel;
@property (nonatomic, retain) UILabel *messageLabel;

@end
