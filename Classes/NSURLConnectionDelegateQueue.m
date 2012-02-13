//
//  NSURLConnectionDelegateQueue.m
//  iSub
//
//  Created by bbaron on 11/12/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "NSURLConnectionDelegateQueue.h"
#import "iSubAppDelegate.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "Song.h"
#import "NSString+md5.h"
#import "FMDatabaseAdditions.h"
#import "NSURLConnectionDelegateQueueArtwork.h"
#import "CustomUIAlertView.h"
#import "NSMutableURLRequest+SUS.h"


@implementation NSURLConnectionDelegateQueue

- (id)init
{
	self = [super init];
	if (self != nil)
	{
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		musicControls = [MusicSingleton sharedInstance];
		databaseControls = [DatabaseSingleton sharedInstance];
	}	
	return self;
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
		alert.tag = 4;
		[alert performSelector:@selector(show) onThread:[NSThread mainThread] withObject:nil waitUntilDone:NO];
		[[NSFileManager defaultManager] removeItemAtPath:musicControls.downloadFileNameQueue error:NULL];
		musicControls.isQueueListDownloading = NO;
	}
	else
	{
		// Update the cache time
		[databaseControls.songCacheDb synchronizedExecuteUpdate:[NSString stringWithFormat:@"UPDATE cacheQueue SET cachedDate = %i WHERE md5 = ?", (NSUInteger)[[NSDate date] timeIntervalSince1970]], musicControls.downloadFileNameHashQueue];
		
		// Move the row from the cacheQueue to the cachedSongs table
		[databaseControls.songCacheDb synchronizedExecuteUpdate:@"UPDATE cacheQueue SET finished = 'YES' WHERE md5 = ?", musicControls.downloadFileNameHashQueue];
		[databaseControls.songCacheDb synchronizedExecuteUpdate:@"REPLACE INTO cachedSongs SELECT * FROM cacheQueue WHERE md5 = ?", musicControls.downloadFileNameHashQueue];
		NSArray *splitPath = [musicControls.queueSongObject.path componentsSeparatedByString:@"/"];
		if ([splitPath count] <= 9)
		{
			NSMutableArray *segments = [[NSMutableArray alloc] initWithArray:splitPath];
			while ([segments count] < 9)
			{
				[segments addObject:@""];
			}
			
			NSString *query = [NSString stringWithFormat:@"REPLACE INTO cachedSongsLayout (md5, genre, segs, seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8, seg9) VALUES ('%@', '%@', %i, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [musicControls.queueSongObject.path md5], musicControls.queueSongObject.genre, [splitPath count]];
			[databaseControls.songCacheDb synchronizedExecuteUpdate:query, [segments objectAtIndex:0], [segments objectAtIndex:1], [segments objectAtIndex:2], [segments objectAtIndex:3], [segments objectAtIndex:4], [segments objectAtIndex:5], [segments objectAtIndex:6], [segments objectAtIndex:7], [segments objectAtIndex:8]];
			
			[segments release];
		}
		[databaseControls.songCacheDb synchronizedExecuteUpdate:@"DELETE FROM cacheQueue WHERE md5 = ?", musicControls.downloadFileNameHashQueue];
		
		// Setup the genre table entries
		if (musicControls.queueSongObject.genre)
		{
			// Check if the genre has a table in the database yet, if not create it and add the new genre to the genres table
			if ([databaseControls.songCacheDb synchronizedIntForQuery:@"SELECT COUNT(*) FROM genres WHERE genre = ?", musicControls.queueSongObject.genre] == 0)
			{							
				[databaseControls.songCacheDb synchronizedExecuteUpdate:@"INSERT INTO genres (genre) VALUES (?)", musicControls.queueSongObject.genre];
				if ([databaseControls.songCacheDb hadError]) { DLog(@"Err adding the genre %d: %@", [databaseControls.songCacheDb lastErrorCode], [databaseControls.songCacheDb lastErrorMessage]); }
			}
			
			// Insert the song object into the appropriate genresSongs table
			[musicControls.queueSongObject insertIntoGenreTable:@"genresSongs"];
		}
		
		// Cache the album art if it exists
		if (musicControls.queueSongObject.coverArtId)
		{
            NSString *size = nil;
            NSString *artId = [[musicControls.queueSongObject.coverArtId copy] autorelease];
            
			NSURLConnectionDelegateQueueArtwork *delegate = [[NSURLConnectionDelegateQueueArtwork alloc] init];
			if ([databaseControls.coverArtCacheDb320 synchronizedIntForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", 
                 [musicControls.queueSongObject.coverArtId md5]] == 0)
			{
				if (SCREEN_SCALE() == 2.0)
				{
                    size = @"640";
				}
				else 
				{
                    size = @"320";
				}
			}
			if ([databaseControls.coverArtCacheDb60 synchronizedIntForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", 
                 [musicControls.queueSongObject.coverArtId md5]] == 0)
			{
				if (SCREEN_SCALE() == 2.0)
				{
                    size = @"120";
				}
				else 
				{
                    size = @"60";
				}
				delegate.is320 = NO;
            }
            
			if (size)
			{
				NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:n2N(size), @"size", n2N(artId), @"id", nil];
				NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getCoverArt" andParameters:parameters];
				
				NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
				if (connection)
				{
					delegate.receivedData = [NSMutableData data];
				}
			}
			
            [delegate release];
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
