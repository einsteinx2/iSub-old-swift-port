//
//  DebugViewController.h
//  iSub
//
//  Created by Ben Baron on 4/9/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class iSubAppDelegate, MusicSingleton, DatabaseSingleton, ViewObjectsSingleton;

@interface DebugViewController : UIViewController 
{
	iSubAppDelegate *appDelegate;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	ViewObjectsSingleton *viewObjects;
	
	IBOutlet UIProgressView *currentSongProgressView;
	IBOutlet UILabel *nextSongLabel;
	IBOutlet UIProgressView *nextSongProgressView;
	
	IBOutlet UILabel *songsCachedLabel;
	IBOutlet UILabel *cacheSizeLabel;
	IBOutlet UILabel *cacheSettingLabel;
	IBOutlet UILabel *cacheSettingSizeLabel;
	IBOutlet UILabel *freeSpaceLabel;
	
	IBOutlet UIButton *songInfoToggleButton;
	
	NSTimer *updateTimer;
	NSTimer *updateTimer2;
}

- (IBAction)songInfoToggle;

- (void) updateStats;
- (void) updateStats2;


@end
