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
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "SUSLyricsLoader.h"
#import "NSString+Additions.h"
#import "SUSCoverArtLoader.h"
#import "ViewObjectsSingleton.h"
#import "iSubAppDelegate.h"
#import "ISMSStreamManager.h"
#import "NSNotificationCenter+MainThread.h"
#import "CacheSingleton.h"

@implementation ISMSCacheQueueManager
@synthesize isQueueDownloading, currentQueuedSong;
@synthesize fileHandle, downloadLength, connection;

#pragma mark - Lyric Loader Delegate

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error
{
	//DLog(@"theLoader: %@", theLoader);
	theLoader.delegate = nil;
    [theLoader release];
}

- (void)loadingFinished:(SUSLoader *)theLoader
{
	//DLog(@"theLoader: %@", theLoader);
	theLoader.delegate = nil;
    [theLoader release];
}

#pragma mark Download Methods

- (Song *)currentQueuedSongInDb
{
	Song *aSong = nil;
	FMResultSet *result = [databaseS.cacheQueueDb executeQuery:@"SELECT * FROM cacheQueue WHERE finished = 'NO' LIMIT 1"];
	if ([databaseS.cacheQueueDb hadError]) 
	{
		DLog(@"Err %d: %@", [databaseS.cacheQueueDb lastErrorCode], [databaseS.cacheQueueDb lastErrorMessage]);
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
	
	// Check if the song is fully cached, if it is remove it from the queue and return
	Song *currentSong = playlistS.currentSong;
	Song *nextSong = playlistS.nextSong;
	if (self.currentQueuedSong.isFullyCached
		|| [currentSong isEqualToSong:self.currentQueuedSong]
		|| [nextSong isEqualToSong:self.currentQueuedSong])
	{
		// The song is fully cached, so delete it from the cache queue database
		[self.currentQueuedSong removeFromCacheQueue];
		
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
				
	// Create new file on disk
	[self.currentQueuedSong removeFromCachedSongsTable];
	[[NSFileManager defaultManager] removeItemAtPath:self.currentQueuedSong.localPath error:NULL];
	[[NSFileManager defaultManager] createFileAtPath:self.currentQueuedSong.localPath contents:[NSData data] attributes:nil];
	
	// Start the download
	NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObject:n2N(self.currentQueuedSong.songId) forKey:@"id"];
	if (settingsS.currentMaxBitrate != 0)
	{
		NSString *bitrate = [[NSString alloc] initWithFormat:@"%i", settingsS.currentMaxBitrate];
		[parameters setObject:n2N(bitrate) forKey:@"maxBitRate"];
		[bitrate release];
	}
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"stream" andParameters:parameters];
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		self.downloadLength = 0;
		self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.currentQueuedSong.localPath];

		[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
		
		[self.currentQueuedSong insertIntoCachedSongsTable];
		
		if (self.currentQueuedSong.coverArtId)
		{
			NSString *coverArtId = self.currentQueuedSong.coverArtId;
			SUSCoverArtLoader *playerArt = [[SUSCoverArtLoader alloc] initWithDelegate:self 
																			coverArtId:coverArtId
																			   isLarge:YES];
			if (![playerArt downloadArtIfNotExists])
				[playerArt release];
			
			SUSCoverArtLoader *tableArt = [[SUSCoverArtLoader alloc] initWithDelegate:self
																		   coverArtId:coverArtId 
																			  isLarge:NO];
			if (![tableArt downloadArtIfNotExists])
				[tableArt release];
		}
	}
}

- (void)resumeDownloadQueue:(NSNumber *)byteOffset
{
	// Create the request and resume the download
	if (!viewObjectsS.isOfflineMode)
	{
        NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(self.currentQueuedSong.songId) forKey:@"id"];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"stream" andParameters:parameters];
        
		NSString *range = [NSString stringWithFormat:@"bytes=%i-", [byteOffset unsignedIntValue]];
		[request setValue:range forHTTPHeaderField:@"Range"];
		self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
		if (self.connection)
		{
			[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
		}
	}
}

- (void)stopDownloadQueue
{
	DLog(@"stopping download queue");
	self.isQueueDownloading = NO;
	
	[self.connection cancel];
	DLog(@"self.connection: %@", self.connection);
	self.connection = nil;
	self.fileHandle = nil;
	[[NSFileManager defaultManager] removeItemAtPath:self.currentQueuedSong.localPath error:NULL];
	
	if (!streamManagerS.isQueueDownloading) 
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

#pragma mark - NSURLConnectionDelegate

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
	if (!streamManagerS.isQueueDownloading) 
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	
	// Check if the file is less than 500 bytes. If it is, then it's almost definitely an API expiration notice
	if (self.downloadLength < 500)
	{
		// Show an alert and delete the file
		UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Notice" message:@"No song data returned. This could be because your Subsonic API trial has expired, this song is not an mp3 and the Subsonic transcoding plugins failed, or another reason." delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil] autorelease];
		alert.tag = 4;
		[alert show];
		[alert release];
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
	
	self.connection = nil;
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
	DLog(@"received memory warning");
	
	
}

#pragma mark - Singleton methods

static ISMSCacheQueueManager *sharedInstance = nil;

- (void)setup
{
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(didReceiveMemoryWarning) 
												 name:UIApplicationDidReceiveMemoryWarningNotification 
											   object:nil];
}

+ (ISMSCacheQueueManager *)sharedInstance
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

- (id)retain 
{
    return self;
}

- (unsigned)retainCount 
{
    return UINT_MAX;  // denotes an object that cannot be released
}

- (oneway void)release 
{
    //do nothing
}

- (id)autorelease 
{
    return self;
}

@end
