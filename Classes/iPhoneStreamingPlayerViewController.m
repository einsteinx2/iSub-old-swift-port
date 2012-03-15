//
//  iPhoneStreamingPlayerViewController.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "iSubAppDelegate.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "ViewObjectsSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "PageControlViewController.h"
#import "AsynchronousImageView.h"
#import "Song.h"
#import <QuartzCore/CoreAnimation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <CFNetwork/CFNetwork.h>
#import "FMDatabaseAdditions.h"
#import "NSString+md5.h"
#import "UIView+Tools.h"
#import <QuartzCore/QuartzCore.h>
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "AudioEngine.h"
#import "EqualizerViewController.h"
#import "SUSCoverArtDAO.h"
#import "UIApplication+StatusBar.h"
#import "OBSlider.h"
#import "NSString+Additions.h"
#import "ISMSStreamManager.h"
#import "ISMSStreamHandler.h"
#import "NSArray+FirstObject.h"
#import "UIImageView+Reflection.h"
#import "NSArray+Additions.h"
#import "JukeboxSingleton.h"
#import "CALayer+ImageFromLayer.h"
#import "SavedSettings.h"

#define downloadProgressBorder 4.
#define downloadProgressWidth (progressSlider.frame.size.width - (downloadProgressBorder * 2))


@interface iPhoneStreamingPlayerViewController ()
@property (retain) UIImageView *reflectionView;
@property (retain) NSDictionary *originalViewFrames;
- (void)createReflection;
- (void)initSongInfo;
- (void)setStopButtonImage;
- (void)setPlayButtonImage;
- (void)setPauseButtonImage;
- (void)updateBarButtonImage;
- (void)registerForNotifications;
- (void)unregisterForNotifications;
- (void)createDownloadProgressView;
- (void)createLandscapeViews;
- (void)updateFormatLabel;
- (void)hideExtraButtons;
@end

@implementation iPhoneStreamingPlayerViewController

@synthesize listOfSongs, reflectionView, originalViewFrames, extraButtons, extraButtonsButton, extraButtonsBackground;
@synthesize bookmarkCountLabel, progressSlider, elapsedTimeLabel, remainingTimeLabel, shuffleButton, repeatButton, bookmarkButton, currentAlbumButton;
@synthesize updateTimer, progressTimer, hasMoved, oldPosition, byteOffset, currentSong, pauseSlider, downloadProgress, sliderMultipleLabel;
@synthesize bookmarkEntry, bookmarkIndex, bookmarkNameTextField, bookmarkPosition;
@synthesize coverArtHolderView, songInfoView, extraButtonsButtonOffImage, extraButtonsButtonOnImage;
@synthesize trackLabel, genreLabel, yearLabel, formatLabel;
@synthesize quickBackLabel, quickForwLabel;
@synthesize swipeDetector;
@synthesize lastProgress;

static const CGFloat kDefaultReflectionFraction = 0.30;
static const CGFloat kDefaultReflectionOpacity = 0.55;

#pragma mark -
#pragma mark Controller Life Cycle

- (NSString *)stringFromSeconds:(NSUInteger)seconds
{
	if (seconds < 60)
		return [NSString stringWithFormat:@"%is", seconds];
	else
		return [NSString stringWithFormat:@"%im", (seconds / 60)];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	DLog(@"coverArtImageView class: %@", NSStringFromClass(coverArtImageView.class));
	
	extraButtonsButtonOffImage = [[UIImage imageNamed:@"controller-extras.png"] retain];
	extraButtonsButtonOnImage = [[UIImage imageNamed:@"controller-extras-on.png"] retain];
	
	// Set default values
	pageControlViewController = nil;
	isFlipped = NO;
	isExtraButtonsShowing = NO;
	pauseSlider = NO;
	
	coverArtImageView.isLarge = YES;
	coverArtImageView.delegate = self;

	// Create the extra views not in the XIB file
	[self createDownloadProgressView];
	[self createLandscapeViews];
	
	// Setup the navigation controller buttons
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"player-overlay.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(songInfoToggle:)] autorelease];
	if (!IS_IPAD())
		self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"back.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(backAction:)] autorelease];
	
	// Initialize the song info
	[self initSongInfo];
	
	// Setup the volume controller view
	if (settingsS.isJukeboxEnabled)
	{
		[jukeboxS jukeboxGetInfo];
		
		self.view.backgroundColor = viewObjectsS.jukeboxColor;
		
		CGRect frame = volumeSlider.bounds;
		frame.size.height = volumeSlider.bounds.size.height / 2;
		jukeboxVolumeView = [[[UISlider alloc] initWithFrame:frame] autorelease];
		[jukeboxVolumeView addTarget:self action:@selector(jukeboxVolumeChanged:) forControlEvents:UIControlEventValueChanged];
		jukeboxVolumeView.minimumValue = 0.0;
		jukeboxVolumeView.maximumValue = 1.0;
		jukeboxVolumeView.continuous = NO;
		jukeboxVolumeView.value = jukeboxS.jukeboxGain;
		[volumeSlider addSubview:jukeboxVolumeView];
	}
	else
	{
		volumeView = [[[MPVolumeView alloc] initWithFrame:volumeSlider.bounds] autorelease];
		[volumeSlider addSubview:volumeView];
		[volumeView sizeToFit];
	}
	
	// Setup the cover art reflection
	reflectionHeight = coverArtImageView.bounds.size.height * kDefaultReflectionFraction;
	reflectionView.height = reflectionHeight;
	reflectionView.image = [coverArtImageView reflectedImageWithHeight:reflectionHeight];
	reflectionView.alpha = kDefaultReflectionOpacity;
	if (isFlipped)
		reflectionView.alpha = 0.0;
    [activityIndicator stopAnimating];
	
	// Register for all notifications
	[self registerForNotifications];
	
	[self extraButtonsToggleAnimated:NO saveState:NO];
	if (!settingsS.isExtraPlayerControlsShowing)
		[self performSelector:@selector(hideExtraButtons) withObject:nil afterDelay:4.0];
	
	// Show the song info screen automatically if the setting is enabled
	if (settingsS.isPlayerPlaylistShowing)
	{
		[self playlistToggleAnimated:NO saveState:NO];
	}
	
	coverArtHolderView.layer.masksToBounds = YES;
	
	if (IS_IPAD())
	{
		// Fix some positions
		eqButton.y -= 10;
		prevButton.y -= 10;
		playButton.y -= 10;
		nextButton.y -= 10;
		extraButtonsButton.y -= 10;
		volumeSlider.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin;
		volumeSlider.y += 5;
	}
	
	// Only add the gesture recognizer on iOS 3.2 and above where it is supported
	if (NSClassFromString(@"UISwipeGestureRecognizer"))
	{
		swipeDetector = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(songInfoToggle:)];
		if ([swipeDetector respondsToSelector:@selector(locationInView:)]) 
		{
			swipeDetector.direction = UISwipeGestureRecognizerDirectionLeft;
			[songInfoToggleButton addGestureRecognizer:swipeDetector];
		}
		else
		{
			[swipeDetector release]; swipeDetector = nil;
		}
	}
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	if (settingsS.isJukeboxEnabled)
	{
		[jukeboxS jukeboxGetInfo];
		
		self.view.backgroundColor = viewObjectsS.jukeboxColor;
	}
	else 
	{
		self.view.backgroundColor = [UIColor blackColor]; 
	}
	
	if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
	{
		[self createSongTitle];
	}
	
	/*if (!IS_IPAD())
	{
		if (animated)
		{
			[UIApplication setStatusBarHidden:YES withAnimation:YES];
			[UIView beginAnimations:nil context:nil];
			[UIView setAnimationDuration:0.3];
		}
		
		self.navigationController.navigationBar.y = 0;
			 
		if (animated)
			 [UIView commitAnimations];
	}*/
	
	[self updateDownloadProgress];
	[self updateSlider];
	
	if (settingsS.isJukeboxEnabled)
	{
		[jukeboxS jukeboxGetInfo];
		
		if (jukeboxS.jukeboxIsPlaying)
			[self setStopButtonImage];
		else 
			[self setPlayButtonImage];
	}
	else
	{
		if(audioEngineS.isPlaying)
			[self setPauseButtonImage];
		else
			[self setPlayButtonImage];
	}
	
	NSString *imageName = audioEngineS.isEqualizerOn ? @"controller-equalizer-on.png" : @"controller-equalizer.png";
	[eqButton setImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
	
	[self quickSecondsSetLabels];
}

- (void)quickSecondsSetLabels
{
	NSString *quickSeconds = [self stringFromSeconds:settingsS.quickSkipNumberOfSeconds];
	quickBackLabel.text = quickSeconds;
	quickForwLabel.text = quickSeconds;
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	/*if (!IS_IPAD())
	{
		//[self.navigationController setWantsFullScreenLayout:NO];
		[UIApplication setStatusBarHidden:NO withAnimation:YES];
		self.navigationController.navigationBar.y = 20;
	}*/
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	if (!settingsS.isExtraPlayerControlsShowing)
	{
		if (isExtraButtonsShowing)
			[self extraButtonsToggleAnimated:NO saveState:NO];
	}
}

- (void)asyncImageViewFinishedLoading:(AsynchronousImageView *)asyncImageView
{
	[self createReflection];
}

- (void)registerForNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setPlayButtonImage) 
												 name:ISMSNotification_SongPlaybackEnded object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setPlayButtonImage) 
												 name:ISMSNotification_SongPlaybackPaused object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setPauseButtonImage) 
												 name:ISMSNotification_SongPlaybackStarted object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initSongInfo) 
												 name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initSongInfo) 
												 name:ISMSNotification_ServerSwitched object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initSongInfo) 
												 name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateShuffleIcon) 
												 name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(songInfoToggle:) 
												 name:@"hideSongInfo" object:nil];
	
	if (IS_IPAD())
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showPlayerOverlayTemp) 
													 name:ISMSNotification_ShowPlayer object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initSongInfo) 
													 name:ISMSNotification_ShowPlayer object:nil];
	}
}

- (void)unregisterForNotifications
{
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:ISMSNotification_SongPlaybackEnded object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:ISMSNotification_SongPlaybackPaused object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:ISMSNotification_SongPlaybackStarted object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:ISMSNotification_ServerSwitched object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self 
													name:@"hideSongInfo" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	
	if (IS_IPAD())
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self 
														name:ISMSNotification_ShowPlayer object:nil];
	}	
}

- (void)createDownloadProgressView
{
	downloadProgress = [[UIView alloc] initWithFrame:progressSlider.frame];
	downloadProgress.x = 0.0;
	downloadProgress.y = 0.0;
	downloadProgress.backgroundColor = [UIColor whiteColor];
	downloadProgress.alpha = 0.3;
	downloadProgress.userInteractionEnabled = NO;
	downloadProgress.width = 0.0;
	downloadProgress.layer.cornerRadius = 5;
	[progressSlider addSubview:downloadProgress];
	[downloadProgress release];
	
	if (settingsS.isJukeboxEnabled)
		downloadProgress.hidden = YES;
}

- (void)createLandscapeViews
{
	// Setup landscape orientation if necessary
	if (!IS_IPAD())
	{
		artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(305, 60, 170, 30)];
		artistLabel.backgroundColor = [UIColor clearColor];
		artistLabel.textColor = [UIColor whiteColor];
		artistLabel.font = [UIFont boldSystemFontOfSize:24];
		artistLabel.adjustsFontSizeToFitWidth = YES;
		artistLabel.textAlignment = UITextAlignmentCenter;
		[self.view addSubview:artistLabel];
		[self.view sendSubviewToBack:artistLabel];
		[artistLabel release];
		
		albumLabel = [[UILabel alloc] initWithFrame:CGRectMake(305, 90, 170, 30)];
		albumLabel.backgroundColor = [UIColor clearColor];
		albumLabel.textColor = [UIColor whiteColor];
		albumLabel.font = [UIFont systemFontOfSize:24];
		albumLabel.adjustsFontSizeToFitWidth = YES;
		albumLabel.textAlignment = UITextAlignmentCenter;
		[self.view addSubview:albumLabel];
		[self.view sendSubviewToBack:albumLabel];
		[albumLabel release];
		
		titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(305, 120, 170, 30)];
		titleLabel.backgroundColor = [UIColor clearColor];
		titleLabel.textColor = [UIColor whiteColor];
		titleLabel.font = [UIFont boldSystemFontOfSize:24];
		titleLabel.adjustsFontSizeToFitWidth = YES;
		titleLabel.textAlignment = UITextAlignmentCenter;
		[self.view addSubview:titleLabel];
		[self.view sendSubviewToBack:titleLabel];
		[titleLabel	release];
		
		NSMutableDictionary *positions = [NSMutableDictionary dictionaryWithCapacity:0];
		[positions setObject:[NSValue valueWithCGRect:volumeSlider.frame] forKey:@"volumeSlider"];
		[positions setObject:[NSValue valueWithCGRect:coverArtHolderView.frame] forKey:@"coverArtHolderView"];
		[positions setObject:[NSValue valueWithCGRect:prevButton.frame] forKey:@"prevButton"];
		[positions setObject:[NSValue valueWithCGRect:playButton.frame] forKey:@"playButton"];
		[positions setObject:[NSValue valueWithCGRect:nextButton.frame] forKey:@"nextButton"];
		[positions setObject:[NSValue valueWithCGRect:eqButton.frame] forKey:@"eqButton"];
		self.originalViewFrames = [NSDictionary dictionaryWithDictionary:positions];
		
		if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
		{
			coverArtHolderView.frame = CGRectMake(0, 0, 300, 270);
			prevButton.origin = CGPointMake(315, 184);
			playButton.origin = CGPointMake(372.5, 184);
			nextButton.origin = CGPointMake(425, 184);
			volumeSlider.frame = CGRectMake(300, 244, 180, 55);
			volumeView.frame = CGRectMake(0, 0, 180, 55);
			eqButton.origin = CGPointMake(372.5, 20);
		}
		else
		{
			artistLabel.alpha = 0.1;
			albumLabel.alpha = 0.1;
			titleLabel.alpha = 0.1;
		}
	}
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{	
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	[self unregisterForNotifications];
	
	coverArtImageView.delegate = nil;
	
	[progressSlider release]; progressSlider = nil;
	[elapsedTimeLabel release]; elapsedTimeLabel = nil;
	[remainingTimeLabel release]; remainingTimeLabel = nil;
	[repeatButton release]; repeatButton = nil;
	[shuffleButton release]; shuffleButton = nil;

	[pageControlViewController viewDidDisappear:NO];
	[pageControlViewController release]; pageControlViewController = nil;
	[playButton release]; playButton = nil;
	[nextButton release]; nextButton = nil;
	[prevButton release]; prevButton = nil;
	[volumeSlider release]; volumeSlider = nil;
	[coverArtImageView release]; coverArtImageView = nil;
	[songInfoToggleButton release]; songInfoToggleButton = nil;
	[reflectionView release]; reflectionView = nil;
	[pageControlViewController release]; pageControlViewController = nil;
	
	[extraButtonsButtonOffImage release]; extraButtonsButtonOffImage = nil;
	[extraButtonsButtonOnImage release]; extraButtonsButtonOnImage = nil;
	
	[swipeDetector release]; swipeDetector = nil;
	
	[super dealloc];
}

#pragma mark Rotation

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if (settingsS.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
	if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
	{
		//[self setSongTitle];
		[self createSongTitle];
	}
	else
	{
		[self removeSongTitle];
	}
	
	if (!IS_IPAD())
	{
		[UIView beginAnimations:@"rotate" context:nil];
		[UIView setAnimationDuration:duration];
		if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
		{
			coverArtHolderView.frame = [[originalViewFrames objectForKey:@"coverArtHolderView"] CGRectValue];
			prevButton.frame = [[originalViewFrames objectForKey:@"prevButton"] CGRectValue];
			playButton.frame = [[originalViewFrames objectForKey:@"playButton"] CGRectValue];
			nextButton.frame = [[originalViewFrames objectForKey:@"nextButton"] CGRectValue];
			eqButton.frame = [[originalViewFrames objectForKey:@"eqButton"] CGRectValue];
			volumeSlider.frame = [[originalViewFrames objectForKey:@"volumeSlider"] CGRectValue];
			
			CGRect volumeFrame = [[originalViewFrames objectForKey:@"volumeSlider"] CGRectValue];
			volumeFrame.origin.x = 0;
			volumeFrame.origin.y = 0;
			
			if (settingsS.isJukeboxEnabled)
				jukeboxVolumeView.frame = volumeFrame;
			else
				volumeView.frame = volumeFrame;
			
			artistLabel.alpha = 0.1;
			albumLabel.alpha = 0.1;
			titleLabel.alpha = 0.1;
			eqButton.alpha = 1.0;
			
			CGFloat width = 320 * pageControlViewController.numberOfPages;
			CGFloat height = pageControlViewController.numberOfPages == 1 ? 320 : 300;
			pageControlViewController.scrollView.contentSize = CGSizeMake(width, height);
		}
		else if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
		{
			coverArtHolderView.frame = CGRectMake(0, 0, 300, 270);
			prevButton.origin = CGPointMake(315, 184);
			playButton.origin = CGPointMake(372.5, 184);
			nextButton.origin = CGPointMake(425, 184);
			eqButton.origin = CGPointMake(372.5, 20);
			volumeSlider.frame = CGRectMake(300, 244, 180, 55);
			
			if (settingsS.isJukeboxEnabled)
				jukeboxVolumeView.frame = CGRectMake(0, 0, 180, 22.5);
			else
				volumeView.frame = CGRectMake(0, 0, 180, 55);
			
			self.navigationItem.titleView = nil;
			
			artistLabel.alpha = 1.0;
			albumLabel.alpha = 1.0;
			titleLabel.alpha = 1.0;
			eqButton.alpha = 1.0;
			
			CGFloat width = 300 * pageControlViewController.numberOfPages;
			CGFloat height = pageControlViewController.numberOfPages == 1 ? 270 : 250;
			pageControlViewController.scrollView.contentSize = CGSizeMake(width, height);
		}
		[UIView commitAnimations];
	}
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	
	if (UIInterfaceOrientationIsLandscape(fromInterfaceOrientation))
	{
		[self createSongTitle];
	}
}

#pragma mark Main

- (void)showPlayerOverlayTemp
{
	if (!isFlipped && !isExtraButtonsShowing)
	{
		[self extraButtonsToggleAnimated:NO saveState:NO];
		if (!settingsS.isExtraPlayerControlsShowing)
			[self performSelector:@selector(hideExtraButtons) withObject:nil afterDelay:4.0];
	}
}

- (void)setPlayButtonImage
{		
	[playButton setImage:[UIImage imageNamed:@"controller-play.png"] forState:0];
}


- (void)setPauseButtonImage
{
	[playButton setImage:[UIImage imageNamed:@"controller-pause.png"] forState:0];
}

- (void)setStopButtonImage
{
	[playButton setImage:[UIImage imageNamed:@"controller-stop.png"] forState:0];
}
 
- (void)createSongTitle
{
	if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation) || IS_IPAD())
	{
		self.navigationItem.titleView = nil;
		
		float width = 180;
		
		UIView *titleView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 40)] autorelease];
		titleView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		
		CGRect artistFrame = CGRectMake(0, -2, width, 15);
		CGRect songFrame   = CGRectMake(0, 10, width, 15);
		CGRect albumFrame  = CGRectMake(0, 23, width, 15);
		
		NSUInteger artistSize = 12;
		NSUInteger albumSize  = 11;
		NSUInteger songSize   = 12;
		
		artistTitleLabel = [[UILabel alloc] initWithFrame:artistFrame];
		artistTitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		artistTitleLabel.backgroundColor = [UIColor clearColor];
		artistTitleLabel.textColor = [UIColor colorWithWhite:.7 alpha:1.];
		artistTitleLabel.font = [UIFont boldSystemFontOfSize:artistSize];
		artistTitleLabel.textAlignment = UITextAlignmentCenter;
		[titleView addSubview:artistTitleLabel];
		[artistTitleLabel release];
		
		songTitleLabel = [[UILabel alloc] initWithFrame:songFrame];
		//MarqueeLabel *song = [[MarqueeLabel alloc] initWithFrame:songFrame andRate:50.0 andBufer:6.0];
		songTitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		songTitleLabel.backgroundColor = [UIColor clearColor];
		songTitleLabel.textColor = [UIColor whiteColor];
		songTitleLabel.font = [UIFont boldSystemFontOfSize:songSize];
		songTitleLabel.textAlignment = UITextAlignmentCenter;
		[titleView addSubview:songTitleLabel];
		[songTitleLabel release];
		
		albumTitleLabel = [[UILabel alloc] initWithFrame:albumFrame];
		albumTitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		albumTitleLabel.backgroundColor = [UIColor clearColor];
		albumTitleLabel.textColor = [UIColor colorWithWhite:.7 alpha:1.];
		albumTitleLabel.font = [UIFont boldSystemFontOfSize:albumSize];
		albumTitleLabel.textAlignment = UITextAlignmentCenter;
		[titleView addSubview:albumTitleLabel];
		[albumTitleLabel release];
				
		artistTitleLabel.text = currentSong.artist;
		albumTitleLabel.text = currentSong.album;
		songTitleLabel.text = currentSong.title;
		
		self.navigationItem.titleView = titleView;		
	}
}

- (void)removeSongTitle
{
	self.navigationItem.titleView = nil;
	artistTitleLabel = nil;
	albumTitleLabel = nil;
	songTitleLabel = nil;
}

- (void)setSongTitle
{
	if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation) || IS_IPAD())
	{		
		artistTitleLabel.text = currentSong.artist;
		albumTitleLabel.text = currentSong.album;
		songTitleLabel.text = currentSong.title;
	}
}

- (void)initSongInfo
{	
	self.currentSong = playlistS.currentDisplaySong;
	
	lastProgress = 0;
	
	//DLog(@"currentSong parentId: %@", currentSong.parentId);
	
	if (currentSong.parentId)
	{
		currentAlbumButton.enabled = YES;
		currentAlbumButton.alpha = 1.0;
	}
	else
	{
		currentAlbumButton.enabled = NO;
		currentAlbumButton.alpha = 0.5;
	}
	
    [self setSongTitle];
	coverArtImageView.coverArtId = currentSong.coverArtId;
	DLog(@"player coverArtId: %@", currentSong.coverArtId);
    [self createReflection];
    
	// Update the icon in top right
	if (isFlipped)
	{
		//DLog(@"Updating the top right button");
		[self updateBarButtonImage];
	}
	
	artistLabel.text = currentSong.artist;
	albumLabel.text = currentSong.album;
	titleLabel.text = currentSong.title;
	
	if (settingsS.isJukeboxEnabled)
	{
		jukeboxVolumeView.value = jukeboxS.jukeboxGain;
		
		if (jukeboxS.jukeboxIsPlaying)
			[self setStopButtonImage];
		else 
			[self setPlayButtonImage];
	}
	
	hasMoved = NO;
	oldPosition = 0.0;
	progressSlider.minimumValue = 0.0;
	if (currentSong.duration && !settingsS.isJukeboxEnabled)
	{
		progressSlider.maximumValue = [currentSong.duration floatValue];
		progressSlider.enabled = YES;
	}
	else
	{
		progressSlider.maximumValue = 100.0;
		progressSlider.enabled = NO;
	}
	
	if(playlistS.repeatMode == 1)
	{
		[repeatButton setImage:[UIImage imageNamed:@"controller-repeat-one.png"] forState:0];
	}
	else if(playlistS.repeatMode == 2)
	{
		[repeatButton setImage:[UIImage imageNamed:@"controller-repeat-all.png"] forState:0];
	}
	
	[self updateShuffleIcon];
	
	NSInteger bookmarkCount = [databaseS.bookmarksDb intForQuery:@"SELECT COUNT(*) FROM bookmarks WHERE songId = ?", currentSong.songId];
	if (bookmarkCount > 0)
	{
		bookmarkCountLabel.text = [NSString stringWithFormat:@"%i", bookmarkCount];
		bookmarkButton.imageView.image = [UIImage imageNamed:@"controller-bookmark-on.png"];
	}
	else
	{
		bookmarkCountLabel.text = @"";
		bookmarkButton.imageView.image = [UIImage imageNamed:@"controller-bookmark.png"];
	}
	
	trackLabel.text = [currentSong.track intValue] != 0 ? [NSString stringWithFormat:@"Track %i", [currentSong.track intValue]] : @"";
	genreLabel.text = currentSong.genre ? currentSong.genre : @"";
	yearLabel.text = [currentSong.year intValue] != 0 ? [currentSong.year stringValue] : @"";
	[self updateFormatLabel];
}

- (void)jukeboxVolumeChanged:(id)sender
{
	[jukeboxS jukeboxSetVolume:jukeboxVolumeView.value];
}

- (void)backAction:(id)sender
{
	NSArray *viewControllers = self.navigationController.viewControllers;
	NSInteger count = [viewControllers count];
	
	UIViewController *backVC = [viewControllers objectAtIndexSafe:(count - 2)];
	
	[self.navigationController popToViewController:backVC animated:YES];
}

- (void)updateBarButtonImage
{
	if (UIGraphicsBeginImageContextWithOptions != NULL)
		UIGraphicsBeginImageContextWithOptions(CGSizeMake(30.0, 30.0), NO, 0.0);
	else
		UIGraphicsBeginImageContext(CGSizeMake(30.0, 30.0));
	//DLog(@"coverArtImageView.image: %@", coverArtImageView.image);
	[coverArtImageView.image drawInRect:CGRectMake(0, 0,30.0, 30.0)];
	UIImage *cover = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	
	UIView *aView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0,34.0, 30.0)] autorelease];
	aView.layer.cornerRadius = 4;
	
	UIImageView *coverView = [[[UIImageView alloc] initWithImage:cover] autorelease];
	coverView.frame = CGRectMake(2, 0,30.0, 30.0);
	//coverView.userInteractionEnabled = YES;
	[aView addSubview:coverView];
	
	UIButton *action = [UIButton buttonWithType:UIButtonTypeCustom];
	action.frame = coverView.frame;
	[action addTarget:self action:@selector(songInfoToggle:) forControlEvents:UIControlEventTouchUpInside];
	[aView addSubview:action];
	
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:aView] autorelease];
}

- (void)playlistToggleAnimated:(BOOL)animated saveState:(BOOL)saveState
{
	if (!isFlipped)
	{
		songInfoToggleButton.userInteractionEnabled = NO;
		
		if (!pageControlViewController)
		{
			pageControlViewController = [[PageControlViewController alloc] initWithNibName:@"PageControlViewController" bundle:nil];
			pageControlViewController.view.frame = CGRectMake (0, 0, coverArtImageView.frame.size.width, coverArtImageView.frame.size.height);
		}
		
		// Set the icon in the top right
		[self updateBarButtonImage];
		
		// Flip the album art horizontally
		coverArtHolderView.transform = CGAffineTransformMakeScale(-1, 1);
		pageControlViewController.view.transform = CGAffineTransformMakeScale(-1, 1);
		
		if (animated)
		{
			[UIView beginAnimations:nil context:NULL];
			[UIView setAnimationDuration:0.40];
			[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:coverArtHolderView cache:YES];
		}
		
		//[pageControlViewController resetScrollView];
		[coverArtHolderView addSubview:pageControlViewController.view];
		reflectionView.alpha = 0.0;
		
		extraButtonsButton.alpha = 0.0;
		extraButtonsButton.enabled = NO;
		extraButtons.alpha = 0.0;
		songInfoView.alpha = 0.0;
		
		if (animated)
			[UIView commitAnimations];
		
		//[pageControlViewController viewWillAppear:NO];
	}
	else
	{
		songInfoToggleButton.userInteractionEnabled = YES;
		
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"player-overlay.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(songInfoToggle:)] autorelease];
		
		// Flip the album art horizontally
		coverArtHolderView.transform = CGAffineTransformMakeScale(1, 1);
		
		if (animated)
		{
			[UIView beginAnimations:nil context:NULL];
			[UIView setAnimationDuration:0.4];
			[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:coverArtHolderView cache:YES];
			//[UIView setAnimationDelegate:self];
			//[UIView setAnimationDidStopSelector:@selector(releaseSongInfo:finished:context:)];
		}
		
		//[[[coverArtImageView subviews] lastObject] removeFromSuperview];
		[pageControlViewController.view removeFromSuperview];
		reflectionView.alpha = kDefaultReflectionOpacity;
		
		extraButtonsButton.alpha = 1.0;
		extraButtonsButton.enabled = YES;
		extraButtons.alpha = 1.0;
		songInfoView.alpha = 1.0;
		
		UIGraphicsEndImageContext();
		
		if (animated)
			[UIView commitAnimations];
		
		//[pageControlViewController resetScrollView];
		
		[pageControlViewController release]; pageControlViewController = nil;
	}
	
	isFlipped = !isFlipped;
	
	if (saveState)
		settingsS.isPlayerPlaylistShowing = isFlipped;
}

- (IBAction)songInfoToggle:(id)sender
{
	[self playlistToggleAnimated:YES saveState:YES];
}

/*- (void)releaseSongInfo:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
	NSLog(@"releaseSongInfo called");
	[pageControlViewController release]; pageControlViewController = nil;
}*/

#pragma mark Player Controls

- (IBAction)playButtonPressed:(id)sender
{
	if (settingsS.isJukeboxEnabled)
	{
		if (jukeboxS.jukeboxIsPlaying)
			[jukeboxS jukeboxStop];
		else
			[jukeboxS jukeboxPlay];
	}
	else
	{
		[audioEngineS playPause];
	}
}

- (IBAction)prevButtonPressed:(id)sender
{	
	//DLog(@"track position: %f", audioEngineS.progress);
	if (audioEngineS.progress > 10.0)
	{
		if (settingsS.isJukeboxEnabled)
			[jukeboxS jukeboxPlaySongAtPosition:[NSNumber numberWithInt:playlistS.currentIndex]];
		else
			[musicS playSongAtPosition:playlistS.currentIndex];
	}
	else
	{
		[musicS prevSong];
	}
}

- (IBAction)nextButtonPressed:(id)sender
{
	[musicS nextSong];
}

/*- (void)showExtraButtonsTemporarilyAnimated
{
	if (!isExtraButtonsShowing)
	{
		[self extraButtonsToggleAnimated:YES saveState:NO];
		[self performSelector:@selector(hideExtraButtons) withObject:nil afterDelay:5.0];
	}
}

- (void)showExtraButtonsTemporarily
{
	if (!isExtraButtonsShowing)
	{
		[self extraButtonsToggleAnimated:NO saveState:NO];
		[self performSelector:@selector(hideExtraButtons) withObject:nil afterDelay:5.0];
	}
}*/

- (void)hideExtraButtons
{
	[self extraButtonsToggleAnimated:YES saveState:NO];
}

- (void)extraButtonsToggleAnimated:(BOOL)animated saveState:(BOOL)saveState
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideExtraButtons) object:nil];
	
	CGPoint extraButtonsHidden = CGPointMake(0, -extraButtons.height);
	CGPoint extraButtonsVisible = CGPointMake(0, 0);
	
	CGPoint songInfoViewHidden  = CGPointMake(0, coverArtHolderView.height);
	CGPoint songInfoViewVisible = CGPointMake(0, coverArtHolderView.height - songInfoView.height);
	
	if (isExtraButtonsShowing)
	{
		[extraButtonsButton setImage:extraButtonsButtonOffImage forState:UIControlStateNormal];
		
		if (animated)
		{
			[UIView beginAnimations:nil context:nil];
			[UIView setAnimationDelegate:self];
			[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
			[UIView setAnimationDidStopSelector:@selector(toggleExtraButtonsAnimationDone)];
			[UIView setAnimationDuration:0.2];
		}
		
		extraButtons.origin = extraButtonsHidden;
		songInfoView.origin = songInfoViewHidden;
		
		if (animated)
			[UIView commitAnimations];
	}
	else
	{
		[extraButtonsButton setImage:extraButtonsButtonOnImage forState:UIControlStateNormal];
		
		extraButtons.origin = extraButtonsHidden;
		extraButtons.width = coverArtHolderView.width;
		songInfoView.origin = songInfoViewHidden;
		songInfoView.width = coverArtHolderView.width;
		[coverArtHolderView addSubview:extraButtons];
		[coverArtHolderView addSubview:songInfoView];
		
		if (isFlipped)
			[coverArtHolderView bringSubviewToFront:pageControlViewController.view];
		
		[self updateFormatLabel];
		
		if (animated)
		{
			[UIView beginAnimations:nil context:nil];
			[UIView setAnimationDelegate:self];
			[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
			[UIView setAnimationDidStopSelector:@selector(toggleExtraButtonsAnimationDone)];
			[UIView setAnimationDuration:0.2];
		}
		
		extraButtons.origin = extraButtonsVisible;
		songInfoView.origin = songInfoViewVisible;
		
		if (animated)
			[UIView commitAnimations];
	}
	
	isExtraButtonsShowing = !isExtraButtonsShowing;
	
	if (saveState)
		settingsS.isExtraPlayerControlsShowing = isExtraButtonsShowing;
}

- (void)toggleExtraButtonsAnimationDone
{
	if (!isExtraButtonsShowing)
	{
		[extraButtons removeFromSuperview];
		[songInfoView removeFromSuperview];
	}
}

- (IBAction)toggleExtraButtons:(id)sender
{	
	[self extraButtonsToggleAnimated:YES saveState:YES];
}
/*- (IBAction)toggleExtraButtons:(id)sender
{	
	CGFloat height = extraButtons.height;
	CGFloat width = 250.;
	CGFloat y = extraButtonsButton.y - ((height - extraButtonsButton.height) / 2);
	
	if (isExtraButtonsShowing)
	{
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
		[UIView setAnimationDidStopSelector:@selector(toggleExtraButtonsAnimationDone)];
		[UIView setAnimationDuration:0.3];
		
		CGRect frame = CGRectMake(extraButtonsButton.x + extraButtonsButton.width, y, 0, height);
		extraButtons.frame = frame;
		extraButtonsBackground.width = 0.;
		
		extraButtons.alpha = 0.;
		for (UIView *subView in extraButtons.subviews)
		{			
			if (subView.tag)
				subView.alpha = 0.;
		}
		
		[UIView commitAnimations];
	}
	else
	{ 
		[self.view addSubview:extraButtons];
		CGRect frame = CGRectMake(extraButtonsButton.x + 40., y, 0, height);
		extraButtons.frame = frame;
		extraButtons.alpha = 0.;
		extraButtonsBackground.width = 0.;
		
		[self.view bringSubviewToFront:extraButtonsButton];
		
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
		[UIView setAnimationDidStopSelector:@selector(toggleExtraButtonsAnimationDone)];
		[UIView setAnimationDuration:0.3];
		
		frame = CGRectMake(extraButtonsButton.x - width + extraButtonsButton.width, y, width, height);
		extraButtons.frame = frame;
		extraButtonsBackground.width = width;
		
		extraButtons.alpha = 1.;
		for (UIView *subView in extraButtons.subviews)
		{			
			if (subView.tag)
				subView.alpha = 1.;
		}
		
		[UIView commitAnimations];
	}
	
	isExtraButtonsShowing = !isExtraButtonsShowing;
}

- (void)toggleExtraButtonsAnimationDone
{
	if (isExtraButtonsShowing)
	{
		
	}
	else
	{
		[extraButtons removeFromSuperview];
	}
}*/


- (IBAction)touchedSlider:(id)sender
{
	pauseSlider = YES;
	
	if (self.sliderMultipleLabel == nil)
	{
		// Create the label
		CGFloat width = 80;
		CGFloat height = 18;
		CGFloat x = (self.coverArtHolderView.width / 2) - (width / 2.);
		CGFloat y = self.songInfoView.y - height;
		CGRect frame = CGRectMake(x, y, width, height);
		self.sliderMultipleLabel = [[[UILabel alloc] initWithFrame:frame] autorelease];
		self.sliderMultipleLabel.textColor = [UIColor colorWithWhite:.8 alpha:1.0];
		self.sliderMultipleLabel.alpha = 0.0;
		self.sliderMultipleLabel.font = [UIFont boldSystemFontOfSize:13.5];
		self.sliderMultipleLabel.shadowOffset = CGSizeMake(0, 2);
		self.sliderMultipleLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.25];
		self.sliderMultipleLabel.textAlignment = UITextAlignmentCenter;
		
		// Create the label background
		CGFloat cornerRadius = 4.;
		CGRect backgroundFrame = CGRectMake(0., 0., self.sliderMultipleLabel.width, self.sliderMultipleLabel.height + cornerRadius);
		CALayer *backgroundLayer = [[CALayer alloc] init];
		backgroundLayer.frame = backgroundFrame;
		backgroundLayer.backgroundColor = [UIColor colorWithWhite:0 alpha:.72].CGColor;
		backgroundLayer.cornerRadius = cornerRadius;
		self.sliderMultipleLabel.backgroundColor = [UIColor colorWithPatternImage:[backgroundLayer imageFromLayer]];
		[backgroundLayer release];

		[self.coverArtHolderView addSubview:self.sliderMultipleLabel];
	}
	
	OBSlider *slider = sender;
	NSString *text = [NSString stringWithFormat:@"%@  x%.1f", [NSString formatTime:progressSlider.value], slider.scrubbingSpeed];
	self.sliderMultipleLabel.text = text;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.2];
	[UIView setAnimationTransition:UIViewAnimationOptionCurveEaseInOut forView:nil cache:YES];
	self.sliderMultipleLabel.alpha = 1.0;
	[UIView commitAnimations];	
}


- (IBAction) movingSlider:(id)sender
{	
	OBSlider *slider = sender;
	NSString *text = [NSString stringWithFormat:@"%@  x%.1f", [NSString formatTime:progressSlider.value], slider.scrubbingSpeed];
	self.sliderMultipleLabel.text = text;
}


- (IBAction)movedSlider:(id)sender
{	
	if (!hasMoved)
	{		
		hasMoved = YES;
		
		// Fix for skipping to end of file going to next song
		// It seems that the max time is always off
		if (progressSlider.value > (progressSlider.maximumValue - 8.0))
		{
			float newValue = progressSlider.maximumValue - 8.0;
			
			if (newValue < 0.0)
				newValue = 0.0;
			
			progressSlider.value = newValue;
		}
		
		byteOffset = audioEngineS.bitRate * 128 * progressSlider.value;
		
		if ([currentSong isTempCached])
		{
            [audioEngineS stop];
			
			audioEngineS.startByteOffset = byteOffset;
			audioEngineS.startSecondsOffset = progressSlider.value;
			
			[streamManagerS removeStreamAtIndex:0];
			[streamManagerS queueStreamForSong:currentSong byteOffset:byteOffset secondsOffset:progressSlider.value atIndex:0 isTempCache:YES isStartDownload:YES];
			if ([streamManagerS.handlerStack count] > 1)
			{
				ISMSStreamHandler *handler = [streamManagerS.handlerStack firstObjectSafe];
				[handler start];
			}
			
			pauseSlider = NO;
			hasMoved = NO;
		}
		else 
		{			
			if (currentSong.isFullyCached || byteOffset <= currentSong.localFileSize)
			{
				[audioEngineS seekToPositionInSeconds:progressSlider.value];
				pauseSlider = NO;
				hasMoved = NO;
			}
			else
			{
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Past Cache Point" message:@"You are trying to skip further than the song has cached. You can do this, but the song won't be cached. Or you can wait a little bit for the cache to catch up." delegate:self cancelButtonTitle:@"Wait" otherButtonTitles:@"OK", nil];
				[alert show];
				[alert release];
			}
		}
	}
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.2];
	[UIView setAnimationTransition:UIViewAnimationOptionCurveEaseInOut forView:nil cache:YES];
	self.sliderMultipleLabel.alpha = 0.0;
	[UIView commitAnimations];	
}

- (IBAction)skipBack30:(id)sender
{
	CGFloat seconds = (CGFloat)settingsS.quickSkipNumberOfSeconds;
	
	float newValue = 0.0;
	if (progressSlider.value - seconds >= 0.0)
	{
		newValue = progressSlider.value - seconds;
	}
	progressSlider.value = newValue;
	[self movedSlider:nil];
}

- (IBAction)skipForward30:(id)sender
{
	CGFloat seconds = (CGFloat)settingsS.quickSkipNumberOfSeconds;
	progressSlider.value = progressSlider.value + seconds;
	[self movedSlider:nil];
}

- (IBAction) repeatButtonToggle:(id)sender
{	
	if(playlistS.repeatMode == 0)
	{
		[repeatButton setImage:[UIImage imageNamed:@"controller-repeat-one.png"] forState:0];
		playlistS.repeatMode = 1;
	}
	else if(playlistS.repeatMode == 1)
	{
		[repeatButton setImage:[UIImage imageNamed:@"controller-repeat-all.png"] forState:0];
		playlistS.repeatMode = 2;
	}
	else if(playlistS.repeatMode == 2)
	{
		[repeatButton setImage:[UIImage imageNamed:@"controller-repeat.png"] forState:0];
		playlistS.repeatMode = 0;
	}
}

- (IBAction)bookmarkButtonToggle:(id)sender
{
	bookmarkPosition = (int)progressSlider.value;
	bookmarkBytePosition = audioEngineS.currentByteOffset;
	
	UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Bookmark Name:" message:@"this gets covered" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
	bookmarkNameTextField = [[UITextField alloc] initWithFrame:CGRectMake(12.0, 47.0, 260.0, 24.0)];
	bookmarkNameTextField.layer.cornerRadius = 3.;
	[bookmarkNameTextField setBackgroundColor:[UIColor whiteColor]];
	[myAlertView addSubview:bookmarkNameTextField];
	if ([[[[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."] objectAtIndexSafe:0] isEqualToString:@"3"])
	{
		CGAffineTransform myTransform = CGAffineTransformMakeTranslation(0.0, 100.0);
		[myAlertView setTransform:myTransform];
	}
	[myAlertView show];
	[myAlertView release];
	[bookmarkNameTextField becomeFirstResponder];
}

- (void)saveBookmark
{
	[databaseS.bookmarksDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO bookmarks (playlistIndex, name, position, %@, bytes) VALUES (?, ?, ?, %@, ?)", [Song standardSongColumnNames], [Song standardSongColumnQMarks]], [NSNumber numberWithInt:playlistS.currentIndex], bookmarkNameTextField.text, [NSNumber numberWithInt:bookmarkPosition], currentSong.title, currentSong.songId, currentSong.artist, currentSong.album, currentSong.genre, currentSong.coverArtId, currentSong.path, currentSong.suffix, currentSong.transcodedSuffix, currentSong.duration, currentSong.bitRate, currentSong.track, currentSong.year, currentSong.size, currentSong.parentId, [NSNumber numberWithUnsignedLongLong:bookmarkBytePosition]];
	
	NSInteger bookmarkId = [databaseS.bookmarksDb intForQuery:@"SELECT MAX(bookmarkId) FROM bookmarks"]; 
	
	NSString *tableName = nil;
	if (settingsS.isJukeboxEnabled)
	{
		tableName = @"jukeboxCurrentPlaylist";
		if (playlistS.isShuffle) 
			tableName = @"jukeboxShufflePlaylist";
	}
	else 
	{
		tableName = @"currentPlaylist";
		if (playlistS.isShuffle) 
			tableName = @"shufflePlaylist";
	}
	
	// Save the playlist
	NSString *dbName = viewObjectsS.isOfflineMode ? @"%@/offlineCurrentPlaylist.db" : @"%@/%@currentPlaylist.db";
	[databaseS.bookmarksDb executeUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:dbName, settingsS.databasePath, [[settingsS urlString] md5]], @"currentPlaylistDb"];
	
	[databaseS.bookmarksDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmark%i (%@)", bookmarkId, [Song standardSongColumnSchema]]];
	
	[databaseS.bookmarksDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO bookmark%i SELECT * FROM currentPlaylistDb.%@", bookmarkId, tableName]]; 
	
	[databaseS.bookmarksDb executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
	
	bookmarkCountLabel.text = [NSString stringWithFormat:@"%i", [databaseS.bookmarksDb intForQuery:@"SELECT COUNT(*) FROM bookmarks WHERE songId = ?", currentSong.songId]];
	bookmarkButton.imageView.image = [UIImage imageNamed:@"controller-bookmark-on.png"];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{	
	if ([alertView.title isEqualToString:@"Sorry"])
	{
		hasMoved = NO;
	}
	if ([alertView.title isEqualToString:@"Past Cache Point"])
	{
		if (buttonIndex == 0)
		{
			pauseSlider = NO;
			hasMoved = NO;
		}
		else if(buttonIndex == 1)
		{
            [audioEngineS stop];
			audioEngineS.startByteOffset = byteOffset;
			audioEngineS.startSecondsOffset = progressSlider.value;
			
			[streamManagerS removeStreamAtIndex:0];
            //DLog(@"byteOffset: %i", byteOffset);
			//DLog(@"starting temp stream");
			[streamManagerS queueStreamForSong:currentSong byteOffset:byteOffset secondsOffset:progressSlider.value atIndex:0 isTempCache:YES isStartDownload:YES];
			if ([streamManagerS.handlerStack count] > 1)
			{
				ISMSStreamHandler *handler = [streamManagerS.handlerStack firstObjectSafe];
				[handler start];
			}
			pauseSlider = NO;
			hasMoved = NO;
		}
	}
	else if([alertView.title isEqualToString:@"Bookmark Name:"])
	{
		[bookmarkNameTextField resignFirstResponder];
		if(buttonIndex == 1)
		{
			// Check if the bookmark exists
			if ([databaseS.bookmarksDb stringForQuery:@"SELECT name FROM bookmarks WHERE name = ? LIMIT 1", bookmarkNameTextField.text])
			{
				// Bookmark exists so ask to overwrite
				UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Overwrite?" message:@"There is already a bookmark with this name. Overwrite it?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
				[myAlertView show];
				[myAlertView release];
			}
			else
			{
				// Bookmark doesn't exist so save it
				[self saveBookmark];
			}
		}
	}
	else if([alertView.title isEqualToString:@"Overwrite?"])
	{
		if(buttonIndex == 1)
		{
			// Overwrite the bookmark
			NSUInteger bookmarkId = [databaseS.bookmarksDb intForQuery:@"SELECT bookmarkId FROM bookmarks WHERE name = ?", bookmarkNameTextField.text];
			
			[databaseS.bookmarksDb executeUpdate:@"DELETE FROM bookmarks WHERE name = ?", bookmarkNameTextField.text];
			[databaseS.bookmarksDb executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS bookmark%i", bookmarkId]];
			
			[self saveBookmark];
		}
	}
}

- (IBAction)shuffleButtonToggle:(id)sender
{	
	NSString *message = playlistS.isShuffle ? @"Unshuffling" : @"Shuffling";
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:message];
	
	[playlistS performSelector:@selector(shuffleToggle) withObject:nil afterDelay:0.05];
}

- (void)updateShuffleIcon
{	
	if (playlistS.isShuffle)
	{
		if (!settingsS.isJukeboxEnabled)
		{
			[shuffleButton setImage:[UIImage imageNamed:@"controller-shuffle-on.png"] forState:0];
		}
	}
	else
	{
		[shuffleButton setImage:[UIImage imageNamed:@"controller-shuffle.png"] forState:0];
	}
	
	[viewObjectsS hideLoadingScreen];
}

- (IBAction)currentAlbumPressed:(id)sender
{
	DLog(@"parentId: %@", currentSong.parentId);
}

- (void)updateDownloadProgress
{		
	// Set the current song progress bar
	if ([self.currentSong isTempCached])
	{
		self.downloadProgress.hidden = YES;
	}
	else
	{
		self.downloadProgress.hidden = NO;
		
		// Keep between 0 and 1
		float modifier = self.currentSong.downloadProgress;
		modifier = modifier < 0. ? 0. : modifier;
		modifier = modifier > 1. ? 1. : modifier;
		
		// Set the width based on the download progress + left border size
		float width = (self.currentSong.downloadProgress * downloadProgressWidth) + downloadProgressBorder;
		
		// If the song is fully cached, add the right side border
		width = modifier >= 1. ? width + downloadProgressBorder : width;

		self.downloadProgress.width = width;
	}
	
	[self performSelector:@selector(updateDownloadProgress) withObject:nil afterDelay:1.0];
}

- (void)updateSlider
{		
	if (settingsS.isJukeboxEnabled)
	{
		if (lastProgress != [currentSong.duration intValue])
		{
			elapsedTimeLabel.text = [NSString formatTime:0];
			remainingTimeLabel.text = [NSString stringWithFormat:@"-%@",[NSString formatTime:[currentSong.duration floatValue]]];
			
			progressSlider.value = 0.0;
		}
	}
	else 
	{
		if (!pauseSlider)
		{
			double progress = 0;
			if (audioEngineS.isPlaying)
				progress = audioEngineS.progress;
			else
				progress = [currentSong isEqualToSong:audioEngineS.currentStreamSong] ? audioEngineS.progress : 0.;
			
			if (lastProgress != ceil(progress))
			{
				lastProgress = ceil(progress);
				
				NSString *elapsedTime = [NSString formatTime:progress];;
				NSString *remainingTime = [NSString formatTime:([currentSong.duration doubleValue] - progress)];
				
				progressSlider.value = progress;
				elapsedTimeLabel.text = elapsedTime;
				remainingTimeLabel.text =[@"-" stringByAppendingString:remainingTime];
			}
		}
		
		if (isExtraButtonsShowing)
			[self updateFormatLabel];
	}
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateSlider) object:nil];
	[self performSelector:@selector(updateSlider) withObject:nil afterDelay:1];
}

- (void)updateFormatLabel
{
	if ([currentSong isEqualToSong:audioEngineS.currentStreamSong] && audioEngineS.bitRate > 0)
		formatLabel.text = [NSString stringWithFormat:@"%i kbps %@", audioEngineS.bitRate, audioEngineS.currentStreamFormat];
	else if ([currentSong isEqualToSong:audioEngineS.currentStreamSong])
		formatLabel.text = audioEngineS.currentStreamFormat;
	else
		formatLabel.text = @"";
}

#pragma mark Image Reflection

- (void)createReflection
{	
    // Create reflection
	reflectionView.image = [coverArtImageView reflectedImageWithHeight:reflectionHeight];
	if (isFlipped)
	{
		[self updateBarButtonImage];
	}
}

- (IBAction)showEq:(id)sender
{
	if (isFlipped)
		[self songInfoToggle:nil];
	
	EqualizerViewController *eqView = [[EqualizerViewController alloc] initWithNibName:@"EqualizerViewController" bundle:nil];
	[self.navigationController pushViewController:eqView animated:YES];
	[eqView release];
}


@end
