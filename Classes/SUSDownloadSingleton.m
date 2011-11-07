//
//  CFNetworkRequests.m
//  iSub
//
//  Created by Ben Baron on 7/14/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SUSDownloadSingleton.h"
#import "iSubAppDelegate.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "NSString-md5.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "AudioStreamer.h"
#import "AsynchronousImageView.h"
#import "AsynchronousImageViewCached.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
#import "SUSPlayerCoverArtLoader.h"
#import "SUSTableCellCoverArtLoader.h"
#import "NSString+URLEncode.h"
#import "NSData+Base64.h"

static SUSDownloadSingleton *sharedInstance = nil;

static iSubAppDelegate *appDelegate;
static MusicSingleton *musicControls;
static DatabaseSingleton *databaseControls;
static CFReadStreamRef readStreamRefA;
static CFReadStreamRef readStreamRefB;
static void TerminateDownload(CFReadStreamRef stream);
id appDelegateRef;
id musicControlsRef;
id databaseControlsRef;
id selfRef;

// Bandwidth Throttling
static UInt32 bytesTransferred;

#define kThrottleTimeInterval 0.01

#define kMaxKilobitsPerSec3G 550
#define kMaxBytesPerSec3G ((kMaxKilobitsPerSec3G * 1024) / 8)
#define kMaxBytesPerInterval3G (kMaxBytesPerSec3G * kThrottleTimeInterval)

#define kMaxKilobitsPerSecWifi 8000
#define kMaxBytesPerSecWifi ((kMaxKilobitsPerSecWifi * 1024) / 8)
#define kMaxBytesPerIntervalWifi (kMaxBytesPerSecWifi * kThrottleTimeInterval)

#define kMinBytesToStartPlayback (1024 * 50)    // Number of bytes to wait before activating the player
#define kMinBytesToStartLimiting (1024 * 1024)   // Start throttling bandwidth after 1 MB downloaded for 192kbps files (adjusted accordingly by bitrate)

// Logging
#define isProgressLoggingEnabled NO
#define isThrottleLoggingEnabled NO


@implementation SUSDownloadSingleton

@synthesize throttlingDate, isDownloadA, isDownloadB;

static const CFOptionFlags kNetworkEvents = kCFStreamEventOpenCompleted | kCFStreamEventHasBytesAvailable | kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred;

- (BOOL) insertSong:(Song *)aSong intoGenreTable:(NSString *)table
{
	[databaseControls.songCacheDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (md5, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", table], [NSString md5:aSong.path], aSong.title, aSong.songId, aSong.artist, aSong.album, aSong.genre, aSong.coverArtId, aSong.path, aSong.suffix, aSong.transcodedSuffix, aSong.duration, aSong.bitRate, aSong.track, aSong.year, aSong.size];
	
	if ([databaseControls.songCacheDb hadError]) {
		DLog(@"Err inserting song into genre table %d: %@", [databaseControls.songCacheDb lastErrorCode], [databaseControls.songCacheDb lastErrorMessage]);
	}
	
	return [databaseControls.songCacheDb hadError];
}

- (void) continueDownloadA
{
	if (isDownloadA)
	{
		// Schedule the stream
        self.throttlingDate = [NSDate date];
		CFReadStreamScheduleWithRunLoop(readStreamRefA, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	}
}

- (void) continueDownloadB
{
	if (isDownloadB)
	{
		// Schedule the stream
		self.throttlingDate = [NSDate date];
		CFReadStreamScheduleWithRunLoop(readStreamRefB, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	}
}


#pragma mark Terminate
static void TerminateDownload(CFReadStreamRef stream)
{	
	if (stream == nil)
	{
		//DLog(@"------------------------------ stream is nil so returning");
		return;
	}
	//DLog(@"------------------------------ stream is not nil so closing the stream");
	
	//***	ALWAYS set the stream client (notifier) to NULL if you are releaseing it
	//	otherwise your notifier may be called after you released the stream leaving you with a 
	//	bogus stream within your notifier.
	CFReadStreamSetClient( stream, kCFStreamEventNone, NULL, NULL );
	CFReadStreamUnscheduleFromRunLoop( stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes );
	CFReadStreamClose( stream );
	CFRelease( stream );
	
	stream = nil;
}

- (void) cancelCFNetA
{
	//DLog(@"cancelCFNetA called, isDownloadA = %i", isDownloadA);
	isDownloadA = NO;
	TerminateDownload(readStreamRefA);
}

- (void) cancelCFNetB
{
	//DLog(@"cancelCFNetB called, isDownloadB = %i", isDownloadB);
	isDownloadB = NO;
	TerminateDownload(readStreamRefB);
}

int currentSongBitrate()
{
	int bitRate = 128;
	
	if ([[musicControlsRef currentSongObject] bitRate] == nil)
		bitRate = 128;
	else if ([[[musicControlsRef currentSongObject] bitRate] intValue] < 1000)
		bitRate = [[[musicControlsRef currentSongObject] bitRate] intValue];
	else
		bitRate = [[[musicControlsRef currentSongObject] bitRate] intValue] / 1000;
	
	if (bitRate > [musicControlsRef maxBitrateSetting] && [musicControlsRef maxBitrateSetting] != 0)
		bitRate = [musicControlsRef maxBitrateSetting];
	
	return bitRate;
}

int nextSongBitrate()
{
	int bitRate = 128;
	
	if ([[musicControlsRef nextSongObject] bitRate] == nil)
		bitRate = 128;
	else if ([[[musicControlsRef nextSongObject] bitRate] intValue] < 1000)
		bitRate = [[[musicControlsRef nextSongObject] bitRate] intValue];
	else
		bitRate = [[[musicControlsRef nextSongObject] bitRate] intValue] / 1000;
	
	if (bitRate > [musicControlsRef maxBitrateSetting] && [musicControlsRef maxBitrateSetting] != 0)
		bitRate = [musicControlsRef maxBitrateSetting];
	
	return bitRate;
}

#pragma mark Callbacks
static void DownloadDoneA()
{
	/*// Get the response header
	CFHTTPMessageRef myResponse = CFReadStreamCopyProperty(readStreamRefA, kCFStreamPropertyHTTPResponseHeader);
	CFStringRef myStatusLine = CFHTTPMessageCopyResponseStatusLine(myResponse);
	DLog(@"http response status: %@", myStatusLine);*/
	
	
	//DLog(@"------------------ DownloadDoneA called");
	// Check if the file is less than 500 bytes. If it is, then it's almost definitely an API expiration notice
	if ([musicControlsRef downloadedLengthA] < 500)
	{
		// Show an alert and delete the file
		UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Error" message:@"No song data returned. This could be because your Subsonic API trial has expired, this song is not an mp3 and the Subsonic transcoding plugins failed, or another reason." delegate:appDelegateRef cancelButtonTitle:@"OK" otherButtonTitles: nil] autorelease];
		alert.tag = 2;
		[alert performSelector:@selector(show) onThread:[NSThread mainThread] withObject:nil waitUntilDone:NO];
		[[NSFileManager defaultManager] removeItemAtPath:[musicControlsRef downloadFileNameA] error:NULL];
		
		// Close the file
		[[musicControlsRef audioFileA] closeFile];
		
        [selfRef setIsDownloadA:NO];
	}
	else
	{
		// Mark that we are done downloading
		[[musicControlsRef streamer] setFileDownloadComplete: YES];
		[[databaseControlsRef songCacheDb] executeUpdate:@"UPDATE cachedSongs SET finished = 'YES' WHERE md5 = ?", [musicControlsRef downloadFileNameHashA]];
		
		// Save the offline view layout info
		NSArray *splitPath = [[[databaseControlsRef songCacheDb] stringForQuery:@"SELECT path FROM cachedSongs WHERE md5 = ?", [musicControlsRef downloadFileNameHashA]] componentsSeparatedByString:@"/"];
		//DLog(@"------------------- splitPath count: %i", [splitPath count]);
		if ([splitPath count] <= 9)
		{
			NSMutableArray *segments = [[NSMutableArray alloc] initWithArray:splitPath];
			while ([segments count] < 9)
			{
				[segments addObject:@""];
			}
			
			NSString *query = [NSString stringWithFormat:@"INSERT INTO cachedSongsLayout (md5, genre, segs, seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8, seg9) VALUES ('%@', '%@', %i, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [musicControlsRef downloadFileNameHashA], [[musicControlsRef currentSongObject] genre], [splitPath count]];
			[[databaseControlsRef songCacheDb] executeUpdate:query, [segments objectAtIndex:0], [segments objectAtIndex:1], [segments objectAtIndex:2], [segments objectAtIndex:3], [segments objectAtIndex:4], [segments objectAtIndex:5], [segments objectAtIndex:6], [segments objectAtIndex:7], [segments objectAtIndex:8]];
			
			[segments release];
		}
		
		// Setup the genre table entries
		if ([[musicControlsRef currentSongObject] genre])
		{
			// Check if the genre has a table in the database yet, if not create it and add the new genre to the genres table
			if ([[databaseControlsRef songCacheDb] intForQuery:@"SELECT COUNT(*) FROM genres WHERE genre = ?", [[musicControlsRef currentSongObject] genre]] == 0)
			{							
				[[databaseControlsRef songCacheDb] executeUpdate:@"INSERT INTO genres (genre) VALUES (?)", [[musicControlsRef currentSongObject] genre]];
				if ([[databaseControlsRef songCacheDb] hadError]) { DLog(@"Err adding the genre %d: %@", [[databaseControlsRef songCacheDb] lastErrorCode], [[databaseControlsRef songCacheDb] lastErrorMessage]); }
			}
			
			// Insert the song object into the genresSongs
			[[SUSDownloadSingleton sharedInstance] insertSong:[musicControlsRef currentSongObject] intoGenreTable:@"genresSongs"];
		}
		
		// Cache the album art if it exists
		NSString *coverArtId = [[databaseControlsRef songCacheDb] stringForQuery:@"SELECT coverArtId FROM cachedSongs WHERE md5 = ?", [musicControlsRef downloadFileNameHashA]];
        
        SUSPlayerCoverArtLoader *playerCoverArtLoader = [[SUSPlayerCoverArtLoader alloc] initWithDelegate:selfRef];
        playerCoverArtLoader.coverArtId = coverArtId;
        if (!playerCoverArtLoader.isCoverArtCached) 
            [playerCoverArtLoader startLoad];
        
        SUSTableCellCoverArtLoader *tableCellCoverArtLoader = [[SUSTableCellCoverArtLoader alloc] initWithDelegate:selfRef];
        tableCellCoverArtLoader.coverArtId = coverArtId;
        if (!tableCellCoverArtLoader.isCoverArtCached)
            [tableCellCoverArtLoader startLoad];
		
		// Close the file
		[[musicControlsRef audioFileA] closeFile];
		
        [selfRef setIsDownloadA:NO];
		
		// Start the download of the next song if there is one and the setting is turned on
		if ([[musicControlsRef nextSongObject] path] != nil && [SavedSettings sharedInstance].isNextSongCacheEnabled)
			[musicControlsRef startDownloadB];
	}
}

static void	ReadStreamClientCallBackA( CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo )
{	
	if ([selfRef isDownloadA])
	{
		#pragma unused (clientCallBackInfo)
		UInt8		buffer[16 * 1024];				//	Create a 16K buffer
		CFIndex		bytesRead;
		
		if (type == kCFStreamEventHasBytesAvailable)
		{
			bytesRead = CFReadStreamRead( stream, buffer, sizeof(buffer) );
			
			if ( bytesRead > 0 )	// If zero bytes were read, wait for the EOF to come.
			{
				// Save the data to the file
				NSData *data = [NSData dataWithBytes:buffer length:bytesRead];
				[[musicControlsRef audioFileA] writeData:data];
				[musicControlsRef setDownloadedLengthA:([musicControlsRef downloadedLengthA] + bytesRead)];
				
				if (isProgressLoggingEnabled)
					DLog(@"downloadedLengthA:  %lu   bytesRead: %ld", [musicControlsRef downloadedLengthA], bytesRead);
				
				if ([musicControlsRef streamer])
					[[musicControlsRef streamer] setFileDownloadCurrentSize:[musicControlsRef downloadedLengthA]];
				
				// When we get enough of the file, then just start playing it.
				if (![musicControlsRef streamer] && ([musicControlsRef downloadedLengthA] > kMinBytesToStartPlayback)) 
				{
					//DLog(@"start playback for %@", [musicControlsRef downloadFileNameA]);
					
					[musicControlsRef createStreamer];
					[musicControlsRef setShowNowPlayingIcon: NO];
				}
				
				
				// Handle bandwidth throttling
				bytesTransferred += bytesRead;

				if ([musicControlsRef downloadedLengthA] < (kMinBytesToStartLimiting * ((float)currentSongBitrate() / 160.0f)))
				{
                    [selfRef setThrottlingDate:[NSDate date]];
					bytesTransferred = 0;
				}
				
				if ([[NSDate date] timeIntervalSinceDate:[selfRef throttlingDate]] > kThrottleTimeInterval &&
					[musicControlsRef downloadedLengthA] > (kMinBytesToStartLimiting * ((float)currentSongBitrate() / 160.0f)))
				{
					if ([appDelegateRef isWifi] == NO && bytesTransferred > kMaxBytesPerInterval3G)
					{
						CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
						
						//Calculate how many intervals to pause
						NSTimeInterval delay = (kThrottleTimeInterval * ((double)bytesTransferred / (double)kMaxBytesPerInterval3G));
						
						if (isThrottleLoggingEnabled)
							DLog(@"Bandwidth used is more than kMaxBytesPerSec3G, Pausing for %f", delay);
						
						[NSTimer scheduledTimerWithTimeInterval:delay target:[SUSDownloadSingleton sharedInstance] selector:@selector(continueDownloadA) userInfo:nil repeats:NO];
						
						bytesTransferred = 0;
					}
					else if ([appDelegateRef isWifi] && bytesTransferred > kMaxBytesPerIntervalWifi)
					{
						CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
						
						//Calculate how many intervals to pause
						NSTimeInterval delay = (kThrottleTimeInterval * ((double)bytesTransferred / (double)kMaxBytesPerIntervalWifi));
						
						if (isThrottleLoggingEnabled)
							DLog(@"Bandwidth used is more than kMaxBytesPerSec3G, Pausing for %f", delay);
						
						[NSTimer scheduledTimerWithTimeInterval:delay target:[SUSDownloadSingleton sharedInstance] selector:@selector(continueDownloadA) userInfo:nil repeats:NO];
						
						bytesTransferred = 0;
					}				
				}
			}
			else if ( bytesRead < 0 )		// Less than zero is an error
			{
				TerminateDownload( stream );
				[musicControlsRef resumeDownloadA:[musicControlsRef downloadedLengthA]];
			}
			else	//	0 assume we are done with the stream
			{
				TerminateDownload( stream );
				DownloadDoneA();
			}
		}
		else if (type == kCFStreamEventEndEncountered)
		{
			TerminateDownload( stream );
			DownloadDoneA();
		}
		else if (type == kCFStreamEventErrorOccurred)
		{
			TerminateDownload( stream );
			[musicControlsRef resumeDownloadA:[musicControlsRef downloadedLengthA]];
		}
	}
}

static void DownloadDoneB()
{
	// Check if the file is less than 500 bytes. If it is, then it's almost definitely an API expiration notice
	if ([musicControlsRef downloadedLengthB] < 500)
	{
		// Show an alert and delete the file
		UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Error" message:@"No song data returned. This could be because your Subsonic API trial has expired, this song is not an mp3 and the Subsonic transcoding plugins failed, or another reason." delegate:appDelegateRef cancelButtonTitle:@"OK" otherButtonTitles: nil] autorelease];
		alert.tag = 2;
		[alert performSelector:@selector(show) onThread:[NSThread mainThread] withObject:nil waitUntilDone:NO];
		[[NSFileManager defaultManager] removeItemAtPath:[musicControlsRef downloadFileNameB] error:NULL];
		
		// Close the file
		[[musicControlsRef audioFileB] closeFile];
		
		[selfRef setIsDownloadB:NO];
	}
	else
	{
		// If we're playing from this file, tell the streamer it's done downloading
		if ([musicControlsRef reportDownloadedLengthB])
			[[musicControlsRef streamer] setFileDownloadComplete: YES];
		
		// Mark that we are done downloading
		[[databaseControlsRef songCacheDb] executeUpdate:@"UPDATE cachedSongs SET finished = 'YES' WHERE md5 = ?", [musicControlsRef downloadFileNameHashB]];
		
		// Save the offline view layout info
		NSArray *splitPath = [[[databaseControlsRef songCacheDb] stringForQuery:@"SELECT path FROM cachedSongs WHERE md5 = ?", [musicControlsRef downloadFileNameHashB]] componentsSeparatedByString:@"/"];
		//DLog(@"------------------- splitPath count: %i", [splitPath count]);
		if ([splitPath count] <= 9)
		{
			NSMutableArray *segments = [[NSMutableArray alloc] initWithArray:splitPath];
			while ([segments count] < 9)
			{
				[segments addObject:@""];
			}
			
			NSString *query = [NSString stringWithFormat:@"INSERT INTO cachedSongsLayout (md5, genre, segs, seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8, seg9) VALUES ('%@', '%@', %i, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [musicControlsRef downloadFileNameHashB], [[musicControlsRef songB] genre], [splitPath count]];
			[[databaseControlsRef songCacheDb] executeUpdate:query, [segments objectAtIndex:0], [segments objectAtIndex:1], [segments objectAtIndex:2], [segments objectAtIndex:3], [segments objectAtIndex:4], [segments objectAtIndex:5], [segments objectAtIndex:6], [segments objectAtIndex:7], [segments objectAtIndex:8]];
			
			[segments release];
		}
		
		// Setup the genre table entries
		if ([[musicControlsRef songB] genre])
		{
			// Check if the genre has a table in the database yet, if not create it and add the new genre to the genres table
			if ([[databaseControlsRef songCacheDb] intForQuery:@"SELECT COUNT(*) FROM genres WHERE genre = ?", [[musicControlsRef songB] genre]] == 0)
			{							
				[[databaseControlsRef songCacheDb] executeUpdate:@"INSERT INTO genres (genre) VALUES (?)", [[musicControlsRef songB] genre]];
				if ([[databaseControlsRef songCacheDb] hadError]) { DLog(@"Err adding the genre %d: %@", [[databaseControlsRef songCacheDb] lastErrorCode], [[databaseControlsRef songCacheDb] lastErrorMessage]); }
			}
			
			// Insert the song object into the genresSongs
			[[SUSDownloadSingleton sharedInstance] insertSong:[musicControlsRef songB] intoGenreTable:@"genresSongs"];
		}
		
		// Cache the album art if it exists
		NSString *coverArtId = [[databaseControlsRef songCacheDb] stringForQuery:@"SELECT coverArtId FROM cachedSongs WHERE md5 = ?", [musicControlsRef downloadFileNameHashB]];
        
        SUSPlayerCoverArtLoader *playerCoverArtLoader = [[SUSPlayerCoverArtLoader alloc] initWithDelegate:selfRef];
        playerCoverArtLoader.coverArtId = coverArtId;
        if (!playerCoverArtLoader.isCoverArtCached) 
            [playerCoverArtLoader startLoad];
        
        SUSTableCellCoverArtLoader *tableCellCoverArtLoader = [[SUSTableCellCoverArtLoader alloc] initWithDelegate:selfRef];
        tableCellCoverArtLoader.coverArtId = coverArtId;
        if (!tableCellCoverArtLoader.isCoverArtCached)
            [tableCellCoverArtLoader startLoad];
        
		// Close the file
		[[musicControlsRef audioFileB] closeFile];
		
		[selfRef setIsDownloadB:NO];
		
		// If we're playing from this file and the setting is turned on, call startDownloadB again to grab the next song
		if ([musicControlsRef reportDownloadedLengthB])
		{
			//if ([[musicControlsRef nextSongObject] path] != nil && [[[appDelegateRef settingsDictionary] objectForKey:@"enableNextSongCacheSetting"] isEqualToString:@"YES"])
			if ([[musicControlsRef nextSongObject] path] != nil && [SavedSettings sharedInstance].isNextSongCacheEnabled)
				[musicControlsRef startDownloadB];
		}
		
		// Tell downloadB to stop reporting length
		[musicControlsRef setReportDownloadedLengthB: NO];
		
		[musicControlsRef setSongB: nil];
	}
}

static void	ReadStreamClientCallBackB( CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo )
{	
	if ([selfRef isDownloadB])
	{
		#pragma unused (clientCallBackInfo)
		UInt8		buffer[16 * 1024];				//	Create a 16K buffer
		CFIndex		bytesRead;
		
		if (type == kCFStreamEventHasBytesAvailable)
		{
			bytesRead = CFReadStreamRead( stream, buffer, sizeof(buffer) );
			
			if ( bytesRead > 0 )	// If zero bytes were read, wait for the EOF to come.
			{
				// Add the bandwidth transferred for the throttler
				bytesTransferred += bytesRead; 
				
				// Save the data to the file
				NSData *data = [NSData dataWithBytes:buffer length:bytesRead];
				[[musicControlsRef audioFileB] writeData:data];
				[musicControlsRef setDownloadedLengthB:([musicControlsRef downloadedLengthB] + bytesRead)];
				
				if (isProgressLoggingEnabled)
					DLog(@"downloadedLengthB:  %lu   bytesRead: %ld", [musicControlsRef downloadedLengthB], bytesRead);
				
				// If this is the currently playing song, update the streamer on the downloaded length
				if ([musicControlsRef reportDownloadedLengthB])
				{
					//DLog(@"downloadB reporting length to streamer");
					if ([musicControlsRef streamer])
						[[musicControlsRef streamer] setFileDownloadCurrentSize:[musicControlsRef downloadedLengthB]];
				}
				
				// Handle bandwidth throttling
				bytesTransferred += bytesRead;

				if ([musicControlsRef downloadedLengthB] < (kMinBytesToStartLimiting * ((float)currentSongBitrate() / 160.0f)))
				{
					[selfRef setThrottlingDate:[NSDate date]];
					bytesTransferred = 0;
				}
				
				if ([[NSDate date] timeIntervalSinceDate:[selfRef throttlingDate]] > kThrottleTimeInterval &&
					[musicControlsRef downloadedLengthB] > (kMinBytesToStartLimiting * ((float)nextSongBitrate() / 160.0f)))
				{
					if ([appDelegateRef isWifi] == NO && bytesTransferred > kMaxBytesPerInterval3G)
					{
						CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
						
						//Calculate how many intervals to pause
						NSTimeInterval delay = kThrottleTimeInterval * ((double)bytesTransferred / (double)kMaxBytesPerInterval3G);
						
						if (isThrottleLoggingEnabled)
							DLog(@"Bandwidth used is more than kMaxBytesPerSec3G, Pausing for %f", delay);
						
						[NSTimer scheduledTimerWithTimeInterval:delay target:[SUSDownloadSingleton sharedInstance] selector:@selector(continueDownloadB) userInfo:nil repeats:NO];
						
						bytesTransferred = 0;
					}
					else if ([appDelegateRef isWifi] && bytesTransferred > kMaxBytesPerIntervalWifi)
					{
						CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
						
						//Calculate how many intervals to pause
						NSTimeInterval delay = kThrottleTimeInterval * ((double)bytesTransferred / (double)kMaxBytesPerIntervalWifi);
						
						if (isThrottleLoggingEnabled)
							DLog(@"Bandwidth used is more than kMaxBytesPerSec3G, Pausing for %f", delay);
						
						[NSTimer scheduledTimerWithTimeInterval:delay target:[SUSDownloadSingleton sharedInstance] selector:@selector(continueDownloadB) userInfo:nil repeats:NO];
						
						bytesTransferred = 0;
					}
				}
			}
			else if ( bytesRead < 0 )		// Less than zero is an error
			{
				TerminateDownload( stream );
				[musicControlsRef resumeDownloadB:[musicControlsRef downloadedLengthB]];
			}
			else	//	0 assume we are done with the stream
			{
				TerminateDownload( stream );				
				DownloadDoneB();
			}
		}
		else if (type == kCFStreamEventEndEncountered)
		{
			TerminateDownload( stream );
			DownloadDoneB();
		}
		else if (type == kCFStreamEventErrorOccurred)
		{
			TerminateDownload( stream );
			[musicControlsRef resumeDownloadB:[musicControlsRef downloadedLengthB]];
		}
	}
}

static void DownloadDoneTemp()
{
	// Check if the file is less than 500 bytes. If it is, then it's almost definitely an API expiration notice
	if ([musicControlsRef downloadedLengthA] < 500)
	{
		// Show an alert and delete the file
		UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Error" message:@"No song data returned. This could be because your Subsonic API trial has expired, this song is not an mp3 and the Subsonic transcoding plugins failed, or another reason." delegate:appDelegateRef cancelButtonTitle:@"OK" otherButtonTitles: nil] autorelease];
		alert.tag = 2;
		[alert performSelector:@selector(show) onThread:[NSThread mainThread] withObject:nil waitUntilDone:NO];
		[[NSFileManager defaultManager] removeItemAtPath:[musicControlsRef downloadFileNameA] error:NULL];
		
		// Close the file
		[[musicControlsRef audioFileA] closeFile];
		
		[selfRef setIsDownloadA:NO];
	}
	else
	{
		// Mark that we are done downloading
		[[musicControlsRef streamer] setFileDownloadComplete: YES];
		
		// Close the file
		[[musicControlsRef audioFileA] closeFile];
	
		[selfRef setIsDownloadA:NO];
		
		// Start the download of the next song if there is one and the setting is turned on and auto song caching is enabled
		//if ([[musicControlsRef nextSongObject] path] != nil && [[[appDelegateRef settingsDictionary] objectForKey:@"enableNextSongCacheSetting"] isEqualToString:@"YES"] && [[[appDelegateRef settingsDictionary] objectForKey:@"enableSongCachingSetting"] isEqualToString:@"YES"])
		if ([[musicControlsRef nextSongObject] path] != nil && [SavedSettings sharedInstance].isNextSongCacheEnabled && [SavedSettings sharedInstance].isSongCachingEnabled)
			[musicControlsRef startDownloadB];
	}
}

static void	ReadStreamClientCallBackTemp( CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo )
{	
	//DLog(@"ReadStreamClientCallBackTemp [musicControlsRef downloadedLengthA]: %i", [musicControlsRef downloadedLengthA]);
	
	#pragma unused (clientCallBackInfo)
	UInt8		buffer[16 * 1024];				//	Create a 16K buffer
	CFIndex		bytesRead;
	
	if (type == kCFStreamEventHasBytesAvailable)
	{
		bytesRead = CFReadStreamRead( stream, buffer, sizeof(buffer) );
		
		if ( bytesRead > 0 )	// If zero bytes were read, wait for the EOF to come.
		{
			// Save the data to the file
			NSData *data = [NSData dataWithBytes:buffer length:bytesRead];
			[[musicControlsRef audioFileA] writeData:data];
			[musicControlsRef setDownloadedLengthA:([musicControlsRef downloadedLengthA] + bytesRead)];
			
			if (isProgressLoggingEnabled)
				DLog(@"downloadedLengthA:  %lu   bytesRead: %ld", [musicControlsRef downloadedLengthA], bytesRead);
			
			if ([musicControlsRef streamer])
				[[musicControlsRef streamer] setFileDownloadCurrentSize:[musicControlsRef downloadedLengthA]];
			
			// When we get enough of the file, then just start playing it.
			if (![musicControlsRef streamer] && ([musicControlsRef downloadedLengthA] > kMinBytesToStartPlayback)) 
			{
				//DLog(@"start playback for %@", [musicControlsRef downloadFileNameA]);
				
				[musicControls createStreamerWithOffset];
				[musicControlsRef setShowNowPlayingIcon: NO];
			}
			
			// Handle bandwidth throttling
			bytesTransferred += bytesRead;

			if ([musicControlsRef downloadedLengthA] < (kMinBytesToStartLimiting * ((float)currentSongBitrate() / 160.0f)))
			{
				[selfRef setThrottlingDate:[NSDate date]];
				bytesTransferred = 0;
			}
			
			if ([[NSDate date] timeIntervalSinceDate:[selfRef throttlingDate]] > kThrottleTimeInterval &&
				[musicControlsRef downloadedLengthA] > (kMinBytesToStartLimiting * ((float)currentSongBitrate() / 160.0f)))
			{
				if ([appDelegateRef isWifi] == NO && bytesTransferred > kMaxBytesPerInterval3G)
				{
					CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
					
					//Calculate how many intervals to pause
					NSTimeInterval delay = kThrottleTimeInterval * ((double)bytesTransferred / (double)kMaxBytesPerInterval3G);
					
					if (isThrottleLoggingEnabled)
						DLog(@"Bandwidth used is more than kMaxBytesPerSec3G, Pausing for %f", delay);
					
					[NSTimer scheduledTimerWithTimeInterval:delay target:[SUSDownloadSingleton sharedInstance] selector:@selector(continueDownloadA) userInfo:nil repeats:NO];
					
					bytesTransferred = 0;
				}
				else if ([appDelegateRef isWifi] && bytesTransferred > kMaxBytesPerIntervalWifi)
				{
					CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
					
					//Calculate how many intervals to pause
					NSTimeInterval delay = kThrottleTimeInterval * ((double)bytesTransferred / (double)kMaxBytesPerIntervalWifi);
					
					if (isThrottleLoggingEnabled)
						DLog(@"Bandwidth used is more than kMaxBytesPerSec3G, Pausing for %f", delay);
					
					[NSTimer scheduledTimerWithTimeInterval:delay target:[SUSDownloadSingleton sharedInstance] selector:@selector(continueDownloadA) userInfo:nil repeats:NO];
					
					bytesTransferred = 0;
				}
			}
		}
		else if ( bytesRead < 0 )		// Less than zero is an error
		{
			TerminateDownload( stream );		
			[musicControlsRef startTempDownloadA:([musicControlsRef tempDownloadByteOffset] + [musicControlsRef downloadedLengthA])];
		}
		else	//	0 assume we are done with the stream
		{
			TerminateDownload( stream );			
			DownloadDoneTemp();
		}
	}
	else if (type == kCFStreamEventEndEncountered)
	{
		TerminateDownload( stream );		
		DownloadDoneTemp();
	}
	else if (type == kCFStreamEventErrorOccurred)
	{
		TerminateDownload( stream );		
		[musicControlsRef startTempDownloadA:([musicControlsRef tempDownloadByteOffset] + [musicControlsRef downloadedLengthA])];
	}
}

#pragma mark Connection factory

- (void)createConnectionForReadStreamRef:(CFReadStreamRef)readStreamRef callback:(CFReadStreamClientCallBack)callback songId:(NSString *)songId offset:(UInt32)byteOffset
{
    SavedSettings *settings = [SavedSettings sharedInstance];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/rest/stream.view", settings.urlString]];
	NSString *username = [settings.username URLEncodeString];
	NSString *password = [settings.password URLEncodeString];
    
    CFHTTPMessageRef messageRef = NULL;
	CFStreamClientContext ctxt = {0, (void*)NULL, NULL, NULL, NULL};
    
	// Create the POST request
	messageRef = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("POST"), (CFURLRef)url, kCFHTTPVersion1_1);
	if ( messageRef == NULL ) goto Bail;
	
	// Create the stream for the request.
	readStreamRef	= CFReadStreamCreateForHTTPRequest( kCFAllocatorDefault, messageRef );
	if ( readStreamRef == NULL ) goto Bail;
	
	//	There are times when a server checks the User-Agent to match a well known browser.  This is what Safari used at the time the sample was written
	//CFHTTPMessageSetHeaderFieldValue( messageRef, CFSTR("User-Agent"), CFSTR("Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/125.5.5 (KHTML, like Gecko) Safari/125")); 
    
    // Set the POST body
    NSString *postString = nil;
    if ([musicControls maxBitrateSetting] != 0)
	{
        postString = [NSString stringWithFormat:@"v=1.2.0&c=iSub&maxBitRate=%i&id=%@", musicControls.maxBitrateSetting, songId];
	}
    else
	{
        postString = [NSString stringWithFormat:@"v=1.1.0&c=iSub&id=%@", songId];
	}
    CFHTTPMessageSetBody(messageRef, (CFDataRef)[postString dataUsingEncoding:NSUTF8StringEncoding]);
	
	// Set a no cache policy
	CFHTTPMessageSetHeaderFieldValue( messageRef, CFSTR("Cache-Control"), CFSTR("no-cache"));
    
    if (byteOffset > 0)
    {
        // Add the HTTP header to resume the download
        //DLog(@"----------------- byteOffset header: %@", [NSString stringWithFormat:@"bytes=%d-", byteOffset]);
        CFHTTPMessageSetHeaderFieldValue( messageRef, CFSTR("Range"), CFStringCreateWithFormat(NULL, NULL, CFSTR("bytes=%i-"), byteOffset)); 
    }
        
    // Handle Basic Auth
    NSString *authStr = [NSString stringWithFormat:@"%@:%@", username, password];
    NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64EncodingWithLineLength:0]];
    CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("Authorization"), (CFStringRef)authValue);
	
	// Enable stream redirection
    if (CFReadStreamSetProperty(readStreamRef, kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanTrue) == false)
		goto Bail;
	
	// Handle SSL connections
	if([[url absoluteString] rangeOfString:@"https"].location != NSNotFound)
	{
		NSDictionary *sslSettings =
		[NSDictionary dictionaryWithObjectsAndKeys:
		 (NSString *)kCFStreamSocketSecurityLevelNegotiatedSSL, kCFStreamSSLLevel,
		 [NSNumber numberWithBool:YES], kCFStreamSSLAllowsExpiredCertificates,
		 [NSNumber numberWithBool:YES], kCFStreamSSLAllowsExpiredRoots,
		 [NSNumber numberWithBool:YES], kCFStreamSSLAllowsAnyRoot,
		 [NSNumber numberWithBool:NO], kCFStreamSSLValidatesCertificateChain,
		 [NSNull null], kCFStreamSSLPeerName,
		 nil];
		
		CFReadStreamSetProperty(readStreamRef, kCFStreamPropertySSLSettings, sslSettings);
	}
	
	// Handle proxy
	CFDictionaryRef proxyDict = CFNetworkCopySystemProxySettings();
	CFReadStreamSetProperty(readStreamRef, kCFStreamPropertyHTTPProxy, proxyDict);
	
	// Set the client notifier
	if (CFReadStreamSetClient(readStreamRef, kNetworkEvents, callback, &ctxt) == false)
		goto Bail;
    
	// Schedule the stream
	CFReadStreamScheduleWithRunLoop(readStreamRef, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    
	// Start the HTTP connection
	if (CFReadStreamOpen(readStreamRef) == false)
	    goto Bail;
	
	DLog(@"--- STARTING HTTP CONNECTION");
	
	if (messageRef != NULL) CFRelease(messageRef);
    return;
	
Bail:
	if (messageRef != NULL) CFRelease(messageRef);
	if (readStreamRef != NULL)
    {
        CFReadStreamSetClient(readStreamRef, kCFStreamEventNone, NULL, NULL);
	    CFReadStreamUnscheduleFromRunLoop(readStreamRef, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	    CFReadStreamClose(readStreamRef);
        CFRelease(readStreamRef);
    }
	return;
}

#pragma mark Download
- (void) downloadCFNetA:(NSString *)songId
{
    self.throttlingDate = nil;
	bytesTransferred = 0;
	
	isDownloadA = YES;
    
    [self createConnectionForReadStreamRef:readStreamRefA callback:ReadStreamClientCallBackA songId:songId offset:0];
}

- (void) downloadCFNetB:(NSString *)songId
{
	self.throttlingDate = nil;
	bytesTransferred = 0;
	
	isDownloadB = YES;
    
    [self createConnectionForReadStreamRef:readStreamRefB callback:ReadStreamClientCallBackB songId:songId offset:0];
}

- (void) downloadCFNetTemp:(NSString *)songId
{
	self.throttlingDate = nil;
	bytesTransferred = 0;
	
	isDownloadA = YES;
    
    [self createConnectionForReadStreamRef:readStreamRefA callback:ReadStreamClientCallBackTemp songId:songId offset:0];
}

#pragma mark Resume
- (void) resumeCFNetA:(NSString *)songId offset:(UInt32)byteOffset
{
    self.throttlingDate = [NSDate date];
	bytesTransferred = 0;
	
	isDownloadA = YES;
    
    [self createConnectionForReadStreamRef:readStreamRefA callback:ReadStreamClientCallBackA songId:songId offset:byteOffset];
}

- (void) resumeCFNetB:(NSString *)songId offset:(UInt32)byteOffset
{
	self.throttlingDate = [NSDate date];
	bytesTransferred = 0;
	
	isDownloadB = YES;
    
    [self createConnectionForReadStreamRef:readStreamRefB callback:ReadStreamClientCallBackB songId:songId offset:byteOffset];
}

#pragma mark - SUSLoader delegate

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error
{
    [theLoader release]; theLoader = nil;
}

- (void)loadingFinished:(SUSLoader*)theLoader
{
    [theLoader release]; theLoader = nil;
}

#pragma mark - Singleton methods

- (void)setup
{
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
    musicControls = [MusicSingleton sharedInstance];
    databaseControls = [DatabaseSingleton sharedInstance];
    appDelegateRef = appDelegate;
    musicControlsRef = musicControls;
    databaseControlsRef = databaseControls;
    selfRef = self;
    isDownloadA = NO;
    isDownloadB = NO;
}

+ (SUSDownloadSingleton *)sharedInstance
{
    @synchronized(self)
    {
        if (sharedInstance == nil)
			[[self alloc] init];
    }
    return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone 
{
    @synchronized(self) 
	{
        if (sharedInstance == nil) 
		{
            sharedInstance = [super allocWithZone:zone];
			[sharedInstance setup];
            return sharedInstance;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

-(id)init 
{
	if ((self = [super init]))
	{
		[self setup];
		sharedInstance = self;
	}
    
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
