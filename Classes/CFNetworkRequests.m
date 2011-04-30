//
//  CFNetworkRequests.m
//  iSub
//
//  Created by Ben Baron on 7/14/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CFNetworkRequests.h"
#import "iSubAppDelegate.h"
#import "MusicControlsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "NSString-md5.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "AudioStreamer.h"
#import "ASIHTTPRequest.h"
#import "AsynchronousImageView.h"
#import "AsynchronousImageViewCached.h"
#import "CustomUIAlertView.h"

static iSubAppDelegate *appDelegate;
static MusicControlsSingleton *musicControls;
static DatabaseControlsSingleton *databaseControls;
static CFReadStreamRef readStreamRefA;
static CFReadStreamRef readStreamRefB;
static BOOL isDownloadA = NO;
static BOOL isDownloadB = NO;
static void TerminateDownload(CFReadStreamRef stream);
id appDelegateRef;
id musicControlsRef;
id databaseControlsRef;

// Bandwidth Throttling
static BOOL isThrottlingEnabled;
static NSDate *throttlingDate;
static UInt32 bytesTransferred;
#define kThrottleTimeInterval 0.01

#define kMaxKilobitsPerSec3G 475
#define kMaxBytesPerSec3G ((kMaxKilobitsPerSec3G * 1024) / 8)
#define kMaxBytesPerInterval3G (kMaxBytesPerSec3G * kThrottleTimeInterval)

#define kMaxKilobitsPerSecWifi 2000
#define kMaxBytesPerSecWifi ((kMaxKilobitsPerSecWifi * 1024) / 8)
#define kMaxBytesPerIntervalWifi (kMaxBytesPerSecWifi * kThrottleTimeInterval)

#define kMinBytesToStartPlayback (1024 * 200)    // Start playback at 200KB to counter playback start delay bug
#define kMinBytesToStartLimiting (1024 * 1024)   // Start throttling bandwidth after 1 MB downloaded


@implementation CFNetworkRequests

static const CFOptionFlags kNetworkEvents = kCFStreamEventOpenCompleted | kCFStreamEventHasBytesAvailable | kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred;

+ (void) setShouldThrottle:(BOOL)shouldThrottle
{
	isThrottlingEnabled = shouldThrottle;
}

+ (BOOL) insertSong:(Song *)aSong intoGenreTable:(NSString *)table
{
	[databaseControls.songCacheDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (md5, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", table], [NSString md5:aSong.path], aSong.title, aSong.songId, aSong.artist, aSong.album, aSong.genre, aSong.coverArtId, aSong.path, aSong.suffix, aSong.transcodedSuffix, aSong.duration, aSong.bitRate, aSong.track, aSong.year, aSong.size];
	
	if ([databaseControls.songCacheDb hadError]) {
		NSLog(@"Err inserting song into genre table %d: %@", [databaseControls.songCacheDb lastErrorCode], [databaseControls.songCacheDb lastErrorMessage]);
	}
	
	return [databaseControls.songCacheDb hadError];
}

+ (BOOL) downloadA
{
	return isDownloadA;
}

+ (BOOL) downloadB
{
	return isDownloadB;
}

+ (void) continueDownloadA
{
	if (isDownloadA)
	{
		// Schedule the stream
		//NSLog(@"continuing downloadA");
		[throttlingDate release]; throttlingDate = [[NSDate date] retain];
		CFReadStreamScheduleWithRunLoop(readStreamRefA, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	}
}

+ (void) continueDownloadB
{
	if (isDownloadB)
	{
		// Schedule the stream
		//NSLog(@"continuing downloadB");
		[throttlingDate release]; throttlingDate = [[NSDate date] retain];
		CFReadStreamScheduleWithRunLoop(readStreamRefB, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	}
}


#pragma mark Terminate
static void TerminateDownload(CFReadStreamRef stream)
{	
	if (stream == nil)
	{
		//NSLog(@"------------------------------ stream is nil so returning");
		return;
	}
	//NSLog(@"------------------------------ stream is not nil so closing the stream");
	
	//***	ALWAYS set the stream client (notifier) to NULL if you are releaseing it
	//	otherwise your notifier may be called after you released the stream leaving you with a 
	//	bogus stream within your notifier.
	CFReadStreamSetClient( stream, kCFStreamEventNone, NULL, NULL );
	CFReadStreamUnscheduleFromRunLoop( stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes );
	CFReadStreamClose( stream );
	CFRelease( stream );
	
	stream = nil;
}

+ (void) cancelCFNetA
{
	//NSLog(@"cancelCFNetA called, isDownloadA = %i", isDownloadA);
	isDownloadA = NO;
	TerminateDownload(readStreamRefA);
}

+ (void) cancelCFNetB
{
	//NSLog(@"cancelCFNetB called, isDownloadB = %i", isDownloadB);
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
	NSLog(@"http response status: %@", myStatusLine);*/
	
	
	//NSLog(@"------------------ DownloadDoneA called");
	// Check if the file is less than 500 bytes. If it is, then it's almost definitely an API expiration notice
	if ([musicControlsRef downloadedLengthA] < 500)
	{
		// Show an alert and delete the file
		UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Error" message:@"No song data returned. This could be because your Subsonic API trial has expired, this song is not an mp3 and the Subsonic transcoding plugins failed, or another reason." delegate:appDelegateRef cancelButtonTitle:@"OK" otherButtonTitles: nil] autorelease];
		[alert performSelector:@selector(show) onThread:[NSThread mainThread] withObject:nil waitUntilDone:NO];
		[[NSFileManager defaultManager] removeItemAtPath:[musicControlsRef downloadFileNameA] error:NULL];
		
		// Close the file
		[[musicControlsRef audioFileA] closeFile];
		
		isDownloadA = NO;
	}
	else
	{
		// Mark that we are done downloading
		[[musicControlsRef streamer] setFileDownloadComplete: YES];
		[[databaseControlsRef songCacheDb] executeUpdate:@"UPDATE cachedSongs SET finished = 'YES' WHERE md5 = ?", [musicControlsRef downloadFileNameHashA]];
		
		// Save the offline view layout info
		NSArray *splitPath = [[[databaseControlsRef songCacheDb] stringForQuery:@"SELECT path FROM cachedSongs WHERE md5 = ?", [musicControlsRef downloadFileNameHashA]] componentsSeparatedByString:@"/"];
		//NSLog(@"------------------- splitPath count: %i", [splitPath count]);
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
				if ([[databaseControlsRef songCacheDb] hadError]) { NSLog(@"Err adding the genre %d: %@", [[databaseControlsRef songCacheDb] lastErrorCode], [[databaseControlsRef songCacheDb] lastErrorMessage]); }
			}
			
			// Insert the song object into the genresSongs
			[CFNetworkRequests insertSong:[musicControlsRef currentSongObject] intoGenreTable:@"genresSongs"];
		}
		
		// Cache the album art if it exists
		NSString *coverArtId = [[databaseControlsRef songCacheDb] stringForQuery:@"SELECT coverArtId FROM cachedSongs WHERE md5 = ?", [musicControlsRef downloadFileNameHashA]];
		if (coverArtId)
		{
			if ([[databaseControlsRef coverArtCacheDb320] intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [NSString md5:coverArtId]] == 0)
			{
				//NSLog(@"320 artwork doesn't exist, caching");
				NSString *imgUrlString;
				if ([appDelegateRef isHighRez])
				{
					imgUrlString = [NSString stringWithFormat:@"%@%@&size=640", [appDelegateRef  getBaseUrl:@"getCoverArt.view"], coverArtId];
				}
				else 
				{
					imgUrlString = [NSString stringWithFormat:@"%@%@&size=320", [appDelegateRef  getBaseUrl:@"getCoverArt.view"], coverArtId];
				}
				ASIHTTPRequest *aRequest = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:imgUrlString]];
				[aRequest startSynchronous];
				if (![aRequest error])
				{
					if([UIImage imageWithData:[aRequest responseData]])
					{
						//NSLog(@"image is good so caching it");
						[[databaseControlsRef coverArtCacheDb320] executeUpdate:@"INSERT INTO coverArtCache (id, data) VALUES (?, ?)", [NSString md5:coverArtId], [aRequest responseData]];
					}
				}
			}
			if ([[databaseControlsRef coverArtCacheDb60] intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [NSString md5:coverArtId]] == 0)
			{
				//NSLog(@"60 artwork doesn't exist, caching");
				NSString *imgUrlString;
				if ([appDelegateRef isHighRez])
				{
					imgUrlString = [NSString stringWithFormat:@"%@%@&size=120", [appDelegateRef  getBaseUrl:@"getCoverArt.view"], coverArtId];
				}
				else 
				{
					imgUrlString = [NSString stringWithFormat:@"%@%@&size=60", [appDelegateRef  getBaseUrl:@"getCoverArt.view"], coverArtId];
				}
				ASIHTTPRequest *aRequest = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:imgUrlString]];
				[aRequest startSynchronous];
				if (![aRequest error])
				{
					if([UIImage imageWithData:[aRequest responseData]])
					{
						//NSLog(@"image is good so caching it");
						[[databaseControlsRef coverArtCacheDb60] executeUpdate:@"INSERT INTO coverArtCache (id, data) VALUES (?, ?)", [NSString md5:coverArtId], [aRequest responseData]];
					}
				}
			}
		}
		
		// Close the file
		[[musicControlsRef audioFileA] closeFile];
		
		isDownloadA = NO;
		
		// Start the download of the next song if there is one and the setting is turned on
		if ([[musicControlsRef nextSongObject] path] != nil && [[[appDelegateRef settingsDictionary] objectForKey:@"enableNextSongCacheSetting"] isEqualToString:@"YES"])
			[musicControlsRef startDownloadB];
	}
}

static void	ReadStreamClientCallBackA( CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo )
{	
	if (isDownloadA)
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
				
				if ([musicControlsRef streamer])
					[[musicControlsRef streamer] setFileDownloadCurrentSize:[musicControlsRef downloadedLengthA]];
				
				// When we get enough of the file, then just start playing it.
				if (![musicControlsRef streamer] && ([musicControlsRef downloadedLengthA] > kMinBytesToStartPlayback)) 
				{
					//NSLog(@"start playback for %@", [musicControlsRef downloadFileNameA]);
					
					[musicControlsRef createStreamer];
					[musicControlsRef setShowNowPlayingIcon: NO];
				}
				
				
				// Handle bandwidth throttling
				bytesTransferred += bytesRead;

				if ([musicControlsRef downloadedLengthA] < (kMinBytesToStartLimiting * ((float)currentSongBitrate() / 160.0f)))
				{
					[throttlingDate release]; throttlingDate = [[NSDate date] retain];
					bytesTransferred = 0;
				}
				
				if ([[NSDate date] timeIntervalSinceDate:throttlingDate] > kThrottleTimeInterval &&
					[musicControlsRef downloadedLengthA] > (kMinBytesToStartLimiting * ((float)currentSongBitrate() / 160.0f)))
				{
					if ([appDelegateRef isWifi] == NO && bytesTransferred > kMaxBytesPerInterval3G)
					{
						//NSLog(@"Bandwidth used is more than kMaxBytesPerSec3G, throttling for kThrottleTimeInterval");
						CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
						
						//Calculate how many intervals to pause
						NSTimeInterval delay = (kThrottleTimeInterval * ((double)bytesTransferred / (double)kMaxBytesPerInterval3G));
						//NSLog(@"Pausing for %f", delay);
						[NSTimer scheduledTimerWithTimeInterval:delay target:[CFNetworkRequests class] selector:@selector(continueDownloadA) userInfo:nil repeats:NO];
						
						bytesTransferred = 0;
					}
					else if ([appDelegateRef isWifi] && bytesTransferred > kMaxBytesPerIntervalWifi)
					{
						//NSLog(@"Bandwidth used is more than kMaxBytesPerSecWifi, throttling for kThrottleTimeInterval");
						CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
						
						//Calculate how many intervals to pause
						NSTimeInterval delay = (kThrottleTimeInterval * ((double)bytesTransferred / (double)kMaxBytesPerIntervalWifi));
						//NSLog(@"Pausing for %f", delay);
						[NSTimer scheduledTimerWithTimeInterval:delay target:[CFNetworkRequests class] selector:@selector(continueDownloadA) userInfo:nil repeats:NO];
						
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
		[alert performSelector:@selector(show) onThread:[NSThread mainThread] withObject:nil waitUntilDone:NO];
		[[NSFileManager defaultManager] removeItemAtPath:[musicControlsRef downloadFileNameB] error:NULL];
		
		// Close the file
		[[musicControlsRef audioFileB] closeFile];
		
		isDownloadB = NO;
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
		//NSLog(@"------------------- splitPath count: %i", [splitPath count]);
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
				if ([[databaseControlsRef songCacheDb] hadError]) { NSLog(@"Err adding the genre %d: %@", [[databaseControlsRef songCacheDb] lastErrorCode], [[databaseControlsRef songCacheDb] lastErrorMessage]); }
			}
			
			// Insert the song object into the genresSongs
			[CFNetworkRequests insertSong:[musicControlsRef songB] intoGenreTable:@"genresSongs"];
		}
		
		// Cache the album art if it exists
		NSString *coverArtId = [[databaseControlsRef songCacheDb] stringForQuery:@"SELECT coverArtId FROM cachedSongs WHERE md5 = ?", [musicControlsRef downloadFileNameHashB]];
		if (coverArtId)
		{
			if ([[databaseControlsRef coverArtCacheDb320] intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [NSString md5:coverArtId]] == 0)
			{
				//NSLog(@"320 artwork doesn't exist, caching");
				NSString *imgUrlString;
				if ([appDelegateRef isHighRez])
				{
					imgUrlString = [NSString stringWithFormat:@"%@%@&size=640", [appDelegateRef  getBaseUrl:@"getCoverArt.view"], coverArtId];
				}
				else 
				{
					imgUrlString = [NSString stringWithFormat:@"%@%@&size=320", [appDelegateRef  getBaseUrl:@"getCoverArt.view"], coverArtId];
				}
				ASIHTTPRequest *aRequest = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:imgUrlString]];
				[aRequest startSynchronous];
				if (![aRequest error])
				{
					if([UIImage imageWithData:[aRequest responseData]])
					{
						//NSLog(@"image is good so caching it");
						[[databaseControlsRef coverArtCacheDb320] executeUpdate:@"INSERT INTO coverArtCache (id, data) VALUES (?, ?)", [NSString md5:coverArtId], [aRequest responseData]];
					}
				}
			}
			if ([[databaseControlsRef coverArtCacheDb60] intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [NSString md5:coverArtId]] == 0)
			{
				//NSLog(@"60 artwork doesn't exist, caching");
				NSString *imgUrlString;
				if ([appDelegateRef isHighRez])
				{
					imgUrlString = [NSString stringWithFormat:@"%@%@&size=120", [appDelegateRef  getBaseUrl:@"getCoverArt.view"], coverArtId];
				}
				else 
				{
					imgUrlString = [NSString stringWithFormat:@"%@%@&size=60", [appDelegateRef  getBaseUrl:@"getCoverArt.view"], coverArtId];
				}
				ASIHTTPRequest *aRequest = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:imgUrlString]];
				[aRequest startSynchronous];
				if (![aRequest error])
				{
					if([UIImage imageWithData:[aRequest responseData]])
					{
						//NSLog(@"image is good so caching it");
						[[databaseControlsRef coverArtCacheDb60] executeUpdate:@"INSERT INTO coverArtCache (id, data) VALUES (?, ?)", [NSString md5:coverArtId], [aRequest responseData]];
					}
				}
			}
		}
		
		// Close the file
		[[musicControlsRef audioFileB] closeFile];
		
		isDownloadB = NO;
		
		// If we're playing from this file and the setting is turned on, call startDownloadB again to grab the next song
		if ([musicControlsRef reportDownloadedLengthB])
		{
			if ([[musicControlsRef nextSongObject] path] != nil && [[[appDelegateRef settingsDictionary] objectForKey:@"enableNextSongCacheSetting"] isEqualToString:@"YES"])
				[musicControlsRef startDownloadB];
		}
		
		// Tell downloadB to stop reporting length
		[musicControlsRef setReportDownloadedLengthB: NO];
		
		[musicControlsRef setSongB: nil];
	}
}

static void	ReadStreamClientCallBackB( CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo )
{	
	if (isDownloadB)
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
				
				// If this is the currently playing song, update the streamer on the downloaded length
				if ([musicControlsRef reportDownloadedLengthB])
				{
					//NSLog(@"downloadB reporting length to streamer");
					if ([musicControlsRef streamer])
						[[musicControlsRef streamer] setFileDownloadCurrentSize:[musicControlsRef downloadedLengthB]];
				}
				
				// Handle bandwidth throttling
				bytesTransferred += bytesRead;

				if ([musicControlsRef downloadedLengthB] < (kMinBytesToStartLimiting * ((float)currentSongBitrate() / 160.0f)))
				{
					[throttlingDate release]; throttlingDate = [[NSDate date] retain];
					bytesTransferred = 0;
				}
				
				if ([[NSDate date] timeIntervalSinceDate:throttlingDate] > kThrottleTimeInterval &&
					[musicControlsRef downloadedLengthB] > (kMinBytesToStartLimiting * ((float)nextSongBitrate() / 160.0f)))
				{
					if ([appDelegateRef isWifi] == NO && bytesTransferred > kMaxBytesPerInterval3G)
					{
						//NSLog(@"Bandwidth used is more than kMaxBytesPerSec, throttling for kThrottleTimeInterval");
						CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
						
						//Calculate how many intervals to pause
						NSTimeInterval delay = kThrottleTimeInterval * ((double)bytesTransferred / (double)kMaxBytesPerInterval3G);
						//NSLog(@"Pausing for %f", delay);
						[NSTimer scheduledTimerWithTimeInterval:delay target:[CFNetworkRequests class] selector:@selector(continueDownloadB) userInfo:nil repeats:NO];
						
						bytesTransferred = 0;
					}
					else if ([appDelegateRef isWifi] && bytesTransferred > kMaxBytesPerIntervalWifi)
					{
						//NSLog(@"Bandwidth used is more than kMaxBytesPerSec, throttling for kThrottleTimeInterval");
						CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
						
						//Calculate how many intervals to pause
						NSTimeInterval delay = kThrottleTimeInterval * ((double)bytesTransferred / (double)kMaxBytesPerIntervalWifi);
						//NSLog(@"Pausing for %f", delay);
						[NSTimer scheduledTimerWithTimeInterval:delay target:[CFNetworkRequests class] selector:@selector(continueDownloadB) userInfo:nil repeats:NO];
						
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
		[alert performSelector:@selector(show) onThread:[NSThread mainThread] withObject:nil waitUntilDone:NO];
		[[NSFileManager defaultManager] removeItemAtPath:[musicControlsRef downloadFileNameA] error:NULL];
		
		// Close the file
		[[musicControlsRef audioFileA] closeFile];
		
		isDownloadA = NO;
	}
	else
	{
		// Mark that we are done downloading
		[[musicControlsRef streamer] setFileDownloadComplete: YES];
		
		// Close the file
		[[musicControlsRef audioFileA] closeFile];
	
		isDownloadA = NO;
		
		// Start the download of the next song if there is one and the setting is turned on and auto song caching is enabled
		if ([[musicControlsRef nextSongObject] path] != nil && [[[appDelegateRef settingsDictionary] objectForKey:@"enableNextSongCacheSetting"] isEqualToString:@"YES"] && [[[appDelegateRef settingsDictionary] objectForKey:@"enableSongCachingSetting"] isEqualToString:@"YES"])
			[musicControlsRef startDownloadB];
	}
}

static void	ReadStreamClientCallBackTemp( CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo )
{	
	//NSLog(@"ReadStreamClientCallBackTemp [musicControlsRef downloadedLengthA]: %i", [musicControlsRef downloadedLengthA]);
	
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
			
			if ([musicControlsRef streamer])
				[[musicControlsRef streamer] setFileDownloadCurrentSize:[musicControlsRef downloadedLengthA]];
			
			// When we get enough of the file, then just start playing it.
			if (![musicControlsRef streamer] && ([musicControlsRef downloadedLengthA] > kMinBytesToStartPlayback)) 
			{
				//NSLog(@"start playback for %@", [musicControlsRef downloadFileNameA]);
				
				[musicControls createStreamerWithOffset];
				[musicControlsRef setShowNowPlayingIcon: NO];
			}
			
			// Handle bandwidth throttling
			bytesTransferred += bytesRead;

			if ([musicControlsRef downloadedLengthA] < (kMinBytesToStartLimiting * ((float)currentSongBitrate() / 160.0f)))
			{
				[throttlingDate release]; throttlingDate = [[NSDate date] retain];
				bytesTransferred = 0;
			}
			
			if ([[NSDate date] timeIntervalSinceDate:throttlingDate] > kThrottleTimeInterval &&
				[musicControlsRef downloadedLengthA] > (kMinBytesToStartLimiting * ((float)currentSongBitrate() / 160.0f)))
			{
				if ([appDelegateRef isWifi] == NO && bytesTransferred > kMaxBytesPerInterval3G)
				{
					//NSLog(@"Bandwidth used is more than kMaxBytesPerSec3G, throttling for kThrottleTimeInterval");
					CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
					
					//Calculate how many intervals to pause
					NSTimeInterval delay = kThrottleTimeInterval * ((double)bytesTransferred / (double)kMaxBytesPerInterval3G);
					//NSLog(@"Pausing for %f", delay);
					[NSTimer scheduledTimerWithTimeInterval:delay target:[CFNetworkRequests class] selector:@selector(continueDownloadA) userInfo:nil repeats:NO];
					
					bytesTransferred = 0;
				}
				else if ([appDelegateRef isWifi] && bytesTransferred > kMaxBytesPerIntervalWifi)
				{
					//NSLog(@"Bandwidth used is more than kMaxBytesPerSecWifi, throttling for kThrottleTimeInterval");
					CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
					
					//Calculate how many intervals to pause
					NSTimeInterval delay = kThrottleTimeInterval * ((double)bytesTransferred / (double)kMaxBytesPerIntervalWifi);
					//NSLog(@"Pausing for %f", delay);
					[NSTimer scheduledTimerWithTimeInterval:delay target:[CFNetworkRequests class] selector:@selector(continueDownloadA) userInfo:nil repeats:NO];
					
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

#pragma mark Download
+ (void) downloadCFNetA:(NSURL *)url
{
	//NSLog(@"downloadCFNetA url: %@", [url absoluteString]);
	
	if (!appDelegate)
	{
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		musicControls = [MusicControlsSingleton sharedInstance];
		databaseControls = [DatabaseControlsSingleton sharedInstance];
		appDelegateRef = appDelegate;
		musicControlsRef = musicControls;
		databaseControlsRef = databaseControls;
	}
	
	if (throttlingDate)
		[throttlingDate release];
	throttlingDate = nil;
	bytesTransferred = 0;
	
	isDownloadA = YES;
	
	CFHTTPMessageRef messageRef = NULL;
	//CFReadStreamRef	readStreamRef = NULL;
	CFStreamClientContext ctxt = {0, (void*)NULL, NULL, NULL, NULL};
    
	// Create the GET request
	messageRef = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("GET"), (CFURLRef)url, kCFHTTPVersion1_1);
	if ( messageRef == NULL ) goto Bail;
	
	// Create the stream for the request.
	readStreamRefA	= CFReadStreamCreateForHTTPRequest( kCFAllocatorDefault, messageRef );
	if ( readStreamRefA == NULL ) goto Bail;
	
	//	There are times when a server checks the User-Agent to match a well known browser.  This is what Safari used at the time the sample was written
	//CFHTTPMessageSetHeaderFieldValue( messageRef, CFSTR("User-Agent"), CFSTR("Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/125.5.5 (KHTML, like Gecko) Safari/125")); 
	
	// Set a no cache policy
	CFHTTPMessageSetHeaderFieldValue( messageRef, CFSTR("Cache-Control"), CFSTR("no-cache"));
	
	// Enable stream redirection
    if (CFReadStreamSetProperty(readStreamRefA, kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanTrue) == false)
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
		
		CFReadStreamSetProperty(readStreamRefA, kCFStreamPropertySSLSettings, sslSettings);
	}
	
	// Set the client notifier
	if (CFReadStreamSetClient(readStreamRefA, kNetworkEvents, ReadStreamClientCallBackA, &ctxt) == false)
		goto Bail;
    
	// Schedule the stream
	CFReadStreamScheduleWithRunLoop(readStreamRefA, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    
	// Start the HTTP connection
	if (CFReadStreamOpen(readStreamRefA) == false)
	    goto Bail;
	
	if (messageRef != NULL) CFRelease(messageRef);
	return;
	
Bail:
	if (messageRef != NULL) CFRelease(messageRef);
	if (readStreamRefA != NULL)
    {
        CFReadStreamSetClient(readStreamRefA, kCFStreamEventNone, NULL, NULL);
	    CFReadStreamUnscheduleFromRunLoop(readStreamRefA, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	    CFReadStreamClose(readStreamRefA);
        CFRelease(readStreamRefA);
    }
	return;
}

+ (void) downloadCFNetB:(NSURL *)url
{
	if (!appDelegate)
	{
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		musicControls = [MusicControlsSingleton sharedInstance];
		databaseControls = [DatabaseControlsSingleton sharedInstance];
		appDelegateRef = appDelegate;
		musicControlsRef = musicControls;
		databaseControlsRef = databaseControls;
	}
	
	if (throttlingDate)
		[throttlingDate release];
	throttlingDate = nil;
	bytesTransferred = 0;
	
	isDownloadB = YES;
	
	CFHTTPMessageRef messageRef = NULL;
	//CFReadStreamRef	readStreamRefB = NULL;
	CFStreamClientContext ctxt = {0, (void*)NULL, NULL, NULL, NULL};
    
	// Create the GET request
	messageRef = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("GET"), (CFURLRef)url, kCFHTTPVersion1_1);
	if ( messageRef == NULL ) goto Bail;
	
	// Create the stream for the request.
	readStreamRefB	= CFReadStreamCreateForHTTPRequest( kCFAllocatorDefault, messageRef );
	if ( readStreamRefB == NULL ) goto Bail;
	
	//	There are times when a server checks the User-Agent to match a well known browser.  This is what Safari used at the time the sample was written
	//CFHTTPMessageSetHeaderFieldValue( messageRef, CFSTR("User-Agent"), CFSTR("Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/125.5.5 (KHTML, like Gecko) Safari/125")); 
	
	// Enable stream redirection
    if (CFReadStreamSetProperty(readStreamRefB, kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanTrue) == false)
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
		
		CFReadStreamSetProperty(readStreamRefB, kCFStreamPropertySSLSettings, sslSettings);
	}
	
	// Set the client notifier
	if (CFReadStreamSetClient(readStreamRefB, kNetworkEvents, ReadStreamClientCallBackB, &ctxt) == false)
		goto Bail;
    
	// Schedule the stream
	CFReadStreamScheduleWithRunLoop(readStreamRefB, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    
	// Start the HTTP connection
	if (CFReadStreamOpen(readStreamRefB) == false)
	    goto Bail;
	
	if (messageRef != NULL) CFRelease(messageRef);
	return;
	
Bail:
	if (messageRef != NULL) CFRelease(messageRef);
	if (readStreamRefB != NULL)
    {
        CFReadStreamSetClient(readStreamRefB, kCFStreamEventNone, NULL, NULL);
	    CFReadStreamUnscheduleFromRunLoop(readStreamRefB, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	    CFReadStreamClose(readStreamRefB);
        CFRelease(readStreamRefB);
    }
	return;
}

+ (void) downloadCFNetTemp:(NSURL *)url
{
	if (!appDelegate)
	{
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		musicControls = [MusicControlsSingleton sharedInstance];
		databaseControls = [DatabaseControlsSingleton sharedInstance];
		appDelegateRef = appDelegate;
		musicControlsRef = musicControls;
		databaseControlsRef = databaseControls;
	}
	
	if (throttlingDate)
		[throttlingDate release];
	throttlingDate = nil;
	bytesTransferred = 0;
	
	isDownloadA = YES;
	
	CFHTTPMessageRef messageRef = NULL;
	//CFReadStreamRef	readStreamRef = NULL;
	CFStreamClientContext ctxt = {0, (void*)NULL, NULL, NULL, NULL};
    
	// Create the GET request
	messageRef = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("GET"), (CFURLRef)url, kCFHTTPVersion1_1);
	if ( messageRef == NULL ) goto Bail;
	
	// Add the HTTP header to resume the download
	//CFHTTPMessageSetHeaderFieldValue( messageRef, CFSTR("Range"), CFStringCreateWithFormat(NULL, NULL, CFSTR("bytes=%d-"), appDelegate.tempDownloadByteOffset)); 
	//NSLog(@"----------------- byteOffset header: %@", [NSString stringWithFormat:@"bytes=%d-", appDelegate.tempDownloadByteOffset]);
	CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("Range"), (CFStringRef)[NSString stringWithFormat:@"bytes=%d-", musicControls.tempDownloadByteOffset]);
	
	// Create the stream for the request.
	readStreamRefA	= CFReadStreamCreateForHTTPRequest( kCFAllocatorDefault, messageRef );
	if ( readStreamRefA == NULL ) goto Bail;
	
	//	There are times when a server checks the User-Agent to match a well known browser.  This is what Safari used at the time the sample was written
	//CFHTTPMessageSetHeaderFieldValue( messageRef, CFSTR("User-Agent"), CFSTR("Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/125.5.5 (KHTML, like Gecko) Safari/125")); 
	
	// Enable stream redirection
    if (CFReadStreamSetProperty(readStreamRefA, kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanTrue) == false)
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
		
		CFReadStreamSetProperty(readStreamRefA, kCFStreamPropertySSLSettings, sslSettings);
	}
	
	// Set the client notifier
	if (CFReadStreamSetClient(readStreamRefA, kNetworkEvents, ReadStreamClientCallBackTemp, &ctxt) == false)
		goto Bail;
    
	// Schedule the stream
	CFReadStreamScheduleWithRunLoop(readStreamRefA, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    
	// Start the HTTP connection
	if (CFReadStreamOpen(readStreamRefA) == false)
	    goto Bail;
	
	if (messageRef != NULL) CFRelease(messageRef);
	return;
	
Bail:
	if (messageRef != NULL) CFRelease(messageRef);
	if (readStreamRefA != NULL)
    {
        CFReadStreamSetClient(readStreamRefA, kCFStreamEventNone, NULL, NULL);
	    CFReadStreamUnscheduleFromRunLoop(readStreamRefA, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	    CFReadStreamClose(readStreamRefA);
        CFRelease(readStreamRefA);
    }
	return;
}

#pragma mark Resume
+ (void) resumeCFNetA:(UInt32)byteOffset
{
	//NSLog(@"resuming download A");
	if (!appDelegate)
	{
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		musicControls = [MusicControlsSingleton sharedInstance];
		databaseControls = [DatabaseControlsSingleton sharedInstance];
		appDelegateRef = appDelegate;
		musicControlsRef = musicControls;
		databaseControlsRef = databaseControls;
	}
	
	if (throttlingDate)
		[throttlingDate release];
	throttlingDate = [[NSDate date] retain];
	bytesTransferred = 0;
	
	isDownloadA = YES;
	
	CFHTTPMessageRef messageRef = NULL;
	//CFReadStreamRef	readStreamRef = NULL;
	CFStreamClientContext ctxt = {0, (void*)NULL, NULL, NULL, NULL};
	
	// Create the GET request
	messageRef = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("GET"), (CFURLRef)musicControls.songUrl, kCFHTTPVersion1_1);
	if ( messageRef == NULL ) goto Bail;
	
	// Add the HTTP header to resume the download
	//NSLog(@"----------------- byteOffset header: %@", [NSString stringWithFormat:@"bytes=%d-", byteOffset]);
	CFHTTPMessageSetHeaderFieldValue( messageRef, CFSTR("Range"), CFStringCreateWithFormat(NULL, NULL, CFSTR("bytes=%i-"), byteOffset)); 
	
	// Create the stream for the request.
	readStreamRefA	= CFReadStreamCreateForHTTPRequest( kCFAllocatorDefault, messageRef );
	if ( readStreamRefA == NULL ) goto Bail;
	
	//	There are times when a server checks the User-Agent to match a well known browser.  This is what Safari used at the time the sample was written
	//CFHTTPMessageSetHeaderFieldValue( messageRef, CFSTR("User-Agent"), CFSTR("Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/125.5.5 (KHTML, like Gecko) Safari/125")); 
	
	// Enable stream redirection
    if (CFReadStreamSetProperty(readStreamRefA, kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanTrue) == false)
		goto Bail;
	
	// Handle SSL connections
	if([[musicControls.songUrl absoluteString] rangeOfString:@"https"].location != NSNotFound)
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
		
		CFReadStreamSetProperty(readStreamRefA, kCFStreamPropertySSLSettings, sslSettings);
	}
	
	// Set the client notifier
	if (CFReadStreamSetClient(readStreamRefA, kNetworkEvents, ReadStreamClientCallBackA, &ctxt) == false)
		goto Bail;
    
	// Schedule the stream
	CFReadStreamScheduleWithRunLoop(readStreamRefA, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    
	// Start the HTTP connection
	if (CFReadStreamOpen(readStreamRefA) == false)
	    goto Bail;
	
	if (messageRef != NULL) CFRelease(messageRef);
	return;
	
Bail:
	if (messageRef != NULL) CFRelease(messageRef);
	if (readStreamRefA != NULL)
    {
        CFReadStreamSetClient(readStreamRefA, kCFStreamEventNone, NULL, NULL);
	    CFReadStreamUnscheduleFromRunLoop(readStreamRefA, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	    CFReadStreamClose(readStreamRefA);
        CFRelease(readStreamRefA);
    }
	return;
}

+ (void) resumeCFNetB:(UInt32)byteOffset
{
	//NSLog(@"resuming download B");
	if (!appDelegate)
	{
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		musicControls = [MusicControlsSingleton sharedInstance];
		databaseControls = [DatabaseControlsSingleton sharedInstance];
		appDelegateRef = appDelegate;
		musicControlsRef = musicControls;
		databaseControlsRef = databaseControls;
	}
	
	if (throttlingDate)
		[throttlingDate release];
	throttlingDate = [[NSDate date] retain];
	bytesTransferred = 0;
	
	isDownloadB = YES;
	
	CFHTTPMessageRef messageRef = NULL;
	//CFReadStreamRef	readStreamRef = NULL;
	CFStreamClientContext ctxt = {0, (void*)NULL, NULL, NULL, NULL};
    
	// Create the GET request
	messageRef = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("GET"), (CFURLRef)musicControls.nextSongUrl, kCFHTTPVersion1_1);
	if ( messageRef == NULL ) goto Bail;
	
	// Add the HTTP header to resume the download
	//NSLog(@"----------------- byteOffset header: %@", [NSString stringWithFormat:@"bytes=%d-", byteOffset]);
	CFHTTPMessageSetHeaderFieldValue( messageRef, CFSTR("Range"), CFStringCreateWithFormat(NULL, NULL, CFSTR("bytes=%i-"), byteOffset)); 
	
	// Create the stream for the request.
	readStreamRefB = CFReadStreamCreateForHTTPRequest( kCFAllocatorDefault, messageRef );
	if ( readStreamRefB == NULL ) goto Bail;
	
	//	There are times when a server checks the User-Agent to match a well known browser.  This is what Safari used at the time the sample was written
	//CFHTTPMessageSetHeaderFieldValue( messageRef, CFSTR("User-Agent"), CFSTR("Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/125.5.5 (KHTML, like Gecko) Safari/125")); 
	
	// Enable stream redirection
    if (CFReadStreamSetProperty(readStreamRefB, kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanTrue) == false)
		goto Bail;
	
	// Handle SSL connections
	if([[musicControls.nextSongUrl absoluteString] rangeOfString:@"https"].location != NSNotFound)
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
		
		CFReadStreamSetProperty(readStreamRefB, kCFStreamPropertySSLSettings, sslSettings);
	}
	
	// Set the client notifier
	if (CFReadStreamSetClient(readStreamRefB, kNetworkEvents, ReadStreamClientCallBackB, &ctxt) == false)
		goto Bail;
    
	// Schedule the stream
	CFReadStreamScheduleWithRunLoop(readStreamRefB, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    
	// Start the HTTP connection
	if (CFReadStreamOpen(readStreamRefB) == false)
	    goto Bail;
	
	if (messageRef != NULL) CFRelease(messageRef);
	return;
	
Bail:
	if (messageRef != NULL) CFRelease(messageRef);
	if (readStreamRefB != NULL)
    {
        CFReadStreamSetClient(readStreamRefB, kCFStreamEventNone, NULL, NULL);
	    CFReadStreamUnscheduleFromRunLoop(readStreamRefB, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	    CFReadStreamClose(readStreamRefB);
        CFRelease(readStreamRefB);
    }
	return;
}

@end
