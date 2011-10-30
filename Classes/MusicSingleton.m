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
 
static MusicSingleton *sharedInstance = nil;

@implementation MusicSingleton

// Audio streamer objects and variables
//
@synthesize streamer, streamerProgress, repeatMode, isShuffle, isPlaying, seekTime, buffersUsed;

// Music player objects
//
@synthesize currentSongObject, nextSongObject, queueSongObject, currentSongLyrics, currentPlaylistPosition, isNewSong, songUrl, nextSongUrl, queueSongUrl, coverArtUrl; 

// Song cache stuff
@synthesize documentsPath, audioFolderPath, tempAudioFolderPath, tempDownloadByteOffset;
@synthesize receivedDataA, downloadFileNameA, downloadFileNameHashA, audioFileA, downloadedLengthA;
@synthesize receivedDataB, downloadFileNameB, downloadFileNameHashB, audioFileB, downloadedLengthB, reportDownloadedLengthB;
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
	self.downloadFileNameA = nil;
	if (currentSongObject.transcodedSuffix)
		self.downloadFileNameA = [audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashA, currentSongObject.transcodedSuffix]];
	else
		self.downloadFileNameA = [audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashA, currentSongObject.suffix]];
	
	// Check to see if the song is already cached
	if ([databaseControls.songCacheDb intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE md5 = ?", downloadFileNameHashA])
	{
		// Looks like the song is in the database, check if it's cached fully
		NSString *isDownloadFinished = [databaseControls.songCacheDb stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", downloadFileNameHashA];
		if ([isDownloadFinished isEqualToString:@"YES"])
		{
			// The song is fully cached, start streaming from the local copy
			
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
			
			if (nextSongObject.path != nil && settings.isNextSongCacheEnabled && settings.isSongCachingEnabled)
				[self startDownloadB];
		}
		else
		{
			// Check to see if the song is being downloaded by startDownloadB
			if ([downloadFileNameHashA isEqualToString:downloadFileNameHashB])
			{
				// The song is already being downloaded so start playing the local copy
				
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
		if (settings.isSongCachingEnabled)
		{			
			// Add the row to the song cache database (looooooong query :P)
			[databaseControls.songCacheDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO cachedSongs (md5, finished, cachedDate, playedDate, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES ('%@', 'NO', %i, %i, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", downloadFileNameHashA, (NSUInteger)[[NSDate date] timeIntervalSince1970], (NSUInteger)[[NSDate date] timeIntervalSince1970]], currentSongObject.title, currentSongObject.songId, currentSongObject.artist, currentSongObject.album, currentSongObject.genre, currentSongObject.coverArtId, currentSongObject.path, currentSongObject.suffix, currentSongObject.transcodedSuffix, currentSongObject.duration, currentSongObject.bitRate, currentSongObject.track, currentSongObject.year, currentSongObject.size];
			
			// Create new file on disk
			[[NSFileManager defaultManager] createFileAtPath:downloadFileNameA contents:[NSData data] attributes:nil];
			self.audioFileA = [NSFileHandle fileHandleForWritingAtPath:downloadFileNameA];

			[CFNetworkRequests downloadCFNetA:songUrl];
		}
		else
		{
			// Song caching is off, so use the startTempDownload method
			[self startTempDownloadA:0];
		}
	}
}

- (void)resumeDownloadA:(UInt32)byteOffset
{
	// Create the request and resume the download
	if (!viewObjects.isOfflineMode)
	{
		[CFNetworkRequests resumeCFNetA:byteOffset];
	}
}

- (void)stopDownloadA 
{
	if ([CFNetworkRequests downloadA])
	{
		[CFNetworkRequests cancelCFNetA];
	}
	
	// Delete the unfinished download and remove it from the cache database
	NSString *isDownloadFinished = [databaseControls.songCacheDb stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", downloadFileNameHashA];
	if ([isDownloadFinished isEqualToString:@"NO"])
	{		
		// Delete the song from disk
		[[NSFileManager defaultManager] removeItemAtPath:downloadFileNameA error:NULL];
		
		// Delete the song row from the cache database
		[databaseControls.songCacheDb executeUpdate:@"DELETE FROM cachedSongs WHERE md5 = ?", downloadFileNameHashA];
	}
}

// Start downloading the file specified in the text field.
- (void)startDownloadB
{			
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
	self.downloadFileNameB = nil;
	if (nextSongObject.transcodedSuffix)
		self.downloadFileNameB = [audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashB, nextSongObject.transcodedSuffix]];
	else
		self.downloadFileNameB = [audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashB, nextSongObject.suffix]];
	
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
			
			// Update the cached and played dates to now
			[databaseControls.songCacheDb executeUpdate:[NSString stringWithFormat:@"UPDATE cachedSongs SET cachedDate = %i, playedDate = 0 WHERE md5 = ?", (NSUInteger)[[NSDate date] timeIntervalSince1970]], downloadFileNameHashB];
			
			// Set the song url
			self.nextSongUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"stream.view"], nextSongObject.songId]];
			
			// Remove and recreate the song file on disk
			[[NSFileManager defaultManager] removeItemAtPath:downloadFileNameB error:NULL];
			[[NSFileManager defaultManager] createFileAtPath:downloadFileNameB contents:[NSData data] attributes:nil];
			self.audioFileB = nil; self.audioFileB = [NSFileHandle fileHandleForWritingAtPath:downloadFileNameB];
			
			self.songB = [[nextSongObject copy] autorelease];
			[CFNetworkRequests downloadCFNetB:nextSongUrl];
		}
	}
	else 
	{
		// The song has not been cached yet, start from scratch
		
		// Add the row to the song cache database (looooooong query :P)
		[databaseControls.songCacheDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO cachedSongs (md5, finished, cachedDate, playedDate, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES ('%@', 'NO', %i, 0, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", downloadFileNameHashB, (NSUInteger)[[NSDate date] timeIntervalSince1970]], nextSongObject.title, nextSongObject.songId, nextSongObject.artist, nextSongObject.album, nextSongObject.genre, nextSongObject.coverArtId, nextSongObject.path, nextSongObject.suffix, nextSongObject.transcodedSuffix, nextSongObject.duration, nextSongObject.bitRate, nextSongObject.track, nextSongObject.year, nextSongObject.size];
		
		// Set the song url
		self.nextSongUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"stream.view"], nextSongObject.songId]];
		
		// Create new file on disk
		[[NSFileManager defaultManager] createFileAtPath:downloadFileNameB contents:[NSData data] attributes:nil];
		self.audioFileB = [NSFileHandle fileHandleForWritingAtPath:downloadFileNameB];
		
		self.songB = [[nextSongObject copy] autorelease];
		[CFNetworkRequests downloadCFNetB:nextSongUrl];
	}
}

- (void)resumeDownloadB:(UInt32)byteOffset
{
	// Create the request and resume the download
	if (!viewObjects.isOfflineMode)
	{
		[CFNetworkRequests resumeCFNetB:byteOffset];
	}
}

- (void)resumeDownloadB:(UInt32)byteOffset withSong:(Song *)song
{
	DLog(@"----------------------------- (void)resumeDownloadB:(UInt32)byteOffset withSong:(Song *)song");
	DLog(@"----------------------------- I SHOULDN'T HAVE BEEN CALLED!!! -------------------------------");
}

- (void)stopDownloadB
{
	reportDownloadedLengthB = NO;

	if ([CFNetworkRequests downloadB])
	{
		[CFNetworkRequests cancelCFNetB];
		self.songB = nil;
	}		
	
	// Delete the unfinished download and remove it from the cache database
	NSString *isDownloadFinished = [databaseControls.songCacheDb stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", downloadFileNameHashB];
	if ([isDownloadFinished isEqualToString:@"NO"])
	{		
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
	
	// Create the new temp file
	[[NSFileManager defaultManager] createFileAtPath:downloadFileNameA contents:[NSData data] attributes:nil];
	self.audioFileA = nil; self.audioFileA = [NSFileHandle fileHandleForWritingAtPath:downloadFileNameA];

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
	
	[result close];
	return [aSong autorelease];
}

// Start downloading the file specified in the text field.
- (void)startDownloadQueue
{		
	DLog(@"startDownloadQueue called");
	
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

- (void)createStreamer
{
	streamerProgress = 0.0;
	seekTime = 0.0;
	
	streamer = [[AudioStreamer alloc] initWithFileURL:[NSURL fileURLWithPath:downloadFileNameA]];
	[self addAutoNextNotification];
	[streamer start];	
}

- (void)createStreamerWithOffset
{
	streamerProgress = 0.0;
	
	streamer = [[AudioStreamer alloc] initWithFileURL:[NSURL fileURLWithPath:downloadFileNameA]];
	[self addAutoNextNotification];
	[streamer start];	
}

- (void)destroyStreamer
{
	self.isPlaying = NO;
	
	if (streamer)
	{
		[self removeAutoNextNotification];
		
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
		if (isPlaying)
		{
			isPlaying = NO;
			[streamer pause];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"setPlayButtonImage" object:nil];
		}
		else
		{
			// If the player is playing from downloadB and it's still downloading, stop it.
			if (reportDownloadedLengthB)
				[self stopDownloadB];
			
			isPlaying = YES;
			
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
		
		if (resume)
		{
			self.songUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"stream.view"], [currentSongObject songId]]];
			
			// Determine the hashed filename
			self.downloadFileNameHashA = nil; self.downloadFileNameHashA = [NSString md5:currentSongObject.path];
						
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
						
						isTempDownload = NO;
						
						// Determine the file hash
						self.downloadFileNameHashA = [NSString md5:currentSongObject.path];
						
						// Determine the name and path of the file.
						if (currentSongObject.transcodedSuffix)
							self.downloadFileNameA = [audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashA, currentSongObject.transcodedSuffix]];
						else
							self.downloadFileNameA = [audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashA, currentSongObject.suffix]];
						
						// Start streaming from the local copy
						
						// Check the file size
						NSNumber *fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:downloadFileNameA error:NULL] objectForKey:NSFileSize];
						downloadedLengthA = [fileSize intValue];
						//DLog(@"downloadedLengthA: %i", downloadedLengthA);
						
						streamerProgress = 0.0;
						
						streamer = [[AudioStreamer alloc] initWithFileURL:[NSURL fileURLWithPath:downloadFileNameA]];
						if (streamer)
						{
							streamer.fileDownloadCurrentSize = downloadedLengthA;
							streamer.fileDownloadComplete = YES;
							[streamer startWithOffsetInSecs:(UInt32) seekTime];
						}
					}
					else
					{
						if (viewObjects.isOfflineMode)
						{
							CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"Unable to resume this song in offline mode as it isn't fully cached." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
							alert.tag = 4;
							[alert show];
							[alert release];
						}
						else 
						{
							// The song is not fully cached, call startTempDownloadA to start a temp cache stream
							
							// Determine the name and path of the file.
							if (currentSongObject.transcodedSuffix)
								self.downloadFileNameA = [audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashA, currentSongObject.transcodedSuffix]];
							else
								self.downloadFileNameA = [audioFolderPath stringByAppendingString:[NSString stringWithFormat:@"/%@.%@", downloadFileNameHashA, currentSongObject.suffix]];
							
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
	// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	NSString *artist = [artistAndTitle objectAtIndex:0];
	NSString *title = [artistAndTitle objectAtIndex:1];
	
	NSString *lyrics = [databaseControls.lyricsDb stringForQuery:@"SELECT lyrics FROM lyrics WHERE artist = ? AND title = ?", artist, title];
	if (lyrics)
	{
		if ([artist isEqualToString:currentSongObject.artist] && [title isEqualToString:currentSongObject.title])
		{
			self.currentSongLyrics = lyrics;
			[[NSNotificationCenter defaultCenter] postNotificationName:@"lyricsDoneLoading" object:nil];
		}
	}
	else
	{
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
			[databaseControls removeSongFromCacheDb:songMD5];
			
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

			[databaseControls removeSongFromCacheDb:songMD5];

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
		currentPlaylistPosition = position;
		
		[connectionQueue registerConnection:connection];
		[connectionQueue startQueue];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		alert.tag = 2;
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
		alert.tag = 2;
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
		alert.tag = 2;
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
		alert.tag = 2;
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
		alert.tag = 2;
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
			alert.tag = 2;
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
		alert.tag = 2;
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
		alert.tag = 2;
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
		alert.tag = 2;
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
		alert.tag = 2;
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
		alert.tag = 2;
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
	self.isNewSong = NO;
	self.reportDownloadedLengthB = NO;
	isAutoNextNotificationOn = NO;
	
	[self addAutoNextNotification];
	
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

- (oneway void)release {
    //do nothing
}

- (id)autorelease {
    return self;
}

@end
