//
//  PlayingViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SUSLoaderDelegate.h"

@class iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, DatabaseSingleton, SUSNowPlayingDAO;

@interface PlayingViewController : UITableViewController <SUSLoaderDelegate>
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	
	BOOL isNothingPlayingScreenShowing;
	UIImageView *nothingPlayingScreen;
	
	NSMutableData *receivedData;
}

@property (retain) UIImageView *nothingPlayingScreen;

@property (retain) SUSNowPlayingDAO *dataModel;

@end
