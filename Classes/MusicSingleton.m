//
//  musicSSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "MusicSingleton.h"
#import "JukeboxXMLParser.h"
#import "JukeboxConnectionDelegate.h"
#import "iPhoneStreamingPlayerViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "iPadRootViewController.h"
#import "MenuViewController.h"
#import "ISMSStreamHandler.h"

static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation MusicSingleton

#pragma mark Control Methods

unsigned long long startSongBytes = 0;
double startSongSeconds = 0.0;
- (void)startSongAtOffsetInBytes:(unsigned long long)bytes andSeconds:(double)seconds
{
	// Only allowed to manipulate BASS from the main thread
	if (![NSThread mainThread])
		return;

    //DLog(@"starting song at offset");
	
	// Destroy the streamer to start a new song
	[audioEngineS.player stop];
	
	ISMSSong *currentSong = playlistS.currentSong;
	
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
    [self removeMoviePlayer];
    
	//DLog(@"startSongAtOffsetInSeconds2");	
	// Always clear the temp cache
	[cacheS clearTempCache];
	
	ISMSSong *currentSong = playlistS.currentSong;
    NSUInteger currentIndex = playlistS.currentIndex;
	
	if (!currentSong)
		return;
	
	// Check to see if the song is already cached
	if (currentSong.isFullyCached)
	{
		// The song is fully cached, start streaming from the local copy
        [audioEngineS startSong:currentSong atIndex:currentIndex withOffsetInBytes:[NSNumber numberWithUnsignedLongLong:startSongBytes] orSeconds:[NSNumber numberWithDouble:startSongSeconds]];
		
		// Fill the stream queue
		if (!viewObjectsS.isOfflineMode)
			[streamManagerS fillStreamQueue:audioEngineS.player.isStarted];
	}
	else if (!currentSong.isFullyCached && viewObjectsS.isOfflineMode)
	{
		/*// The song is not fully cached and this is offline mode, so warn that it can't be played
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" 
																	message:@"Unable to play this song in offline mode as it isn't fully cached." 
																   delegate:self 
														  cancelButtonTitle:@"Ok" 
														  otherButtonTitles:nil];
		alert.tag = 4;
		[alert show];*/
		
		[self playSongAtPosition:playlistS.nextIndex];
	}
	else
	{
		if ([cacheQueueManagerS.currentQueuedSong isEqualToSong:currentSong])
		{
			// The cache queue is downloading this song, remove it before continuing
			[cacheQueueManagerS removeCurrentSong];
		}
		
		if ([streamManagerS isSongDownloading:currentSong])
		{
			// The song is caching, start streaming from the local copy
			ISMSStreamHandler *handler = [streamManagerS handlerForSong:currentSong];
			if (!audioEngineS.player.isPlaying && handler.isDelegateNotifiedToStartPlayback)
			{
				// Only start the player if the handler isn't going to do it itself
                [audioEngineS startSong:currentSong atIndex:currentIndex withOffsetInBytes:[NSNumber numberWithUnsignedLongLong:startSongBytes] orSeconds:[NSNumber numberWithDouble:startSongSeconds]];
			}
		}
		else if ([streamManagerS isSongFirstInQueue:currentSong] && ![streamManagerS isQueueDownloading])
		{
			// The song is first in queue, but the queue is not downloading. Probably the song was downloading
			// when the app quit. Resume the download and start the player
			[streamManagerS resumeQueue];
			
			// The song is caching, start streaming from the local copy
			ISMSStreamHandler *handler = [streamManagerS handlerForSong:currentSong];
			if (!audioEngineS.player.isPlaying && handler.isDelegateNotifiedToStartPlayback)
			{
				// Only start the player if the handler isn't going to do it itself
                [audioEngineS startSong:currentSong atIndex:currentIndex withOffsetInBytes:[NSNumber numberWithUnsignedLongLong:startSongBytes] orSeconds:[NSNumber numberWithDouble:startSongSeconds]];
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
									isTempCache:isTempCache
								isStartDownload:YES];
			
			// Fill the stream queue
			if (settingsS.isSongCachingEnabled)
				[streamManagerS fillStreamQueue:audioEngineS.player.isStarted];
		}
	}
}

- (void)startSong
{	
	[self startSongAtOffsetInBytes:0 andSeconds:0.0];
}

- (ISMSSong *)playSongAtPosition:(NSInteger)position
{
	playlistS.currentIndex = position;
    ISMSSong *currentSong = playlistS.currentSong;
 
    if (!currentSong.isVideo)
    {
        // Remove the video player if this is not a video
        [self removeMoviePlayer];
    }
    
	if (settingsS.isJukeboxEnabled)
	{
        if (currentSong.isVideo)
        {
            currentSong = nil;
            [EX2SlidingNotification slidingNotificationOnMainWindowWithMessage:@"Cannot play videos in Jukebox mode." image:nil];
        }
        else
        {
            [jukeboxS jukeboxPlaySongAtPosition:[NSNumber numberWithInt:position]];
        }
	}
	else
	{
		[streamManagerS removeAllStreamsExceptForSong:playlistS.currentSong];
        
        if (currentSong.isVideo)
        {
            [self playVideo:currentSong];
        }
        else
        {
            [self startSong];
        }
	}
    
    return currentSong;
}

- (void)prevSong
{	
	DDLogVerbose(@"musicS prevSong called");
	if (audioEngineS.player.progress > 10.0)
	{
		// Past 10 seconds in the song, so restart playback instead of changing songs
		DDLogVerbose(@"musicS prevSong Past 10 seconds in the song, so restart playback instead of changing songs, calling playSongAtPosition:%u", playlistS.currentIndex);
		[self playSongAtPosition:playlistS.currentIndex];
	}
	else
	{
		// Within first 10 seconds, go to previous song
		DDLogVerbose(@"musicS prevSong within first 10 seconds, so go to previous, calling playSongAtPosition:%u", playlistS.prevIndex);
		[self playSongAtPosition:playlistS.prevIndex];
	}
}

- (void)nextSong
{
	DDLogVerbose(@"musicS nextSong called, calling playSongAtPosition:%u", playlistS.nextIndex);
	[self playSongAtPosition:playlistS.nextIndex];
}

// Resume song after iSub shuts down
- (void)resumeSong
{    
	ISMSSong *currentSong = playlistS.currentSong;
		
//DLog(@"isRecover: %@  currentSong: %@", NSStringFromBOOL(settingsS.isRecover), currentSong);
//DLog(@"byteOffset: %llu   seekTime: %f\n   ", settingsS.byteOffset, settingsS.seekTime);
	
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
	}
}

- (void)updateLockScreenInfo
{
	if ([NSClassFromString(@"MPNowPlayingInfoCenter") class])  
	{
		/* we're on iOS 5, so set up the now playing center */
		NSMutableDictionary *trackInfo = [NSMutableDictionary dictionaryWithCapacity:10];
		
		ISMSSong *currentSong = playlistS.currentSong;
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
		NSNumber *progress = [NSNumber numberWithDouble:audioEngineS.player.progress];
		if (progress)
			[trackInfo setObject:progress forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
		
		if (settingsS.isLockScreenArtEnabled)
		{
			SUSCoverArtDAO *artDataModel = [[SUSCoverArtDAO alloc] initWithDelegate:nil coverArtId:currentSong.coverArtId isLarge:YES];
			[trackInfo setObject:[[MPMediaItemArtwork alloc] initWithImage:artDataModel.coverArtImage] 
						  forKey:MPMediaItemPropertyArtwork];
		}
		
		[MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = trackInfo;
	}
	
	// Run this every 30 seconds to update the progress and keep it in sync
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateLockScreenInfo) object:nil];
	[self performSelector:@selector(updateLockScreenInfo) withObject:nil afterDelay:30.0];
}

- (void)createMoviePlayer
{
    if (!self.moviePlayer)
    {
        self.moviePlayer = [[MPMoviePlayerController alloc] init];//WithContentURL:[NSURL URLWithString:urlString]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayerExitedFullscreen:) name:MPMoviePlayerDidExitFullscreenNotification object:self.moviePlayer];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayBackDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:self.moviePlayer];
        
        self.moviePlayer.controlStyle = MPMovieControlStyleDefault;
        self.moviePlayer.shouldAutoplay = YES;
        self.moviePlayer.movieSourceType = MPMovieSourceTypeStreaming;
        self.moviePlayer.allowsAirPlay = YES;
        
        //[(IS_IPAD() ? appDelegateS.ipadRootViewController.menuViewController.playerHolder : appDelegateS.mainTabBarController.view) addSubview:moviePlayer.view];
        
        if (IS_IPAD())
        {
            [appDelegateS.ipadRootViewController.menuViewController.playerHolder addSubview:self.moviePlayer.view];
            self.moviePlayer.view.frame = self.moviePlayer.view.superview.bounds;
        }
        else
        {
            [appDelegateS.mainTabBarController.view addSubview:self.moviePlayer.view];
            self.moviePlayer.view.frame = CGRectZero;
        }
        
        [self.moviePlayer setFullscreen:YES animated:YES];
    }
}

- (void)removeMoviePlayer
{
    if (self.moviePlayer)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerDidExitFullscreenNotification object:self.moviePlayer];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:self.moviePlayer];
        
        // Dispose of any existing movie player
        [self.moviePlayer stop];
        [self.moviePlayer.view removeFromSuperview];
        self.moviePlayer = nil;
    }
}

- (void)playVideo:(ISMSSong *)aSong
{
    if (!aSong.isVideo || !settingsS.isVideoSupported)
        return;
        
    if (IS_IPAD())
    {
        // Turn off repeat one so user doesn't get stuck
        if (playlistS.repeatMode == ISMSRepeatMode_RepeatOne)
            playlistS.repeatMode = ISMSRepeatMode_Normal;
    }
    
    NSString *serverType = settingsS.serverType;
    if ([serverType isEqualToString:SUBSONIC] || [serverType isEqualToString:UBUNTU_ONE])
    {
        [self playSubsonicVideo:aSong];
    }
    else if ([serverType isEqualToString:WAVEBOX])
    {
        [self playWaveBoxVideo:aSong];
    }
}

- (void)playSubsonicVideo:(ISMSSong *)aSong
{
    [audioEngineS.player stop];
    
    if (!aSong.itemId)
        return;
    
    NSDictionary *parameters = @{ @"id" : aSong.itemId, @"bitRate" : @[@"1024",@"60"] };
    NSURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"hls" parameters:parameters];
    
    NSString *urlString = [NSString stringWithFormat:@"%@?%@", request.URL.absoluteString, [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]];
    
    //NSString *urlString = [NSString stringWithFormat:@"%@/rest/hls.m3u8?c=iSub&v=1.8.0&u=%@&p=%@&id=%@", settingsS.urlString, [settingsS.username URLEncodeString], [settingsS.password URLEncodeString], aSong.itemId];
    DLog(@"urlString: %@", urlString);
    
    [self createMoviePlayer];
    
    self.moviePlayer.contentURL = [NSURL URLWithString:urlString];
    //[moviePlayer prepareToPlay];
    [self.moviePlayer play];
}

- (void)playWaveBoxVideo:(ISMSSong *)aSong
{
    
}

- (void)moviePlayerExitedFullscreen:(NSNotification *)notification
{
    // Hack to fix broken navigation bar positioning
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    UIView *view = [window.subviews lastObject];
    if (view)
    {
        [view removeFromSuperview];
        [window addSubview:view];
    }
    
    if (!IS_IPAD())
    {
        [self removeMoviePlayer];
    }
}

- (void)moviePlayBackDidFinish:(NSNotification *)notification
{
    DLog(@"userInfo: %@", notification.userInfo);
    if (notification.userInfo)
    {
        NSNumber *reason = [notification.userInfo objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
        if (reason && reason.integerValue == MPMovieFinishReasonPlaybackEnded)
        {
            // Playback ended normally, so start the next item
            [playlistS incrementIndex];
            [self playSongAtPosition:playlistS.currentIndex];
        }
    }
    else
    {
        //[self removeMoviePlayer];
    }
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
//DLog(@"received memory warning");
	
	
}

#pragma mark -
#pragma mark Singleton methods

- (void)setup 
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLockScreenInfo) name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLockScreenInfo) name:ISMSNotification_AlbumArtLargeDownloaded object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(didReceiveMemoryWarning) 
												 name:UIApplicationDidReceiveMemoryWarningNotification 
											   object:nil];
}

+ (id)sharedInstance
{
    static MusicSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
