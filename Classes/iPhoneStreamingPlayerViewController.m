//
//  iPhoneStreamingPlayerViewController.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "iSubAppDelegate.h"
#import "MusicControlsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "ViewObjectsSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "SongInfoViewController.h"
#import "PageControlViewController.h"
#import "AudioStreamer.h"
#import "CoverArtImageView.h"
#import "Song.h"
#import <QuartzCore/CoreAnimation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <CFNetwork/CFNetwork.h>
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString-md5.h"
#import "UIView-tools.h"
#import <QuartzCore/QuartzCore.h>


@interface iPhoneStreamingPlayerViewController ()

@property (nonatomic, retain) UIImageView *reflectionView;

- (UIImage *)reflectedImage:(UIImageView *)fromImage withHeight:(NSUInteger)height;

- (void)createReflection;
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
	musicControls.songUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"stream.view"], [musicControls.currentSongObject songId]]];
	
	[self initSongInfo];
	
	if (viewObjects.isJukebox)
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
	
	if (viewObjects.isJukebox)
	{
		if (musicControls.jukeboxIsPlaying)
			[self setStopButtonImage];
		else 
			[self setPlayButtonImage];
	}
	else
	{
		if(musicControls.isNewSong)
		{
			[self setPlayButtonImage];
		}
		else
		{
			if([musicControls.streamer isPlaying])
				[self setPauseButtonImage];
			else
				[self setPlayButtonImage];
		}		
	}
	
	// determine the size of the reflection to create
	reflectionHeight = coverArtImageView.bounds.size.height * kDefaultReflectionFraction;
	[reflectionView newHeight:(float)reflectionHeight];
	
	// create the reflection image and assign it to the UIImageView
	reflectionView.image = [self reflectedImage:coverArtImageView withHeight:reflectionHeight];
	reflectionView.alpha = kDefaultReflectionOpacity;
	
	if([[appDelegate.settingsDictionary objectForKey:@"autoPlayerInfoSetting"] isEqualToString:@"YES"])
	{
		[self songInfoToggle:nil];
	}
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	//[coverArtImageView.layer setCornerRadius:20];
	
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	musicControls = [MusicControlsSingleton sharedInstance];
	databaseControls = [DatabaseControlsSingleton sharedInstance];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	
	isFlipped = NO;
	
	if (!IS_IPAD())
		self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"back.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(backAction:)] autorelease];
	
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"player-overlay.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(songInfoToggle:)] autorelease];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setPlayButtonImage) name:@"setPlayButtonImage" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setPauseButtonImage) name:@"setPauseButtonImage" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setSongTitle) name:@"setSongTitle" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initSongInfo) name:@"initSongInfo" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createReflection) name:@"createReflection" object:nil];
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
			
			[self setSongTitle];
		}
	}
	
	if (viewObjects.isJukebox)
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
	
	if (viewObjects.isJukebox)
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
	
	[[UIApplication sharedApplication] setStatusBarHidden:NO animated:NO];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"hideSongInfoFast" object:nil];
}

- (void)viewDidUnload
{
	[super viewDidUnload];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"setPlayButtonImage" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"setPauseButtonImage" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"setSongTitle" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"initSongInfo" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"createReflection" object:nil];
}

#pragma mark Rotation

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	//[[NSNotificationCenter defaultCenter] postNotificationName:@"hideSongInfoFast" object:nil];
	if (isFlipped)
		[self songInfoToggle:nil];
	
	if (!IS_IPAD())
	{
		if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
		{
			coverArtImageView.frame = CGRectMake(0, 0, 320, 320);
			prevButton.frame = CGRectMake(13, 324, 72, 60);
			playButton.frame = CGRectMake(123, 324, 72, 60);
			nextButton.frame = CGRectMake(228, 324, 72, 60);
			volumeSlider.frame = CGRectMake(20, 384, 280, 55);
			
			if (viewObjects.isJukebox)
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
			
			if (viewObjects.isJukebox)
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
	self.navigationItem.titleView = nil;
	
	float width;
	if (IS_IPAD())
		width = 400;
	else
		width = 180;
	
	UIView *titleView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 40)] autorelease];
	titleView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	
	CGRect artistFrame = CGRectMake(0, -2, width, 15);
	CGRect albumFrame  = CGRectMake(0, 10, width, 15);
	CGRect songFrame   = CGRectMake(0, 23, width, 15);
	
	NSUInteger artistSize = 12;
	NSUInteger albumSize  = 11;
	NSUInteger songSize   = 12;
	
	UILabel *artist = [[UILabel alloc] initWithFrame:artistFrame];
	artist.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	artist.backgroundColor = [UIColor clearColor];
	artist.textColor = [UIColor whiteColor];
	artist.font = [UIFont boldSystemFontOfSize:artistSize];
	//artist.adjustsFontSizeToFitWidth = YES;
	artist.textAlignment = UITextAlignmentCenter;
	[titleView addSubview:artist];
	[artist release];
	
	UILabel *album = [[UILabel alloc] initWithFrame:albumFrame];
	album.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	album.backgroundColor = [UIColor clearColor];
	album.textColor = [UIColor whiteColor];
	album.font = [UIFont systemFontOfSize:albumSize];
	//album.adjustsFontSizeToFitWidth = YES;
	album.textAlignment = UITextAlignmentCenter;
	[titleView addSubview:album];
	[album release];
	
	UILabel *song = [[UILabel alloc] initWithFrame:songFrame];
	song.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	song.backgroundColor = [UIColor clearColor];
	song.textColor = [UIColor whiteColor];
	song.font = [UIFont boldSystemFontOfSize:songSize];
	//song.adjustsFontSizeToFitWidth = YES;
	song.textAlignment = UITextAlignmentCenter;
	[titleView addSubview:song];
	[song release];
	
	artist.text = [musicControls.currentSongObject artist];
	album.text = [musicControls.currentSongObject album];
	song.text = [musicControls.currentSongObject title];
	
	self.navigationItem.titleView = titleView;
	
	//self.title = [musicControls.currentSongObject title];
}

- (void)initSongInfo
{	
	coverArtImageView.isForPlayer = YES;
	if([musicControls.currentSongObject coverArtId])
	{
		//NSLog(@"coverArtId: %@", [musicControls.currentSongObject coverArtId]);
		
		FMDatabase *coverArtCache;
		if (IS_IPAD())
			coverArtCache = databaseControls.coverArtCacheDb540;
		else
			coverArtCache = databaseControls.coverArtCacheDb320;
			
		if ([coverArtCache intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [NSString md5:musicControls.currentSongObject.coverArtId]] == 1)
		{
			NSData *imageData = [coverArtCache dataForQuery:@"SELECT data FROM coverArtCache WHERE id = ?", [NSString md5:musicControls.currentSongObject.coverArtId]];
			if (appDelegate.isHighRez)
			{
				UIGraphicsBeginImageContextWithOptions(CGSizeMake(320.0,320.0), NO, 2.0);
				[[UIImage imageWithData:imageData] drawInRect:CGRectMake(0,0,320,320)];
				coverArtImageView.image = UIGraphicsGetImageFromCurrentImageContext();
				UIGraphicsEndImageContext();
				//coverArtImageView.image = [[UIImage imageWithData:imageData] drawInRect:CGRectMake(0,0,320,320)];
			}
			else
			{
				coverArtImageView.image = [UIImage imageWithData:imageData];
			}
		}
		else 
		{
			/*musicControls.coverArtUrl = nil;
			if (appDelegate.isHighRez)
			{
				musicControls.coverArtUrl = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@%@&size=640", [appDelegate getBaseUrl:@"getCoverArt.view"], musicControls.currentSongObject.coverArtId]];
			}
			else
			{	
				musicControls.coverArtUrl = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@%@&size=320", [appDelegate getBaseUrl:@"getCoverArt.view"], musicControls.currentSongObject.coverArtId]];
			}
			NSLog(@"covertArt URL: %@", [musicControls.coverArtUrl absoluteString]);
			[coverArtImageView loadImageFromURLString:[musicControls.coverArtUrl absoluteString]];*/
			[coverArtImageView loadImageFromCoverArtId:musicControls.currentSongObject.coverArtId isForPlayer:YES];
		}
	}
	else 
	{
		if (IS_IPAD())
			coverArtImageView.image = [UIImage imageNamed:@"default-album-art-ipad.png"];
		else
			coverArtImageView.image = [UIImage imageNamed:@"default-album-art.png"];
	}
	
	// Update the icon in top right
	if (isFlipped)
		[self updateBarButtonImage];
	
	// create the reflection image and assign it to the UIImageView
	reflectionView.image = [self reflectedImage:coverArtImageView withHeight:reflectionHeight];
	if (isFlipped)
		reflectionView.alpha = 0.0;
	else
		reflectionView.alpha = kDefaultReflectionOpacity;
	
	artistLabel.text = [musicControls currentSongObject].artist;
	albumLabel.text = [musicControls currentSongObject].album;
	titleLabel.text = [musicControls currentSongObject].title;
	
	if (viewObjects.isJukebox)
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
		
		PageControlViewController *pageControlViewController = [[PageControlViewController alloc] initWithNibName:@"PageControlViewController" bundle:nil];
		pageControlViewController.view.frame = CGRectMake (0, 0, coverArtImageView.frame.size.width, coverArtImageView.frame.size.height);
		
		// Set the icon in the top right
		[self updateBarButtonImage];
		
		// Flip the album art horizontally
		coverArtImageView.transform = CGAffineTransformMakeScale(-1, 1);
		pageControlViewController.view.transform = CGAffineTransformMakeScale(-1, 1);
				
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.40];
		[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:coverArtImageView cache:YES];
		
		[coverArtImageView addSubview:pageControlViewController.view];
		[reflectionView setAlpha:0.0];
		
		[UIView commitAnimations];
		
		[pageControlViewController viewWillAppear:NO];
	}
	else
	{
		songInfoToggleButton.userInteractionEnabled = YES;
		
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"player-overlay.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(songInfoToggle:)] autorelease];
		
		// Flip the album art horizontally
		coverArtImageView.transform = CGAffineTransformMakeScale(1, 1);
		
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.5];
		[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:coverArtImageView cache:YES];
		
		[[[coverArtImageView subviews] lastObject] removeFromSuperview];
		[reflectionView setAlpha:kDefaultReflectionOpacity];
		
		UIGraphicsEndImageContext();
		
		[UIView commitAnimations];
	}
	
	isFlipped = !isFlipped;
}


- (IBAction)playButtonPressed:(id)sender
{
	if (viewObjects.isJukebox)
	{
		if (musicControls.jukeboxIsPlaying)
			[musicControls jukeboxStop];
		else
			[musicControls jukeboxPlay];
	}
	else
	{
		[musicControls playPauseSong];
	}
}

- (IBAction)prevButtonPressed:(id)sender
{
	musicControls.streamerProgress = [musicControls.streamer progress];
	NSLog(@"track position: %f", (musicControls.streamerProgress + musicControls.seekTime));
	if ((musicControls.streamerProgress + musicControls.seekTime) > 10.0)
	{
		if (viewObjects.isJukebox)
			[musicControls jukeboxPlaySongAtPosition:musicControls.currentPlaylistPosition];
		else
			[musicControls playSongAtPosition:musicControls.currentPlaylistPosition];
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

CGImageRef CreateGradientImage(int pixelsWide, int pixelsHigh)
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

CGContextRef MyCreateBitmapContext(int pixelsWide, int pixelsHigh)
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
	CGContextRef mainViewContentContext = MyCreateBitmapContext(fromImage.bounds.size.width, height);
	
	// create a 2 bit CGImage containing a gradient that will be used for masking the 
	// main view content to create the 'fade' of the reflection.  The CGImageCreateWithMask
	// function will stretch the bitmap image as required, so we can create a 1 pixel wide gradient
	CGImageRef gradientMaskImage = CreateGradientImage(1, height);
	
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

- (void)createReflection
{
	// create the reflection image and assign it to the UIImageView
	reflectionView.image = [self reflectedImage:coverArtImageView withHeight:reflectionHeight];
	reflectionView.alpha = kDefaultReflectionOpacity;
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
	[playButton release];
	[nextButton release];
	[prevButton release];
	[volumeSlider release];
	[coverArtImageView release];
	[songInfoToggleButton release];

	[super dealloc];
}

@end
