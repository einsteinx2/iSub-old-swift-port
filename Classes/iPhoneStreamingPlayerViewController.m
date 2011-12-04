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
#import "SongInfoViewController.h"
#import "PageControlViewController.h"
#import "CoverArtImageView.h"
#import "Song.h"
#import <QuartzCore/CoreAnimation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <CFNetwork/CFNetwork.h>
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString+md5.h"
#import "UIView+tools.h"
#import <QuartzCore/QuartzCore.h>
#import "SavedSettings.h"
#import "SUSCurrentPlaylistDAO.h"
#import "BassWrapperSingleton.h"
#import "EqualizerViewController.h"
#import "SUSCoverArtLargeDAO.h"
//#import "MarqueeLabel.h"


@interface iPhoneStreamingPlayerViewController ()

@property (nonatomic, retain) UIImageView *reflectionView;

- (UIImage *)reflectedImage:(UIImageView *)fromImage withHeight:(NSUInteger)height;

- (void)setupCoverArt;
- (void)initSongInfo;
- (void)setStopButtonImage;
- (void)setPlayButtonImage;
- (void)setPauseButtonImage;
- (void)updateBarButtonImage;

@end

@implementation iPhoneStreamingPlayerViewController

@synthesize listOfSongs, reflectionView;

static const CGFloat kDefaultReflectionFraction = 0.30;
static const CGFloat kDefaultReflectionOpacity = 0.55;

#pragma mark -
#pragma mark Controller Life Cycle

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{	
	NSString *name;
	if (IS_IPAD())
	{
		name = @"iPhoneStreamingPlayerViewController~iPad";
	}
	else
	{
		name = @"iPhoneStreamingPlayerViewController";
	}
	
	self = [super initWithNibName:name bundle:nil];
	
	return self;
}

- (void)viewDidLoad2
{
    //musicControls.songUrl = [NSURL URLWithString:[appDelegate getStreamURLStringForSongId:musicControls.currentSongObject.songId]];
	
	//if([[appDelegate.settingsDictionary objectForKey:@"autoPlayerInfoSetting"] isEqualToString:@"YES"])
	if ([SavedSettings sharedInstance].isAutoShowSongInfoEnabled)
	{
		[self songInfoToggle:nil];
	}
	
	[self initSongInfo];
	
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		CGRect frame = volumeSlider.bounds;
		frame.size.height = volumeSlider.bounds.size.height / 2;
		jukeboxVolumeView = [[[UISlider alloc] initWithFrame:frame] autorelease];
		[jukeboxVolumeView addTarget:self action:@selector(jukeboxVolumeChanged:) forControlEvents:UIControlEventValueChanged];
		jukeboxVolumeView.minimumValue = 0.0;
		jukeboxVolumeView.maximumValue = 1.0;
		jukeboxVolumeView.continuous = NO;
		jukeboxVolumeView.value = musicControls.jukeboxGain;
		[volumeSlider addSubview:jukeboxVolumeView];
	}
	else
	{
		volumeView = [[[MPVolumeView alloc] initWithFrame:volumeSlider.bounds] autorelease];
		[volumeSlider addSubview:volumeView];
		[volumeView sizeToFit];
	}
	
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		if (musicControls.jukeboxIsPlaying)
			[self setStopButtonImage];
		else 
			[self setPlayButtonImage];
	}
	else
	{
		if(bassWrapper.isPlaying)
			[self setPauseButtonImage];
		else
			[self setPlayButtonImage];
	}
	
	// determine the size of the reflection to create
	reflectionHeight = coverArtImageView.bounds.size.height * kDefaultReflectionFraction;
	[reflectionView newHeight:(float)reflectionHeight];
	
	// create the reflection image and assign it to the UIImageView
	reflectionView.image = [self reflectedImage:coverArtImageView withHeight:reflectionHeight];
	reflectionView.alpha = kDefaultReflectionOpacity;
	
	if (isFlipped)
		reflectionView.alpha = 0.0;
    
    [activityIndicator stopAnimating];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	//[coverArtImageView.layer setCornerRadius:20];
	
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	musicControls = [MusicSingleton sharedInstance];
	databaseControls = [DatabaseSingleton sharedInstance];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	
	bassWrapper = [BassWrapperSingleton sharedInstance];
	
	pageControlViewController = nil;
	
	isFlipped = NO;
	
	if (!IS_IPAD())
		self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"back.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(backAction:)] autorelease];
	
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"player-overlay.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(songInfoToggle:)] autorelease];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setPlayButtonImage) name:ISMSNotification_SongPlaybackEnded object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setPlayButtonImage) name:ISMSNotification_SongPlaybackPaused object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setPauseButtonImage) name:ISMSNotification_SongPlaybackStarted object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initSongInfo) name:ISMSNotification_SongPlaybackStarted object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initSongInfo) name:ISMSNotification_ServerSwitched object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupCoverArt) name:ISMSNotification_AlbumArtLargeDownloaded object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(songInfoToggle:) name:@"hideSongInfo" object:nil];
	
	
	// Setup landscape orientation if necessary
	if (!IS_IPAD())
	{
		artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(310, 50, 170, 30)];
		artistLabel.backgroundColor = [UIColor clearColor];
		artistLabel.textColor = [UIColor whiteColor];
		artistLabel.font = [UIFont boldSystemFontOfSize:24];
		artistLabel.adjustsFontSizeToFitWidth = YES;
		artistLabel.textAlignment = UITextAlignmentCenter;
		[self.view addSubview:artistLabel];
		[self.view sendSubviewToBack:artistLabel];
		[artistLabel release];
		
		albumLabel = [[UILabel alloc] initWithFrame:CGRectMake(310, 80, 170, 30)];
		albumLabel.backgroundColor = [UIColor clearColor];
		albumLabel.textColor = [UIColor whiteColor];
		albumLabel.font = [UIFont systemFontOfSize:24];
		albumLabel.adjustsFontSizeToFitWidth = YES;
		albumLabel.textAlignment = UITextAlignmentCenter;
		[self.view addSubview:albumLabel];
		[self.view sendSubviewToBack:albumLabel];
		[albumLabel release];
		
		titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(310, 110, 170, 30)];
		titleLabel.backgroundColor = [UIColor clearColor];
		titleLabel.textColor = [UIColor whiteColor];
		titleLabel.font = [UIFont boldSystemFontOfSize:24];
		titleLabel.adjustsFontSizeToFitWidth = YES;
		titleLabel.textAlignment = UITextAlignmentCenter;
		[self.view addSubview:titleLabel];
		[self.view sendSubviewToBack:titleLabel];
		[titleLabel	release];
		
		if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
		{
			coverArtImageView.frame = CGRectMake(0, 0, 300, 300);
			prevButton.frame = CGRectMake(290, 184, 72, 60);
			playButton.frame = CGRectMake(357.5, 184, 72, 60);
			nextButton.frame = CGRectMake(420, 184, 72, 60);
			volumeSlider.frame = CGRectMake(300, 244, 180, 55);
			volumeView.frame = CGRectMake(0, 0, 180, 55);
		}
		else
		{
			artistLabel.hidden = YES;
			albumLabel.hidden = YES;
			titleLabel.hidden = YES;
			
			//[self setSongTitle];
		}
	}
	
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		//[viewObjects showLoadingScreen:self.view.superview blockInput:YES mainWindow:NO];
		//[self performSelectorInBackground:@selector(loadJukeboxInfo) withObject:nil];
		[musicControls jukeboxGetInfo];
		
		self.view.backgroundColor = viewObjects.jukeboxColor;
	}
	
	[self viewDidLoad2];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		//[viewObjects showLoadingScreen:self.view.superview blockInput:YES mainWindow:NO];
		//[self performSelectorInBackground:@selector(loadJukeboxInfo) withObject:nil];
		[musicControls jukeboxGetInfo];
		
		self.view.backgroundColor = viewObjects.jukeboxColor;
	}
	else 
	{
		self.view.backgroundColor = [UIColor blackColor]; 
	}
	
}


- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	
	//[[UIApplication sharedApplication] setStatusBarHidden:NO animated:NO];
	//[[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"hideSongInfoFast" object:nil];
}

#pragma mark Memory Management


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

//
// dealloc
//
// Releases instance memory.
//
- (void)dealloc
{	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_SongPlaybackEnded object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_SongPlaybackPaused object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_SongPlaybackStarted object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_AlbumArtLargeDownloaded object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_ServerSwitched object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideSongInfo" object:nil];
	
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
	[super dealloc];
}

#pragma mark Rotation

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
	//[[NSNotificationCenter defaultCenter] postNotificationName:@"hideSongInfoFast" object:nil];
	if (isFlipped)
		[self songInfoToggle:nil];
	
	if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
	{
		[self setSongTitle];
	}
	
	if (!IS_IPAD())
	{
		if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
		{
			coverArtImageView.frame = CGRectMake(0, 0, 320, 320);
			prevButton.frame = CGRectMake(13, 324, 72, 60);
			playButton.frame = CGRectMake(123, 324, 72, 60);
			nextButton.frame = CGRectMake(228, 324, 72, 60);
			volumeSlider.frame = CGRectMake(20, 384, 280, 55);
			
			if ([SavedSettings sharedInstance].isJukeboxEnabled)
				jukeboxVolumeView.frame = CGRectMake(0, 0, 280, 22.5);
			else
				volumeView.frame = CGRectMake(0, 0, 280, 55);
			
			//[self setSongTitle];
			//[self.navigationItem.titleView addX:-100.0];
			
			artistLabel.hidden = YES;
			albumLabel.hidden = YES;
			titleLabel.hidden = YES;
		}
		else if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
		{
			coverArtImageView.frame = CGRectMake(0, 0, 300, 300);
			prevButton.frame = CGRectMake(290, 184, 72, 60);
			playButton.frame = CGRectMake(357.5, 184, 72, 60);
			nextButton.frame = CGRectMake(420, 184, 72, 60);
			volumeSlider.frame = CGRectMake(300, 244, 180, 55);
			
			if ([SavedSettings sharedInstance].isJukeboxEnabled)
				jukeboxVolumeView.frame = CGRectMake(0, 0, 180, 22.5);
			else
				volumeView.frame = CGRectMake(0, 0, 180, 55);
			
			self.navigationItem.titleView = nil;
			
			artistLabel.hidden = NO;
			albumLabel.hidden = NO;
			titleLabel.hidden = NO;
		}
	}
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	
	if (UIInterfaceOrientationIsLandscape(fromInterfaceOrientation))
	{
		[self setSongTitle];
	}
}

#pragma mark Main

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
 

- (void)setSongTitle
{
	if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation) || IS_IPAD())
	{
		self.navigationItem.titleView = nil;
		
		float width;
		if (IS_IPAD())
			width = 400;
		else
			width = 180;
		
		UIView *titleView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 40)] autorelease];
		titleView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		
		CGRect artistFrame = CGRectMake(0, -2, width, 15);
		CGRect songFrame   = CGRectMake(0, 10, width, 15);
		CGRect albumFrame  = CGRectMake(0, 23, width, 15);
		
		NSUInteger artistSize = 12;
		NSUInteger albumSize  = 11;
		NSUInteger songSize   = 12;
		
		UILabel *artist = [[UILabel alloc] initWithFrame:artistFrame];
		artist.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		artist.backgroundColor = [UIColor clearColor];
		artist.textColor = [UIColor colorWithWhite:.7 alpha:1.];
		artist.font = [UIFont boldSystemFontOfSize:artistSize];
		artist.textAlignment = UITextAlignmentCenter;
		[titleView addSubview:artist];
		[artist release];
		
		UILabel *song = [[UILabel alloc] initWithFrame:songFrame];
		//MarqueeLabel *song = [[MarqueeLabel alloc] initWithFrame:songFrame andRate:50.0 andBufer:6.0];
		song.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		song.backgroundColor = [UIColor clearColor];
		song.textColor = [UIColor whiteColor];
		song.font = [UIFont boldSystemFontOfSize:songSize];
		song.textAlignment = UITextAlignmentCenter;
		[titleView addSubview:song];
		[song release];
		
		UILabel *album = [[UILabel alloc] initWithFrame:albumFrame];
		album.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		album.backgroundColor = [UIColor clearColor];
		album.textColor = [UIColor colorWithWhite:.7 alpha:1.];
		album.font = [UIFont boldSystemFontOfSize:albumSize];
		album.textAlignment = UITextAlignmentCenter;
		[titleView addSubview:album];
		[album release];
		
		SUSCurrentPlaylistDAO *dataModel = [SUSCurrentPlaylistDAO dataModel];
		Song *currentSong = dataModel.currentSong;
		
		artist.text = [[currentSong.artist copy] autorelease];
		album.text = [[currentSong.album copy] autorelease];
		song.text = [[currentSong.title copy] autorelease];
		
		self.navigationItem.titleView = titleView;		
	}
}

- (void)initSongInfo
{	
    [self setSongTitle];
    
    [self setupCoverArt];
    
	SUSCurrentPlaylistDAO *dataModel = [SUSCurrentPlaylistDAO dataModel];
	Song *currentSong = dataModel.currentSong;
    
	// Update the icon in top right
	if (isFlipped)
	{
		DLog(@"Updating the top right button");
		[self updateBarButtonImage];
	}
	
	artistLabel.text = [[currentSong.artist copy] autorelease];
	albumLabel.text = [[currentSong.album copy] autorelease];
	titleLabel.text = [[currentSong.title copy] autorelease];
	
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		jukeboxVolumeView.value = musicControls.jukeboxGain;
		
		if (musicControls.jukeboxIsPlaying)
			[self setStopButtonImage];
		else 
			[self setPlayButtonImage];
	}
}

/*- (void)loadJukeboxInfo
{
	NSAutoreleasePool *releasePool = [[NSAutoreleasePool alloc] init];
	
	[musicControls jukeboxGetInfo];
		
	//[viewObjects performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:YES];
	
	[self performSelectorOnMainThread:@selector(viewDidLoad2) withObject:nil waitUntilDone:NO];
	
	[releasePool release];
}*/

- (void)jukeboxVolumeChanged:(id)sender
{
	[musicControls jukeboxSetVolume:jukeboxVolumeView.value];
}

- (void)backAction:(id)sender
{
	NSArray *viewControllers = self.navigationController.viewControllers;
	NSInteger count = [viewControllers count];
	
	UIViewController *backVC = [viewControllers objectAtIndex:(count - 2)];
	
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

- (IBAction)songInfoToggle:(id)sender
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
		coverArtImageView.transform = CGAffineTransformMakeScale(-1, 1);
		pageControlViewController.view.transform = CGAffineTransformMakeScale(-1, 1);
				
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.40];
		[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:coverArtImageView cache:YES];
		
		//[pageControlViewController resetScrollView];
		[coverArtImageView addSubview:pageControlViewController.view];
		[reflectionView setAlpha:0.0];
		
		[UIView commitAnimations];
		
		//[pageControlViewController viewWillAppear:NO];
	}
	else
	{
		songInfoToggleButton.userInteractionEnabled = YES;
		
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"player-overlay.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(songInfoToggle:)] autorelease];
		
		// Flip the album art horizontally
		coverArtImageView.transform = CGAffineTransformMakeScale(1, 1);
		
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.4];
		[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:coverArtImageView cache:YES];
		//[UIView setAnimationDelegate:self];
		//[UIView setAnimationDidStopSelector:@selector(releaseSongInfo:finished:context:)];
		
		//[[[coverArtImageView subviews] lastObject] removeFromSuperview];
		[pageControlViewController.view removeFromSuperview];
		[reflectionView setAlpha:kDefaultReflectionOpacity];
		
		UIGraphicsEndImageContext();
		
		[UIView commitAnimations];
		
		//[pageControlViewController resetScrollView];
		
		[pageControlViewController release]; pageControlViewController = nil;
	}
	
	isFlipped = !isFlipped;
}

/*- (void)releaseSongInfo:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
	NSLog(@"releaseSongInfo called");
	[pageControlViewController release]; pageControlViewController = nil;
}*/


- (IBAction)playButtonPressed:(id)sender
{
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		if (musicControls.jukeboxIsPlaying)
			[musicControls jukeboxStop];
		else
			[musicControls jukeboxPlay];
	}
	else
	{
		[bassWrapper playPause];
	}
}

- (IBAction)prevButtonPressed:(id)sender
{
	SUSCurrentPlaylistDAO *dataModel = [SUSCurrentPlaylistDAO dataModel];
	
	DLog(@"track position: %f", bassWrapper.progress);
	if (bassWrapper.progress > 10.0)
	{
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
			[musicControls jukeboxPlaySongAtPosition:dataModel.currentIndex];
		else
			[musicControls playSongAtPosition:dataModel.currentIndex];
	}
	else
	{
		[musicControls prevSong];
	}
}

- (IBAction)nextButtonPressed:(id)sender
{
	[musicControls nextSong];
}

#pragma mark Image Reflection

CGImageRef CreateGradientImagePlayer(int pixelsWide, int pixelsHigh)
{
	CGImageRef theCGImage = NULL;
	
	// gradient is always black-white and the mask must be in the gray colorspace
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
	
	// create the bitmap context
	CGContextRef gradientBitmapContext = CGBitmapContextCreate(NULL, pixelsWide, pixelsHigh,
															   8, 0, colorSpace, kCGImageAlphaNone);
	
	// define the start and end grayscale values (with the alpha, even though
	// our bitmap context doesn't support alpha the gradient requires it)
	CGFloat colors[] = {0.0, 1.0, 1.0, 1.0};
	
	// create the CGGradient and then release the gray color space
	CGGradientRef grayScaleGradient = CGGradientCreateWithColorComponents(colorSpace, colors, NULL, 2);
	CGColorSpaceRelease(colorSpace);
	
	// create the start and end points for the gradient vector (straight down)
	CGPoint gradientStartPoint = CGPointZero;
	CGPoint gradientEndPoint = CGPointMake(0, pixelsHigh);
	
	// draw the gradient into the gray bitmap context
	CGContextDrawLinearGradient(gradientBitmapContext, grayScaleGradient, gradientStartPoint,
								gradientEndPoint, kCGGradientDrawsAfterEndLocation);
	CGGradientRelease(grayScaleGradient);
	
	// convert the context into a CGImageRef and release the context
	theCGImage = CGBitmapContextCreateImage(gradientBitmapContext);
	CGContextRelease(gradientBitmapContext);
	
	// return the imageref containing the gradient
    return theCGImage;
}

CGContextRef MyCreateBitmapContextPlayer(int pixelsWide, int pixelsHigh)
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	
	// create the bitmap context
	CGContextRef bitmapContext = CGBitmapContextCreate (NULL, pixelsWide, pixelsHigh, 8,
														0, colorSpace,
														// this will give us an optimal BGRA format for the device:
														(kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst));
	CGColorSpaceRelease(colorSpace);
	
    return bitmapContext;
}

- (UIImage *)reflectedImage:(UIImageView *)fromImage withHeight:(NSUInteger)height
{
    if(height == 0)
		return nil;
    
	// create a bitmap graphics context the size of the image
	CGContextRef mainViewContentContext = MyCreateBitmapContextPlayer(fromImage.bounds.size.width, height);
	
	// create a 2 bit CGImage containing a gradient that will be used for masking the 
	// main view content to create the 'fade' of the reflection.  The CGImageCreateWithMask
	// function will stretch the bitmap image as required, so we can create a 1 pixel wide gradient
	CGImageRef gradientMaskImage = CreateGradientImagePlayer(1, height);
	
	// create an image by masking the bitmap of the mainView content with the gradient view
	// then release the  pre-masked content bitmap and the gradient bitmap
	CGContextClipToMask(mainViewContentContext, CGRectMake(0.0, 0.0, fromImage.bounds.size.width, height), gradientMaskImage);
	CGImageRelease(gradientMaskImage);
	
	// In order to grab the part of the image that we want to render, we move the context origin to the
	// height of the image that we want to capture, then we flip the context so that the image draws upside down.
	CGContextTranslateCTM(mainViewContentContext, 0.0, height);
	CGContextScaleCTM(mainViewContentContext, 1.0, -1.0);
	
	// draw the image into the bitmap context
	CGContextDrawImage(mainViewContentContext, fromImage.bounds, fromImage.image.CGImage);
	
	// create CGImageRef of the main view bitmap content, and then release that bitmap context
	CGImageRef reflectionImage = CGBitmapContextCreateImage(mainViewContentContext);
	CGContextRelease(mainViewContentContext);
	
	// convert the finished reflection image to a UIImage 
	UIImage *theImage = [UIImage imageWithCGImage:reflectionImage];
	
	// image is retained by the property setting above, so we can release the original
	CGImageRelease(reflectionImage);
	
	return theImage;
}

- (void)setupCoverArt
{
    SUSCurrentPlaylistDAO *dataModel = [SUSCurrentPlaylistDAO dataModel];
    SUSCoverArtLargeDAO *artDataModel = [SUSCoverArtLargeDAO dataModel];
	Song *currentSong = dataModel.currentSong;
    
    // Get the album art
	if(currentSong.coverArtId)
	{
        UIImage *albumArt = [artDataModel coverArtImageForId:currentSong.coverArtId];
        if (albumArt)
        {
            coverArtImageView.image = albumArt;
            //[activityIndicator stopAnimating];
        }
        else
        {
            coverArtImageView.image = artDataModel.defaultCoverArt;
            //[activityIndicator startAnimating];
        }
	}
	else 
	{
        coverArtImageView.image = artDataModel.defaultCoverArt;		
        //[activityIndicator stopAnimating];
	}

    // Create reflection
	if (isFlipped)
	{
		[self updateBarButtonImage];
	}
	else
	{
		//DLog(@"It's not flipped, creating the reflection");
		// create the reflection image and assign it to the UIImageView
		reflectionView.image = [self reflectedImage:coverArtImageView withHeight:reflectionHeight];
		reflectionView.alpha = kDefaultReflectionOpacity;
	}
}

- (IBAction)showEq:(id)sender
{
	if (isFlipped)
		[self songInfoToggle:nil];
	
	EqualizerViewController *eqView = [[EqualizerViewController alloc] initWithNibName:@"EqualizerViewController" bundle:nil];
	eqView.modalPresentationStyle = UIModalPresentationFormSheet;
	[self presentModalViewController:eqView animated:YES];
	[eqView release];
	//[appDelegate.currentTabBarController presentModalViewController:eqView animated:NO];
	
	//[self songInfoToggle];
}


@end
