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
#import "SUSCurrentPlaylistDAO.h"
#import "BassWrapperSingleton.h"
#import "NSArray+FirstObject.h"
#import "SUSStreamHandler.h"
#import "EqualizerViewController.h"

//#define downloadProgressWidth (progressSlider.frame.size.width + 4)
#define downloadProgressWidth progressSlider.frame.size.width

@implementation SongInfoViewController
@synthesize progressSlider, downloadProgress, elapsedTimeLabel, remainingTimeLabel, artistLabel, albumLabel, titleLabel, trackLabel, yearLabel, genreLabel, bitRateLabel, lengthLabel, repeatButton, bookmarkButton, shuffleButton, progressTimer, currentSong, songInfoToggleButton, progressLabelBackground, progressLabel, bookmarkCountLabel;


- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
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
    bassWrapper = [BassWrapperSingleton sharedInstance];
    
    downloadProgress = [[UIView alloc] initWithFrame:progressSlider.frame];
	[downloadProgress newX:0.0];
	[downloadProgress newY:0.0];
	downloadProgress.backgroundColor = [UIColor whiteColor];
	downloadProgress.alpha = 0.3;
	downloadProgress.userInteractionEnabled = NO;
	[progressSlider addSubview:downloadProgress];
	[downloadProgress release];
	
	/////////// RESIZE PROGRESS SLIDER
	//progressSlider.layer.transform = CATransform3DMakeScale(1.0, 2.0, 1.0);
	/////
	
	[self updateSlider];
	[self initInfo];
	
	[self.view newY:0];
	[self.view newX:-320];
	
	progressTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateSlider) userInfo:nil repeats:YES];
	bitrateTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(updateBitrateLabel) userInfo:nil repeats:YES];
	
	pauseSlider = NO;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initInfo) name:ISMSNotification_SongPlaybackStart object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidUnload) name:@"hideSongInfoFast" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidUnload) name:@"hideSongInfo" object:nil];
	
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		downloadProgress.hidden = YES;
	}
	else
	{
		// Setup the update timer for the song download progress bar
		updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateDownloadProgress) userInfo:nil repeats:YES];
		[downloadProgress newWidth:0.0];
		//[downloadProgress newX:70.0];
		//if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
		//	[downloadProgress addX:2.0];
		//DLog(@"downloadProgress.frame %@", NSStringFromCGRect(downloadProgress.frame));
		downloadProgress.layer.cornerRadius = 5;
		
		[self updateDownloadProgress];
	}
	
	/*DLog(@"songInfoToggleButton: %@", songInfoToggleButton.layer);
	DLog(@"progressSlider: %@", progressSlider.layer);
	DLog(@"progressLabel: %@", progressLabel.layer);
	DLog(@"progressLabelBackground: %@", progressLabelBackground.layer);
	DLog(@"downloadProgress: %@", downloadProgress.layer);
	DLog(@"elapsedTimeLabel: %@", elapsedTimeLabel.layer);
	DLog(@"remainingTimeLabel: %@", remainingTimeLabel.layer);
	DLog(@"artistLabel: %@", artistLabel.layer);
	DLog(@"albumLabel: %@", albumLabel.layer);
	DLog(@"titleLabel: %@", titleLabel.layer);
	DLog(@"trackLabel: %@", trackLabel.layer);
	DLog(@"yearLabel: %@", yearLabel.layer);
	DLog(@"genreLabel: %@", genreLabel.layer);
	DLog(@"bitRateLabel: %@", bitRateLabel.layer);
	DLog(@"lengthLabel: %@", lengthLabel.layer);
	DLog(@"repeatButton: %@", repeatButton.layer);
	DLog(@"bookmarkButton: %@", bookmarkButton.layer);
	DLog(@"bookmarkCountLabel: %@", bookmarkCountLabel.layer);
	DLog(@"shuffleButton: %@", shuffleButton.layer);
	DLog(@"bookmarkNameTextField: %@", bookmarkNameTextField.layer);*/
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_SongPlaybackStart object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideSongInfoFast" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideSongInfo" object:nil];
	
	// TODO: Re-enable later
	[songInfoToggleButton release]; songInfoToggleButton = nil;
	[progressSlider release]; progressSlider = nil;
	[progressLabel release]; progressLabel = nil;
	[progressLabelBackground release]; progressLabelBackground = nil;
	[elapsedTimeLabel release]; elapsedTimeLabel = nil;
	[remainingTimeLabel release]; remainingTimeLabel = nil;
	[artistLabel release]; artistLabel = nil;
	[albumLabel release]; albumLabel = nil;
	[titleLabel release]; titleLabel = nil;
	[trackLabel release]; trackLabel = nil;
	[yearLabel release]; yearLabel = nil;
	[genreLabel release]; genreLabel = nil;
	[bitRateLabel release]; bitRateLabel = nil;
	[lengthLabel release]; lengthLabel = nil;
	[repeatButton release]; repeatButton = nil;
	[shuffleButton release]; shuffleButton = nil;
		
	[progressTimer invalidate]; progressTimer = nil;
	[bitrateTimer invalidate]; bitrateTimer = nil;
	[updateTimer invalidate]; updateTimer = nil;
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
	bitRateLabel.text = [NSString stringWithFormat:@"Bit Rate: %i kbps", bassWrapper.bitRate];
}

- (void)initInfo
{
	hasMoved = NO;
	oldPosition = 0.0;
	
	progressSlider.minimumValue = 0.0;
	
	self.currentSong = [SUSCurrentPlaylistDAO dataModel].currentSong;
	
	if (currentSong.duration && ![SavedSettings sharedInstance].isJukeboxEnabled)
	{
		progressSlider.maximumValue = [currentSong.duration floatValue];
		progressSlider.enabled = YES;
	}
	else
	{
		progressSlider.maximumValue = 100.0;
		progressSlider.enabled = NO;
	}
		
	artistLabel.text = currentSong.artist;
	titleLabel.text = currentSong.title;
	
	//if (currentSong.bitRate)
		bitRateLabel.text = [NSString stringWithFormat:@"Bit Rate: %i kbps", bassWrapper.bitRate]; //]] [currentSong.bitRate stringValue]];
	//else
	//	bitRateLabel.text = @"";
		
	if (currentSong.duration)
		lengthLabel.text = [NSString stringWithFormat:@"Length: %@", [NSString formatTime:[currentSong.duration floatValue]]];
	else
		lengthLabel.text = @"";
	
	if (currentSong.album)
		albumLabel.text = currentSong.album;
	else
		albumLabel.text = @"";
		
	if (currentSong.track)
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
	
	if(musicControls.repeatMode == 1)
	{
		if (IS_IPAD())
			[repeatButton setImage:[UIImage imageNamed:@"controller-repeat-one-ipad.png"] forState:0];
		else
			[repeatButton setImage:[UIImage imageNamed:@"controller-repeat-one.png"] forState:0];
	}
	else if(musicControls.repeatMode == 2)
	{
		if (IS_IPAD())
			[repeatButton setImage:[UIImage imageNamed:@"controller-repeat-all-ipad.png"] forState:0];
		else
			[repeatButton setImage:[UIImage imageNamed:@"controller-repeat-all.png"] forState:0];
	}
	
	if(musicControls.isShuffle)
	{
		if (IS_IPAD())
			[shuffleButton setImage:[UIImage imageNamed:@"controller-shuffle-on-ipad.png"] forState:0];
		else
			[shuffleButton setImage:[UIImage imageNamed:@"controller-shuffle-on.png"] forState:0];
	}
	
	NSInteger bookmarkCount = [databaseControls.bookmarksDb intForQuery:@"SELECT COUNT(*) FROM bookmarks WHERE songId = ?", currentSong.songId];
	if (bookmarkCount > 0)
	{
		bookmarkCountLabel.text = [NSString stringWithFormat:@"%i", bookmarkCount];
		if (IS_IPAD())
			bookmarkButton.imageView.image = [UIImage imageNamed:@"controller-bookmark-on-ipad.png"];
		else
			bookmarkButton.imageView.image = [UIImage imageNamed:@"controller-bookmark-on.png"];
	}
	else
	{
		bookmarkCountLabel.text = @"";
		if(IS_IPAD())
			bookmarkButton.imageView.image = [UIImage imageNamed:@"controller-bookmark-ipad.png"];
		else
			bookmarkButton.imageView.image = [UIImage imageNamed:@"controller-bookmark.png"];
	}
}


- (void)updateDownloadProgress
{
	// Set the current song progress bar
	if (musicControls.isTempDownload)
	{
		downloadProgress.hidden = YES;
	}
	else
	{
		downloadProgress.hidden = NO;
		
		float width = ([musicControls findCurrentSongProgress] * downloadProgressWidth);
		if (width > downloadProgressWidth)
		{
			width = downloadProgressWidth;
		}
		[downloadProgress newWidth:width];
	}	
}


- (void)updateSlider
{	
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		elapsedTimeLabel.text = [NSString formatTime:0];
		remainingTimeLabel.text = [NSString stringWithFormat:@"-%@",[NSString formatTime:[currentSong.duration floatValue]]];

		progressSlider.value = 0.0;
		
		return;
	}

	bitRateLabel.text = [NSString stringWithFormat:@"Bit Rate: %i kbps", bassWrapper.bitRate];
	
	if (!pauseSlider)
	{
		/*if(currentSong.duration)
		{
			CGRect frame = self.view.frame;
			if (frame.origin.x == 0)
			{
				progressSlider.value = bassWrapper.progress;
				elapsedTimeLabel.text = [NSString formatTime:bassWrapper.progress];
				remainingTimeLabel.text = [NSString stringWithFormat:@"-%@",[NSString formatTime:([currentSong.duration floatValue] - bassWrapper.progress)]];
			}
		}
		else 
		{
			progressSlider.value = 0.0;
			elapsedTimeLabel.text = [NSString formatTime:bassWrapper.progress];
			remainingTimeLabel.text = [NSString formatTime:0];
		}*/
		
		NSString *elapsedTime = [NSString formatTime:bassWrapper.progress];
		NSString *remainingTime = [NSString formatTime:([currentSong.duration floatValue] - bassWrapper.progress)];
		
		progressSlider.value = bassWrapper.progress;
		elapsedTimeLabel.text = elapsedTime;
		remainingTimeLabel.text =[@"-" stringByAppendingString:remainingTime];
	}
}


- (IBAction) touchedSlider
{
	pauseSlider = YES;
}


- (IBAction) movingSlider
{
	DLog(@"scrubbing speed: %f", progressSlider.scrubbingSpeed);
	
	progressLabel.hidden = NO;
	progressLabelBackground.hidden = NO;
	
	CGFloat percent = progressSlider.value / progressSlider.maximumValue;
	CGFloat x = 20 + (percent * progressSlider.frame.size.width);
	progressLabel.center = CGPointMake(x, 15);
	progressLabelBackground.center = CGPointMake(x - 0.5, 15.5);
	
	[progressLabel setText:[NSString formatTime:progressSlider.value]];
}


- (IBAction) movedSlider
{	
	if (!hasMoved)
	{		
		hasMoved = YES;
		progressLabel.hidden = YES;
		progressLabelBackground.hidden = YES;
		
		// Fix for skipping to end of file going to next song
		// It seems that the max time is always off
		if (progressSlider.value > (progressSlider.maximumValue - 8.0))
		{
			float newValue = progressSlider.maximumValue - 8.0;
			
			if (newValue < 0.0)
				newValue = 0.0;
			
			progressSlider.value = newValue;
		}
		
		byteOffset = bassWrapper.bitRate * 128 * progressSlider.value;

		DLog(@"byteOffset: %i", byteOffset);
		
		if (musicControls.isTempDownload)
		{
            [bassWrapper stop];
			
			//musicControls.seekTime = progressSlider.value;
			[[SUSStreamSingleton sharedInstance] queueStreamForSong:currentSong offset:byteOffset atIndex:0];
			
			pauseSlider = NO;
			hasMoved = NO;
		}
		else 
		{			
			if (currentSong.isFullyCached || byteOffset <= currentSong.localFileSize)
			{
				[bassWrapper seekToPositionInBytes:byteOffset];
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
}


- (IBAction) songInfoToggle
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"hideSongInfo" object:nil];
}


- (IBAction) repeatButtonToggle
{
	if(musicControls.repeatMode == 0)
	{
		if (IS_IPAD())
			[repeatButton setImage:[UIImage imageNamed:@"controller-repeat-one-ipad.png"] forState:0];
		else
			[repeatButton setImage:[UIImage imageNamed:@"controller-repeat-one.png"] forState:0];
		musicControls.repeatMode = 1;
	}
	else if(musicControls.repeatMode == 1)
	{
		if (IS_IPAD())
			[repeatButton setImage:[UIImage imageNamed:@"controller-repeat-all-ipad.png"] forState:0];
		else
			[repeatButton setImage:[UIImage imageNamed:@"controller-repeat-all.png"] forState:0];
		musicControls.repeatMode = 2;
	}
	else if(musicControls.repeatMode == 2)
	{
		if (IS_IPAD())
			[repeatButton setImage:[UIImage imageNamed:@"controller-repeat-ipad.png"] forState:0];
		else
			[repeatButton setImage:[UIImage imageNamed:@"controller-repeat.png"] forState:0];
		musicControls.repeatMode = 0;
	}
}

- (IBAction) bookmarkButtonToggle
{
	bookmarkPosition = (int)progressSlider.value;
	
	UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Bookmark Name:" message:@"this gets covered" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
	bookmarkNameTextField = [[UITextField alloc] initWithFrame:CGRectMake(12.0, 47.0, 260.0, 22.0)];
	[bookmarkNameTextField setBackgroundColor:[UIColor whiteColor]];
	[myAlertView addSubview:bookmarkNameTextField];
	if ([[[[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."] objectAtIndex:0] isEqualToString:@"3"])
	{
		CGAffineTransform myTransform = CGAffineTransformMakeTranslation(0.0, 100.0);
		[myAlertView setTransform:myTransform];
	}
	[myAlertView show];
	[myAlertView release];
	[bookmarkNameTextField becomeFirstResponder];
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
            [bassWrapper stop];
			[[SUSStreamSingleton sharedInstance] removeStreamAtIndex:0];
            DLog(@"byteOffset: %i", byteOffset);
			[[SUSStreamSingleton sharedInstance] queueStreamForSong:currentSong offset:byteOffset atIndex:0];
			if ([[SUSStreamSingleton sharedInstance].handlerStack count] > 1)
			{
				SUSStreamHandler *handler = [[SUSStreamSingleton sharedInstance].handlerStack firstObject];
				[handler start];
			}
			pauseSlider = NO;
			hasMoved = NO;
		}
	}
	else if([alertView.title isEqualToString:@"Bookmark Name:"])
	{
		[bookmarkNameTextField resignFirstResponder];
		//bookmarkEntry = [[NSArray alloc] initWithObjects:[bookmarkNameTextField.text copy], [appDelegate.currentSongObject copy], [NSNumber numberWithFloat:progressSlider.value], nil];
		if(buttonIndex == 1)
		{
			// Check if the bookmark exists
			if ([databaseControls.bookmarksDb intForQuery:@"SELECT COUNT(*) FROM bookmarks WHERE name = ?", bookmarkNameTextField.text] == 0)
			{
				// Bookmark doesn't exist so save it
				[databaseControls.bookmarksDb executeUpdate:@"INSERT INTO bookmarks (name, position, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", bookmarkNameTextField.text, [NSNumber numberWithInt:bookmarkPosition], currentSong.title, currentSong.songId, currentSong.artist, currentSong.album, currentSong.genre, currentSong.coverArtId, currentSong.path, currentSong.suffix, currentSong.transcodedSuffix, currentSong.duration, currentSong.bitRate, currentSong.track, currentSong.year, currentSong.size];
				bookmarkCountLabel.text = [NSString stringWithFormat:@"%i", [databaseControls.bookmarksDb intForQuery:@"SELECT COUNT(*) FROM bookmarks WHERE songId = ?", currentSong.songId]];
				if (IS_IPAD())
					bookmarkButton.imageView.image = [UIImage imageNamed:@"controller-bookmark-on-ipad.png"];
				else
					bookmarkButton.imageView.image = [UIImage imageNamed:@"controller-bookmark-on.png"];
			}
			else
			{
				// Bookmark exists so ask to overwrite
				UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Overwrite?" message:@"There is already a bookmark with this name. Overwrite it?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
				[myAlertView show];
				[myAlertView release];
			}
		}
	}
	else if([alertView.title isEqualToString:@"Overwrite?"])
	{
		if(buttonIndex == 1)
		{
			// Overwrite the bookmark
			[databaseControls.bookmarksDb executeUpdate:@"DELETE FROM bookmarks WHERE name = ?", bookmarkNameTextField.text];
			[databaseControls.bookmarksDb executeUpdate:@"INSERT INTO bookmarks (name, position, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", bookmarkNameTextField.text, [NSNumber numberWithInt:(int)progressSlider.value], currentSong.title, currentSong.songId, currentSong.artist, currentSong.album, currentSong.genre, currentSong.coverArtId, currentSong.path, currentSong.suffix, currentSong.transcodedSuffix, currentSong.duration, currentSong.bitRate, currentSong.track, currentSong.year, currentSong.size];
			bookmarkCountLabel.text = [NSString stringWithFormat:@"%i", [databaseControls.bookmarksDb intForQuery:@"SELECT COUNT(*) FROM bookmarks WHERE songId = ?", currentSong.songId]];
			if (IS_IPAD())
				bookmarkButton.imageView.image = [UIImage imageNamed:@"controller-bookmark-on-ipad.png"];
			else
				bookmarkButton.imageView.image = [UIImage imageNamed:@"controller-bookmark-on.png"];
		}
	}
}


- (void) performShuffle
{	
	// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];

	SUSCurrentPlaylistDAO *dataModel = [SUSCurrentPlaylistDAO dataModel];
	
	NSNumber *oldPlaylistPosition = [NSNumber numberWithInt:(dataModel.currentIndex + 1)];
	dataModel.currentIndex = 0;
	musicControls.isShuffle = YES;
	
	[databaseControls resetShufflePlaylist];
	[currentSong addToShuffleQueue];
	//[databaseControls insertSong:musicControls.currentSongObject intoTable:@"shufflePlaylist" inDatabase:databaseControls.currentPlaylistDb];
	
	/*if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		[musicControls jukeboxShuffle];
		musicControls.isShuffle = NO;
	}
	else
	{
		[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO shufflePlaylist SELECT * FROM currentPlaylist WHERE ROWID != ? ORDER BY RANDOM()", oldPlaylistPosition];
	}*/
	
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO jukeboxShufflePlaylist SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID != ? ORDER BY RANDOM()", oldPlaylistPosition];
	}
	else
	{
		[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO shufflePlaylist SELECT * FROM currentPlaylist WHERE ROWID != ? ORDER BY RANDOM()", oldPlaylistPosition];
	}
	
	// Send a notification to update the playlist view
	[[NSNotificationCenter defaultCenter] postNotificationName:@"reloadPlaylist" object:nil];
	
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
		[self performSelectorOnMainThread:@selector(jukeboxShuffleSteps) withObject:nil waitUntilDone:NO];
	
	// Hide the loading screen
	[viewObjects performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:NO];
	 
	[autoreleasePool release];
}

- (void)jukeboxShuffleSteps
{
	[musicControls jukeboxReplacePlaylistWithLocal];
	[musicControls jukeboxPlaySongAtPosition:1];
	
	musicControls.isShuffle = NO;
}

- (IBAction) shuffleButtonToggle
{	
	if (musicControls.isShuffle)
	{
		if (IS_IPAD())
			[shuffleButton setImage:[UIImage imageNamed:@"controller-shuffle-ipad.png"] forState:0];
		else
			[shuffleButton setImage:[UIImage imageNamed:@"controller-shuffle.png"] forState:0];
		musicControls.isShuffle = NO;
		
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
		{
			[musicControls jukeboxReplacePlaylistWithLocal];
			//[musicControls playSongAtPosition:1];
		}
		else
		{
			[SUSCurrentPlaylistDAO dataModel].currentIndex = -1;
		}
		
		// Send a notification to update the playlist view
		[[NSNotificationCenter defaultCenter] postNotificationName:@"reloadPlaylist" object:nil];
	}
	else
	{
		if (![SavedSettings sharedInstance].isJukeboxEnabled)
		{
			if (IS_IPAD())
				[shuffleButton setImage:[UIImage imageNamed:@"controller-shuffle-on-ipad.png"] forState:0];
			else
				[shuffleButton setImage:[UIImage imageNamed:@"controller-shuffle-on.png"] forState:0];
		}
					
		[viewObjects showLoadingScreenOnMainWindow];
		[self performSelectorInBackground:@selector(performShuffle) withObject:nil];
	}
}

@end

