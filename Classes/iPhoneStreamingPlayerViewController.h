//
//  iPhoneStreamingPlayerViewController.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "AsynchronousImageViewDelegate.h"

@class AsynchronousImageView, PageControlViewController, MPVolumeView, OBSlider, Song;

@interface iPhoneStreamingPlayerViewController : UIViewController <AsynchronousImageViewDelegate>

@property NSUInteger reflectionHeight;
@property BOOL isFlipped;
@property BOOL isExtraButtonsShowing;
@property (retain) PageControlViewController *pageControlViewController;
@property uint64_t bookmarkBytePosition;	

@property (retain) MPVolumeView *volumeView;
@property (retain) UISlider *jukeboxVolumeView;

@property (retain) UILabel *artistTitleLabel;
@property (retain) UILabel *albumTitleLabel;
@property (retain) UILabel *songTitleLabel;



@property (retain) IBOutlet UIButton *playButton;
@property (retain) IBOutlet UIButton *nextButton;
@property (retain) IBOutlet UIButton *prevButton;
@property (retain) IBOutlet UIButton *eqButton;
@property (retain) IBOutlet UIView *volumeSlider;
@property (retain) IBOutlet AsynchronousImageView *coverArtImageView;
@property (retain) IBOutlet UIImageView *reflectionView;
@property (retain) IBOutlet UIButton *songInfoToggleButton;
@property (retain) IBOutlet UIActivityIndicatorView *activityIndicator;



@property (retain) UILabel *artistLabel;
@property (retain) UILabel *albumLabel;
@property (retain) UILabel *titleLabel;




@property (retain) IBOutlet UIView *extraButtons;
@property (retain) IBOutlet UIImageView *extraButtonsBackground;
@property (retain) IBOutlet UIButton *extraButtonsButton;
@property (retain) IBOutlet UIView *songInfoView;

@property (retain) IBOutlet UILabel *sliderMultipleLabel;

@property (retain) IBOutlet UILabel *trackLabel;
@property (retain) IBOutlet UILabel *genreLabel;
@property (retain) IBOutlet UILabel *yearLabel;
@property (retain) IBOutlet UILabel *formatLabel;

@property (retain) UIImage *extraButtonsButtonOffImage;
@property (retain) UIImage *extraButtonsButtonOnImage;

@property (retain) IBOutlet UIView *coverArtHolderView;

@property (retain) IBOutlet UIButton *currentAlbumButton;
@property (retain) IBOutlet UIButton *repeatButton;
@property (retain) IBOutlet UIButton *bookmarkButton;
@property (retain) IBOutlet UILabel *bookmarkCountLabel;
@property (retain) IBOutlet UIButton *shuffleButton;
@property (retain) IBOutlet OBSlider *progressSlider;
@property (retain) IBOutlet UILabel *elapsedTimeLabel;
@property (retain) IBOutlet UILabel *remainingTimeLabel;
@property (retain) UIView *downloadProgress;

@property (retain) NSTimer *updateTimer;
@property (retain) NSTimer *progressTimer;
@property (nonatomic) BOOL pauseSlider;
@property (nonatomic) BOOL hasMoved;
@property (nonatomic) float oldPosition;
@property (nonatomic) NSUInteger byteOffset;

@property (copy) Song *currentSong;

@property (retain) UITextField *bookmarkNameTextField;
@property (retain) NSArray *bookmarkEntry;
@property (nonatomic) NSInteger bookmarkIndex;
@property (nonatomic) int bookmarkPosition;

@property (retain) IBOutlet UILabel *quickBackLabel;
@property (retain) IBOutlet UILabel *quickForwLabel;

@property (retain) UISwipeGestureRecognizer *swipeDetector;

@property NSUInteger lastProgress;

@property (retain) IBOutlet UIView *largeOverlayView;
@property (retain) IBOutlet UILabel *largeOverlayArtist;
@property (retain) IBOutlet UILabel *largeOverlaySong;
@property (retain) IBOutlet UILabel *largeOverlayAlbum;

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
- (void)extraButtonsToggleAnimated:(BOOL)animated saveState:(BOOL)saveState;

- (void)playlistToggleAnimated:(BOOL)animated saveState:(BOOL)saveState;

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

- (void)quickSecondsSetLabels;


@end

