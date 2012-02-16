//
//  SongInfoViewController.h
//  iSub
//
//  Created by Ben Baron on 3/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, DatabaseSingleton, OBSlider, Song, AudioEngine;

@interface SongInfoViewController : UIViewController
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
    AudioEngine *audio;

	NSTimer *bitrateTimer;
}

@property (copy) Song *currentSong;

@property (retain) IBOutlet UIButton *songInfoToggleButton;
@property (retain) IBOutlet UILabel *artistLabel;
@property (retain) IBOutlet UILabel *albumLabel;
@property (retain) IBOutlet UILabel *titleLabel;
@property (retain) IBOutlet UILabel *trackLabel;
@property (retain) IBOutlet UILabel *yearLabel;
@property (retain) IBOutlet UILabel *genreLabel;
@property (retain) IBOutlet UILabel *bitRateLabel;
@property (retain) IBOutlet UILabel *lengthLabel;

- (void)initInfo;
//- (void)showSongInfo;
//- (void)hideSongInfo;
//- (void)hideSongInfoFast;
- (IBAction)songInfoToggle;

@end
