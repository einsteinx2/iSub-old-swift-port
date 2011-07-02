//
//  NSURLConnectionDelegateQueue.m
//  iSub
//
//  Created by bbaron on 11/12/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "NSURLConnectionDelegateQueue.h"
#import "iSubAppDelegate.h"
#import "MusicControlsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "Song.h"
#import "NSString-md5.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSURLConnectionDelegateQueueArtwork.h"
#import "CustomUIAlertView.h"

@implementation NSURLConnectionDelegateQueue

- (id) init
{
	self = [super init];
	if (self != nil)
	{
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		musicControls = [MusicControlsSingleton sharedInstance];
		databaseControls = [DatabaseControlsSingleton sharedInstance];
	}	
	return self;
}

- (BOOL) insertSong:(Song *)aSong intoGenreTable:(NSString *)table
{
	[databaseControls.songCacheDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (md5, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", table], [NSString md5:aSong.path], aSong.title, aSong.songId, aSong.artist, aSong.album, aSong.genre, aSong.coverArtId, aSong.path, aSong.suffix, aSong.transcodedSuffix, aSong.duration, aSong.bitRate, aSong.track, aSong.year, aSong.size];
	
	if ([databaseControls.songCacheDb hadError]) {
		DLog(@"Err inserting song into genre table %d: %@", [databaseControls.songCacheDb lastErrorCode], [databaseControls.songCacheDb lastErrorMessage]);
	}
	
	return [databaseControls.songCacheDb hadError];
}

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
	[musicControls.audioFileQueue truncateFileAtOffset:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    // Append the data chunk to the file and update the downloaded length
	[musicControls.audioFileQueue writeData:incrementalData];	
	musicControls.downloadedLengthQueue += [incrementalData length];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	DLog(@"didFailWithError, resuming download");
	[musicControls resumeDownloadQueue:musicControls.downloadedLengthQueue];
	
	// Had to comment this out to fix an EXC_BAD_ACCESS crash, 
	// don't have any idea why this is necessary and isn't causing leaks
	// The NSURLConnection seemingly isn't being released anywhere, but yet it is
	//[theConnection release];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	//DLog(@"connectionDidFinishLoading");
	
	// Check if the file is less than 500 bytes. If it is, then it's almost definitely an API expiration notice
	if (musicControls.downloadedLengthQueue < 500)
	{
		// Show an alert and delete the file
		UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Notice" message:@"No song data returned. This could be because your Subsonic API trial has expired, this song is not an mp3 and the Subsonic transcoding plugins failed, or another reason." delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil] autorelease];
		[alert performSelector:@selector(show) onThread:[NSThread mainThread] withObject:nil waitUntilDone:NO];
		[[NSFileManager defaultManager] removeItemAtPath:musicControls.downloadFileNameQueue error:NULL];
		musicControls.isQueueListDownloading = NO;
	}
	else
	{
		// Update the cache time
		[databaseControls.songCacheDb executeUpdate:[NSString stringWithFormat:@"UPDATE cacheQueue SET cachedDate = %i WHERE md5 = ?", (NSUInteger)[[NSDate date] timeIntervalSince1970]], musicControls.downloadFileNameHashQueue];
		
		// Move the row from the cacheQueue to the cachedSongs table
		[databaseControls.songCacheDb executeUpdate:@"UPDATE cacheQueue SET finished = 'YES' WHERE md5 = ?", musicControls.downloadFileNameHashQueue];
		[databaseControls.songCacheDb executeUpdate:@"INSERT INTO cachedSongs SELECT * FROM cacheQueue WHERE md5 = ?", musicControls.downloadFileNameHashQueue];
		NSArray *splitPath = [musicControls.queueSongObject.path componentsSeparatedByString:@"/"];
		if ([splitPath count] <= 9)
		{
			NSMutableArray *segments = [[NSMutableArray alloc] initWithArray:splitPath];
			while ([segments count] < 9)
			{
				[segments addObject:@""];
			}
			
			NSString *query = [NSString stringWithFormat:@"INSERT INTO cachedSongsLayout (md5, genre, segs, seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8, seg9) VALUES ('%@', '%@', %i, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [NSString md5:musicControls.queueSongObject.path], musicControls.queueSongObject.genre, [splitPath count]];
			[databaseControls.songCacheDb executeUpdate:query, [segments objectAtIndex:0], [segments objectAtIndex:1], [segments objectAtIndex:2], [segments objectAtIndex:3], [segments objectAtIndex:4], [segments objectAtIndex:5], [segments objectAtIndex:6], [segments objectAtIndex:7], [segments objectAtIndex:8]];
			
			[segments release];
		}
		[databaseControls.songCacheDb executeUpdate:@"DELETE FROM cacheQueue WHERE md5 = ?", musicControls.downloadFileNameHashQueue];
		
		// Setup the genre table entries
		if (musicControls.queueSongObject.genre)
		{
			// Check if the genre has a table in the database yet, if not create it and add the new genre to the genres table
			if ([databaseControls.songCacheDb intForQuery:@"SELECT COUNT(*) FROM genres WHERE genre = ?", musicControls.queueSongObject.genre] == 0)
			{							
				[databaseControls.songCacheDb executeUpdate:@"INSERT INTO genres (genre) VALUES (?)", musicControls.queueSongObject.genre];
				if ([databaseControls.songCacheDb hadError]) { DLog(@"Err adding the genre %d: %@", [databaseControls.songCacheDb lastErrorCode], [databaseControls.songCacheDb lastErrorMessage]); }
			}
			
			// Insert the song object into the appropriate genresSongs table
			[self insertSong:musicControls.queueSongObject intoGenreTable:@"genresSongs"];
		}
		
		// Cache the album art if it exists
		if (musicControls.queueSongObject.coverArtId)
		{
			if ([databaseControls.coverArtCacheDb320 intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [NSString md5:musicControls.queueSongObject.coverArtId]] == 0)
			{
				//DLog(@"320 artwork doesn't exist, caching");
				NSString *imgUrlString;
				if (appDelegate.isHighRez)
				{
					imgUrlString = [NSString stringWithFormat:@"%@%@&size=640", [appDelegate getBaseUrl:@"getCoverArt.view"], musicControls.queueSongObject.coverArtId];
				}
				else 
				{
					imgUrlString = [NSString stringWithFormat:@"%@%@&size=320", [appDelegate getBaseUrl:@"getCoverArt.view"], musicControls.queueSongObject.coverArtId];
				}
				NSURLConnectionDelegateQueueArtwork *delegate = [[NSURLConnectionDelegateQueueArtwork alloc] init];
				NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:imgUrlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kLoadingTimeout];
				NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
				if (connection)
				{
					delegate.receivedData = [NSMutableData data];
				} 
				[delegate release];
			}
			if ([databaseControls.coverArtCacheDb60 intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [NSString md5:musicControls.queueSongObject.coverArtId]] == 0)
			{
				//DLog(@"60 artwork doesn't exist, caching");
				NSString *imgUrlString;
				if (appDelegate.isHighRez)
				{
					imgUrlString = [NSString stringWithFormat:@"%@%@&size=120", [appDelegate getBaseUrl:@"getCoverArt.view"], musicControls.queueSongObject.coverArtId];
				}
				else 
				{
					imgUrlString = [NSString stringWithFormat:@"%@%@&size=60", [appDelegate getBaseUrl:@"getCoverArt.view"], musicControls.queueSongObject.coverArtId];
				}
				NSURLConnectionDelegateQueueArtwork *delegate = [[NSURLConnectionDelegateQueueArtwork alloc] init];
				delegate.is320 = NO;
				NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:imgUrlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kLoadingTimeout];
				NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
				if (connection)
				{
					delegate.receivedData = [NSMutableData data];
				} 
				[delegate release];
			}
		}
		
		// Close the file
		[musicControls.audioFileQueue closeFile];
		
		// Tell the cache queue view to reload
		[[NSNotificationCenter defaultCenter] postNotificationName:@"queuedSongDone" object:nil];
		
		// Download the next song in the queue
		[musicControls downloadNextQueuedSong];
	}	
	
	// Had to comment this out to fix an EXC_BAD_ACCESS crash, 
	// don't have any idea why this is necessary and isn't causing leaks
	// The NSURLConnection seemingly isn't being released anywhere, but yet it is
	//[theConnection release];
}


@end
