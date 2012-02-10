//
//  MusicControlsSingleton.m
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
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "Reachability.h"
#import "JukeboxXMLParser.h"
#import "NSURLConnectionDelegateQueue.h"
#import "JukeboxConnectionDelegate.h"
#import "BBSimpleConnectionQueue.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
#import "NSMutableURLRequest+SUS.h"
#import "OrderedDictionary.h"
#import "SUSLyricsLoader.h" 
#import "SUSStreamSingleton.h"
#import "PlaylistSingleton.h"
#import "AudioEngine.h"
#import <MediaPlayer/MediaPlayer.h>
#import "SUSCoverArtLargeDAO.h"
#import "FMDatabase+Synchronized.h"
#import "CacheSingleton.h"

static MusicSingleton *sharedInstance = nil;

@implementation MusicSingleton

// Music player objects
//
@synthesize queueSongObject; 

// Song cache stuff
@synthesize receivedDataQueue, downloadQueue, downloadFileNameQueue, downloadFileNameHashQueue, audioFileQueue, downloadedLengthQueue, isQueueListDownloading;

@synthesize jukeboxIsPlaying, jukeboxGain;

@synthesize connectionQueue;

#pragma mark -
#pragma mark Class instance methods
#pragma mark -

#pragma mark Subsonic chache notification hack and Last.fm scrobbling connection delegate

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	// Do nothing
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
	if ([incrementalData length] > 0)
	{
		// Subsonic has been notified, cancel the connection
		[theConnection cancel];
		[theConnection release];
	}
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	DLog(@"Subsonic cached song play notification failed\n\nError: %@", [error localizedDescription]);
	[theConnection release];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	[theConnection release];
}

#pragma mark - Lyric Loader Delegate

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error
{
	DLog(@"theLoader: %@", theLoader);
	theLoader.delegate = nil;
    [theLoader release];
}

- (void)loadingFinished:(SUSLoader *)theLoader
{
	DLog(@"theLoader: %@", theLoader);
	theLoader.delegate = nil;
    [theLoader release];
}

#pragma mark Download Methods

- (Song *)nextQueuedSong
{
	Song *aSong = nil;
	FMResultSet *result = [databaseControls.songCacheDb synchronizedQuery:@"SELECT * FROM cacheQueue WHERE finished = 'NO' LIMIT 1"];
	if ([databaseControls.songCacheDb hadError]) 
	{
		DLog(@"Err %d: %@", [databaseControls.songCacheDb lastErrorCode], [databaseControls.songCacheDb lastErrorMessage]);
	}
	else
	{
		aSong = [Song songFromDbResult:result];
	}
	
	[result close];
	return aSong;
}

// Start downloading the file specified in the text field.
- (void)startDownloadQueue
{		
	DLog(@"queueSongObject songId: %@", queueSongObject.songId);
	
	Song *currentSong = [PlaylistSingleton sharedInstance].currentSong;
	Song *nextSong = [PlaylistSingleton sharedInstance].nextSong;
	
	DLog(@"startDownloadQueue called");
	
	// Are we already downloading?  If so, stop it.
	[self stopDownloadQueue];
    
    // Grab the lyrics
	if (queueSongObject.artist && queueSongObject.title && [SavedSettings sharedInstance].isLyricsEnabled)
	{
        SUSLyricsLoader *lyricsLoader = [[SUSLyricsLoader alloc] initWithDelegate:self];
		DLog(@"lyricsLoader: %@", lyricsLoader);
        lyricsLoader.artist = queueSongObject.artist;
        lyricsLoader.title = queueSongObject.title;
        [lyricsLoader startLoad];        
	}
	
	isQueueListDownloading = YES;
	
	// Reset the download counter
	downloadedLengthQueue = 0;
	
	// Determine the hashed filename
	self.downloadFileNameHashQueue = nil; self.downloadFileNameHashQueue = [queueSongObject.path md5];
	
	// Determine the name of the file we are downloading.
	self.downloadFileNameQueue = queueSongObject.localPath;

	// Check to see if the song is already cached
	if ([databaseControls.songCacheDb synchronizedIntForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE md5 = ?", downloadFileNameHashQueue])
	{
		// Looks like the song is in the database, check if it's cached fully
		NSString *isDownloadFinished = [databaseControls.songCacheDb synchronizedStringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", downloadFileNameHashQueue];
		if ([isDownloadFinished isEqualToString:@"YES"])
		{
			// The song is fully cached, so delete it from the cache queue database
			[databaseControls.cacheQueueDb executeUpdate:@"DELETE FROM cacheQueue WHERE md5 = ?", downloadFileNameHashQueue];
			
			// Start queuing the next song if there is one
			if ([databaseControls.cacheQueueDb intForQuery:@"SELECT COUNT(*) FROM cacheQueue"] > 0)
			{
				self.queueSongObject = nil; self.queueSongObject = [self nextQueuedSong];
				[self startDownloadQueue];
			}
		}
		else
		{
			// The song is not fully cached, check to see if it is the current or next playing song
			
			BOOL doDownload = YES;
			if (currentSong.path)
			{
				if ([currentSong.path isEqualToString:queueSongObject.path])
				{
					// This is the current song so don't download
					doDownload = NO;
				}
			}
			if (nextSong.path)
			{
				if ([nextSong.path isEqualToString:queueSongObject.path])
				{
					// This is the next song so don't download
					doDownload = NO;
				}
			}
			
			if (doDownload)
			{
				// Delete the row from cachedSongs
				[databaseControls.songCacheDb synchronizedUpdate:@"DELETE FROM cachedSongs WHERE md5 = downloadFileNameHashQueue"];
				
				// Remove and recreate the song file on disk
				[[NSFileManager defaultManager] removeItemAtPath:downloadFileNameQueue error:NULL];
				[[NSFileManager defaultManager] createFileAtPath:downloadFileNameQueue contents:[NSData data] attributes:nil];
				self.audioFileQueue = nil; self.audioFileQueue = [NSFileHandle fileHandleForWritingAtPath:downloadFileNameQueue];
				
				// Start the download
				NSURLConnectionDelegateQueue *connDelegateQueue = [[NSURLConnectionDelegateQueue alloc] init];
                NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObject:n2N(queueSongObject.songId) forKey:@"id"];
				if ([SavedSettings sharedInstance].currentMaxBitrate != 0)
				{
					NSString *bitrate = [[NSString alloc] initWithFormat:@"%i", [SavedSettings sharedInstance].currentMaxBitrate];
					[parameters setObject:n2N(bitrate) forKey:@"maxBitRate"];
					[bitrate release];
				}
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"stream" andParameters:parameters];
				self.downloadQueue = [NSURLConnection connectionWithRequest:request delegate:connDelegateQueue];
				[connDelegateQueue release];
			}
			else 
			{
				// The song will be cached by the player soon, so delete it from the cache queue database
				[databaseControls.cacheQueueDb executeUpdate:@"DELETE FROM cacheQueue WHERE md5 = ?", downloadFileNameHashQueue];
				
				// Start queuing the next song if there is one
				if ([databaseControls.cacheQueueDb intForQuery:@"SELECT COUNT(*) FROM cacheQueue"] > 0)
				{
					self.queueSongObject = nil; self.queueSongObject = [self nextQueuedSong];
					[self startDownloadQueue];
				}
			}
			
		}
	}
	else 
	{
		BOOL doDownload = YES;
		if (currentSong.path)
		{
			if ([currentSong.path isEqualToString:queueSongObject.path])
			{
				// This is the current song so don't download
				doDownload = NO;
			}
		}
		if (nextSong.path)
		{
			if ([nextSong.path isEqualToString:queueSongObject.path])
			{
				// This is the next song so don't download
				doDownload = NO;
			}
		}
		
		if (doDownload)
		{
			// The song has not been cached yet, start from scratch
						
			// Create new file on disk
			[[NSFileManager defaultManager] createFileAtPath:downloadFileNameQueue contents:[NSData data] attributes:nil];
			self.audioFileQueue = [NSFileHandle fileHandleForWritingAtPath:downloadFileNameQueue];
			
			// Start the download
			NSURLConnectionDelegateQueue *connDelegateQueue = [[NSURLConnectionDelegateQueue alloc] init];
			NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObject:n2N(queueSongObject.songId) forKey:@"id"];
			if ([SavedSettings sharedInstance].currentMaxBitrate != 0)
			{
				NSString *bitrate = [[NSString alloc] initWithFormat:@"%i", [SavedSettings sharedInstance].currentMaxBitrate];
				[parameters setObject:n2N(bitrate) forKey:@"maxBitRate"];
				[bitrate release];
			}
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"stream" andParameters:parameters];
			self.downloadQueue = [NSURLConnection connectionWithRequest:request delegate:connDelegateQueue];
			//[connDelegateQueue release];
		}
	}
}

- (void)resumeDownloadQueue:(UInt32)byteOffset
{
	// Create the request and resume the download
	if (!viewObjects.isOfflineMode)
	{
		NSURLConnectionDelegateQueue *connDelegateQueue = [[NSURLConnectionDelegateQueue alloc] init];	
        NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(queueSongObject.songId) forKey:@"id"];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"stream" andParameters:parameters];
        
		NSString *range = [NSString stringWithFormat:@"bytes=%i-", byteOffset];
		[request setValue:range forHTTPHeaderField:@"Range"];
		self.downloadQueue = [NSURLConnection connectionWithRequest:request delegate:connDelegateQueue];
		[connDelegateQueue release];		
	}
}

- (void)stopDownloadQueue
{
	isQueueListDownloading = NO;
	
	if (downloadQueue) 
	{
		[downloadQueue cancel];
		self.downloadQueue = nil;
	}		
	
	// Delete the unfinished download
	NSString *isDownloadFinished = [databaseControls.cacheQueueDb stringForQuery:@"SELECT finished FROM cacheQueue WHERE md5 = ?", downloadFileNameHashQueue];
	if ([isDownloadFinished isEqualToString:@"NO"])
	{		
		// Delete the song from disk
		[[NSFileManager defaultManager] removeItemAtPath:downloadFileNameQueue error:NULL];
	}
}

- (void)downloadNextQueuedSong
{
	@synchronized(self)
	{
		if (appDelegate.isWifi)
		{
			if ([databaseControls.cacheQueueDb intForQuery:@"SELECT COUNT(*) FROM cacheQueue"] > 0)
			{
				isQueueListDownloading = YES;
				self.queueSongObject = nil; self.queueSongObject = [self nextQueuedSong];
				[self startDownloadQueue];
			}
			else
			{
				isQueueListDownloading = NO;
			}
		}
		else
		{
			isQueueListDownloading = NO;
		}
	}
}

#pragma mark Control Methods

unsigned long long startSongBytes = 0;
double startSongSeconds = 0.0;
- (void)startSongAtOffsetInBytes:(unsigned long long)bytes andSeconds:(double)seconds
{
	// Destroy the streamer to start a new song
	[audio stop];
	
	Song *currentSong = [PlaylistSingleton sharedInstance].currentSong;
	
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
	SavedSettings *settings = [SavedSettings sharedInstance];
	SUSStreamSingleton *streamSingleton = [SUSStreamSingleton sharedInstance];
	
	// Always clear the temp cache
	[[CacheSingleton sharedInstance] clearTempCache];
	
	Song *currentSong = [PlaylistSingleton sharedInstance].currentSong;
	
	// Check to see if the song is already cached
	if (currentSong.isFullyCached)
	{
		// The song is fully cached, start streaming from the local copy
		[audio startWithOffsetInBytes:[NSNumber numberWithUnsignedLongLong:startSongBytes] 
							orSeconds:[NSNumber numberWithDouble:startSongSeconds]];
		
		// Fill the stream queue
		if (!viewObjects.isOfflineMode)
			[streamSingleton fillStreamQueue];
	}
	else if (!currentSong.isFullyCached && viewObjects.isOfflineMode)
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
		// Clear the stream manager
		[streamSingleton removeAllStreams];
		
		BOOL isTempCache = NO;
		if (startSongBytes > 0)
			isTempCache = YES;
		else if (!settings.isSongCachingEnabled)
			isTempCache = YES;
		
		// Start downloading the current song from the correct offset
		[streamSingleton queueStreamForSong:currentSong 
								 byteOffset:startSongBytes 
							  secondsOffset:startSongSeconds 
									atIndex:0 
								isTempCache:isTempCache];
		
		// Fill the stream queue
		if (settings.isSongCachingEnabled)
			[streamSingleton fillStreamQueue];
	}
	
	/*DLog(@"running startSongAtOffsetInSeconds2");
	SUSStreamSingleton *streamSingleton = [SUSStreamSingleton sharedInstance];
	Song *currentSong = [SUSCurrentPlaylistDAO dataModel].currentSong;

	// Remove all songs from the queue except the current one if it exists
	[streamSingleton removeAllStreamsExceptForSong:currentSong];
	
	// Fill the stream queue
	[streamSingleton fillStreamQueue];
	
	// The file is not fully cached and we're in offline mode, so complain
	if (!currentSong.isFullyCached && viewObjects.isOfflineMode)
	{
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"Unable to play this song in offline mode as it isn't fully cached." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		alert.tag = 4;
		[alert show];
		[alert release];
	}*/
}

- (void)startSong
{
	[self startSongAtOffsetInBytes:0 andSeconds:0.0];
}

- (void)playSongAtPosition:(NSInteger)position
{
	[[SUSStreamSingleton sharedInstance] removeAllStreams];
	
	[PlaylistSingleton sharedInstance].currentIndex = position;
	
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		[self jukeboxPlaySongAtPosition:[NSNumber numberWithInt:position]];
	}
	else
	{		
		[self startSong];
	}
	
	//[self addAutoNextNotification];
}

- (void)prevSong
{
	NSInteger currentIndex = [PlaylistSingleton sharedInstance].currentIndex;
	
	if (audio.progress > 10.0)
	{
		// Past 10 seconds in the song, so restart playback instead of changing songs
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
			[self jukeboxPlaySongAtPosition:[NSNumber numberWithInt:currentIndex]];
		else
			[self playSongAtPosition:currentIndex];
	}
	else
	{
		// Within first 10 seconds, go to previous song
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
		{
			[self jukeboxPrevSong];
		}
		else
		{
			NSInteger index = currentIndex - 1;
			if (index >= 0)
			{
				currentIndex = index;
								
				[self playSongAtPosition:index];
				
				//[self addAutoNextNotification];
			}
		}
	}
}

- (void)nextSong
{
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		[self jukeboxNextSong];
	}
	else
	{		
		NSInteger index = [PlaylistSingleton sharedInstance].currentIndex + 1;
		if (index <= ([databaseControls.currentPlaylistDb intForQuery:@"SELECT COUNT(*) FROM currentPlaylist"] - 1))
		{
			[PlaylistSingleton sharedInstance].currentIndex = index;
			[self startSong];			
		}
		else
		{
            [audio stop];
			[[SavedSettings sharedInstance] saveState];
		}
	}
}

// Resume song after iSub shuts down
- (void)resumeSong
{	
	SavedSettings *settings = [SavedSettings sharedInstance];
	PlaylistSingleton *currentPlaylistDAO = [PlaylistSingleton sharedInstance];
	Song *currentSong = currentPlaylistDAO.currentSong;
		
	DLog(@"isRecover: %@  currentSong: %@", NSStringFromBOOL(settings.isRecover), currentSong);
	DLog(@"byteOffset: %llu   seekTime: %f", settings.byteOffset, settings.seekTime);
	
	if (currentSong && settings.isRecover)
	{
		[self startSongAtOffsetInBytes:settings.byteOffset andSeconds:settings.seekTime];
	}
	else
	{
		audio.startByteOffset = settings.byteOffset;
		audio.startSecondsOffset = settings.seekTime;
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
		[[NSNotificationCenter defaultCenter] postNotificationName:@"showPlayer" object:nil];
	}
	else
	{
		iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
		streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
		[(UINavigationController*)appDelegate.currentTabBarController.selectedViewController pushViewController:streamingPlayerViewController animated:YES];
		[streamingPlayerViewController release];
	}
}

- (void)updateLockScreenInfo
{
	if ([NSClassFromString(@"MPNowPlayingInfoCenter") class])  
	{
		/* we're on iOS 5, so set up the now playing center */
		AudioEngine *wrapper = [AudioEngine sharedInstance];
		PlaylistSingleton *dataModel = [PlaylistSingleton sharedInstance];
		SUSCoverArtLargeDAO *artDataModel = [SUSCoverArtLargeDAO dataModel];
		
		Song *currentSong = dataModel.currentSong;
		
		UIImage *albumArtImage = [artDataModel coverArtImageForId:currentSong.coverArtId];
		if (!albumArtImage)
			albumArtImage = artDataModel.defaultCoverArt;
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
		NSNumber *trackIndex = [NSNumber numberWithInt:dataModel.currentIndex];
		if (trackIndex)
			[trackInfo setObject:trackIndex forKey:MPNowPlayingInfoPropertyPlaybackQueueIndex];
		NSNumber *playlistCount = [NSNumber numberWithInt:dataModel.count];
		if (playlistCount)
			[trackInfo setObject:playlistCount forKey:MPNowPlayingInfoPropertyPlaybackQueueCount];
		NSNumber *progress = [NSNumber numberWithDouble:wrapper.progress];
		if (progress)
			[trackInfo setObject:progress forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
		
		[MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = trackInfo;
	}
}

#pragma mark -
#pragma mark Jukebox Control methods

- (void)jukeboxPlaySongAtPosition:(NSNumber *)position
{
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
	    
    NSString *positionString = [position stringValue];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"skip", @"action", n2N(positionString), @"index", nil];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" andParameters:parameters];
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
		PlaylistSingleton *dataModel = [PlaylistSingleton sharedInstance];
		
		dataModel.currentIndex = [position intValue];
		
		[connectionQueue registerConnection:connection];
		[connectionQueue startQueue];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
	
	[connDelegate release];
}


- (void)jukeboxPlay
{
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
	    
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:@"start" forKey:@"action"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" andParameters:parameters];
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
		[connectionQueue registerConnection:connection];
		[connectionQueue startQueue];
	}
	else
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
	
	[connDelegate release];
	
	jukeboxIsPlaying = YES;
}

- (void)jukeboxStop
{
	
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:@"stop" forKey:@"action"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" andParameters:parameters];
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
		[connectionQueue registerConnection:connection];
		[connectionQueue startQueue];
	}
	else
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
	
	[connDelegate release];
	
	jukeboxIsPlaying = NO;
}

- (void)jukeboxPrevSong
{
	NSInteger index = [PlaylistSingleton sharedInstance].currentIndex - 1;
	if (index >= 0)
	{						
		[self jukeboxPlaySongAtPosition:[NSNumber numberWithInt:index]];
		
		jukeboxIsPlaying = YES;
	}
}

- (void)jukeboxNextSong
{
	NSInteger index = [PlaylistSingleton sharedInstance].currentIndex + 1;
	if (index <= ([databaseControls.currentPlaylistDb intForQuery:@"SELECT COUNT(*) FROM jukeboxCurrentPlaylist"] - 1))
	{		
		[self jukeboxPlaySongAtPosition:[NSNumber numberWithInt:index]];
		
		jukeboxIsPlaying = YES;
	}
	else
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:ISMSNotification_SongPlaybackEnded object:nil];
		[self jukeboxStop];
		
		jukeboxIsPlaying = NO;
	}
}

- (void)jukeboxSetVolume:(float)level
{
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
    
    NSString *gainString = [NSString stringWithFormat:@"%f", level];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"setGain", @"action", n2N(gainString), @"gain", nil];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" andParameters:parameters];
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
		[connectionQueue registerConnection:connection];
		[connectionQueue startQueue];
	}
	else
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
	
	[connDelegate release];
}

- (void)jukeboxAddSong:(NSString*)songId
{
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"add", @"action", n2N(songId), @"id", nil];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" andParameters:parameters];
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
		[connectionQueue registerConnection:connection];
		[connectionQueue startQueue];
	}
	else
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
	
	[connDelegate release];
}

- (void)jukeboxAddSongs:(NSArray*)songIds
{
	if ([songIds count] > 0)
	{
        JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
        
        NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObject:@"add" forKey:@"action"];
		[parameters setObject:n2N(songIds) forKey:@"id"];
		
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" andParameters:parameters];
		
        NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
		if (connection)
		{
			[connectionQueue registerConnection:connection];
			[connectionQueue startQueue];
		}
		else
		{
			// Inform the user that the connection failed.
			CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
			[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
			[alert release];
		}
		
		[connDelegate release];
	}
}

- (void)jukeboxReplacePlaylistWithLocal
{
	[self jukeboxClearRemotePlaylist];
	
	PlaylistSingleton *currentPlaylist = [PlaylistSingleton sharedInstance];
	
	NSMutableArray *songIds = [[NSMutableArray alloc] init];
	
	FMResultSet *result;
	if (currentPlaylist.isShuffle)
		result = [databaseControls.currentPlaylistDb executeQuery:@"SELECT songId FROM jukeboxShufflePlaylist"];
	else
		result = [databaseControls.currentPlaylistDb executeQuery:@"SELECT songId FROM jukeboxCurrentPlaylist"];
	
	while ([result next])
	{
		if ([result stringForColumnIndex:0] != nil)
			[songIds addObject:[NSString stringWithString:[result stringForColumnIndex:0]]];
	}
	[result close];
	
	[self jukeboxAddSongs:songIds];
	
	[songIds release];
}


- (void)jukeboxRemoveSong:(NSString*)songId
{
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"remove", @"action", n2N(songId), @"id", nil];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" andParameters:parameters];
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
		[connectionQueue registerConnection:connection];
		[connectionQueue startQueue];
	}
	else
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
	
	[connDelegate release];
}

- (void)jukeboxClearPlaylist
{
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:@"clear" forKey:@"action"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" andParameters:parameters];
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
		[databaseControls resetJukeboxPlaylist];

		[connectionQueue registerConnection:connection];
		[connectionQueue startQueue];
	}
	else
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}

	[connDelegate release];
}

- (void)jukeboxClearRemotePlaylist
{
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:@"clear" forKey:@"action"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" andParameters:parameters];
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
		[connectionQueue registerConnection:connection];
		[connectionQueue startQueue];
	}
	else
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
	
	[connDelegate release];
}

- (void)jukeboxShuffle
{
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
	
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:@"shuffle" forKey:@"action"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" andParameters:parameters];
    
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
		[databaseControls resetJukeboxPlaylist];
		
		[connectionQueue registerConnection:connection];
		[connectionQueue startQueue];
	}
	else
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
	
	[connDelegate release];
}

- (void)jukeboxGetInfo
{	
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
	connDelegate.isGetInfo = YES;
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:@"get" forKey:@"action"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" andParameters:parameters];
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
		[databaseControls resetJukeboxPlaylist];
	
		[connectionQueue registerConnection:connection];
		[connectionQueue startQueue];
	}
	else
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
	
	[connDelegate release];
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
	
	audio = [AudioEngine sharedInstance];
	
	//initialize here
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	databaseControls = [DatabaseSingleton sharedInstance];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	
	isAutoNextNotificationOn = NO;
	
	//[self addAutoNextNotification];
	
	connectionQueue = [[BBSimpleConnectionQueue alloc] init];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLockScreenInfo) name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLockScreenInfo) name:ISMSNotification_AlbumArtLargeDownloaded object:nil];
	
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
