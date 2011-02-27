//
//  SongInfoViewController.m
//  iSub
//
//  Created by Ben Baron on 3/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SongInfoViewController.h"
#import "ViewObjectsSingleton.h"
#import "MusicControlsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "iSubAppDelegate.h"
#import "AudioStreamer.h"
#import "math.h"
#import "Song.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString+md5.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView-tools.h"

#define downloadProgressWidth (progressSlider.frame.size.width + 4)

@implementation SongInfoViewController
@synthesize progressSlider, downloadProgress, elapsedTimeLabel, remainingTimeLabel, artistLabel, albumLabel, titleLabel, trackLabel, yearLabel, genreLabel, bitRateLabel, lengthLabel, repeatButton, bookmarkButton, shuffleButton, progressTimer;


- (void)viewDidLoad {
    [super viewDidLoad];
	
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicControlsSingleton sharedInstance];
	databaseControls = [DatabaseControlsSingleton sharedInstance];
	
	[self initInfo];
	
	CGRect frame = self.view.frame;
	frame.origin.y = 0;
	frame.origin.x = -320;
	self.view.frame = frame;
	
	NSInteger bookmarkCount = [databaseControls.bookmarksDb intForQuery:@"SELECT COUNT(*) FROM bookmarks WHERE songId = ?", musicControls.currentSongObject.songId];
	if (bookmarkCount > 0)
	{
		bookmarkCountLabel.text = [NSString stringWithFormat:@"%i", bookmarkCount];
		bookmarkButton.imageView.image = [UIImage imageNamed:@"controller-bookmark-on.png"];
	}
	
	progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateSlider) userInfo:nil repeats:YES];
	pauseSlider = NO;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initInfo) name:@"initSongInfo" object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidUnload) name:@"hideSongInfoFast" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidUnload) name:@"hideSongInfo" object:nil];
	
	if (viewObjects.isJukebox)
	{
		downloadProgress.hidden = YES;
	}
	else
	{
		// Setup the update timer for the song download progress bar
		updateTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateDownloadProgress) userInfo:nil repeats:YES];
		CGRect frame = downloadProgress.frame;
		downloadProgress.frame = CGRectMake(frame.origin.x, frame.origin.y, 0.0, frame.size.height);
		downloadProgress.layer.cornerRadius = 5;
		
		[self updateDownloadProgress];
	}
}

- (void) viewDidUnload 
{
	[super viewDidUnload];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideSongInfoFast" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideSongInfo" object:nil];
	 
	[progressTimer invalidate]; progressTimer = nil;
	
	[updateTimer invalidate]; updateTimer = nil;
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}


- (void) initInfo
{
	hasMoved = NO;
	oldPosition = 0.0;
	
	progressSlider.minimumValue = 0.0;
	
	if ([musicControls.currentSongObject duration] && !viewObjects.isJukebox)
	{
		progressSlider.maximumValue = [[musicControls.currentSongObject duration] floatValue];
		progressSlider.enabled = YES;
	}
	else
	{
		progressSlider.maximumValue = 100.0;
		progressSlider.enabled = NO;
	}
		
	artistLabel.text = [musicControls.currentSongObject artist];
	titleLabel.text = [musicControls.currentSongObject title];
	
	if ([musicControls.currentSongObject bitRate])
		bitRateLabel.text = [NSString stringWithFormat:@"Bit Rate: %@ kbps", [[musicControls.currentSongObject bitRate] stringValue]];
	else
		bitRateLabel.text = @"";
		
	if ([musicControls.currentSongObject duration])
		lengthLabel.text = [NSString stringWithFormat:@"Length: %@", [appDelegate formatTime:[[musicControls.currentSongObject duration] floatValue]]];
	else
		lengthLabel.text = @"";
	
	if ([musicControls.currentSongObject album])
		albumLabel.text = [musicControls.currentSongObject album];
	else
		albumLabel.text = @"";
		
	if ([musicControls.currentSongObject track])
		trackLabel.text = [NSString stringWithFormat:@"Track: %@", [[musicControls.currentSongObject track] stringValue]];
	else
		trackLabel.text = @"";
		
	if ([musicControls.currentSongObject year])
		yearLabel.text = [NSString stringWithFormat:@"Year: %@", [[musicControls.currentSongObject year] stringValue]];
	else
		yearLabel.text = @"";
		
	if ([musicControls.currentSongObject genre])
		genreLabel.text = [NSString stringWithFormat:@"Genre: %@", [musicControls.currentSongObject genre]];
	else
		genreLabel.text = @"";
	
	if(musicControls.repeatMode == 1)
		[repeatButton setImage:[UIImage imageNamed:@"controller-repeat-one.png"] forState:0];
	else if(musicControls.repeatMode == 2)
		[repeatButton setImage:[UIImage imageNamed:@"controller-repeat-all.png"] forState:0];
	
	if(musicControls.isShuffle)
		[shuffleButton setImage:[UIImage imageNamed:@"controller-shuffle-on.png"] forState:0];
	
	NSInteger bookmarkCount = [databaseControls.bookmarksDb intForQuery:@"SELECT COUNT(*) FROM bookmarks WHERE songId = ?", musicControls.currentSongObject.songId];
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

}


- (void) updateDownloadProgress
{
	// Set the current song progress bar
	if (musicControls.isTempDownload)
	{
		downloadProgress.hidden = YES;
		//CGRect frame = downloadProgress.frame;
		//downloadProgress.frame = CGRectMake(frame.origin.x, frame.origin.y, 0.0, frame.size.height);
	}
	else
	{
		downloadProgress.hidden = NO;
		float width = ([musicControls findCurrentSongProgress] * downloadProgressWidth) + 5.0;
		if (width > downloadProgressWidth)
			width = downloadProgressWidth;
		[downloadProgress newWidth:width];
	}	
}


- (void) updateSlider
{
	if (viewObjects.isJukebox)
	{
		elapsedTimeLabel.text = [appDelegate formatTime:0];
		remainingTimeLabel.text = [NSString stringWithFormat:@"-%@",[appDelegate formatTime:[[musicControls.currentSongObject duration] floatValue]]];

		progressSlider.value = 0.0;
		
		return;
	}
	
	if (!pauseSlider)
	{
		if([musicControls.currentSongObject duration])
		{
			CGRect frame = self.view.frame;
			if (frame.origin.x == 0)
			{
				musicControls.streamerProgress = [musicControls.streamer progress];
				progressSlider.value = (musicControls.streamerProgress + musicControls.seekTime);
				elapsedTimeLabel.text = [appDelegate formatTime:(musicControls.streamerProgress + musicControls.seekTime)];
				remainingTimeLabel.text = [NSString stringWithFormat:@"-%@",[appDelegate formatTime:([[musicControls.currentSongObject duration] floatValue] - (musicControls.streamerProgress + musicControls.seekTime))]];
			}
		}
		else 
		{
			musicControls.streamerProgress = [musicControls.streamer progress];
			elapsedTimeLabel.text = [appDelegate formatTime:(musicControls.streamerProgress + musicControls.seekTime)];
			remainingTimeLabel.text = [appDelegate formatTime:0];
		}
	}
}


- (IBAction) touchedSlider
{
	pauseSlider = YES;
}


- (IBAction) movingSlider
{
	progressLabel.hidden = NO;
	progressLabelBackground.hidden = NO;
	
	CGFloat percent = progressSlider.value / progressSlider.maximumValue;
	CGFloat x = 20 + (percent * progressSlider.frame.size.width);
	progressLabel.center = CGPointMake(x, 15);
	progressLabelBackground.center = CGPointMake(x - 0.5, 15.5);
	
	[progressLabel setText:[appDelegate formatTime:progressSlider.value]];
}


- (IBAction) movedSlider
{
	// Don't allow seeking of m4a's
	BOOL isM4A = NO;
	if (musicControls.currentSongObject.transcodedSuffix)
	{
		if ([musicControls.currentSongObject.transcodedSuffix isEqualToString:@"m4a"] || [musicControls.currentSongObject.transcodedSuffix isEqualToString:@"aac"])
			isM4A = YES;
	}
	else
	{
		if ([musicControls.currentSongObject.suffix isEqualToString:@"m4a"] || [musicControls.currentSongObject.suffix isEqualToString:@"aac"])
			isM4A = YES;
	}
	
	if (isM4A)
	{
		if (!hasMoved)
		{
			hasMoved = YES;
			progressLabel.hidden = YES;
			progressLabelBackground.hidden = YES;
			pauseSlider = NO;

			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Sorry" message:@"It's currently not possible to skip within m4a files.\n\nYou can turn on m4a > mp3 transcoding in Subsonic to skip within this song." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
			[alert show];
			[alert release];
		}
	}
	else
	{
		if (!hasMoved)
		{
			hasMoved = YES;
			progressLabel.hidden = YES;
			progressLabelBackground.hidden = YES;
			
			if (musicControls.bitRate < 1000)
				byteOffset = ((float)musicControls.bitRate * 128 * progressSlider.value);
			else
				byteOffset = (((float)musicControls.bitRate / 1000) * 128 * progressSlider.value);
			//NSLog(@"byteOffset: %f", byteOffset);
			
			if (musicControls.isTempDownload)
			{
				[musicControls destroyStreamer];
				musicControls.isPlaying = YES;
				musicControls.seekTime = progressSlider.value;
				[musicControls startTempDownloadA:(UInt32)byteOffset];
				pauseSlider = NO;
				hasMoved = NO;
			}
			else 
			{
				if (musicControls.streamer.fileDownloadComplete)
				{
					//NSLog(@"skipping to area within cached song inside if");
					musicControls.seekTime = progressSlider.value;
					[musicControls.streamer startWithOffsetInSecs:(UInt32)progressSlider.value];
					musicControls.streamer.fileDownloadComplete = YES;
					pauseSlider = NO;
					hasMoved = NO;
				}
				else
				{
					//NSLog(@"------------- byteOffset: %i", (int)byteOffset);
					//NSLog(@"------------- fileDownloadCurrentSize: %i", musicControls.streamer.fileDownloadCurrentSize);
					if ((int)byteOffset > musicControls.streamer.fileDownloadCurrentSize)
					{
						//NSLog(@"fileDownloadCurrentSize inside else: %i", musicControls.streamer.fileDownloadCurrentSize);
						UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Past Cache Point" message:@"You are trying to skip further than the song has cached. You can do this, but the song won't be cached. Or you can wait a little bit for the cache to catch up." delegate:self cancelButtonTitle:@"Wait" otherButtonTitles:@"OK", nil];
						[alert show];
						[alert release];
					}
					else
					{
						//NSLog(@"skipping to area within cached song inside else");
						musicControls.seekTime = progressSlider.value;
						[musicControls.streamer startWithOffsetInSecs:(UInt32)progressSlider.value];
						pauseSlider = NO;
						hasMoved = NO;
					}
				}
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
		[repeatButton setImage:[UIImage imageNamed:@"controller-repeat-one.png"] forState:0];
		musicControls.repeatMode = 1;
	}
	else if(musicControls.repeatMode == 1)
	{
		[repeatButton setImage:[UIImage imageNamed:@"controller-repeat-all.png"] forState:0];
		musicControls.repeatMode = 2;
	}
	else if(musicControls.repeatMode == 2)
	{
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
			[musicControls destroyStreamer];
			musicControls.isPlaying = YES;
			musicControls.seekTime = progressSlider.value;
			//NSLog(@"seekTime: %f", musicControls.seekTime);
			[musicControls startTempDownloadA:(UInt32)byteOffset];
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
				Song *aSong = musicControls.currentSongObject;
				[databaseControls.bookmarksDb executeUpdate:@"INSERT INTO bookmarks (name, position, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", bookmarkNameTextField.text, [NSNumber numberWithInt:bookmarkPosition], aSong.title, aSong.songId, aSong.artist, aSong.album, aSong.genre, aSong.coverArtId, aSong.path, aSong.suffix, aSong.transcodedSuffix, aSong.duration, aSong.bitRate, aSong.track, aSong.year, aSong.size];
				bookmarkCountLabel.text = [NSString stringWithFormat:@"%i", [databaseControls.bookmarksDb intForQuery:@"SELECT COUNT(*) FROM bookmarks WHERE songId = ?", musicControls.currentSongObject.songId]];
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
			Song *aSong = musicControls.currentSongObject;
			[databaseControls.bookmarksDb executeUpdate:@"DELETE FROM bookmarks WHERE name = ?", bookmarkNameTextField.text];
			[databaseControls.bookmarksDb executeUpdate:@"INSERT INTO bookmarks (name, position, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", bookmarkNameTextField.text, [NSNumber numberWithInt:(int)progressSlider.value], aSong.title, aSong.songId, aSong.artist, aSong.album, aSong.genre, aSong.coverArtId, aSong.path, aSong.suffix, aSong.transcodedSuffix, aSong.duration, aSong.bitRate, aSong.track, aSong.year, aSong.size];
			bookmarkCountLabel.text = [NSString stringWithFormat:@"%i", [databaseControls.bookmarksDb intForQuery:@"SELECT COUNT(*) FROM bookmarks WHERE songId = ?", musicControls.currentSongObject.songId]];
			bookmarkButton.imageView.image = [UIImage imageNamed:@"controller-bookmark-on.png"];
		}
	}
}


- (void) performShuffle
{
	// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	NSNumber *oldPlaylistPosition = [NSNumber numberWithInt:(musicControls.currentPlaylistPosition + 1)];
	musicControls.currentPlaylistPosition = 0;
	musicControls.isShuffle = YES;
	
	[databaseControls resetShufflePlaylist];
	[databaseControls addSongToShuffleQueue:musicControls.currentSongObject];
	//[databaseControls insertSong:musicControls.currentSongObject intoTable:@"shufflePlaylist" inDatabase:databaseControls.currentPlaylistDb];
	
	/*if (viewObjects.isJukebox)
	{
		[musicControls jukeboxShuffle];
		musicControls.isShuffle = NO;
	}
	else
	{
		[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO shufflePlaylist SELECT * FROM currentPlaylist WHERE ROWID != ? ORDER BY RANDOM()", oldPlaylistPosition];
	}*/
	
	if (viewObjects.isJukebox)
	{
		[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO jukeboxShufflePlaylist SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID != ? ORDER BY RANDOM()", oldPlaylistPosition];
	}
	else
	{
		[databaseControls.currentPlaylistDb executeUpdate:@"INSERT INTO shufflePlaylist SELECT * FROM currentPlaylist WHERE ROWID != ? ORDER BY RANDOM()", oldPlaylistPosition];
	}
	
	// Send a notification to update the playlist view
	[[NSNotificationCenter defaultCenter] postNotificationName:@"reloadPlaylist" object:nil];
	
	if (viewObjects.isJukebox)
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
		[shuffleButton setImage:[UIImage imageNamed:@"controller-shuffle.png"] forState:0];
		musicControls.isShuffle = NO;
		
		if (viewObjects.isJukebox)
		{
			[musicControls jukeboxReplacePlaylistWithLocal];
			//[musicControls playSongAtPosition:1];
		}
		else
		{
			musicControls.currentPlaylistPosition = -1;
		}
		
		// Send a notification to update the playlist view
		[[NSNotificationCenter defaultCenter] postNotificationName:@"reloadPlaylist" object:nil];
	}
	else
	{
		if (!viewObjects.isJukebox)
			[shuffleButton setImage:[UIImage imageNamed:@"controller-shuffle-on.png"] forState:0];
					
		[viewObjects showLoadingScreenOnMainWindow];
		[self performSelectorInBackground:@selector(performShuffle) withObject:nil];
	}
}


- (void)dealloc {
	[songInfoToggleButton release];
	[progressSlider release];
	[progressLabel release];
	[progressLabelBackground release];
	[elapsedTimeLabel release];
	[remainingTimeLabel release];
	[artistLabel release];
	[albumLabel release];
	[titleLabel release];
	[trackLabel release];
	[yearLabel release];
	[genreLabel release];
	[bitRateLabel release];
	[lengthLabel release];
	[repeatButton release];
	[shuffleButton release];
    [super dealloc];
}


@end

