//
//  SongInfoViewController.h
//  iSub
//
//  Created by Ben Baron on 3/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, DatabaseSingleton, OBSlider, Song;

@interface SongInfoViewController : UIViewController
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
		
	UITextField *bookmarkNameTextField;
	NSArray *bookmarkEntry;
	NSInteger bookmarkIndex;

	NSTimer *progressTimer;
	NSTimer *bitrateTimer;
	BOOL pauseSlider;
	
	BOOL hasMoved;
	float oldPosition;
	NSUInteger byteOffset;
	
	NSTimer *updateTimer;
	
	int bookmarkPosition;
}

@property (nonatomic, copy) Song *currentSong;

@property (nonatomic, retain) IBOutlet UIButton *songInfoToggleButton;
@property (nonatomic, retain) IBOutlet OBSlider *progressSlider;
@property (nonatomic, retain) IBOutlet UILabel *progressLabel;
@property (nonatomic, retain) IBOutlet UIImageView *progressLabelBackground;
@property (nonatomic, retain) UIView *downloadProgress;
@property (nonatomic, retain) IBOutlet UILabel *elapsedTimeLabel;
@property (nonatomic, retain) IBOutlet UILabel *remainingTimeLabel;
@property (nonatomic, retain) IBOutlet UILabel *artistLabel;
@property (nonatomic, retain) IBOutlet UILabel *albumLabel;
@property (nonatomic, retain) IBOutlet UILabel *titleLabel;
@property (nonatomic, retain) IBOutlet UILabel *trackLabel;
@property (nonatomic, retain) IBOutlet UILabel *yearLabel;
@property (nonatomic, retain) IBOutlet UILabel *genreLabel;
@property (nonatomic, retain) IBOutlet UILabel *bitRateLabel;
@property (nonatomic, retain) IBOutlet UILabel *lengthLabel;
@property (nonatomic, retain) IBOutlet UIButton *repeatButton;
@property (nonatomic, retain) IBOutlet UIButton *bookmarkButton;
@property (nonatomic, retain) IBOutlet UILabel *bookmarkCountLabel;
@property (nonatomic, retain) IBOutlet UIButton *shuffleButton;

@property (nonatomic, retain) NSTimer *progressTimer;

- (void)initInfo;

- (void)updateDownloadProgress;
- (void)updateSlider;
//- (void)showSongInfo;
//- (void)hideSongInfo;
//- (void)hideSongInfoFast;
- (IBAction)songInfoToggle;
- (IBAction)repeatButtonToggle;
- (IBAction)bookmarkButtonToggle;
- (IBAction)shuffleButtonToggle;
- (IBAction)touchedSlider;
- (IBAction)movingSlider;
- (IBAction)movedSlider;

@end
