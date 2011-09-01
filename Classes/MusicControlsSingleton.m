//
//  MusicControlsSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "MusicControlsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "ViewObjectsSingleton.h"
#import "iSubAppDelegate.h"
#import "ASIHTTPRequest.h"
#import "Song.h"
#import "AudioStreamer.h"
#import "NSString-md5.h"
#import "CFNetworkRequests.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "LyricsXMLParser.h"
#import "Reachability.h"
#import "JukeboxXMLParser.h"
#import "NSURLConnectionDelegateQueue.h"
#import "JukeboxConnectionDelegate.h"
#import "BBSimpleConnectionQueue.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
 
static MusicControlsSingleton *sharedInstance = nil;

@implementation MusicControlsSingleton

// Audio streamer objects and variables
//
@synthesize streamer, streamerProgress, repeatMode, isShuffle, isPlaying, seekTime, buffersUsed;

// Music player objects
//
@synthesize currentSongObject, nextSongObject, queueSongObject, currentSongLyrics, currentPlaylistPosition, isNewSong, songUrl, nextSongUrl, queueSongUrl, coverArtUrl; 

// Song cache stuff
@synthesize documentsPath, audioFolderPath, tempAudioFolderPath, tempDownloadByteOffset;
@synthesize receivedDataA, downloadA, downloadFileNameA, downloadFileNameHashA, audioFileA, downloadedLengthA;
@synthesize receivedDataB, downloadB, downloadFileNameB, downloadFileNameHashB, audioFileB, downloadedLengthB, reportDownloadedLengthB;
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

#pragma mark Download Methods

// Start downloading the file specified in the text field.
- (void)startDownloadA 
{		
	SavedSettings *settings = [SavedSettings sharedInstance];
	
	isTempDownload = NO;
	
	// Are we already downloading?  If so, stop it.
	[self stopDownloadA];
	
	// Check to see if this song is currently being downloaded by the cache queue, if so cancel that download and delete it
	if (queueSongObject.path)
	{
		if ([currentSongObject.path isEqualToString:queueSongObject.path])
		{
			// Stop the download
			[self stopDownloadQueue];
			[databaseControls.songCacheDb executeUpdate:@"DELETE FROM cacheQueue WHERE md5 = ?", downloadFileNameHashQueue];
			[self downloadNextQueuedSong];
		}
	}
	
	// Grab the lyrics
	if (currentSongObject.artist && currentSongObject.title)
	{
		[self performSelectorInBackground:@selector(loadLyricsForArtistAndTitle:) withObject:[NSArray arrayWithObjects:currentSongObject.artist, currentSongObject.title, nil]];
	}
	
	// Reset the download counter
	downloadedLengthA = 0;
	
	// Determine the hashed filename
	self.downloadFileNameHashA = nil; downloadFileNameHashA = [[NSString md5:currentSongObject.path] retain];
	
	// Determine the name of the file we are downloading.
	//DLog(@"currentSongObject.path: %@", currentSongObject.path);
	self.downloadFileNameA = nil;
	if (currentSongObject.transcodedSuffix)
		self.downloadFileNameA = [audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashA, currentSongObject.transcodedSuffix]];
	else
		self.downloadFileNameA = [audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashA, currentSongObject.suffix]];
	//DLog(@"File name = %@", downloadFileNameA);
	
	// Check to see if the song is already cached
	if ([databaseControls.songCacheDb intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE md5 = ?", downloadFileNameHashA])
	{
		// Looks like the song is in the database, check if it's cached fully
		NSString *isDownloadFinished = [databaseControls.songCacheDb stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", downloadFileNameHashA];
		if ([isDownloadFinished isEqualToString:@"YES"])
		{
			// The song is fully cached, start streaming from the local copy
			//DLog(@"Playing from local copy");
			
			// Grab the first bytes of the song to trick Subsonic into seeing that it's being played
			NSURLRequest *request = [NSURLRequest requestWithURL:songUrl cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kLoadingTimeout];
			NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
			if (!connection)
			{
				DLog(@"Subsonic cached song play notification failed");
			}
			
			// Update the playtime to now
			[databaseControls.songCacheDb executeUpdate:[NSString stringWithFormat:@"UPDATE cachedSongs SET playedDate = %i WHERE md5 = '%@'", (NSUInteger)[[NSDate date] timeIntervalSince1970], downloadFileNameHashA]];
			
			// Check the file size
			NSNumber *fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:downloadFileNameA error:NULL] objectForKey:NSFileSize];
			downloadedLengthA = [fileSize intValue];
			
			seekTime = 0.0;
			streamerProgress = 0.0;
			
			streamer = [[AudioStreamer alloc] initWithFileURL:[NSURL fileURLWithPath:downloadFileNameA]];
			if (streamer)
			{
				streamer.fileDownloadCurrentSize = downloadedLengthA;
				streamer.fileDownloadComplete = YES;
			}			
			[streamer start];
			
			//if (nextSongObject.path != nil && [[appDelegate.settingsDictionary objectForKey:@"enableNextSongCacheSetting"] isEqualToString:@"YES"] && [[appDelegate.settingsDictionary objectForKey:@"enableSongCachingSetting"] isEqualToString:@"YES"])
			if (nextSongObject.path != nil && settings.isNextSongCacheEnabled && settings.isSongCachingEnabled)
				[self startDownloadB];
		}
		else
		{
			// Check to see if the song is being downloaded by startDownloadB
			if ([downloadFileNameHashA isEqualToString:downloadFileNameHashB])
			{
				// The song is already being downloaded so start playing the local copy
				//DLog(@"Playing from downloadB's file");
				
				// Update the playtime to now
				[databaseControls.songCacheDb executeUpdate:[NSString stringWithFormat:@"UPDATE cachedSongs SET playedDate = %i WHERE md5 = '%@'", (NSUInteger)[[NSDate date] timeIntervalSince1970], downloadFileNameHashA]];
				
				seekTime = 0.0;
				streamerProgress = 0.0;
				
				streamer = [[AudioStreamer alloc] initWithFileURL:[NSURL fileURLWithPath:downloadFileNameA]];
				if (streamer)
				{
					streamer.fileDownloadCurrentSize = downloadedLengthB;
					streamer.fileDownloadComplete = NO;
				}			
				[streamer start];
				
				// Tell the connectionDelegateB to start reporting the downloaded length
				reportDownloadedLengthB = YES;
			}
			else
			{
				// The song is not being downloaded and is not fully cached
				//if ([[appDelegate.settingsDictionary objectForKey:@"enableSongCachingSetting"] isEqualToString:@"YES"])
				if (settings.isSongCachingEnabled)
				{
					// Delete the download and start over
					DLog(@"Deleting the Download and starting over");
					
					// Update the cached and played dates to now
					[databaseControls.songCacheDb executeUpdate:[NSString stringWithFormat:@"UPDATE cachedSongs SET cachedDate = %i, playedDate = %i WHERE md5 = '%@'", (NSUInteger)[[NSDate date] timeIntervalSince1970], (NSUInteger)[[NSDate date] timeIntervalSince1970], downloadFileNameHashA]];
					
					// Remove and recreate the song file on disk
					[[NSFileManager defaultManager] removeItemAtPath:downloadFileNameA error:NULL];
					[[NSFileManager defaultManager] createFileAtPath:downloadFileNameA contents:[NSData data] attributes:nil];
					self.audioFileA = nil; self.audioFileA = [NSFileHandle fileHandleForWritingAtPath:downloadFileNameA];
					
					/*NSURLConnectionDelegateA *connDelegateA = [[NSURLConnectionDelegateA alloc] init];
					 NSURLRequest *downloadRequestA = [NSURLRequest requestWithURL:songUrl cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];	
					 self.downloadA = [[NSURLConnection alloc] initWithRequest:downloadRequestA delegate:connDelegateA];
					 [connDelegateA release];*/
					
					/*ASIHTTPRequestDelegateA *requestDelegateA = [[ASIHTTPRequestDelegateA alloc] init];
					 self.downloadA = [ASIHTTPRequest requestWithURL:songUrl];
					 [downloadA setDelegate:requestDelegateA];
					 [downloadA startAsynchronous];*/
					
					//DLog(@"--------- calling DownloadCFNetA");
					[CFNetworkRequests downloadCFNetA:songUrl];
				}
				else
				{
					// Song caching is off, so use the startTempDownload method
					DLog(@"Song caching is off, using startTempDownload");
					[self startTempDownloadA:0];
				}
			}
		}
	}
	else 
	{
		// The song has not been cached yet, start from scratch
		//if ([[appDelegate.settingsDictionary objectForKey:@"enableSongCachingSetting"] isEqualToString:@"YES"])
		if (settings.isSongCachingEnabled)
		{
			//DLog(@"starting a new download of %@", downloadFileNameHashA);
			
			// Add the row to the song cache database (looooooong query :P)
			[databaseControls.songCacheDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO cachedSongs (md5, finished, cachedDate, playedDate, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES ('%@', 'NO', %i, %i, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", downloadFileNameHashA, (NSUInteger)[[NSDate date] timeIntervalSince1970], (NSUInteger)[[NSDate date] timeIntervalSince1970]], currentSongObject.title, currentSongObject.songId, currentSongObject.artist, currentSongObject.album, currentSongObject.genre, currentSongObject.coverArtId, currentSongObject.path, currentSongObject.suffix, currentSongObject.transcodedSuffix, currentSongObject.duration, currentSongObject.bitRate, currentSongObject.track, currentSongObject.year, currentSongObject.size];
			
			// Create new file on disk
			[[NSFileManager defaultManager] createFileAtPath:downloadFileNameA contents:[NSData data] attributes:nil];
			self.audioFileA = [NSFileHandle fileHandleForWritingAtPath:downloadFileNameA];
			
			// Start the download
			/*ASIHTTPRequestDelegateA *requestDelegateA = [[ASIHTTPRequestDelegateA alloc] init];
			 self.downloadA = [ASIHTTPRequest requestWithURL:songUrl];
			 [downloadA setDelegate:requestDelegateA];
			 [downloadA startAsynchronous];*/
			
			//DLog(@"--------- calling DownloadCFNetA");
			[CFNetworkRequests downloadCFNetA:songUrl];
		}
		else
		{
			// Song caching is off, so use the startTempDownload method
			//DLog(@"Song caching is off, using startTempDownload");
			[self startTempDownloadA:0];
		}
	}
}

- (void)resumeDownloadA:(UInt32)byteOffset
{
	// Create the request and resume the download
	if (!viewObjects.isOfflineMode)
	{
		/*ASIHTTPRequestDelegateA *requestDelegateA = [[ASIHTTPRequestDelegateA alloc] init];
		 self.downloadA = [ASIHTTPRequest requestWithURL:songUrl];
		 NSString *range = [NSString stringWithFormat:@"bytes=%i-", byteOffset];
		 [downloadA setDelegate:requestDelegateA];
		 [downloadA addRequestHeader:@"Range" value:range];
		 [downloadA startAsynchronous];*/
		
		//DLog(@"--------- calling resumeCFNetA");
		[CFNetworkRequests resumeCFNetA:byteOffset];
	}
}

- (void)stopDownloadA 
{
	//if (downloadA)
	//DLog(@"---------------------------------------- downloadA %i", [CFNetworkRequests downloadA]);
	if ([CFNetworkRequests downloadA])
	{
		/*[downloadA cancel];
		 self.downloadA = nil;*/
		
		//DLog(@"calling cancelCFNetA");
		[CFNetworkRequests cancelCFNetA];
	}
	
	// Delete the unfinished download and remove it from the cache database
	NSString *isDownloadFinished = [databaseControls.songCacheDb stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", downloadFileNameHashA];
	if ([isDownloadFinished isEqualToString:@"NO"])
	{
		//DLog(@"Removing unfinished download");
		
		// Delete the song from disk
		[[NSFileManager defaultManager] removeItemAtPath:downloadFileNameA error:NULL];
		
		// Delete the song row from the cache database
		[databaseControls.songCacheDb executeUpdate:@"DELETE FROM cachedSongs WHERE md5 = ?", downloadFileNameHashA];
	}
}

// Start downloading the file specified in the text field.
- (void)startDownloadB
{		
	//DLog(@"nextSongObject: %@", nextSongObject.title);
	
	// Are we already downloading?  If so, stop it.
	[self stopDownloadB];
	
	// Check to see if this song is currently being downloaded by the cache queue, if so cancel that download and delete it
	if (queueSongObject.path)
	{
		if ([nextSongObject.path isEqualToString:queueSongObject.path])
		{
			// Stop the download
			[self stopDownloadQueue];
			[databaseControls.songCacheDb executeUpdate:@"DELETE FROM cacheQueue WHERE md5 = ?", downloadFileNameHashQueue];
			[self downloadNextQueuedSong];
		}
	}
	
	// Grab the lyrics
	if (nextSongObject.artist && nextSongObject.title)
	{
		[self performSelectorInBackground:@selector(loadLyricsForArtistAndTitle:) 
							   withObject:[NSArray arrayWithObjects:[NSString stringWithString:nextSongObject.artist], 
																	[NSString stringWithString:nextSongObject.title], nil]];
	}
	
	// Reset the download counter
	downloadedLengthB = 0;
	
	// Determine the hashed filename
	self.downloadFileNameHashB = nil; 
	self.downloadFileNameHashB = [nextSongObject.path md5];
	
	// Determine the name of the file we are downloading.
	//DLog(@"nextSongObject.path: %@", nextSongObject.path);
	self.downloadFileNameB = nil;
	if (nextSongObject.transcodedSuffix)
		self.downloadFileNameB = [audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashB, nextSongObject.transcodedSuffix]];
	else
		self.downloadFileNameB = [audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashB, nextSongObject.suffix]];
	//DLog(@"File name = %@", downloadFileNameB);
	
	// Check to see if the song is already cached
	if ([databaseControls.songCacheDb intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE md5 = ?", downloadFileNameHashB])
	{
		// Looks like the song is in the database, check if it's cached fully
		NSString *isDownloadFinished = [databaseControls.songCacheDb stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", downloadFileNameHashB];
		if ([isDownloadFinished isEqualToString:@"YES"])
		{
			// The song is fully cached, so do nothing
		}
		else
		{
			// The song is not fully cached, delete the download and start over
			//DLog(@"Deleting the Download and starting over");
			
			// Update the cached and played dates to now
			[databaseControls.songCacheDb executeUpdate:[NSString stringWithFormat:@"UPDATE cachedSongs SET cachedDate = %i, playedDate = 0 WHERE md5 = ?", (NSUInteger)[[NSDate date] timeIntervalSince1970]], downloadFileNameHashB];
			
			// Set the song url
			self.nextSongUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"stream.view"], nextSongObject.songId]];
			
			// Remove and recreate the song file on disk
			[[NSFileManager defaultManager] removeItemAtPath:downloadFileNameB error:NULL];
			[[NSFileManager defaultManager] createFileAtPath:downloadFileNameB contents:[NSData data] attributes:nil];
			self.audioFileB = nil; self.audioFileB = [NSFileHandle fileHandleForWritingAtPath:downloadFileNameB];
			
			// Start the download
			/*NSURLConnectionDelegateB *connDelegateB = [[NSURLConnectionDelegateB alloc] init];
			 connDelegateB.songB = [nextSongObject copy];
			 NSURLRequest *downloadRequestB = [NSURLRequest requestWithURL:nextSongUrl cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];	
			 self.downloadB = [[NSURLConnection alloc] initWithRequest:downloadRequestB delegate:connDelegateB];
			 [connDelegateB release];*/
			
			/*ASIHTTPRequestDelegateB *requestDelegateB = [[ASIHTTPRequestDelegateB alloc] init];
			 requestDelegateB.songB = [nextSongObject copy];
			 self.downloadB = [ASIHTTPRequest requestWithURL:nextSongUrl];
			 [downloadB setDelegate:requestDelegateB];
			 [downloadB startAsynchronous];*/
			
			//DLog(@"--------- calling DownloadCFNetB");
			self.songB = [[nextSongObject copy] autorelease];
			[CFNetworkRequests downloadCFNetB:nextSongUrl];
		}
	}
	else 
	{
		// The song has not been cached yet, start from scratch
		//DLog(@"starting a new download of %@", downloadFileNameHashB);
		
		// Add the row to the song cache database (looooooong query :P)
		[databaseControls.songCacheDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO cachedSongs (md5, finished, cachedDate, playedDate, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES ('%@', 'NO', %i, 0, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", downloadFileNameHashB, (NSUInteger)[[NSDate date] timeIntervalSince1970]], nextSongObject.title, nextSongObject.songId, nextSongObject.artist, nextSongObject.album, nextSongObject.genre, nextSongObject.coverArtId, nextSongObject.path, nextSongObject.suffix, nextSongObject.transcodedSuffix, nextSongObject.duration, nextSongObject.bitRate, nextSongObject.track, nextSongObject.year, nextSongObject.size];
		
		// Set the song url
		self.nextSongUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"stream.view"], nextSongObject.songId]];
		
		// Create new file on disk
		[[NSFileManager defaultManager] createFileAtPath:downloadFileNameB contents:[NSData data] attributes:nil];
		self.audioFileB = [NSFileHandle fileHandleForWritingAtPath:downloadFileNameB];
		
		// Start the download
		/*NSURLConnectionDelegateB *connDelegateB = [[NSURLConnectionDelegateB alloc] init];
		 connDelegateB.songB = [nextSongObject copy];
		 NSURLRequest *downloadRequestB = [NSURLRequest requestWithURL:nextSongUrl cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];	
		 downloadB = [[NSURLConnection alloc] initWithRequest:downloadRequestB delegate:connDelegateB];
		 [connDelegateB release];*/
		
		/*ASIHTTPRequestDelegateB *requestDelegateB = [[ASIHTTPRequestDelegateB alloc] init];
		 requestDelegateB.songB = [nextSongObject copy];
		 self.downloadB = [ASIHTTPRequest requestWithURL:nextSongUrl];
		 [downloadB setDelegate:requestDelegateB];
		 [downloadB startAsynchronous];*/
		
		//DLog(@"--------- calling DownloadCFNetB");
		self.songB = [[nextSongObject copy] autorelease];
		[CFNetworkRequests downloadCFNetB:nextSongUrl];
	}
}

- (void)resumeDownloadB:(UInt32)byteOffset
{
	// Create the request and resume the download
	if (!viewObjects.isOfflineMode)
	{
		/*ASIHTTPRequestDelegateB *requestDelegateB = [[ASIHTTPRequestDelegateB alloc] init];
		 requestDelegateB.songB = [songB copy];
		 self.downloadB = [ASIHTTPRequest requestWithURL:nextSongUrl];
		 [downloadB setDelegate:requestDelegateB];
		 NSString *range = [NSString stringWithFormat:@"bytes=%i-", byteOffset];
		 [downloadB addRequestHeader:@"Range" value:range];
		 [downloadB startAsynchronous];*/
		
		//DLog(@"--------- calling resumeCFNetB");
		[CFNetworkRequests resumeCFNetB:byteOffset];
	}
}

- (void)resumeDownloadB:(UInt32)byteOffset withSong:(Song *)song
{
	DLog(@"----------------------------- (void)resumeDownloadB:(UInt32)byteOffset withSong:(Song *)song");
	DLog(@"----------------------------- I SHOULDN'T HAVE BEEN CALLED!!! -------------------------------");
	/*// Create the request and resume the download
	if (!viewObjects.isOfflineMode)
	{
		ASIHTTPRequestDelegateB *requestDelegateB = [[ASIHTTPRequestDelegateB alloc] init];
		requestDelegateB.songB = [song copy];
		self.downloadB = [ASIHTTPRequest requestWithURL:nextSongUrl];
		[downloadB setDelegate:requestDelegateB];
		NSString *range = [NSString stringWithFormat:@"bytes=%i-", byteOffset];
		[downloadB addRequestHeader:@"Range" value:range];
		[downloadB startAsynchronous];
	}*/
}

- (void)stopDownloadB
{
	reportDownloadedLengthB = NO;
	
	//if (downloadB) 
	//DLog(@"---------------------------------------- downloadA %i", [CFNetworkRequests downloadB]);
	if ([CFNetworkRequests downloadB])
	{
		/*[downloadB cancel];
		 self.downloadB = nil;*/
		
		[CFNetworkRequests cancelCFNetB];
		self.songB = nil;
	}		
	
	// Delete the unfinished download and remove it from the cache database
	NSString *isDownloadFinished = [databaseControls.songCacheDb stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", downloadFileNameHashB];
	if ([isDownloadFinished isEqualToString:@"NO"])
	{
		//DLog(@"Removing unfinished download");
		
		// Delete the song from disk
		[[NSFileManager defaultManager] removeItemAtPath:downloadFileNameB error:NULL];
		
		// Delete the song row from the cache database
		[databaseControls.songCacheDb executeUpdate:@"DELETE FROM cachedSongs WHERE md5 = ?", downloadFileNameHashB];
	}
}

- (void)startTempDownloadA:(UInt32)byteOffset
{
	tempDownloadByteOffset = byteOffset;
	
	isTempDownload = YES;
	
	// Are we already downloading?  If so, stop it.
	[self stopDownloadA];
	
	// Remove and recreate the tempCache directory
	[[NSFileManager defaultManager] removeItemAtPath:tempAudioFolderPath error:NULL];
	[[NSFileManager defaultManager] createDirectoryAtPath:tempAudioFolderPath withIntermediateDirectories:YES attributes:nil error:NULL];
	
	// Reset the download counter
	downloadedLengthA = 0;
	
	// Determine the hashed filename
	self.downloadFileNameHashA = nil; self.downloadFileNameHashA = [NSString md5:currentSongObject.path];
	
	// Determine the name of the file we are downloading.
	self.downloadFileNameA = nil;
	if (currentSongObject.transcodedSuffix)
		self.downloadFileNameA = [tempAudioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashA, currentSongObject.transcodedSuffix]];
	else
		self.downloadFileNameA = [tempAudioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashA, currentSongObject.suffix]];	
	//DLog(@"File name = %@", downloadFileNameA);
	
	// Create the new temp file
	[[NSFileManager defaultManager] createFileAtPath:downloadFileNameA contents:[NSData data] attributes:nil];
	self.audioFileA = nil; self.audioFileA = [NSFileHandle fileHandleForWritingAtPath:downloadFileNameA];
	
	// Create the request and start the download
	/*NSURLConnectionDelegateTempA *connDelegateA = [[NSURLConnectionDelegateTempA alloc] init];
	 NSMutableURLRequest *downloadRequestA = [NSMutableURLRequest requestWithURL:songUrl cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];	
	 NSString *range = [NSString stringWithFormat:@"bytes=%i-", byteOffset];
	 [downloadRequestA setValue:range forHTTPHeaderField:@"Range"];		
	 self.downloadA = [[NSURLConnection alloc] initWithRequest:downloadRequestA delegate:connDelegateA];
	 [connDelegateA release];*/
	
	/*ASIHTTPRequestDelegateTemp *requestDelegateA = [[ASIHTTPRequestDelegateTemp alloc] init];
	 self.downloadA = [ASIHTTPRequest requestWithURL:songUrl];
	 NSString *range = [NSString stringWithFormat:@"bytes=%i-", byteOffset];
	 [downloadA setDelegate:requestDelegateA];
	 [downloadA addRequestHeader:@"Range" value:range];
	 [downloadA startAsynchronous];*/
	
	//DLog(@"--------- calling DownloadCFNetTempA");
	[CFNetworkRequests downloadCFNetTemp:songUrl];
}

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
	
	/*aSong.title = [result stringForColumnIndex:4];
	aSong.songId = [result stringForColumnIndex:5];
	aSong.artist = [result stringForColumnIndex:6];
	aSong.album = [result stringForColumnIndex:7];
	aSong.genre = [result stringForColumnIndex:8];
	aSong.coverArtId = [result stringForColumnIndex:9];
	aSong.path = [result stringForColumnIndex:10];
	aSong.suffix = [result stringForColumnIndex:11];
	aSong.transcodedSuffix = [result stringForColumnIndex:12];
	aSong.duration = [NSNumber numberWithInt:[result intForColumnIndex:13]];
	aSong.bitRate = [NSNumber numberWithInt:[result intForColumnIndex:14]];
	aSong.track = [NSNumber numberWithInt:[result intForColumnIndex:15]];
	aSong.year = [NSNumber numberWithInt:[result intForColumnIndex:16]];
	aSong.size = [NSNumber numberWithInt:[result intForColumnIndex:17]];*/
	
	[result close];
	return [aSong autorelease];
}

// Start downloading the file specified in the text field.
- (void)startDownloadQueue
{		
	DLog(@"startDownloadQueue called");
	//DLog(@"queueSongObject: %@", queueSongObject.title);
	
	// Are we already downloading?  If so, stop it.
	[self stopDownloadQueue];
	
	// Grab the lyrics
	if (queueSongObject.artist && queueSongObject.title)
	{
		[self performSelectorInBackground:@selector(loadLyricsForArtistAndTitle:) withObject:[NSArray arrayWithObjects:queueSongObject.artist, queueSongObject.title, nil]];
	}
	
	isQueueListDownloading = YES;
	
	// Reset the download counter
	downloadedLengthQueue = 0;
	
	// Determine the hashed filename
	self.downloadFileNameHashQueue = nil; self.downloadFileNameHashQueue = [NSString md5:queueSongObject.path];
	
	// Determine the name of the file we are downloading.
	//DLog(@"queueSongObject.path: %@", queueSongObject.path);
	self.downloadFileNameQueue = nil;
	if (queueSongObject.transcodedSuffix)
		self.downloadFileNameQueue = [audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashQueue, queueSongObject.transcodedSuffix]];
	else
		self.downloadFileNameQueue = [audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashQueue, queueSongObject.suffix]];
	//DLog(@"File name = %@", downloadFileNameQueue);
	
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
			//DLog(@"Deleting the Download and starting over");
			
			BOOL doDownload = YES;
			if (currentSongObject.path)
			{
				if ([currentSongObject.path isEqualToString:queueSongObject.path])
				{
					// This is the current song so don't download
					doDownload = NO;
				}
			}
			if (nextSongObject.path)
			{
				if ([nextSongObject.path isEqualToString:queueSongObject.path])
				{
					// This is the next song so don't download
					doDownload = NO;
				}
			}
			
			if (doDownload)
			{
				// Delete the row from cachedSongs
				[databaseControls.songCacheDb executeUpdate:@"DELETE FROM cachedSongs WHERE md5 = downloadFileNameHashQueue"];
				
				// Set the song url
				self.queueSongUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"stream.view"], queueSongObject.songId]];
				
				// Remove and recreate the song file on disk
				[[NSFileManager defaultManager] removeItemAtPath:downloadFileNameQueue error:NULL];
				[[NSFileManager defaultManager] createFileAtPath:downloadFileNameQueue contents:[NSData data] attributes:nil];
				self.audioFileQueue = nil; self.audioFileQueue = [NSFileHandle fileHandleForWritingAtPath:downloadFileNameQueue];
				
				// Start the download
				NSURLConnectionDelegateQueue *connDelegateQueue = [[NSURLConnectionDelegateQueue alloc] init];
				NSURLRequest *downloadRequestQueue = [NSURLRequest requestWithURL:queueSongUrl cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:kLoadingTimeout];	
				self.downloadQueue = [NSURLConnection connectionWithRequest:downloadRequestQueue delegate:connDelegateQueue];
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
		if (currentSongObject.path)
		{
			if ([currentSongObject.path isEqualToString:queueSongObject.path])
			{
				// This is the current song so don't download
				doDownload = NO;
			}
		}
		if (nextSongObject.path)
		{
			if ([nextSongObject.path isEqualToString:queueSongObject.path])
			{
				// This is the next song so don't download
				doDownload = NO;
			}
		}
		
		if (doDownload)
		{
			// The song has not been cached yet, start from scratch
			//DLog(@"starting a new download of %@", downloadFileNameHashQueue);
			
			// Set the song url
			self.queueSongUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"stream.view"], queueSongObject.songId]];
			
			// Create new file on disk
			[[NSFileManager defaultManager] createFileAtPath:downloadFileNameQueue contents:[NSData data] attributes:nil];
			self.audioFileQueue = [NSFileHandle fileHandleForWritingAtPath:downloadFileNameQueue];
			
			// Start the download
			NSURLConnectionDelegateQueue *connDelegateQueue = [[NSURLConnectionDelegateQueue alloc] init];
			NSURLRequest *downloadRequestQueue = [NSURLRequest requestWithURL:queueSongUrl cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:kLoadingTimeout];	
			self.downloadQueue = [NSURLConnection connectionWithRequest:downloadRequestQueue delegate:connDelegateQueue];
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
		NSMutableURLRequest *downloadRequestQueue = [NSMutableURLRequest requestWithURL:queueSongUrl cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:kLoadingTimeout];	
		NSString *range = [NSString stringWithFormat:@"bytes=%i-", byteOffset];
		[downloadRequestQueue setValue:range forHTTPHeaderField:@"Range"];
		self.downloadQueue = [NSURLConnection connectionWithRequest:downloadRequestQueue delegate:connDelegateQueue];
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
		//DLog(@"Removing unfinished download");
		
		// Delete the song from disk
		[[NSFileManager defaultManager] removeItemAtPath:downloadFileNameQueue error:NULL];
		
		// Delete the song row from the cache database
		//[songCacheDb executeUpdate:@"DELETE FROM cacheQueue WHERE md5 = ?", downloadFileNameHashQueue];
	}
}

- (void)downloadNextQueuedSong
{
	//if (appDelegate.reachabilityStatus == 2 || IS_3G_UNRESTRICTED)
	//if ([appDelegate.wifiReach currentReachabilityStatus] == ReachableViaWiFi || IS_3G_UNRESTRICTED)
	if (appDelegate.isWifi)
	{
		//DLog(@"reachabilityStatus is 2 so this is on Wifi");
		if ([databaseControls.cacheQueueDb intForQuery:@"SELECT COUNT(*) FROM cacheQueue"] > 0)
		{
			//DLog(@"cacheQueue has more than 0 rows, so starting the download queue");
			//DLog(@"downloadNextQueuedSong: inside select count if");
			isQueueListDownloading = YES;
			self.queueSongObject = nil; self.queueSongObject = [self nextQueuedSong];
			[self startDownloadQueue];
		}
		else
		{
			DLog(@"There are no more songs to cache, setting isQueueListDownloading = NO");
			isQueueListDownloading = NO;
		}
	}
	else
	{
		DLog(@"Wifi not reachable and 3G is restricted, setting isQueueListDownloading = NO");
		isQueueListDownloading = NO;
	}
}

#pragma mark Control Methods

- (void)createStreamer
{
	//DLog(@"createStreamer method called");
	streamerProgress = 0.0;
	seekTime = 0.0;
	
	streamer = [[AudioStreamer alloc] initWithFileURL:[NSURL fileURLWithPath:downloadFileNameA]];
	[self addAutoNextNotification];
	//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateChanged:) name:ASStatusChangedNotification object:nil];		
	[streamer start];	
	//DLog(@"streamer: %@", streamer);
}

- (void)createStreamerWithOffset
{
	streamerProgress = 0.0;
	
	streamer = [[AudioStreamer alloc] initWithFileURL:[NSURL fileURLWithPath:downloadFileNameA]];
	[self addAutoNextNotification];
	//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateChanged:) name:ASStatusChangedNotification object:nil];		
	[streamer start];	
}

- (void)destroyStreamer
{
	self.isPlaying = NO;
	
	if (streamer)
	{
		//DLog(@"there is a streamer, destroying....");
		[self removeAutoNextNotification];
		//[[NSNotificationCenter defaultCenter] removeObserver:self name:ASStatusChangedNotification object:nil];
		
		[streamer stop];
		[streamer release];
		streamer = nil;
	}
}

- (void)playPauseSong
{
	
	if ([streamer isPaused])
	{
		isPlaying = YES;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"setPauseButtonImage" object:nil];
		[streamer start];
	}
	else if ([streamer isPlaying])
	{
		isPlaying = NO;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"setPlayButtonImage" object:nil];
		[streamer pause];
	}
	else 
	{
		// If the player is playing from downloadB and it's still downloading, stop it.
		if (reportDownloadedLengthB)
			[self stopDownloadB];
		
		isPlaying = YES;
		//seekTime = 0.0;
		
		if (seekTime > 0.0)
		{
			// TODO: test this
			[SavedSettings sharedInstance].isRecover = YES;
			[self resumeSong];
		}
		else
		{
			[self startDownloadA];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"setPauseButtonImage" object:nil];
		}
		
		[self addAutoNextNotification];
	}
}

- (void)playSongAtPosition:(NSInteger)position
{
	currentPlaylistPosition = position;
	
	if (isShuffle) {
		self.currentSongObject = [databaseControls songFromDbRow:position inTable:@"shufflePlaylist" inDatabase:databaseControls.currentPlaylistDb];
		self.nextSongObject = [databaseControls songFromDbRow:(position + 1) inTable:@"shufflePlaylist" inDatabase:databaseControls.currentPlaylistDb];
	}
	else {
		self.currentSongObject = [databaseControls songFromDbRow:position inTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
		self.nextSongObject = [databaseControls songFromDbRow:(position + 1) inTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
	}
	
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		[self jukeboxPlaySongAtPosition:position];
	}
	else
	{
		self.songUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"stream.view"], currentSongObject.songId]];
		
		[self destroyStreamer];
		seekTime = 0.0;
		[self playPauseSong];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"setSongTitle" object:nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"initSongInfo" object:nil];
	}
	
	[self addAutoNextNotification];
}

- (void)prevSong
{
	self.streamerProgress = [streamer progress];
	DLog(@"track position: %f", (streamerProgress + seekTime));
	if ((streamerProgress + seekTime) > 10.0)
	{
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
			[self jukeboxPlaySongAtPosition:currentPlaylistPosition];
		else
			[self playSongAtPosition:currentPlaylistPosition];
	}
	else
	{
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
		{
			[self jukeboxPrevSong];
		}
		else
		{
			NSInteger index = currentPlaylistPosition - 1;
			if (index >= 0)
			{
				currentPlaylistPosition = index;
				
				if (isShuffle) {
					self.currentSongObject = [databaseControls songFromDbRow:index inTable:@"shufflePlaylist" inDatabase:databaseControls.currentPlaylistDb];
					self.nextSongObject = [databaseControls songFromDbRow:(index + 1) inTable:@"shufflePlaylist" inDatabase:databaseControls.currentPlaylistDb];
				}
				else {
					self.currentSongObject = [databaseControls songFromDbRow:index inTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
					self.nextSongObject = [databaseControls songFromDbRow:(index + 1) inTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
				}
				
				self.songUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"stream.view"], currentSongObject.songId]];
				
				[self destroyStreamer];
				seekTime = 0.0;
				[self playPauseSong];
				[[NSNotificationCenter defaultCenter] postNotificationName:@"setSongTitle" object:nil];
				[[NSNotificationCenter defaultCenter] postNotificationName:@"initSongInfo" object:nil];
				
				[self addAutoNextNotification];
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
		NSInteger index = currentPlaylistPosition + 1;
		if (index <= ([databaseControls.currentPlaylistDb intForQuery:@"SELECT COUNT(*) FROM currentPlaylist"] - 1))
		{
			currentPlaylistPosition = index;
			
			if (isShuffle) {
				self.currentSongObject = [databaseControls songFromDbRow:index inTable:@"shufflePlaylist" inDatabase:databaseControls.currentPlaylistDb];
				self.nextSongObject = [databaseControls songFromDbRow:(index + 1) inTable:@"shufflePlaylist" inDatabase:databaseControls.currentPlaylistDb];
			}
			else {
				self.currentSongObject = [databaseControls songFromDbRow:index inTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
				self.nextSongObject = [databaseControls songFromDbRow:(index + 1) inTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
			}
			
			self.songUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"stream.view"], currentSongObject.songId]];
			
			[self destroyStreamer];
			seekTime = 0.0;
			[self playPauseSong];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"setSongTitle" object:nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"initSongInfo" object:nil];
			
			[self addAutoNextNotification];
		}
		else
		{
			[[NSNotificationCenter defaultCenter] postNotificationName:@"setPlayButtonImage" object:nil];
			[self destroyStreamer];
			seekTime = 0.0;
			
			[[SavedSettings sharedInstance] saveState];
		}
	}
}

- (void)nextSongAuto
{
	//DLog(@"nextSongAuto called");
	
	// If it's in regular play mode, then go to the next track.
	if(repeatMode == 0)
	{
		[self nextSong];
	}
	// If it's in repeat-one mode then just restart the streamer
	else if(repeatMode == 1)
	{
		[self destroyStreamer];
		seekTime = 0.0;
		[self playPauseSong];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"setSongTitle" object:nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"initSongInfo" object:nil];
	}
	// If it's in repeat-all mode then check if it's at the end of the playlist and start from the beginning, or just go to the next track.
	else if(repeatMode == 2)
	{
		NSInteger index = currentPlaylistPosition + 1;
		
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
	
	[settings loadState];
	
	if (settings.isRecover)
	{
		BOOL resume = NO;
		if (self.isPlaying)
		{
			if (settings.recoverSetting == 0 || settings.recoverSetting == 1)
				resume = YES;
			
			if (settings.recoverSetting == 1)
				self.isPlaying = NO;
		}
		else
		{
			// Always resume when isPlaying == NO just to resume the song state, song doesn't play
			resume = YES;
		}
		
		if (resume)
		{
			self.songUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"stream.view"], [currentSongObject songId]]];
			//DLog(@"resumeSong2 songUrl: %@", [self.songUrl absoluteString]);
			
			// Determine the hashed filename
			self.downloadFileNameHashA = nil; self.downloadFileNameHashA = [NSString md5:currentSongObject.path];
			
			//self.isPlaying = YES;
			
			// Check to see if the song is an m4a, if so don't resume and display message
			BOOL isM4A = NO;
			if (currentSongObject.transcodedSuffix)
			{
				if ([currentSongObject.transcodedSuffix isEqualToString:@"m4a"] || [currentSongObject.transcodedSuffix isEqualToString:@"aac"])
					isM4A = YES;
			}
			else
			{
				if ([currentSongObject.suffix isEqualToString:@"m4a"] || [currentSongObject.suffix isEqualToString:@"aac"])
					isM4A = YES;
			}
			
			if (isM4A)
			{
				[self startDownloadA];
				
				CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Sorry" message:@"It's currently not possible to skip within m4a files, so the song is starting from the begining instead of resuming.\n\nYou can turn on m4a > mp3 transcoding in Subsonic to resume this song properly." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
				[alert show];
				[alert release];
			}
			else
			{
				// Check to see if the song is already cached
				if ([databaseControls.songCacheDb intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE md5 = ?", downloadFileNameHashA])
				{
					// Looks like the song is in the database, check if it's cached fully
					NSString *isDownloadFinished = [databaseControls.songCacheDb stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", downloadFileNameHashA];
					if ([isDownloadFinished isEqualToString:@"YES"])
					{
						// The song is fully cached, start streaming from the local copy
						//DLog(@"Resuming from local copy");
						
						isTempDownload = NO;
						
						// Determine the file hash
						self.downloadFileNameHashA = [NSString md5:currentSongObject.path];
						
						// Determine the name and path of the file.
						if (currentSongObject.transcodedSuffix)
							self.downloadFileNameA = [audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashA, currentSongObject.transcodedSuffix]];
						else
							self.downloadFileNameA = [audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashA, currentSongObject.suffix]];
						//DLog(@"File name = %@", downloadFileNameA);		
						
						// Start streaming from the local copy
						//DLog(@"Playing from local copy");
						
						// Check the file size
						NSNumber *fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:downloadFileNameA error:NULL] objectForKey:NSFileSize];
						downloadedLengthA = [fileSize intValue];
						//DLog(@"downloadedLengthA: %i", downloadedLengthA);
						
						streamerProgress = 0.0;
						
						streamer = [[AudioStreamer alloc] initWithFileURL:[NSURL fileURLWithPath:downloadFileNameA]];
						if (streamer)
						{
							streamer.fileDownloadCurrentSize = downloadedLengthA;
							//DLog(@"fileDownloadCurrentSize: %i", streamer.fileDownloadCurrentSize);
							streamer.fileDownloadComplete = YES;
							[streamer startWithOffsetInSecs:(UInt32) seekTime];
							
							//DLog(@"started with offset in secs");
						}
					}
					else
					{
						if (viewObjects.isOfflineMode)
						{
							CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"Unable to resume this song in offline mode as it isn't fully cached." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
							[alert show];
							[alert release];
						}
						else 
						{
							// The song is not fully cached, call startTempDownloadA to start a temp cache stream
							//DLog(@"Resuming with a temp download");
							
							// Determine the name and path of the file.
							if (currentSongObject.transcodedSuffix)
								self.downloadFileNameA = [audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashA, currentSongObject.transcodedSuffix]];
							else
								self.downloadFileNameA = [audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashA, currentSongObject.suffix]];
							//DLog(@"File name = %@", downloadFileNameA);		
							
							// Determine the byte offset
							float byteOffset;
							if (bitRate < 1000)
								byteOffset = ((float)bitRate * 128 * seekTime);
							else
								byteOffset = (((float)bitRate / 1000) * 128 * seekTime);
							
							
							// Start the download
							[self startTempDownloadA:byteOffset];
						}
					}
				}
				else
				{
					if (!viewObjects.isOfflineMode)
					{
						// Somehow we're resuming a song that doesn't exist in the cache at all (should never happen). So call startDownloadA to start a fresh download.
						DLog(@"Somehow the song we're trying to resume doesn't exist. Starting a fresh download");
						
						[self startDownloadA];
					}
				}
			}
		}
	}
	else 
	{
		self.bitRate = 192;
	}
}

#pragma mark Helper Methods

- (void)playbackStateChanged:(NSNotification *)aNotification
{
	if ([streamer isWaiting])
	{
	}
	else if ([streamer isPlaying])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"setPauseButtonImage" object:nil];
	}
	else if ([streamer isIdle])
	{	
		[self nextSongAuto];
	}
}


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
	
	//DLog(@"maxBitrateSetting: %i", bitrate);
	
	return bitrate;
}

- (void)incrementProgress
{
	streamerProgress = streamerProgress + 1.0;
}


- (void)createProgressTimer
{
	progressTimer = nil;
	progressTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(incrementProgress) userInfo:nil repeats:YES];
}

- (void) loadLyricsForArtistAndTitle:(NSArray *)artistAndTitle
{
	//DLog(@"artistAndTitle: %@", artistAndTitle);
	// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	NSString *artist = [artistAndTitle objectAtIndex:0];
	NSString *title = [artistAndTitle objectAtIndex:1];
	
	NSString *lyrics = [databaseControls.lyricsDb stringForQuery:@"SELECT lyrics FROM lyrics WHERE artist = ? AND title = ?", artist, title];
	if (lyrics)
	{
		//DLog(@"-------------- lyrics found for %@ - %@, loading from DB -----------", artist, title);
		if ([artist isEqualToString:currentSongObject.artist] && [title isEqualToString:currentSongObject.title])
		{
			self.currentSongLyrics = lyrics;
			[[NSNotificationCenter defaultCenter] postNotificationName:@"lyricsDoneLoading" object:nil];
		}
	}
	else
	{
		//DLog(@"-------------- lyrics not found for %@ - %@, loading lyrics from server -------------", artist, title);
		ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:[appDelegate getBaseUrl:@"getLyrics.view"]]];
		[request startSynchronous];
		if ([request error])
		{
			if ([artist isEqualToString:currentSongObject.artist] && [title isEqualToString:currentSongObject.title])
			{
				self.currentSongLyrics = [NSString stringWithFormat:@"\n\nHTTP Connection Error Code: %i\n\nError Message: %@", [[request error] code], [ASIHTTPRequest errorCodeToEnglish:[[request error] code]]];
				[[NSNotificationCenter defaultCenter] postNotificationName:@"lyricsDoneLoading" object:nil];
			}
		}
		else
		{
			NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:[request responseData]];
			LyricsXMLParser *parser = [(LyricsXMLParser *)[LyricsXMLParser alloc] initXMLParser];
			parser.artist = artist;
			parser.title = title;
			[xmlParser setDelegate:parser];
			[xmlParser parse];
			
			[xmlParser release];
			[parser release];
		}
	}
	
	[autoreleasePool release];
}

- (void) removeOldestCachedSongs
{
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	SavedSettings *settings = [SavedSettings sharedInstance];
	
	unsigned long long int freeSpace = [[[[NSFileManager defaultManager] attributesOfFileSystemForPath:audioFolderPath error:NULL] objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
	//unsigned long long int minFreeSpace = [[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] unsignedLongLongValue];
	unsigned long long minFreeSpace = settings.minFreeSpace;
	//unsigned long long int maxCacheSize = [[appDelegate.settingsDictionary objectForKey:@"maxCacheSize"] unsignedLongLongValue];
	unsigned long long maxCacheSize = settings.maxCacheSize;
	NSString *songMD5;
	int songSize;
	
	//if ([[appDelegate.settingsDictionary objectForKey:@"cachingTypeSetting"] intValue] == 0)
	if (settings.cachingType == 0)
	{
		// Remove the oldest songs based on either oldest played or oldest cached until free space is more than minFreeSpace
		while (freeSpace < minFreeSpace)
		{
			//if ([[appDelegate.settingsDictionary objectForKey:@"autoDeleteCacheTypeSetting"] intValue] == 0)
			if (settings.autoDeleteCacheType == 0)
				songMD5 = [databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY playedDate ASC LIMIT 1"];
			else
				songMD5 = [databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY chachedDate ASC LIMIT 1"];
			//DLog(@"removing %@", songMD5);
			[databaseControls removeSongFromCacheDb:songMD5];
			
			freeSpace = [[[[NSFileManager defaultManager] attributesOfFileSystemForPath:audioFolderPath error:NULL] objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
		}
	}
	//else if ([[appDelegate.settingsDictionary objectForKey:@"cachingTypeSetting"] intValue] == 1)
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
			//if ([[appDelegate.settingsDictionary objectForKey:@"autoDeleteCacheTypeSetting"] intValue] == 0)
			if (settings.autoDeleteCacheType == 0)
			{
				songMD5 = [databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY playedDate ASC LIMIT 1"];
			}
			else
			{
				songMD5 = [databaseControls.songCacheDb stringForQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'YES' ORDER BY chachedDate ASC LIMIT 1"];
			}
			songSize = [databaseControls.songCacheDb intForQuery:@"SELECT size FROM cachedSongs WHERE md5 = ?", songMD5];
			DLog(@"removing %@", songMD5);
			[databaseControls removeSongFromCacheDb:songMD5];

			DLog(@"cacheSize: %i", cacheSize);
			cacheSize = cacheSize - songSize;
			DLog(@"new cacheSize: %i", cacheSize);
			DLog(@"maxCacheSize: %i", maxCacheSize);
			
			// Sleep the thread so the repeated cacheSize calls don't kill performance
			[NSThread sleepForTimeInterval:5];
		}
	}
	
	[autoreleasePool release];
}

- (void) checkCache
{
	SavedSettings *settings = [SavedSettings sharedInstance];
	
	unsigned long long cacheSize = 0;
	for (NSString *path in [[NSFileManager defaultManager] subpathsAtPath:documentsPath]) 
	{
		cacheSize += [[[NSFileManager defaultManager] attributesOfItemAtPath:[documentsPath stringByAppendingPathComponent:path] error:NULL] fileSize];
	}
	unsigned long long int freeSpace = [[[[NSFileManager defaultManager] attributesOfFileSystemForPath:audioFolderPath error:NULL] objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
	//unsigned long long int minFreeSpace = [[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] unsignedLongLongValue];
	unsigned long long minFreeSpace = settings.minFreeSpace;
	//unsigned long long int maxCacheSize = [[appDelegate.settingsDictionary objectForKey:@"maxCacheSize"] unsignedLongLongValue];
	unsigned long long maxCacheSize = settings.maxCacheSize;
	NSLog(@"checkCache:  cacheSize = %llu  freeSpace = %llu  minFreeSpace = %llu  maxCacheSize = %llu", cacheSize, freeSpace, minFreeSpace, maxCacheSize);
	//DLog(@"cacheSize: %qu", cacheSize);
	//DLog(@"freeSpace: %qu", freeSpace);
	//DLog(@"minFreeSpace: %qu", minFreeSpace);
	//DLog(@"maxCacheSize: %qu", maxCacheSize);
	
	//if ([[appDelegate.settingsDictionary objectForKey:@"cachingTypeSetting"] intValue] == 0 &&
	//	[[appDelegate.settingsDictionary objectForKey:@"enableSongCachingSetting"] isEqualToString:@"YES"])
	if (settings.cachingType == 0 && settings.isSongCachingEnabled)
	{
		NSLog(@"checkCache:  entered the if");
		// User has chosen to limit cache by minimum free space
		
		// Check to see if the free space left is lower than the setting
		if (freeSpace < minFreeSpace)
		{
			NSLog(@"checkCache:  entered the if if");
			// Check to see if the cache size + free space is still less than minFreeSpace
			if (cacheSize + freeSpace < minFreeSpace)
			{
				NSLog(@"checkCache:  entered the if if if");
				// Looks like even removing all of the cache will not be enough so turn off caching
				//[appDelegate.settingsDictionary setObject:@"NO" forKey:@"enableSongCachingSetting"];
				settings.isSongCachingEnabled = NO;
				
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"IMPORTANT" message:@"Free space is running low, but even deleting the entire cache will not bring the free space up higher than your minimum setting. Automatic song caching has been turned off.\n\nYou can re-enable it in the Settings menu (tap the gear, tap Settings at the top)" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
				[alert show];
				[alert release];
			}
			else
			{
				NSLog(@"checkCache:  entered the if if else");
				// Remove the oldest cached songs until freeSpace > minFreeSpace or pop the free space low alert
				DLog(@"freeSpace < minFreeSpace");
				//if ([[appDelegate.settingsDictionary objectForKey:@"autoDeleteCacheSetting"] isEqualToString:@"YES"])
				if (settings.isAutoDeleteCacheEnabled)
				{
					NSLog(@"checkCache:  entered the if if else if");
					DLog(@"deleting oldest cached songs");
					[self performSelectorInBackground:@selector(removeOldestCachedSongs) withObject:nil];
				}
				else
				{
					NSLog(@"checkCache:  entered the if if else else");
					UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Notice" message:@"Free space is running low. Delete some cached songs or lower the minimum free space setting." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
					[alert show];
					[alert release];
				}
			}
		}
	}
	//else if ([[appDelegate.settingsDictionary objectForKey:@"cachingTypeSetting"] intValue] == 1 &&
	//		 [[appDelegate.settingsDictionary objectForKey:@"enableSongCachingSetting"] isEqualToString:@"YES"])
	else if (settings.cachingType == 1 && settings.isSongCachingEnabled)
	{
		NSLog(@"checkCache:  entered the else");
		// User has chosen to limit cache by maximum size
		
		// Check to see if the cache size is higher than the max
		if (cacheSize > maxCacheSize)
		{
			NSLog(@"checkCache:  entered the else if");
			DLog(@"cacheSize > maxCacheSize");
			//if ([[appDelegate.settingsDictionary objectForKey:@"autoDeleteCacheSetting"] isEqualToString:@"YES"])
			if (settings.isAutoDeleteCacheEnabled)
			{
				NSLog(@"checkCache:  entered the else if if");
				DLog(@"deleting oldest cached songs");
				[self performSelectorInBackground:@selector(removeOldestCachedSongs) withObject:nil];
			}
			else
			{
				NSLog(@"checkCache:  entered the else if else");
				//[appDelegate.settingsDictionary setObject:@"NO" forKey:@"enableSongCachingSetting"];
				settings.isSongCachingEnabled = NO;
				
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Notice" message:@"The song cache is full. Automatic song caching has been disabled.\n\nYou can re-enable it in the Settings menu (tap the gear, tap Settings at the top)" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
				[alert show];
				[alert release];
			}			
		}
	}
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
	self.isNewSong = YES;
	
	[self destroyStreamer];
	
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

- (void)removeAutoNextNotification
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
}

- (void)scrobbleSong:(NSString*)songId isSubmission:(BOOL)isSubmission
{
	NSString *urlString = [NSString stringWithFormat:@"%@%@&submission=%i", [appDelegate getBaseUrl:@"scrobble.view"], songId, isSubmission];
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kLoadingTimeout];
	[[NSURLConnection alloc] initWithRequest:request delegate:self];
	DLog(@"scrobbling song: %@", urlString);
}

#pragma mark -
#pragma mark Song Download Progress Methods


- (float) findCurrentSongProgress
{
	NSString *songMD5 = [NSString md5:self.currentSongObject.path];
	
	if ([[databaseControls.songCacheDb stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", songMD5] isEqualToString:@"YES"])
		return 1.0;
	
	NSString *fileName;
	if (self.currentSongObject.transcodedSuffix)
		fileName = [self.audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", songMD5, self.currentSongObject.transcodedSuffix]];
	else
		fileName = [self.audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", songMD5, self.currentSongObject.suffix]];
	
	float fileSize = (float)[[[NSFileManager defaultManager] attributesOfItemAtPath:fileName error:NULL] fileSize];
	
	float formattedBitRate;

	if (self.bitRate < 1000)
		formattedBitRate = (float)self.bitRate;
	else
		formattedBitRate = (float)self.bitRate / 1000;
	
	float totalSize = formattedBitRate * 128.0 * [self.currentSongObject.duration floatValue];
	
	if (totalSize == 0)
		return 0.0;
	
	return (fileSize / totalSize);
}


- (float) findNextSongProgress
{
	if (self.nextSongObject.path != nil)
	{
		NSString *songMD5 = [self.nextSongObject.path md5];
		
		if ([[databaseControls.songCacheDb stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", songMD5] isEqualToString:@"YES"])
		{
			// The next song is already cached so return 1
			return 1.0;
		}
		else if ([[databaseControls.songCacheDb stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", songMD5] isEqualToString:@"NO"])
		{
			if ([self.downloadFileNameHashB isEqualToString:songMD5])
			{
				// The next song is being downloaded right now so return the progress
				NSString *fileName;
				if (self.nextSongObject.transcodedSuffix)
					fileName = [self.audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", songMD5, self.nextSongObject.transcodedSuffix]];
				else
					fileName = [self.audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", songMD5, self.nextSongObject.suffix]];
				
				float fileSize = (float)[[[NSFileManager defaultManager] attributesOfItemAtPath:fileName error:NULL] fileSize];
				
				float formattedBitRate;
				if (self.bitRate < 1000)
					formattedBitRate = (float)self.bitRate;
				else
					formattedBitRate = (float)self.bitRate / 1000;
				
				float totalSize = formattedBitRate * 128.0 * [self.nextSongObject.duration floatValue];
				
				float progress = fileSize / totalSize;
				
				return progress;
			}
			else
			{
				// The next song is partially downloaded but will be overwritten with downloadB starts, so return 0
				return 0.0;
			}
		}
		else 
		{
			// The next song hasn't started downloading yet
			return 0.0;
		}
	}
	
	return 0.0;
}


- (unsigned long long int) findCacheSize
{	
	unsigned long long combinedSize = 0;
	for (NSString *path in [[NSFileManager defaultManager] subpathsAtPath:self.documentsPath]) 
	{
		combinedSize += [[[NSFileManager defaultManager] attributesOfItemAtPath:[self.documentsPath stringByAppendingPathComponent:path] error:NULL] fileSize];
	}
	return combinedSize;
}


- (unsigned long long int) findFreeSpace
{
	return [[[[NSFileManager defaultManager] attributesOfFileSystemForPath:self.audioFolderPath error:NULL] objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
}


#pragma mark -
#pragma mark Jukebox Control methods

- (void)jukeboxPlaySongAtPosition:(NSUInteger)position
{
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
	
	seekTime = 0.0;
	
	NSString *urlString = [NSString stringWithFormat:@"%@&action=skip&index=%i", [appDelegate getBaseUrl:@"jukeboxControl.view"], position];
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kJukeboxTimeout];
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
		//[viewObjects showAlbumLoadingScreen:self.view sender:self];
		currentPlaylistPosition = position;
		
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
	
	seekTime = 0.0;
	
	NSString *urlString = [NSString stringWithFormat:@"%@&action=start", [appDelegate getBaseUrl:@"jukeboxControl.view"]];
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kJukeboxTimeout];
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
	
	isPlaying = YES;
}

- (void)jukeboxStop
{
	
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
	
	NSString *urlString = [NSString stringWithFormat:@"%@&action=stop", [appDelegate getBaseUrl:@"jukeboxControl.view"]];
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kJukeboxTimeout];
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
	
	isPlaying = NO;
}

- (void)jukeboxPrevSong
{
	NSInteger index = currentPlaylistPosition - 1;
	if (index >= 0)
	{		
		seekTime = 0.0;
				
		[self jukeboxPlaySongAtPosition:index];
		
		isPlaying = YES;
	}
}

- (void)jukeboxNextSong
{
	NSInteger index = currentPlaylistPosition + 1;
	if (index <= ([databaseControls.currentPlaylistDb intForQuery:@"SELECT COUNT(*) FROM jukeboxCurrentPlaylist"] - 1))
	{
		seekTime = 0.0;
		
		[self jukeboxPlaySongAtPosition:index];
		
		isPlaying = YES;
	}
	else
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"setPlayButtonImage" object:nil];
		[self jukeboxStop];
		
		isPlaying = NO;
	}
}

- (void)jukeboxSetVolume:(float)level
{
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
	
	NSString *urlString = [NSString stringWithFormat:@"%@&action=setGain&gain=%f", [appDelegate getBaseUrl:@"jukeboxControl.view"], level];
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kJukeboxTimeout];
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
	
	NSString *urlString = [NSString stringWithFormat:@"%@&action=add&id=%@", [appDelegate getBaseUrl:@"jukeboxControl.view"], songId];
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kJukeboxTimeout];
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
		NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@&action=add", [appDelegate getBaseUrl:@"jukeboxControl.view"]];
		
		for (NSString *songId in songIds)
		{
			[urlString appendString:@"&id="];
			[urlString appendString:songId];
		}
		
		DLog(@"jukeboxAddSongs urlString: %@", urlString);
		
		JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
		
		NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kJukeboxTimeout];
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
		[songIds addObject:[NSString stringWithString:[result stringForColumnIndex:0]]];
	}
	[result close];
	
	[self jukeboxAddSongs:songIds];
	
	[songIds release];
}


- (void)jukeboxRemoveSong:(NSString*)songId
{
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
	
	NSString *urlString = [NSString stringWithFormat:@"%@&action=remove&id=%@", [appDelegate getBaseUrl:@"jukeboxControl.view"], songId];
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kJukeboxTimeout];
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
	
	NSString *urlString = [NSString stringWithFormat:@"%@&action=clear", [appDelegate getBaseUrl:@"jukeboxControl.view"]];
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kJukeboxTimeout];
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
	
	NSString *urlString = [NSString stringWithFormat:@"%@&action=clear", [appDelegate getBaseUrl:@"jukeboxControl.view"]];
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kJukeboxTimeout];
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
	
	NSString *urlString = [NSString stringWithFormat:@"%@&action=shuffle", [appDelegate getBaseUrl:@"jukeboxControl.view"]];
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kJukeboxTimeout];
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
	
	NSString *urlString = [NSString stringWithFormat:@"%@&action=get", [appDelegate getBaseUrl:@"jukeboxControl.view"]];
	//DLog(@"jukeboxGetInfo urlString: %@", urlString);
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kJukeboxTimeout];
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

+ (MusicControlsSingleton*)sharedInstance
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
	
	//initialize here
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	databaseControls = [DatabaseControlsSingleton sharedInstance];
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
	self.isNewSong = NO;
	self.reportDownloadedLengthB = NO;
	isAutoNextNotificationOn = NO;
	
	[self addAutoNextNotification];
	//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateChanged:) name:ASStatusChangedNotification object:nil];
	
	// Check the free space every 60 seconds
	[NSTimer scheduledTimerWithTimeInterval:60.0 target:self selector:@selector(checkCache) userInfo:nil repeats:YES];
	
	connectionQueue = [[BBSimpleConnectionQueue alloc] init];
	
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

- (void)release {
    //do nothing
}

- (id)autorelease {
    return self;
}

@end
