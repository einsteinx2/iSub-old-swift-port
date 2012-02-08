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

@property (nonatomic, copy) Song *currentSong;

@property (nonatomic, retain) IBOutlet UIButton *songInfoToggleButton;
@property (nonatomic, retain) IBOutlet UILabel *artistLabel;
@property (nonatomic, retain) IBOutlet UILabel *albumLabel;
@property (nonatomic, retain) IBOutlet UILabel *titleLabel;
@property (nonatomic, retain) IBOutlet UILabel *trackLabel;
@property (nonatomic, retain) IBOutlet UILabel *yearLabel;
@property (nonatomic, retain) IBOutlet UILabel *genreLabel;
@property (nonatomic, retain) IBOutlet UILabel *bitRateLabel;
@property (nonatomic, retain) IBOutlet UILabel *lengthLabel;

- (void)initInfo;
//- (void)showSongInfo;
//- (void)hideSongInfo;
//- (void)hideSongInfoFast;
- (IBAction)songInfoToggle;

@end
