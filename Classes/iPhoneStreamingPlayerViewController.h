//
//  iPhoneStreamingPlayerViewController.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class iSubAppDelegate, MusicSingleton, DatabaseSingleton, PlaylistSingleton, ViewObjectsSingleton, CoverArtImageView, PageControlViewController, MPVolumeView, AudioEngine, PlaylistSingleton, OBSlider, Song;

@interface iPhoneStreamingPlayerViewController : UIViewController
{
	IBOutlet UIButton *playButton;
	IBOutlet UIButton *nextButton;
	IBOutlet UIButton *prevButton;
	IBOutlet UIButton *eqButton;
	IBOutlet UIView *volumeSlider;
	MPVolumeView *volumeView;
	UISlider *jukeboxVolumeView;
	IBOutlet CoverArtImageView *coverArtImageView;
	IBOutlet UIImageView *reflectionView;
	IBOutlet UIButton *songInfoToggleButton;
    IBOutlet UIActivityIndicatorView *activityIndicator;
	
	UILabel *artistLabel;
	UILabel *albumLabel;
	UILabel *titleLabel;
	
	UILabel *artistTitleLabel;
	UILabel *albumTitleLabel;
	UILabel *songTitleLabel;
	
	iSubAppDelegate *appDelegate;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	ViewObjectsSingleton *viewObjects;
	PlaylistSingleton *currentPlaylist;
	AudioEngine *audio;
	
	NSUInteger reflectionHeight;
	
	BOOL isFlipped;
	BOOL isExtraButtonsShowing;
	
	UIView *flipButtonView;
	
	PageControlViewController *pageControlViewController;
	
	uint64_t bookmarkBytePosition;
}

@property (nonatomic, retain) NSArray *listOfSongs;

@property (nonatomic, retain) IBOutlet UIView *extraButtons;
@property (nonatomic, retain) IBOutlet UIImageView *extraButtonsBackground;
@property (nonatomic, retain) IBOutlet UIButton *extraButtonsButton;

@property (nonatomic, retain) IBOutlet UIButton *currentAlbumButton;
@property (nonatomic, retain) IBOutlet UIButton *repeatButton;
@property (nonatomic, retain) IBOutlet UIButton *bookmarkButton;
@property (nonatomic, retain) IBOutlet UILabel *bookmarkCountLabel;
@property (nonatomic, retain) IBOutlet UIButton *shuffleButton;
@property (nonatomic, retain) IBOutlet OBSlider *progressSlider;
@property (nonatomic, retain) IBOutlet UILabel *progressLabel;
@property (nonatomic, retain) IBOutlet UIImageView *progressLabelBackground;
@property (nonatomic, retain) IBOutlet UILabel *elapsedTimeLabel;
@property (nonatomic, retain) IBOutlet UILabel *remainingTimeLabel;
@property (nonatomic, retain) UIView *downloadProgress;

@property (nonatomic, retain) NSTimer *updateTimer;
@property (nonatomic, retain) NSTimer *progressTimer;
@property (nonatomic) BOOL pauseSlider;
@property (nonatomic) BOOL hasMoved;
@property (nonatomic) float oldPosition;
@property (nonatomic) NSUInteger byteOffset;

@property (nonatomic, copy) Song *currentSong;

@property (nonatomic, retain) UITextField *bookmarkNameTextField;
@property (nonatomic, retain) NSArray *bookmarkEntry;
@property (nonatomic) NSInteger bookmarkIndex;
@property (nonatomic) int bookmarkPosition;

- (void)setPlayButtonImage;
- (void)setPauseButtonImage;
- (IBAction)songInfoToggle:(id)sender;
- (IBAction)playButtonPressed:(id)sender;
- (IBAction)prevButtonPressed:(id)sender;
- (IBAction)nextButtonPressed:(id)sender;
- (IBAction)currentAlbumPressed:(id)sender;

- (void)createSongTitle;
- (void)removeSongTitle;
- (void)setSongTitle;
- (IBAction)toggleExtraButtons:(id)sender;

- (IBAction)showEq:(id)sender;


- (IBAction)repeatButtonToggle:(id)sender;
- (IBAction)bookmarkButtonToggle:(id)sender;
- (IBAction)shuffleButtonToggle:(id)sender;
- (IBAction)touchedSlider:(id)sender;
- (IBAction)movingSlider:(id)sender;
- (IBAction)movedSlider:(id)sender;

- (IBAction)skipBack30:(id)sender;
- (IBAction)skipForward30:(id)sender;

- (void)updateDownloadProgress;
- (void)updateSlider;
- (void)updateShuffleIcon;


@end

