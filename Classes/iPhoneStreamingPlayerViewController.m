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
#import <QuartzCore/QuartzCore.h>
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "AudioEngine.h"
#import "EqualizerViewController.h"
#import "SUSCoverArtDAO.h"
#import "OBSlider.h"
#import "ISMSStreamManager.h"
#import "ISMSStreamHandler.h"
#import "NSArray+FirstObject.h"
#import "UIImageView+Reflection.h"
#import "NSArray+Additions.h"
#import "JukeboxSingleton.h"
#import "CALayer+ImageFromLayer.h"
#import "SavedSettings.h"
#import "StoreViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "FMDatabaseQueue.h"

#define downloadProgressBorder 4.
#define downloadProgressWidth (progressSlider.frame.size.width - (downloadProgressBorder * 2))


@interface iPhoneStreamingPlayerViewController ()
@property (strong) NSDictionary *originalViewFrames;
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

@synthesize back30Button, forw30Button;
@synthesize originalViewFrames, extraButtons, extraButtonsButton, extraButtonsBackground;
@synthesize bookmarkCountLabel, progressSlider, elapsedTimeLabel, remainingTimeLabel, shuffleButton, repeatButton, bookmarkButton, currentAlbumButton;
@synthesize updateTimer, progressTimer, hasMoved, oldPosition, byteOffset, currentSong, pauseSlider, downloadProgress, sliderMultipleLabel;
@synthesize bookmarkEntry, bookmarkIndex, bookmarkNameTextField, bookmarkPosition;
@synthesize coverArtHolderView, songInfoView, extraButtonsButtonOffImage, extraButtonsButtonOnImage;
@synthesize trackLabel, genreLabel, yearLabel, formatLabel;
@synthesize quickBackLabel, quickForwLabel;
@synthesize swipeDetector;
@synthesize lastProgress;
@synthesize largeOverlayArtist, largeOverlaySong, largeOverlayAlbum, largeOverlayView;

@synthesize artistLabel, albumLabel, titleLabel;
@synthesize playButton, nextButton, prevButton, eqButton, volumeSlider, coverArtImageView, reflectionView, songInfoToggleButton, activityIndicator;
@synthesize artistTitleLabel, albumTitleLabel, songTitleLabel;
@synthesize volumeView, jukeboxVolumeView;
@synthesize reflectionHeight, isFlipped, isExtraButtonsShowing, pageControlViewController, bookmarkBytePosition;


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

- (void)showStore
{	
	if (isFlipped)
		[self songInfoToggle:nil];
	
	StoreViewController *store = [[StoreViewController alloc] init];
	//[self pushViewControllerCustom:store];
	[self.navigationController pushViewController:store animated:YES];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	DLog(@"coverArtImageView class: %@", NSStringFromClass(coverArtImageView.class));
	
	extraButtonsButtonOffImage = [UIImage imageNamed:@"controller-extras.png"];
	extraButtonsButtonOnImage = [UIImage imageNamed:@"controller-extras-on.png"];
	
	// Set default values
	self.pageControlViewController = nil;
	isFlipped = NO;
	isExtraButtonsShowing = NO;
	pauseSlider = NO;
	
	coverArtImageView.isLarge = YES;
	//coverArtImageView.delegate = self;

	// Create the extra views not in the XIB file
	[self createDownloadProgressView];
	[self createLandscapeViews];
	
	// Setup the navigation controller buttons
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"player-overlay.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(songInfoToggle:)];
	if (!IS_IPAD())
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"back.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(backAction:)];
	
	// Initialize the song info
	[self initSongInfo];
	
	[self jukeboxToggled];
	
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
			 swipeDetector = nil;
		}
	}
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	//[UIApplication setStatusBarHidden:NO withAnimation:NO];
	
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
	
	NSString *imageName = settingsS.isEqualizerOn ? @"controller-equalizer-on.png" : @"controller-equalizer.png";
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

- (void)largeSongInfoWasToggled
{
	if (isExtraButtonsShowing)
	{
		[self extraButtonsToggleAnimated:NO saveState:NO];
		[self extraButtonsToggleAnimated:NO saveState:NO];
	}
}

- (void)registerForNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(jukeboxToggled) 
												 name:ISMSNotification_JukeboxDisabled object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(jukeboxToggled) 
												 name:ISMSNotification_JukeboxEnabled object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setPlayButtonImage) 
												 name:ISMSNotification_SongPlaybackEnded object:nil];
    
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setPlayButtonImage) 
												 name:ISMSNotification_SongPlaybackPaused object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setPauseButtonImage) 
												 name:ISMSNotification_SongPlaybackStarted object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initSongInfo) 
												 name:ISMSNotification_JukeboxSongInfo object:nil];
	
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
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(largeSongInfoWasToggled) name:ISMSNotification_LargeSongInfoToggle object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showStore) name:@"player show store" object:nil];
	
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
													name:ISMSNotification_JukeboxEnabled object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:ISMSNotification_JukeboxDisabled object:nil];
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
													name:ISMSNotification_JukeboxSongInfo object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self 
													name:@"hideSongInfo" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_LargeSongInfoToggle object:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:@"player show store" object:nil];
	
	if (IS_IPAD())
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self 
														name:ISMSNotification_ShowPlayer object:nil];
	}
}

- (void)createDownloadProgressView
{
	self.downloadProgress = [[UIView alloc] initWithFrame:progressSlider.frame];
	downloadProgress.x = 0.0;
	downloadProgress.y = 0.0;
	downloadProgress.backgroundColor = [UIColor whiteColor];
	downloadProgress.alpha = 0.3;
	downloadProgress.userInteractionEnabled = NO;
	downloadProgress.width = 0.0;
	downloadProgress.layer.cornerRadius = 5;
	[progressSlider addSubview:downloadProgress];
	
	if (settingsS.isJukeboxEnabled)
		downloadProgress.hidden = YES;
}

- (void)createLandscapeViews
{
	// Setup landscape orientation if necessary
	if (!IS_IPAD())
	{
		self.artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(305, 60, 170, 30)];
		self.artistLabel.backgroundColor = [UIColor clearColor];
		self.artistLabel.textColor = [UIColor colorWithWhite:.7 alpha:1.];
		self.artistLabel.font = [UIFont boldSystemFontOfSize:22];
		self.artistLabel.adjustsFontSizeToFitWidth = YES;
		self.artistLabel.textAlignment = UITextAlignmentCenter;
		[self.view addSubview:self.artistLabel];
		[self.view sendSubviewToBack:self.artistLabel];
		
		self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(305, 90, 170, 30)];
		self.titleLabel.backgroundColor = [UIColor clearColor];
		self.titleLabel.textColor = [UIColor whiteColor];
		self.titleLabel.font = [UIFont boldSystemFontOfSize:24];
		self.titleLabel.adjustsFontSizeToFitWidth = YES;
		self.titleLabel.textAlignment = UITextAlignmentCenter;
		[self.view addSubview:self.titleLabel];
		[self.view sendSubviewToBack:self.titleLabel];
		
		self.albumLabel = [[UILabel alloc] initWithFrame:CGRectMake(305, 120, 170, 30)];
		self.albumLabel.backgroundColor = [UIColor clearColor];
		self.albumLabel.textColor = [UIColor colorWithWhite:.7 alpha:1.];
		self.albumLabel.font = [UIFont systemFontOfSize:22];
		self.albumLabel.adjustsFontSizeToFitWidth = YES;
		self.albumLabel.textAlignment = UITextAlignmentCenter;
		[self.view addSubview:self.albumLabel];
		[self.view sendSubviewToBack:self.albumLabel];
		
		NSMutableDictionary *positions = [NSMutableDictionary dictionaryWithCapacity:0];
		[positions setObject:[NSValue valueWithCGRect:volumeSlider.frame] forKey:@"volumeSlider"];
		[positions setObject:[NSValue valueWithCGRect:coverArtHolderView.frame] forKey:@"coverArtHolderView"];
		[positions setObject:[NSValue valueWithCGRect:prevButton.frame] forKey:@"prevButton"];
		[positions setObject:[NSValue valueWithCGRect:playButton.frame] forKey:@"playButton"];
		[positions setObject:[NSValue valueWithCGRect:nextButton.frame] forKey:@"nextButton"];
		[positions setObject:[NSValue valueWithCGRect:eqButton.frame] forKey:@"eqButton"];
		[positions setObject:[NSValue valueWithCGRect:extraButtonsButton.frame] forKey:@"extraButtonsButton"];
		self.originalViewFrames = [NSDictionary dictionaryWithDictionary:positions];
		
		if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
		{
			self.coverArtHolderView.frame = CGRectMake(0, 0, 300, 270);
			self.prevButton.origin = CGPointMake(315, 184);
			self.playButton.origin = CGPointMake(372.5, 184);
			self.nextButton.origin = CGPointMake(425, 184);
			self.volumeSlider.frame = CGRectMake(300, 244, 180, 55);
			self.volumeView.frame = CGRectMake(0, 0, 180, 55);
			self.eqButton.origin = CGPointMake(328, 20);
			self.extraButtonsButton.origin = CGPointMake(418, 20);
		}
		else
		{
			self.artistLabel.alpha = 0.1;
			self.albumLabel.alpha = 0.1;
			self.titleLabel.alpha = 0.1;
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
	
	coverArtImageView.delegate = nil;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
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
			self.coverArtHolderView.frame = [[self.originalViewFrames objectForKey:@"coverArtHolderView"] CGRectValue];
			self.prevButton.frame = [[self.originalViewFrames objectForKey:@"prevButton"] CGRectValue];
			self.playButton.frame = [[self.originalViewFrames objectForKey:@"playButton"] CGRectValue];
			self.nextButton.frame = [[self.originalViewFrames objectForKey:@"nextButton"] CGRectValue];
			self.eqButton.frame = [[self.originalViewFrames objectForKey:@"eqButton"] CGRectValue];
			self.extraButtonsButton.frame = [[self.originalViewFrames objectForKey:@"extraButtonsButton"] CGRectValue];
			self.volumeSlider.frame = [[self.originalViewFrames objectForKey:@"volumeSlider"] CGRectValue];
			
			CGRect volumeFrame = [[self.originalViewFrames objectForKey:@"volumeSlider"] CGRectValue];
			volumeFrame.origin.x = 0;
			volumeFrame.origin.y = 0;
			
			if (settingsS.isJukeboxEnabled)
				self.jukeboxVolumeView.frame = volumeFrame;
			else
				self.volumeView.frame = volumeFrame;
			
			self.artistLabel.alpha = 0.1;
			self.albumLabel.alpha = 0.1;
			self.titleLabel.alpha = 0.1;
			
			CGFloat width = 320 * self.pageControlViewController.numberOfPages;
			CGFloat height = self.pageControlViewController.numberOfPages == 1 ? 320 : 300;
			self.pageControlViewController.scrollView.contentSize = CGSizeMake(width, height);
		}
		else if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
		{
			self.coverArtHolderView.frame = CGRectMake(0, 0, 300, 270);
			self.prevButton.origin = CGPointMake(315, 184);
			self.playButton.origin = CGPointMake(372.5, 184);
			self.nextButton.origin = CGPointMake(425, 184);
			self.eqButton.origin = CGPointMake(328, 20);
			self.extraButtonsButton.origin = CGPointMake(418, 20);
			self.volumeSlider.frame = CGRectMake(300, 244, 180, 55);
			
			if (settingsS.isJukeboxEnabled)
				self.jukeboxVolumeView.frame = CGRectMake(0, 0, 180, 22.5);
			else
				self.volumeView.frame = CGRectMake(0, 0, 180, 55);
			
			self.navigationItem.titleView = nil;
			
			self.artistLabel.alpha = 1.0;
			self.albumLabel.alpha = 1.0;
			self.titleLabel.alpha = 1.0;
			
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
		
		UIView *titleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 40)];
		titleView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		
		CGRect artistFrame = CGRectMake(0, -2, width, 15);
		CGRect songFrame   = CGRectMake(0, 10, width, 15);
		CGRect albumFrame  = CGRectMake(0, 23, width, 15);
		
		NSUInteger artistSize = 11;
		NSUInteger songSize   = 12;
		NSUInteger albumSize  = 11;
		
		self.artistTitleLabel = [[UILabel alloc] initWithFrame:artistFrame];
		self.artistTitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.artistTitleLabel.backgroundColor = [UIColor clearColor];
		self.artistTitleLabel.textColor = [UIColor colorWithWhite:.7 alpha:1.];
		self.artistTitleLabel.font = [UIFont boldSystemFontOfSize:artistSize];
		self.artistTitleLabel.textAlignment = UITextAlignmentCenter;
		[titleView addSubview:self.artistTitleLabel];
		
		self.songTitleLabel = [[UILabel alloc] initWithFrame:songFrame];
		//MarqueeLabel *song = [[MarqueeLabel alloc] initWithFrame:songFrame andRate:50.0 andBufer:6.0];
		self.songTitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.songTitleLabel.backgroundColor = [UIColor clearColor];
		self.songTitleLabel.textColor = [UIColor whiteColor];
		self.songTitleLabel.font = [UIFont boldSystemFontOfSize:songSize];
		self.songTitleLabel.textAlignment = UITextAlignmentCenter;
		[titleView addSubview:self.songTitleLabel];
		
		self.albumTitleLabel = [[UILabel alloc] initWithFrame:albumFrame];
		self.albumTitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.albumTitleLabel.backgroundColor = [UIColor clearColor];
		self.albumTitleLabel.textColor = [UIColor colorWithWhite:.7 alpha:1.];
		self.albumTitleLabel.font = [UIFont boldSystemFontOfSize:albumSize];
		self.albumTitleLabel.textAlignment = UITextAlignmentCenter;
		[titleView addSubview:self.albumTitleLabel];
				
		self.artistTitleLabel.text = self.currentSong.artist;
		self.albumTitleLabel.text = self.currentSong.album;
		self.songTitleLabel.text = self.currentSong.title;
		
		self.navigationItem.titleView = titleView;		
	}
}

- (void)removeSongTitle
{
	self.navigationItem.titleView = nil;
	self.artistTitleLabel = nil;
	self.albumTitleLabel = nil;
	self.songTitleLabel = nil;
}

- (void)setSongTitle
{
	if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation) || IS_IPAD())
	{		
		self.artistTitleLabel.text = self.currentSong.artist;
		self.albumTitleLabel.text = self.currentSong.album;
		self.songTitleLabel.text = self.currentSong.title;
	}
}

- (void)initSongInfo
{	
	self.currentSong = playlistS.currentDisplaySong;
	
	lastProgress = NSUIntegerMax;
	
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
	
	self.artistLabel.text = currentSong.artist;
	self.albumLabel.text = currentSong.album;
	self.titleLabel.text = currentSong.title;
	
	self.largeOverlayArtist.text = currentSong.artist;
	self.largeOverlayAlbum.text = currentSong.album;
	self.largeOverlaySong.text = currentSong.title;
	
	if (settingsS.isJukeboxEnabled)
	{
		self.jukeboxVolumeView.value = jukeboxS.jukeboxGain;
		
		if (jukeboxS.jukeboxIsPlaying)
			[self setStopButtonImage];
		else 
			[self setPlayButtonImage];
	}
	
	hasMoved = NO;
	oldPosition = 0.0;
	progressSlider.minimumValue = 0.0;
	if (!settingsS.isJukeboxEnabled && currentSong.duration && [currentSong.duration intValue] > 0)
	{
		progressSlider.maximumValue = [currentSong.duration floatValue];
		progressSlider.enabled = YES;
	}
	else
	{
		progressSlider.maximumValue = 0.0;
		progressSlider.enabled = NO;
	}
	
	[repeatButton setImage:[UIImage imageNamed:@"controller-repeat.png"] forState:0];
	repeatButton.enabled = NO;
	if (!settingsS.isJukeboxEnabled)
	{
		repeatButton.enabled = YES;
		if(playlistS.repeatMode == 1)
		{
			[repeatButton setImage:[UIImage imageNamed:@"controller-repeat-one.png"] forState:0];
		}
		else if(playlistS.repeatMode == 2)
		{
			[repeatButton setImage:[UIImage imageNamed:@"controller-repeat-all.png"] forState:0];
		}
	}
	
	eqButton.enabled = YES;
	back30Button.enabled = YES;
	forw30Button.enabled = YES;
	if (settingsS.isJukeboxEnabled)
	{
		eqButton.enabled = NO;
		back30Button.enabled = NO;
		forw30Button.enabled = NO;
	}
	
	[self updateShuffleIcon];
	
	__block NSInteger bookmarkCount;
	[databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db)
	{
		bookmarkCount = [db intForQuery:@"SELECT COUNT(*) FROM bookmarks WHERE songId = ?", currentSong.songId]; 
	}];
	
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
	
	self.trackLabel.text = [self.currentSong.track intValue] != 0 ? [NSString stringWithFormat:@"Track %i", [self.currentSong.track intValue]] : @"";
	self.genreLabel.text = self.currentSong.genre ? self.currentSong.genre : @"";
	self.yearLabel.text = [self.currentSong.year intValue] != 0 ? [self.currentSong.year stringValue] : @"";
	[self updateFormatLabel];
}

- (void)jukeboxToggled
{
	// Setup the volume controller view
	if (settingsS.isJukeboxEnabled)
	{
		// Remove the regular volume control if there
		[self.volumeView removeFromSuperview];
		self.volumeView = nil;
		
		[jukeboxS jukeboxGetInfo];
		
		self.view.backgroundColor = viewObjectsS.jukeboxColor;
		
		CGRect frame = volumeSlider.bounds;
		frame.size.height = volumeSlider.bounds.size.height / 2;
		self.jukeboxVolumeView = [[UISlider alloc] initWithFrame:frame];
		[self.jukeboxVolumeView addTarget:self action:@selector(jukeboxVolumeChanged:) forControlEvents:UIControlEventValueChanged];
		self.jukeboxVolumeView.minimumValue = 0.0;
		self.jukeboxVolumeView.maximumValue = 1.0;
		self.jukeboxVolumeView.continuous = NO;
		self.jukeboxVolumeView.value = jukeboxS.jukeboxGain;
		[self.volumeSlider addSubview:self.jukeboxVolumeView];
	}
	else
	{
		// Remove the jukebox volume control if there
		[self.jukeboxVolumeView removeFromSuperview];
		self.jukeboxVolumeView = nil;
		
		self.view.backgroundColor = [UIColor blackColor];
		
		//volumeSlider.backgroundColor = [UIColor greenColor];
		CGRect newFrame = CGRectMake(10, 0, volumeSlider.width-20, volumeSlider.height);
		//CGRect newFrame = CGRectMake(volumeSlider.x, volumeSlider.y-10, volumeSlider.width, 30);
		self.volumeView = [[MPVolumeView alloc] initWithFrame:newFrame];
		[self.volumeSlider addSubview:self.volumeView];
		//[self.view addSubview:volumeView];
		//[volumeView sizeToFit];
	}
	
	[self initSongInfo];
}

- (void)jukeboxVolumeChanged:(id)sender
{
	[jukeboxS jukeboxSetVolume:self.jukeboxVolumeView.value];
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
	
	UIView *aView = [[UIView alloc] initWithFrame:CGRectMake(0, 0,34.0, 30.0)];
	aView.layer.cornerRadius = 4;
	
	UIImageView *coverView = [[UIImageView alloc] initWithImage:cover];
	coverView.frame = CGRectMake(2, 0,30.0, 30.0);
	//coverView.userInteractionEnabled = YES;
	[aView addSubview:coverView];
	
	UIButton *action = [UIButton buttonWithType:UIButtonTypeCustom];
	action.frame = coverView.frame;
	[action addTarget:self action:@selector(songInfoToggle:) forControlEvents:UIControlEventTouchUpInside];
	[aView addSubview:action];
	
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:aView];
}

- (void)playlistToggleAnimated:(BOOL)animated saveState:(BOOL)saveState
{
	if (!isFlipped)
	{
		songInfoToggleButton.userInteractionEnabled = NO;
		
		if (!self.pageControlViewController)
		{
			self.pageControlViewController = [[PageControlViewController alloc] initWithNibName:@"PageControlViewController" bundle:nil];
			self.pageControlViewController.view.frame = CGRectMake (0, 0, coverArtImageView.frame.size.width, coverArtImageView.frame.size.height);
		}
		
		// Set the icon in the top right
		[self updateBarButtonImage];
		
		// Flip the album art horizontally
		self.coverArtHolderView.transform = CGAffineTransformMakeScale(-1, 1);
		self.pageControlViewController.view.transform = CGAffineTransformMakeScale(-1, 1);
		
		if (animated)
		{
			[UIView beginAnimations:nil context:NULL];
			[UIView setAnimationDuration:0.40];
			[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:self.coverArtHolderView cache:YES];
		}
		
		//[pageControlViewController resetScrollView];
		[self.coverArtHolderView addSubview:self.pageControlViewController.view];
		self.reflectionView.alpha = 0.0;
		
		self.extraButtonsButton.alpha = 0.0;
		self.extraButtonsButton.enabled = NO;
		//extraButtons.alpha = 0.0;
		//songInfoView.alpha = 0.0;
		
		if (animated)
			[UIView commitAnimations];
		
		//[pageControlViewController viewWillAppear:NO];
	}
	else
	{
		self.songInfoToggleButton.userInteractionEnabled = YES;
		
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"player-overlay.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(songInfoToggle:)];
		
		// Flip the album art horizontally
		self.coverArtHolderView.transform = CGAffineTransformMakeScale(1, 1);
		
		if (animated)
		{
			[UIView beginAnimations:nil context:NULL];
			[UIView setAnimationDuration:0.4];
			[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:coverArtHolderView cache:YES];
			//[UIView setAnimationDelegate:self];
			//[UIView setAnimationDidStopSelector:@selector(releaseSongInfo:finished:context:)];
		}
		
		//[[[coverArtImageView subviews] lastObject] removeFromSuperview];
		[self.pageControlViewController.view removeFromSuperview];
		self.reflectionView.alpha = kDefaultReflectionOpacity;
		
		self.extraButtonsButton.alpha = 1.0;
		self.extraButtonsButton.enabled = YES;
		//extraButtons.alpha = 1.0;
		//songInfoView.alpha = 1.0;
		
		UIGraphicsEndImageContext();
		
		if (animated)
			[UIView commitAnimations];
		
		//[pageControlViewController resetScrollView];
		
		self.pageControlViewController = nil;
	}
	
	self.isFlipped = !self.isFlipped;
	
	if (saveState)
		settingsS.isPlayerPlaylistShowing = self.isFlipped;
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
	
	[self initSongInfo];
}

- (IBAction)nextButtonPressed:(id)sender
{
	[musicS nextSong];
	[self initSongInfo];
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
		largeOverlayView.alpha = 0.0;

		if (animated)
		{
			[UIView commitAnimations];
		}
		else
		{
			[extraButtons removeFromSuperview];
			[songInfoView removeFromSuperview];
			[largeOverlayView removeFromSuperview];
		}
	}
	else
	{
		[self.extraButtonsButton setImage:self.extraButtonsButtonOnImage forState:UIControlStateNormal];
		
		self.extraButtons.origin = extraButtonsHidden;
		self.extraButtons.width = self.coverArtHolderView.width;
		self.songInfoView.origin = songInfoViewHidden;
		self.songInfoView.width = self.coverArtHolderView.width;
		if (settingsS.isShowLargeSongInfoInPlayer)
		{
			//largeOverlayView.origin = CGPointMake(0, extraButtons.height);
			//largeOverlayView.width = coverArtImageView.width;
			self.largeOverlayView.frame = CGRectMake(0, extraButtons.height, coverArtImageView.width, coverArtImageView.height - extraButtons.height - songInfoView.height);
			self.largeOverlayView.alpha = 0.0;
			[self.coverArtImageView addSubview:self.largeOverlayView];
		}
		[self.coverArtHolderView addSubview:self.extraButtons];
		[self.coverArtHolderView addSubview:self.songInfoView];
		
		if (self.isFlipped)
			[self.coverArtHolderView bringSubviewToFront:self.pageControlViewController.view];
		
		[self updateFormatLabel];
		
		if (animated)
		{
			[UIView beginAnimations:nil context:nil];
			[UIView setAnimationDelegate:self];
			[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
			[UIView setAnimationDidStopSelector:@selector(toggleExtraButtonsAnimationDone)];
			[UIView setAnimationDuration:0.2];
		}
		
		self.extraButtons.origin = extraButtonsVisible;
		self.songInfoView.origin = songInfoViewVisible;
		self.largeOverlayView.alpha = 1.0;
		
		if (animated)
			[UIView commitAnimations];
	}
	
	self.isExtraButtonsShowing = !self.isExtraButtonsShowing;
	
	if (saveState)
		settingsS.isExtraPlayerControlsShowing = self.isExtraButtonsShowing;
}

- (void)toggleExtraButtonsAnimationDone
{
	if (!self.isExtraButtonsShowing)
	{
		[self.extraButtons removeFromSuperview];
		[self.songInfoView removeFromSuperview];
		[self.largeOverlayView removeFromSuperview];
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
		self.sliderMultipleLabel = [[UILabel alloc] initWithFrame:frame];
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
		
		byteOffset = audioEngineS.estimatedBitrate * 128 * progressSlider.value;
		DLog(@"bitrate: %i slider: %f byteOffset: %i localFileSize: %llu", audioEngineS.estimatedBitrate, progressSlider.value, byteOffset, currentSong.localFileSize);
		
		if (currentSong.isTempCached)
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
	
	[FlurryAnalytics logEvent:@"QuickSkip"];
}

- (IBAction)skipForward30:(id)sender
{
	CGFloat seconds = (CGFloat)settingsS.quickSkipNumberOfSeconds;
	progressSlider.value = progressSlider.value + seconds;
	[self movedSlider:nil];
	
	[FlurryAnalytics logEvent:@"QuickSkip"];
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
	[bookmarkNameTextField becomeFirstResponder];
}

- (void)saveBookmark
{
	// TODO: somehow this is saving the incorrect playlist index sometimes
	__block NSUInteger bookmarksCount;
	[databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO bookmarks (playlistIndex, name, position, %@, bytes) VALUES (?, ?, ?, %@, ?)", [Song standardSongColumnNames], [Song standardSongColumnQMarks]], [NSNumber numberWithInt:playlistS.currentIndex], bookmarkNameTextField.text, [NSNumber numberWithInt:bookmarkPosition], currentSong.title, currentSong.songId, currentSong.artist, currentSong.album, currentSong.genre, currentSong.coverArtId, currentSong.path, currentSong.suffix, currentSong.transcodedSuffix, currentSong.duration, currentSong.bitRate, currentSong.track, currentSong.year, currentSong.size, currentSong.parentId, [NSNumber numberWithUnsignedLongLong:bookmarkBytePosition]];
		
		NSInteger bookmarkId = [db intForQuery:@"SELECT MAX(bookmarkId) FROM bookmarks"]; 
		
		NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
		NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
		NSString *table = playlistS.isShuffle ? shufTable : currTable;
		DLog(@"table: %@", table);
		
		// Save the playlist
		NSString *dbName = viewObjectsS.isOfflineMode ? @"%@/offlineCurrentPlaylist.db" : @"%@/%@currentPlaylist.db";
		[db executeUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:dbName, settingsS.databasePath, settingsS.urlString.md5], @"currentPlaylistDb"];
		
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmark%i (%@)", bookmarkId, [Song standardSongColumnSchema]]];
		
		[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO bookmark%i SELECT * FROM currentPlaylistDb.%@", bookmarkId, table]]; 
		
		bookmarksCount = [db intForQuery:@"SELECT COUNT(*) FROM bookmarks WHERE songId = ?", currentSong.songId];
		
		[db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
	}];
	
	bookmarkCountLabel.text = [NSString stringWithFormat:@"%i", bookmarksCount];
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
			__block BOOL exists;
			[databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db)
			{
				exists = [db intForQuery:@"SELECT COUNT(*) FROM bookmarks WHERE name = ? LIMIT 1", bookmarkNameTextField.text];
			}];
			
			// Check if the bookmark exists
			if (exists)
			{
				// Bookmark exists so ask to overwrite
				UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Overwrite?" message:@"There is already a bookmark with this name. Overwrite it?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
				[myAlertView show];
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
			[databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db)
			{
				NSUInteger bookmarkId = [db intForQuery:@"SELECT bookmarkId FROM bookmarks WHERE name = ?", bookmarkNameTextField.text];
				
				[db executeUpdate:@"DELETE FROM bookmarks WHERE name = ?", bookmarkNameTextField.text];
				[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS bookmark%i", bookmarkId]];
			}];
			
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
		[shuffleButton setImage:[UIImage imageNamed:@"controller-shuffle-on.png"] forState:0];
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
			// Handle the case where Subsonic didn't detect the song length
			if ((!currentSong.duration || [currentSong.duration intValue] <= 0) &&
					 currentSong.isFullyCached && audioEngineS.isStarted)
			{
				progressSlider.maximumValue = audioEngineS.currentStreamDuration;
				progressSlider.enabled = YES;
			}
			
			double progress = 0;
			if (audioEngineS.isPlaying)
				progress = audioEngineS.progress;
			else
				progress = [currentSong isEqualToSong:audioEngineS.currentStreamSong] ? audioEngineS.progress : 0.;
			
			if (lastProgress != ceil(progress))
			{
				lastProgress = ceil(progress);
				
				NSString *elapsedTime = [NSString formatTime:progress];
				NSString *remainingTime = [NSString formatTime:([currentSong.duration doubleValue] - progress)];
				
				// Handle the case where Subsonic didn't detect the song length
				if ((!currentSong.duration || [currentSong.duration intValue] <= 0) &&
					currentSong.isFullyCached && audioEngineS.isStarted)
				{
					remainingTime = [NSString formatTime:(audioEngineS.currentStreamDuration - progress)];
				}
				
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
}


@end
