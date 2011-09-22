//
//  BWHockeySettingsViewController.h
//  HockeyDemo
//
//  Created by Andreas Linde on 3/8/11.
//  Copyright 2011 Buzzworks. All rights reserved.
//

//#import <UIKit/UIKit.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER
@class BWHockeyManager;


@interface BWHockeySettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource> {
    BWHockeyManager *hockeyManager_;
}

@property (nonatomic, retain) BWHockeyManager *hockeyManager;

- (id)init:(BWHockeyManager *)newHockeyManager;
- (id)init;

@end
