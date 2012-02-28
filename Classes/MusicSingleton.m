//
//  musicSSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "ViewObjectsSingleton.h"
#import "iSubAppDelegate.h"
#import "Song.h"
#import "NSString+md5.h"
#import "FMDatabaseAdditions.h"
#import "Reachability.h"
#import "JukeboxXMLParser.h"
#import "JukeboxConnectionDelegate.h"
#import "BBSimpleConnectionQueue.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
#import "NSMutableURLRequest+SUS.h"
#import "OrderedDictionary.h"
#import "SUSLyricsLoader.h" 
#import "ISMSStreamManager.h"
#import "PlaylistSingleton.h"
#import "AudioEngine.h"
#import <MediaPlayer/MediaPlayer.h>
#import "SUSCoverArtDAO.h"
#import "SUSCoverArtLoader.h"
#import "ISMSStreamHandler.h"
#import "CacheSingleton.h"
#import "NSNotificationCenter+MainThread.h"
#import "JukeboxSingleton.h"

static MusicSingleton *sharedInstance = nil;

@implementation MusicSingleton

#pragma mark Control Methods

unsigned long long startSongBytes = 0;
double startSongSeconds = 0.0;
- (void)startSongAtOffsetInBytes:(unsigned long long)bytes andSeconds:(double)seconds
{
	// Only allowed to manipulate BASS from the main thread
	if (![NSThread mainThread])
		return;
	
	// Destroy the streamer to start a new song
	[audioEngineS stop];
	
	Song *currentSong = playlistS.currentSong;
	
	if (!currentSong)
		return;
	
	startSongBytes = bytes;
	startSongSeconds = seconds;
		
	// Only start the caching process if it's been a half second after the last request
	// Prevents crash when skipping through playlist fast
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[self performSelector:@selector(startSongAtOffsetInSeconds2) withObject:nil afterDelay:1.0];
}

// TODO: put this method somewhere and name it properly
- (void)startSongAtOffsetInSeconds2
{
	//DLog(@"startSongAtOffsetInSeconds2");	
	// Always clear the temp cache
	[cacheS clearTempCache];
	
	Song *currentSong = playlistS.currentSong;
	
	// Check to see if the song is already cached
	if (currentSong.isFullyCached)
	{
		// The song is fully cached, start streaming from the local copy
		[audioEngineS startWithOffsetInBytes:[NSNumber numberWithUnsignedLongLong:startSongBytes] 
							orSeconds:[NSNumber numberWithDouble:startSongSeconds]];
		
		// Fill the stream queue
		if (!viewObjectsS.isOfflineMode)
			[streamManagerS fillStreamQueue];
	}
	else if (!currentSong.isFullyCached && viewObjectsS.isOfflineMode)
	{
		// The song is not fully cached and this is offline mode, so warn that it can't be played
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" 
																	message:@"Unable to play this song in offline mode as it isn't fully cached." 
																   delegate:self 
														  cancelButtonTitle:@"Ok" 
														  otherButtonTitles:nil];
		alert.tag = 4;
		[alert show];
		[alert release];
	}
	else
	{
		if ([streamManagerS isSongDownloading:currentSong])
		{
			// The song is caching, start streaming from the local copy
			ISMSStreamHandler *handler = [streamManagerS handlerForSong:currentSong];
			if (!audioEngineS.isPlaying && handler.isDelegateNotifiedToStartPlayback)
			{
				// Only start the player if the handler isn't going to do it itself
				[audioEngineS startWithOffsetInBytes:[NSNumber numberWithUnsignedLongLong:startSongBytes] 
									orSeconds:[NSNumber numberWithDouble:startSongSeconds]];
			}
		}
		else if ([streamManagerS isSongFirstInQueue:currentSong] && ![streamManagerS isQueueDownloading])
		{
			// The song is first in queue, but the queue is not downloading. Probably the song was downloading
			// when the app quit. Resume the download and start the player
			[streamManagerS resumeQueue];
			
			// The song is caching, start streaming from the local copy
			ISMSStreamHandler *handler = [streamManagerS handlerForSong:currentSong];
			if (!audioEngineS.isPlaying && handler.isDelegateNotifiedToStartPlayback)
			{
				// Only start the player if the handler isn't going to do it itself
				[audioEngineS startWithOffsetInBytes:[NSNumber numberWithUnsignedLongLong:startSongBytes] 
									orSeconds:[NSNumber numberWithDouble:startSongSeconds]];
			}
		}
		else
		{
			// Clear the stream manager
			[streamManagerS removeAllStreams];
			
			BOOL isTempCache = NO;
			if (startSongBytes > 0)
				isTempCache = YES;
			else if (!settingsS.isSongCachingEnabled)
				isTempCache = YES;
			
			// Start downloading the current song from the correct offset
			[streamManagerS queueStreamForSong:currentSong 
									 byteOffset:startSongBytes 
								  secondsOffset:startSongSeconds 
										atIndex:0 
									isTempCache:isTempCache];
			
			// Fill the stream queue
			if (settingsS.isSongCachingEnabled)
				[streamManagerS fillStreamQueue];
		}
	}
}

- (void)startSong
{	
	[self startSongAtOffsetInBytes:0 andSeconds:0.0];
}

- (void)playSongAtPosition:(NSInteger)position
{	
	playlistS.currentIndex = position;

	DLog(@"before handler stack: %@", streamManagerS.handlerStack);
	DLog(@"currentSong: %@", playlistS.currentSong);
	[streamManagerS removeAllStreamsExceptForSong:playlistS.currentSong];
	DLog(@"after handler stack: %@\n   ", streamManagerS.handlerStack);
	
	if (settingsS.isJukeboxEnabled)
	{
		[jukeboxS jukeboxPlaySongAtPosition:[NSNumber numberWithInt:position]];
	}
	else
	{		
		[self startSong];
	}
}

- (void)prevSong
{	
	if (audioEngineS.progress > 10.0)
	{
		// Past 10 seconds in the song, so restart playback instead of changing songs
		[self playSongAtPosition:playlistS.currentIndex];
	}
	else
	{
		// Within first 10 seconds, go to previous song
		[self playSongAtPosition:playlistS.prevIndex];
	}
}

- (void)nextSong
{
	[self playSongAtPosition:playlistS.nextIndex];
}

// Resume song after iSub shuts down
- (void)resumeSong
{	
	Song *currentSong = playlistS.currentSong;
		
	DLog(@"isRecover: %@  currentSong: %@", NSStringFromBOOL(settingsS.isRecover), currentSong);
	DLog(@"byteOffset: %llu   seekTime: %f\n   ", settingsS.byteOffset, settingsS.seekTime);
	
	if (currentSong && settingsS.isRecover)
	{
		[self startSongAtOffsetInBytes:settingsS.byteOffset andSeconds:settingsS.seekTime];
	}
	else
	{
		audioEngineS.startByteOffset = settingsS.byteOffset;
		audioEngineS.startSecondsOffset = settingsS.seekTime;
	}
}

#pragma mark Helper Methods

- (BOOL)showPlayerIcon
{
	if (IS_IPAD())
		return NO;
	
	return YES;
}

- (void)showPlayer
{
	// Start the player		
	[self playSongAtPosition:0];
	
	if (IS_IPAD())
	{
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowPlayer];
	}
	else
	{
		iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
		streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
		[(UINavigationController*)appDelegateS.currentTabBarController.selectedViewController pushViewController:streamingPlayerViewController animated:YES];
		[streamingPlayerViewController release];
	}
}

- (void)updateLockScreenInfo
{
	if ([NSClassFromString(@"MPNowPlayingInfoCenter") class])  
	{
		/* we're on iOS 5, so set up the now playing center */
		Song *currentSong = playlistS.currentSong;

		SUSCoverArtDAO *artDataModel = [[SUSCoverArtDAO alloc] initWithDelegate:nil coverArtId:currentSong.coverArtId isLarge:YES];
		
		UIImage *albumArtImage = artDataModel.coverArtImage;
		
		MPMediaItemArtwork *albumArt = [[[MPMediaItemArtwork alloc] initWithImage:albumArtImage] autorelease];
		
		NSMutableDictionary *trackInfo = [NSMutableDictionary dictionaryWithObject:albumArt forKey:MPMediaItemPropertyArtwork];
		if (currentSong.title)
			[trackInfo setObject:currentSong.title forKey:MPMediaItemPropertyTitle];
		if (currentSong.album)
			[trackInfo setObject:currentSong.album forKey:MPMediaItemPropertyAlbumTitle];
		if (currentSong.artist)
			[trackInfo setObject:currentSong.artist forKey:MPMediaItemPropertyArtist];
		if (currentSong.genre)
			[trackInfo setObject:currentSong.genre forKey:MPMediaItemPropertyGenre];
		if (currentSong.duration)
			[trackInfo setObject:currentSong.duration forKey:MPMediaItemPropertyPlaybackDuration];
		NSNumber *trackIndex = [NSNumber numberWithInt:playlistS.currentIndex];
		if (trackIndex)
			[trackInfo setObject:trackIndex forKey:MPNowPlayingInfoPropertyPlaybackQueueIndex];
		NSNumber *playlistCount = [NSNumber numberWithInt:playlistS.count];
		if (playlistCount)
			[trackInfo setObject:playlistCount forKey:MPNowPlayingInfoPropertyPlaybackQueueCount];
		NSNumber *progress = [NSNumber numberWithDouble:audioEngineS.progress];
		if (progress)
			[trackInfo setObject:progress forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
		
		[MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = trackInfo;
	}
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
	DLog(@"received memory warning");
	
	
}

#pragma mark -
#pragma mark Singleton methods

+ (MusicSingleton*)sharedInstance
{
    @synchronized(self)
    {
		if (sharedInstance == nil)
			[[self alloc] init];
    }
    return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (sharedInstance == nil) {
            sharedInstance = [super allocWithZone:zone];
            return sharedInstance;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

-(id)init 
{
	self = [super init];
	sharedInstance = self;
		
	isAutoNextNotificationOn = NO;
	
	//[self addAutoNextNotification];
		
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLockScreenInfo) name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLockScreenInfo) name:ISMSNotification_AlbumArtLargeDownloaded object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(didReceiveMemoryWarning) 
												 name:UIApplicationDidReceiveMemoryWarningNotification 
											   object:nil];
	
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain {
    return self;
}

- (unsigned)retainCount {
    return UINT_MAX;  // denotes an object that cannot be released
}

- (oneway void)release {
    //do nothing
}

- (id)autorelease {
    return self;
}

@end
