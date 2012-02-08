//
//  SongInfoViewController.m
//  iSub
//
//  Created by Ben Baron on 3/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SongInfoViewController.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "iSubAppDelegate.h"
#import "math.h"
#import "Song.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString+md5.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+tools.h"
#import "CustomUIAlertView.h"
#import "OBSlider.h"
#import "UIView+tools.h"
#import "SavedSettings.h"
#import "NSString+time.h"
#import "SUSStreamSingleton.h"
#import "PlaylistSingleton.h"
#import "AudioEngine.h"
#import "NSArray+FirstObject.h"
#import "SUSStreamHandler.h"
#import "EqualizerViewController.h"

@implementation SongInfoViewController
@synthesize artistLabel, albumLabel, titleLabel, trackLabel, yearLabel, genreLabel, bitRateLabel, lengthLabel, currentSong, songInfoToggleButton;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{	
	NSString *name;
	if (IS_IPAD())
	{
		name = @"SongInfoViewController-iPad";
	}
	else
	{
		name = @"SongInfoViewController";
	}
	
	self = [super initWithNibName:name bundle:nil];
	
	return self;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicSingleton sharedInstance];
	databaseControls = [DatabaseSingleton sharedInstance];
    audio = [AudioEngine sharedInstance];

	/////////// RESIZE PROGRESS SLIDER
	//progressSlider.layer.transform = CATransform3DMakeScale(1.0, 2.0, 1.0);
	/////
	
	[self initInfo];
	
	self.view.y = 0;
	self.view.x = -320;
	
	bitrateTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(updateBitrateLabel) userInfo:nil repeats:YES];
	
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initInfo) name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initInfo) name:ISMSNotification_ServerSwitched object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidUnload) name:@"hideSongInfoFast" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidUnload) name:@"hideSongInfo" object:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_ServerSwitched object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideSongInfoFast" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideSongInfo" object:nil];
	
	// TODO: Re-enable later
	[songInfoToggleButton release]; songInfoToggleButton = nil;
	[artistLabel release]; artistLabel = nil;
	[albumLabel release]; albumLabel = nil;
	[titleLabel release]; titleLabel = nil;
	[trackLabel release]; trackLabel = nil;
	[yearLabel release]; yearLabel = nil;
	[genreLabel release]; genreLabel = nil;
	[bitRateLabel release]; bitRateLabel = nil;
	[lengthLabel release]; lengthLabel = nil;
		
	[bitrateTimer invalidate]; bitrateTimer = nil;
}

- (void)dealloc
{	
    [super dealloc];
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)updateBitrateLabel
{
	bitRateLabel.text = audio.bitRate < 0 ? @"" : [NSString stringWithFormat:@"Bit Rate: %i kbps", audio.bitRate];
}

- (void)initInfo
{
	PlaylistSingleton *currentPlaylistDAO = [PlaylistSingleton sharedInstance];
	
	self.currentSong = currentPlaylistDAO.currentDisplaySong;
		
	artistLabel.text = currentSong.artist;
	titleLabel.text = currentSong.title;
	
	[self updateBitrateLabel];
			
	if (currentSong.duration)
		lengthLabel.text = [NSString stringWithFormat:@"Length: %@", [NSString formatTime:[currentSong.duration floatValue]]];
	else
		lengthLabel.text = @"";
	
	if (currentSong.album)
		albumLabel.text = currentSong.album;
	else
		albumLabel.text = @"";
		
	if ( [currentSong.track intValue] != 0 )
		trackLabel.text = [NSString stringWithFormat:@"Track: %@", [currentSong.track stringValue]];
	else
		trackLabel.text = @"";
		
	if (currentSong.year)
		yearLabel.text = [NSString stringWithFormat:@"Year: %@", [currentSong.year stringValue]];
	else
		yearLabel.text = @"";
		
	if (currentSong.genre)
		genreLabel.text = [NSString stringWithFormat:@"Genre: %@", currentSong.genre];
	else
		genreLabel.text = @"";
}

- (IBAction) songInfoToggle
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"hideSongInfo" object:nil];
}

@end

