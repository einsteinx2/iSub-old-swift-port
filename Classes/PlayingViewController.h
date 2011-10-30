//
//  PlayingViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, DatabaseSingleton;

@interface PlayingViewController : UITableViewController 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	
	BOOL isNothingPlayingScreenShowing;
	UIImageView *nothingPlayingScreen;
	
	NSMutableData *receivedData;
}

@property (nonatomic, retain) UIImageView *nothingPlayingScreen;

@end
