//
//  ISMSCacheQueueManager.m
//  iSub
//
//  Created by Ben Baron on 2/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "ISMSCacheQueueManager.h"
#import "Song.h"
#import "Song+DAO.h"
#import "SUSLoader.h"
#import "DatabaseSingleton.h"
#import "PlaylistSingleton.h"
#import "SavedSettings.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueueAdditions.h"
#import "SUSLyricsLoader.h"
#import "SUSCoverArtLoader.h"
#import "ViewObjectsSingleton.h"
#import "iSubAppDelegate.h"
#import "ISMSStreamManager.h"
#import "NSNotificationCenter+MainThread.h"
#import "CacheSingleton.h"
#import "ISMSStreamHandler.h"

#define maxNumOfReconnects 5

@implementation ISMSCacheQueueManager
@synthesize isQueueDownloading, currentQueuedSong, currentStreamHandler;
//@synthesize fileHandle, downloadLength, connection, contentLength, numberOfContentLengthFailures;

#pragma mark - Lyric Loader Delegate

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error
{
	//DLog(@"theLoader: %@", theLoader);
	theLoader.delegate = nil;
}

- (void)loadingFinished:(SUSLoader *)theLoader
{
	//DLog(@"theLoader: %@", theLoader);
	theLoader.delegate = nil;
}

#pragma mark Download Methods

- (Song *)currentQueuedSongInDb
{
	__block Song *aSong = nil;
	[databaseS.cacheQueueDbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:@"SELECT * FROM cacheQueue WHERE finished = 'NO' LIMIT 1"];
		if ([db hadError]) 
		{
			DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
		}
		else
		{
			aSong = [Song songFromDbResult:result];
		}
		
		[result close];
	}];
	return aSong;
}

// Start downloading the file specified in the text field.
- (void)startDownloadQueue
{
	// Are we already downloading?  If so, stop it.
	[self stopDownloadQueue];
	
	// For simplicity sake, just make sure we never go under 50 MB and let the cache check process take care of the rest
	if (cacheS.freeSpace <= BytesToMB(25))
		return;
	
	DLog(@"starting download queue");
	
	// Check if there's another queued song and that were are on Wifi
	self.currentQueuedSong = self.currentQueuedSongInDb;
	if (!self.currentQueuedSong || (!appDelegateS.isWifi && !IS_3G_UNRESTRICTED) || viewObjectsS.isOfflineMode)
		return;
	
	// Check if the song is fully cached or if it's the current or next song in the regular stream queue
	// if it is remove it from the queue and return
	if (self.currentQueuedSong.isFullyCached
		|| [self.currentQueuedSong isEqualToSong:playlistS.currentSong]
		|| [self.currentQueuedSong isEqualToSong:playlistS.nextSong])
	{
		// The song is fully cached, so delete it from the cache queue database
		[self.currentQueuedSong removeFromCacheQueueDbQueue];
		
		// Continue the queue
		[self startDownloadQueue];
		return;
	}
	
	self.isQueueDownloading = YES;
	
	// Grab the lyrics
	if (self.currentQueuedSong.artist && self.currentQueuedSong.title && settingsS.isLyricsEnabled)
	{
        SUSLyricsLoader *lyricsLoader = [[SUSLyricsLoader alloc] initWithDelegate:self];
		//DLog(@"lyricsLoader: %@", lyricsLoader);
        lyricsLoader.artist = self.currentQueuedSong.artist;
        lyricsLoader.title = self.currentQueuedSong.title;
        [lyricsLoader startLoad];        
	}
	
	// Download the art
	if (self.currentQueuedSong.coverArtId)
	{
		NSString *coverArtId = self.currentQueuedSong.coverArtId;
		SUSCoverArtLoader *playerArt = [[SUSCoverArtLoader alloc] initWithDelegate:self 
																		coverArtId:coverArtId
																		   isLarge:YES];
		[playerArt downloadArtIfNotExists];
		
		SUSCoverArtLoader *tableArt = [[SUSCoverArtLoader alloc] initWithDelegate:self
																	   coverArtId:coverArtId 
																		  isLarge:NO];
		[tableArt downloadArtIfNotExists];
	}
	
	// Create the stream handler
	self.currentStreamHandler = [[ISMSStreamHandler alloc] initWithSong:self.currentQueuedSong isTemp:NO delegate:self];
	self.currentStreamHandler.partialPrecacheSleep = NO;
	[self.currentStreamHandler start];
}

- (void)resumeDownloadQueue:(NSNumber *)byteOffset
{
	// Create the request and resume the download
	if (!viewObjectsS.isOfflineMode)
	{
		[self.currentStreamHandler start:YES];
	}
}

- (void)stopDownloadQueue
{
	DLog(@"stopping download queue");
	self.isQueueDownloading = NO;
	
	[self.currentStreamHandler cancel];
	self.currentStreamHandler = nil;
}

- (void)removeCurrentSong
{
	if (self.isQueueDownloading)
		[self stopDownloadQueue];
	
	[self.currentQueuedSong removeFromCacheQueueDbQueue];
	
	if (!self.isQueueDownloading)
		[self startDownloadQueue];
}

#pragma mark - ISMSStreamHandler Delegate

- (void)ISMSStreamHandlerPartialPrecachePaused:(ISMSStreamHandler *)handler
{
	// Don't ever partial pre-cache
	handler.partialPrecacheSleep = NO;
}

- (void)ISMSStreamHandlerConnectionFailed:(ISMSStreamHandler *)handler withError:(NSError *)error
{
	if (handler.numOfReconnects < maxNumOfReconnects)
	{
		// Less than max number of reconnections, so try again 
		handler.numOfReconnects++;
		// Retry connection after a delay to prevent a tight loop
		[self performSelector:@selector(resumeDownloadQueue:) withObject:nil afterDelay:2.0];
	}
	else
	{
		// Tried max number of times so remove
		[self.currentQueuedSong removeFromCacheQueueDbQueue];
		self.currentStreamHandler = nil;
		[self startDownloadQueue];
	}
}

- (void)ISMSStreamHandlerConnectionFinished:(ISMSStreamHandler *)handler
{
	if (handler.totalBytesTransferred < 500)
	{
		// Show an alert and delete the file, this was not a song but an XML error
		// TODO: Parse with TBXML and display proper error
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"No song data returned. This could be because your Subsonic API trial has expired, this song is not an mp3 and the Subsonic transcoding plugins failed, or another reason." delegate:appDelegateS cancelButtonTitle:@"OK" otherButtonTitles: nil];
		[alert show];
		[[NSFileManager defaultManager] removeItemAtPath:handler.filePath error:NULL];
	}
	else
	{		
		// Mark song as cached
		self.currentQueuedSong.isFullyCached = YES;
		[self.currentQueuedSong removeFromCacheQueueDbQueue];
		self.currentQueuedSong = nil;
		
		// Remove the stream handler
		self.currentStreamHandler = nil;
		
		// Tell the cache queue view to reload
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CacheQueueSongDownloaded];
		
		// Download the next song in the queue
		[self startDownloadQueue];
	}
}


/*#pragma mark - NSURLConnectionDelegate

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

- (void)connection:(NSURLConnection *)theConnection didReceiveResponse:(NSURLResponse *)response
{
	if ([response isKindOfClass:[NSHTTPURLResponse class]])
	{
		NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
		DLog(@"allHeaderFields: %@", [httpResponse allHeaderFields]);
		DLog(@"statusCode: %i - %@", [httpResponse statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[httpResponse statusCode]]);
		
		if ([httpResponse statusCode] >= 500)
		{
			// This is a failure, cancel the connection and call the didFail delegate method
			[self.connection cancel];
			[self connection:self.connection didFailWithError:nil];
		}
		else
		{
			if (self.contentLength == ULLONG_MAX)
			{
				// Set the content length if it isn't set already, only set the first connection, not on retries
				NSString *contentLengthString = [[httpResponse allHeaderFields] objectForKey:@"Content-Length"];
				if (contentLengthString)
				{
					NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
					self.contentLength = [[formatter numberFromString:contentLengthString] unsignedLongLongValue];
				}
			}
		}
	}
	
	[self.fileHandle truncateFileAtOffset:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{	
	// For simplicity sake, just make sure we never go under 50 MB and let the cache check process take care of the rest
	if (cacheS.freeSpace <= BytesToMB(25))
	{
		[self stopDownloadQueue];
		return;
	}
	
	// Save the data to the file
	@try
	{
		[self.fileHandle writeData:incrementalData];
		self.downloadLength += [incrementalData length];
	}
	@catch (NSException *exception) 
	{
		DLog(@"Failed to write to file %@, %@ - %@", self.currentQueuedSong, exception.name, exception.description);
		[self stopDownloadQueue];
	}
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	//DLog(@"didFailWithError, resuming download");
	[self performSelector:@selector(resumeDownloadQueue:)
			   withObject:[NSNumber numberWithUnsignedInt:self.downloadLength] 
			   afterDelay:2.0];
	//[self resumeDownloadQueue:self.downloadLength];
	
	if (!streamManagerS.isQueueDownloading)
	{
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	}
	self.connection = nil;
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	DLog(@"theConnection: %@", theConnection);
	DLog(@"queue download finished: %@", self.currentQueuedSong.title);
	
	// Check to see if we're within 100K of the contentLength (to allow some leeway for contentLength estimation of transcoded songs
	if (self.contentLength != ULLONG_MAX && currentQueuedSong.localFileSize < self.contentLength - BytesToKB(100) && self.numberOfContentLengthFailures < ISMSMaxContentLengthFailures)
	{
		self.numberOfContentLengthFailures++;
		[self connection:self.connection didFailWithError:nil];
	}
	else
	{
		if (!streamManagerS.isQueueDownloading) 
			[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
		
		// Check if the file is less than 500 bytes. If it is, then it's almost definitely an API expiration notice
		if (self.downloadLength < 500)
		{
			// Show an alert and delete the file
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Notice" message:@"No song data returned. This could be because your Subsonic API trial has expired, this song is not an mp3 and the Subsonic transcoding plugins failed, or another reason." delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
			alert.tag = 4;
			[alert show];
			[[NSFileManager defaultManager] removeItemAtPath:self.currentQueuedSong.localPath error:NULL];
			self.isQueueDownloading = NO;
		}
		else
		{
			self.currentQueuedSong.isFullyCached = YES;
			[self.currentQueuedSong removeFromCacheQueue];
			self.currentQueuedSong = nil;
			
			// Close the file
			[self.fileHandle closeFile];
			self.fileHandle = nil;
			
			// Tell the cache queue view to reload
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CacheQueueSongDownloaded];
			
			// Download the next song in the queue
			[self startDownloadQueue];
		}
	}
	
	self.connection = nil;
}*/

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
	DLog(@"received memory warning");
	
	
}

#pragma mark - Singleton methods

- (void)setup
{
	//self.contentLength = ULLONG_MAX;
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(didReceiveMemoryWarning) 
												 name:UIApplicationDidReceiveMemoryWarningNotification 
											   object:nil];
}

+ (id)sharedInstance
{
    static ISMSCacheQueueManager *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
