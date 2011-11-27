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
#import "SUSCurrentPlaylistDAO.h"
#import "BassWrapperSingleton.h"
#import <MediaPlayer/MediaPlayer.h>
#import "SUSCoverArtLargeDAO.h"

static MusicSingleton *sharedInstance = nil;

@implementation MusicSingleton

// Audio streamer objects and variables
//
@synthesize repeatMode, isShuffle;

// Music player objects
//
@synthesize queueSongObject, currentSongLyrics, coverArtUrl; 

// Song cache stuff
@synthesize documentsPath, audioFolderPath, tempAudioFolderPath;
@synthesize receivedDataQueue, downloadQueue, downloadFileNameQueue, downloadFileNameHashQueue, audioFileQueue, downloadedLengthQueue, isQueueListDownloading;
@synthesize bitRate, isTempDownload, showNowPlayingIcon;

@synthesize songB;

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
    [theLoader release]; theLoader = nil;
}

- (void)loadingFinished:(SUSLoader *)theLoader
{
    [theLoader release]; theLoader = nil;
}

#pragma mark Download Methods

- (Song *) nextQueuedSong
{
	Song *aSong = [[Song alloc] init];
	FMResultSet *result = [databaseControls.songCacheDb executeQuery:@"SELECT * FROM cacheQueue WHERE finished = 'NO' LIMIT 1"];
	if ([databaseControls.songCacheDb hadError]) 
	{
		DLog(@"Err %d: %@", [databaseControls.songCacheDb lastErrorCode], [databaseControls.songCacheDb lastErrorMessage]);
	}
	else
	{
		[result next];
		
		if ([result stringForColumn:@"title"] != nil)
			aSong.title = [[result stringForColumn:@"title"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		if ([result stringForColumn:@"songId"] != nil)
			aSong.songId = [NSString stringWithString:[result stringForColumn:@"songId"]];
		if ([result stringForColumn:@"artist"] != nil)
			aSong.artist = [[result stringForColumn:@"artist"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		if ([result stringForColumn:@"album"] != nil)
			aSong.album = [[result stringForColumn:@"album"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		if ([result stringForColumn:@"genre"] != nil)
			aSong.genre = [[result stringForColumn:@"genre"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		if ([result stringForColumn:@"coverArtId"] != nil)
			aSong.coverArtId = [NSString stringWithString:[result stringForColumn:@"coverArtId"]];
		if ([result stringForColumn:@"path"] != nil)
			aSong.path = [NSString stringWithString:[result stringForColumn:@"path"]];
		if ([result stringForColumn:@"suffix"] != nil)
			aSong.suffix = [NSString stringWithString:[result stringForColumn:@"suffix"]];
		if ([result stringForColumn:@"transcodedSuffix"] != nil)
			aSong.transcodedSuffix = [NSString stringWithString:[result stringForColumn:@"transcodedSuffix"]];
		aSong.duration = [NSNumber numberWithInt:[result intForColumn:@"duration"]];
		aSong.bitRate = [NSNumber numberWithInt:[result intForColumn:@"bitRate"]];
		aSong.track = [NSNumber numberWithInt:[result intForColumn:@"track"]];
		aSong.year = [NSNumber numberWithInt:[result intForColumn:@"year"]];
		aSong.size = [NSNumber numberWithInt:[result intForColumn:@"size"]];
	}
	
	[result close];
	return [aSong autorelease];
}

// Start downloading the file specified in the text field.
- (void)startDownloadQueue
{		
	Song *currentSong = [SUSCurrentPlaylistDAO dataModel].currentSong;
	Song *nextSong = [SUSCurrentPlaylistDAO dataModel].nextSong;
	
	DLog(@"startDownloadQueue called");
	
	// Are we already downloading?  If so, stop it.
	[self stopDownloadQueue];
    
    // Grab the lyrics
	if (queueSongObject.artist && queueSongObject.title)
	{
        SUSLyricsLoader *lyricsLoader = [[SUSLyricsLoader alloc] initWithDelegate:self];
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
	self.downloadFileNameQueue = nil;
	if (queueSongObject.transcodedSuffix)
		self.downloadFileNameQueue = [audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashQueue, queueSongObject.transcodedSuffix]];
	else
		self.downloadFileNameQueue = [audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashQueue, queueSongObject.suffix]];
	
	// Check to see if the song is already cached
	if ([databaseControls.songCacheDb intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE md5 = ?", downloadFileNameHashQueue])
	{
		// Looks like the song is in the database, check if it's cached fully
		NSString *isDownloadFinished = [databaseControls.songCacheDb stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", downloadFileNameHashQueue];
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
				[databaseControls.songCacheDb executeUpdate:@"DELETE FROM cachedSongs WHERE md5 = downloadFileNameHashQueue"];
				
				// Remove and recreate the song file on disk
				[[NSFileManager defaultManager] removeItemAtPath:downloadFileNameQueue error:NULL];
				[[NSFileManager defaultManager] createFileAtPath:downloadFileNameQueue contents:[NSData data] attributes:nil];
				self.audioFileQueue = nil; self.audioFileQueue = [NSFileHandle fileHandleForWritingAtPath:downloadFileNameQueue];
				
				// Start the download
				NSURLConnectionDelegateQueue *connDelegateQueue = [[NSURLConnectionDelegateQueue alloc] init];
                NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(queueSongObject.songId) forKey:@"id"];
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
            NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(queueSongObject.songId) forKey:@"id"];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"stream" andParameters:parameters];
			self.downloadQueue = [NSURLConnection connectionWithRequest:request delegate:connDelegateQueue];
			[connDelegateQueue release];
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

#pragma mark Control Methods

- (void)startSongAtOffsetInSeconds:(NSUInteger)seconds
{
	// Destroy the streamer to start a new song
	[bassWrapper stop];
	
	Song *currentSong = [SUSCurrentPlaylistDAO dataModel].currentSong;
	Song *nextSong = [SUSCurrentPlaylistDAO dataModel].nextSong;
	
	if (!currentSong)
		return;
		
	// Check to see if the song is already cached
	if (currentSong.isFullyCached)
	{
		// The song is fully cached, start streaming from the local copy
		isTempDownload = NO;
				
		// Create the streamer
		/*streamer = [[AudioStreamer alloc] initWithFileURL:[NSURL fileURLWithPath:currentSong.localPath]];
		if (streamer)
		{
			streamer.fileDownloadCurrentSize = currentSong.localFileSize;
			streamer.fileDownloadComplete = YES;
			[streamer startWithOffsetInSecs:seconds];
		}*/
		// TODO: Rewrite this
		//[bassWrapper startSong:currentSong];
		
		[bassWrapper start];
		
		//[self addAutoNextNotification];
	}
	
	// The file doesn't exist or it's not fully cached, start downloading it from the middle
	if (!currentSong.fileExists || (!currentSong.isFullyCached && !viewObjects.isOfflineMode))
	{
		// Determine the byte offset
		float byteOffset;
		if (bitRate < 1000)
			byteOffset = ((float)bitRate * 128 * seconds);
		else
			byteOffset = (((float)bitRate / 1000) * 128 * seconds);
		
		// If we're starting from within the downloaded area, start playing immediately
		if ((int)byteOffset < currentSong.localFileSize)
		{
			// TODO: Rewrite this
			//[bassWrapper startSong:currentSong withOffsetInSeconds:seconds];
			
			[bassWrapper start];
		}
		
		// Start to download the rest of the song
		[[SUSStreamSingleton sharedInstance] queueStreamForSong:currentSong];
		
		//[self addAutoNextNotification];
	}
	
	// The file doesn't exist or it's not fully cached, start downloading it from the middle
	if (!nextSong.fileExists || (!nextSong.isFullyCached && !viewObjects.isOfflineMode))
	{
		// Start to download the rest of the song
		[[SUSStreamSingleton sharedInstance] queueStreamForSong:nextSong];
	}
	
	// The file is not fully cached and we're in offline mode, so complain
	if (!currentSong.isFullyCached && viewObjects.isOfflineMode)
	{
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"Unable to resume this song in offline mode as it isn't fully cached." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		alert.tag = 4;
		[alert show];
		[alert release];
	}
}

- (void)startSong
{
	[self startSongAtOffsetInSeconds:0];
}

- (void)playSongAtPosition:(NSInteger)position
{
	[[SUSStreamSingleton sharedInstance] removeAllStreams];
	
	[SUSCurrentPlaylistDAO dataModel].currentIndex = position;
	
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		[self jukeboxPlaySongAtPosition:position];
	}
	else
	{		
		[self startSong];
	}
	
	//[self addAutoNextNotification];
}

- (void)prevSong
{
	NSInteger currentIndex = [SUSCurrentPlaylistDAO dataModel].currentIndex;
	
	if (bassWrapper.progress > 10.0)
	{
		// Past 10 seconds in the song, so restart playback instead of changing songs
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
			[self jukeboxPlaySongAtPosition:currentIndex];
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
		NSInteger index = [SUSCurrentPlaylistDAO dataModel].currentIndex + 1;
		if (index <= ([databaseControls.currentPlaylistDb intForQuery:@"SELECT COUNT(*) FROM currentPlaylist"] - 1))
		{
			[SUSCurrentPlaylistDAO dataModel].currentIndex = index;
			
			[self startSong];
			
			//[self addAutoNextNotification];
		}
		else
		{
            [bassWrapper stop];
			
			[[SavedSettings sharedInstance] saveState];
		}
	}
}

- (void)nextSongAuto
{	
	// If it's in regular play mode, then go to the next track.
	if(repeatMode == 0)
	{
		[self nextSong];
	}
	// If it's in repeat-one mode then just restart the streamer
	else if(repeatMode == 1)
	{
		[self startSong];
	}
	// If it's in repeat-all mode then check if it's at the end of the playlist and start from the beginning, or just go to the next track.
	else if(repeatMode == 2)
	{
		SUSCurrentPlaylistDAO *dataModel = [SUSCurrentPlaylistDAO dataModel];
		
		NSInteger index = dataModel.currentIndex + 1;
		
		if (index <= ([databaseControls.currentPlaylistDb intForQuery:@"SELECT COUNT(*) FROM currentPlaylist"] - 1)) {
			[self nextSong];
		}
		else {
			[self playSongAtPosition:0];
		}
	}
}

- (void)resumeSong
{	
	SavedSettings *settings = [SavedSettings sharedInstance];
	Song *currentSong = [SUSCurrentPlaylistDAO dataModel].currentSong;
	DLog(@"currentSong: %@", currentSong);
		
	if (currentSong && settings.isRecover)
	{
		//self.songUrl = [NSURL URLWithString:[appDelegate getStreamURLStringForSongId:currentSongObject.songId]];
		
		// Check to see if the song is an m4a, if so don't resume and display message
		BOOL isM4A = NO;
		if (currentSong.transcodedSuffix)
		{
			if ([currentSong.transcodedSuffix isEqualToString:@"m4a"] || [currentSong.transcodedSuffix isEqualToString:@"aac"])
				isM4A = YES;
		}
		else
		{
			if ([currentSong.suffix isEqualToString:@"m4a"] || [currentSong.suffix isEqualToString:@"aac"])
				isM4A = YES;
		}
		
		if (isM4A)
		{
			[self startSong];
			
			CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Sorry" message:@"It's currently not possible to skip within m4a files, so the song is starting from the begining instead of resuming.\n\nYou can turn on m4a > mp3 transcoding in Subsonic to resume this song properly." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
			[alert show];
			[alert release];
		}
		else
		{
			[self startSongAtOffsetInSeconds:[SavedSettings sharedInstance].seekTime];
		}
	}
	else 
	{
		self.bitRate = 192;
	}
}

#pragma mark Helper Methods

- (NSInteger) maxBitrateSetting
{
	int bitrateSetting;
	if ([appDelegate.wifiReach currentReachabilityStatus] == ReachableViaWiFi)
		bitrateSetting = [SavedSettings sharedInstance].maxBitrateWifi;
	else
		bitrateSetting = [SavedSettings sharedInstance].maxBitrate3G;	
	
	NSInteger bitrate;
	switch (bitrateSetting)
	{
		case 0:
			bitrate = 64;
			break;
		case 1:
			bitrate = 96;
			break;
		case 2:
			bitrate = 128;
			break;
		case 3:
			bitrate = 160;
			break;
		case 4:
			bitrate = 192;
			break;
		case 5:
			bitrate = 224;
			break;
		case 6:
			bitrate = 256;
			break;
		default:
			bitrate = 0;
			break;
	}
		
	return bitrate;
}

- (void) removeOldestCachedSongs
{
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	SavedSettings *settings = [SavedSettings sharedInstance];
	
	unsigned long long int freeSpace = [[[[NSFileManager defaultManager] attributesOfFileSystemForPath:audioFolderPath error:NULL] objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
	unsigned long long minFreeSpace = settings.minFreeSpace;
	unsigned long long maxCacheSize = settings.maxCacheSize;
	NSString *songMD5;
	int songSize;
	
	if (settings.cachingType == 0)
	{
		// Remove the oldest songs based on either oldest played or oldest cached until free space is more than minFreeSpace
		while (freeSpace < minFreeSpace)
		{
			if (settings.autoDeleteCacheType == 0)
				songMD5 = [databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY playedDate ASC LIMIT 1"];
			else
				songMD5 = [databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY chachedDate ASC LIMIT 1"];
			[Song removeSongFromCacheDbByMD5:songMD5];
			
			freeSpace = [[[[NSFileManager defaultManager] attributesOfFileSystemForPath:audioFolderPath error:NULL] objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
		}
	}
	else if (settings.cachingType == 1)
	{
		// Remove the oldest songs based on either oldest played or oldest cached until cache size is less than maxCacheSize
		unsigned long long cacheSize = 0;
		for (NSString *path in [[NSFileManager defaultManager] subpathsAtPath:documentsPath]) 
		{
			cacheSize += [[[NSFileManager defaultManager] attributesOfItemAtPath:[documentsPath stringByAppendingPathComponent:path] error:NULL] fileSize];
		}
		
		while (cacheSize > maxCacheSize)
		{
			if (settings.autoDeleteCacheType == 0)
			{
				songMD5 = [databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY playedDate ASC LIMIT 1"];
			}
			else
			{
				songMD5 = [databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY chachedDate ASC LIMIT 1"];
			}
			songSize = [databaseControls.songCacheDb intForQuery:@"SELECT size FROM cachedSongs WHERE md5 = ?", songMD5];

			[Song removeSongFromCacheDbByMD5:songMD5];

			cacheSize = cacheSize - songSize;
			
			// Sleep the thread so the repeated cacheSize calls don't kill performance
			[NSThread sleepForTimeInterval:5];
		}
	}
	
	[autoreleasePool release];
}

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
		BassWrapperSingleton *wrapper = [BassWrapperSingleton sharedInstance];
		SUSCurrentPlaylistDAO *dataModel = [SUSCurrentPlaylistDAO dataModel];
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

// TODO: Reimplement these for libBASS
/*- (void)removeAutoNextNotification
{
	if (isAutoNextNotificationOn)
		[[NSNotificationCenter defaultCenter] removeObserver:self name:ASStatusChangedNotification object:nil];
	
	isAutoNextNotificationOn = NO;
}

- (void)addAutoNextNotification
{
	if (!isAutoNextNotificationOn)
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateChanged:) name:ASStatusChangedNotification object:nil];
	
	isAutoNextNotificationOn = YES;
}*/

- (void)scrobbleSong:(NSString*)songId isSubmission:(BOOL)isSubmission
{
    NSString *isSubmissionString = [NSString stringWithFormat:@"%i", isSubmission];
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:n2N(songId), @"id", n2N(isSubmissionString), @"submission", nil];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"scrobble" andParameters:parameters];
    
	[[NSURLConnection alloc] initWithRequest:request delegate:self];
}

#pragma mark -
#pragma mark Song Download Progress Methods

- (float)findProgressForSong:(Song *)aSong
{	
	if (aSong.isFullyCached)
		return 1.0;
	
	if (aSong.isPartiallyCached)
	{
		// The song is being downloaded right now so return the progress (note basswrapper bitrate is actually kilobitrate
		// Convert to actual bitrate, convert to bytes per second, multiply by number of seconds
		float totalSize = (([BassWrapperSingleton sharedInstance].bitRate * 1024.) / 8.) * [aSong.duration floatValue];
		DLog(@"is partially cached: bitRate: %i totalSize: %f", [BassWrapperSingleton sharedInstance].bitRate, totalSize);
		return ((float)aSong.localFileSize / totalSize);
	}
	
	// The song hasn't started downloading yet
	return 0.0;
}

- (float) findCurrentSongProgress
{
	SUSCurrentPlaylistDAO *dataModel = [SUSCurrentPlaylistDAO dataModel];
	return [self findProgressForSong:dataModel.currentSong];
}

- (float) findNextSongProgress
{
	SUSCurrentPlaylistDAO *dataModel = [SUSCurrentPlaylistDAO dataModel];
	return [self findProgressForSong:dataModel.nextSong];
}

#pragma mark -
#pragma mark Jukebox Control methods

- (void)jukeboxPlaySongAtPosition:(NSUInteger)position
{
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
	    
    NSString *positionString = [NSString stringWithFormat:@"%i", position];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"skip", @"action", n2N(positionString), @"index", nil];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" andParameters:parameters];
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
		SUSCurrentPlaylistDAO *dataModel = [SUSCurrentPlaylistDAO dataModel];
		
		dataModel.currentIndex = position;
		
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
	NSInteger index = [SUSCurrentPlaylistDAO dataModel].currentIndex - 1;
	if (index >= 0)
	{						
		[self jukeboxPlaySongAtPosition:index];
		
		jukeboxIsPlaying = YES;
	}
}

- (void)jukeboxNextSong
{
	NSInteger index = [SUSCurrentPlaylistDAO dataModel].currentIndex + 1;
	if (index <= ([databaseControls.currentPlaylistDb intForQuery:@"SELECT COUNT(*) FROM jukeboxCurrentPlaylist"] - 1))
	{		
		[self jukeboxPlaySongAtPosition:index];
		
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
        
        OrderedDictionary *parameters = [OrderedDictionary dictionaryWithObject:@"add" forKey:@"action"];
		for (NSString *songId in songIds)
		{
            [parameters setObject:n2N(songId) forKey:@"id"];
		}
		
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
	
	NSMutableArray *songIds = [[NSMutableArray alloc] init];
	
	FMResultSet *result;
	if (self.isShuffle)
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
	
	bassWrapper = [BassWrapperSingleton sharedInstance];
	
	//initialize here
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	databaseControls = [DatabaseSingleton sharedInstance];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	self.documentsPath = [paths objectAtIndex: 0];
	self.audioFolderPath = [documentsPath stringByAppendingPathComponent:@"songCache"];
	self.tempAudioFolderPath = [documentsPath stringByAppendingPathComponent:@"tempCache"];
	
	// Make sure songCache and tempCache directories exist, if not create them
	BOOL isDir = YES;
	if (![[NSFileManager defaultManager] fileExistsAtPath:audioFolderPath isDirectory:&isDir]) 
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:audioFolderPath withIntermediateDirectories:YES attributes:nil error:NULL];
	}
	[[NSFileManager defaultManager] removeItemAtPath:tempAudioFolderPath error:NULL];
	[[NSFileManager defaultManager] createDirectoryAtPath:tempAudioFolderPath withIntermediateDirectories:YES attributes:nil error:NULL];
	
	self.showNowPlayingIcon = NO;
	self.repeatMode = 0;
	self.isShuffle = NO;
	isAutoNextNotificationOn = NO;
	
	//[self addAutoNextNotification];
	
	connectionQueue = [[BBSimpleConnectionQueue alloc] init];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLockScreenInfo) name:ISMSNotification_SongPlaybackStarted object:nil];
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
