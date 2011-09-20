//
//  DebugViewController.h
//  iSub
//
//  Created by Ben Baron on 4/9/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MusicSingleton, CacheSingleton, SavedSettings;

@interface DebugViewController : UIViewController 
{
	MusicSingleton *musicControls;
	CacheSingleton *cacheControls;
	SavedSettings *settings;
	
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
}

- (IBAction)songInfoToggle;
- (void) updateStats;

@end
