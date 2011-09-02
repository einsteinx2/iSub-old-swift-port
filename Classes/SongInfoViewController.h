//
//  SongInfoViewController.h
//  iSub
//
//  Created by Ben Baron on 3/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, DatabaseSingleton, OBSlider;

@interface SongInfoViewController : UIViewController
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	
	IBOutlet UIButton *songInfoToggleButton;
	IBOutlet OBSlider *progressSlider;
	UIView *downloadProgress;
	IBOutlet UILabel *progressLabel;
	IBOutlet UIImageView *progressLabelBackground;
	IBOutlet UILabel *elapsedTimeLabel;
	IBOutlet UILabel *remainingTimeLabel;
	IBOutlet UILabel *artistLabel;
	IBOutlet UILabel *albumLabel;
	IBOutlet UILabel *titleLabel;
	IBOutlet UILabel *trackLabel;
	IBOutlet UILabel *yearLabel;
	IBOutlet UILabel *genreLabel;
	IBOutlet UILabel *bitRateLabel;
	IBOutlet UILabel *lengthLabel;
	IBOutlet UIButton *repeatButton;
	IBOutlet UIButton *bookmarkButton;
	IBOutlet UILabel *bookmarkCountLabel;
	IBOutlet UIButton *shuffleButton;
	
	UITextField *bookmarkNameTextField;
	NSArray *bookmarkEntry;
	NSInteger bookmarkIndex;

	NSTimer *progressTimer;
	BOOL pauseSlider;
	
	BOOL hasMoved;
	float oldPosition;
	float byteOffset;
	
	NSTimer *updateTimer;
	
	int bookmarkPosition;
}

@property (nonatomic, retain) OBSlider *progressSlider;
@property (nonatomic, retain) UIView *downloadProgress;
@property (nonatomic, retain) UILabel *elapsedTimeLabel;
@property (nonatomic, retain) UILabel *remainingTimeLabel;
@property (nonatomic, retain) UILabel *artistLabel;
@property (nonatomic, retain) UILabel *albumLabel;
@property (nonatomic, retain) UILabel *titleLabel;
@property (nonatomic, retain) UILabel *trackLabel;
@property (nonatomic, retain) UILabel *yearLabel;
@property (nonatomic, retain) UILabel *genreLabel;
@property (nonatomic, retain) UILabel *bitRateLabel;
@property (nonatomic, retain) UILabel *lengthLabel;
@property (nonatomic, retain) UIButton *repeatButton;
@property (nonatomic, retain) UIButton *bookmarkButton;
@property (nonatomic, retain) UIButton *shuffleButton;

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
