//
//  PlayingViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class iSubAppDelegate, ViewObjectsSingleton, MusicControlsSingleton, DatabaseControlsSingleton;

@interface PlayingViewController : UITableViewController 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicControlsSingleton *musicControls;
	DatabaseControlsSingleton *databaseControls;
	
	BOOL isNothingPlayingScreenShowing;
	UIImageView *nothingPlayingScreen;
	
	NSMutableData *receivedData;
}

@property (nonatomic, retain) UIImageView *nothingPlayingScreen;

@end
