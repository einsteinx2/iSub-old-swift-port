//
//  ISMSStreamManager.m
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSStreamManager.h"
#import "iSub-Swift.h"
#import "ISMSStreamHandler.h"
#import "RXMLElement.h"

LOG_LEVEL_ISUB_DEBUG
#define maxNumOfReconnects 5

@interface ISMSStreamManager()
@property (nullable, strong) NSMutableArray *handlerStack;
@property (nullable, strong) Song *lastCachedSong;
@property (nullable, readonly) Song *currentStreamingSong;
@end

@implementation ISMSStreamManager

- (Song *)currentStreamingSong
{
	if (!self.isDownloading)
		return nil;
	
	ISMSStreamHandler *handler = [self.handlerStack firstObjectSafe];
	return handler.song;
}

- (ISMSStreamHandler *)handlerForSong:(Song *)aSong
{
	if (!aSong)
		return nil;
	
	for (ISMSStreamHandler *handler in self.handlerStack)
	{
		if ([handler.song isEqual:aSong])
		{
			//DLog(@"handler.song: %@    aSong: %@", handler.song.title, aSong.title);
			return handler;
		}
	}
	return nil;
}

- (BOOL)isSongFirstInQueue:(Song *)aSong
{
	if (!aSong)
		return NO;
	
	ISMSStreamHandler *firstHandler = [self.handlerStack firstObjectSafe];
	return [aSong isEqual:firstHandler.song];
}

- (BOOL)isSongDownloading:(Song *)aSong
{
	if (!aSong)
		return NO;
	
	return [self handlerForSong:aSong].isDownloading;
}

- (BOOL)isDownloading
{
	for (ISMSStreamHandler *handler in self.handlerStack)
	{
		if (handler.isDownloading)
			return YES;
	}
	return NO;
}

// Main worker method
- (void)cancelAllStreamsExcept:(NSArray *)handlersToSkip
{
	// Cancel the handlers
	for (ISMSStreamHandler *handler in self.handlerStack)
	{
		if (![handlersToSkip containsObject:handler])
		{
			// If we're trying to resume, cancel the request
			[NSObject cancelPreviousPerformRequestsWithTarget:self 
													 selector:@selector(resumeHandler:)
													   object:handler];
			
			// Cancel the handler
			[handler cancel];
		}
	}
	
	[self saveHandlerStack];
}

// Convenience method
- (void)cancelAllStreamsExceptForSongs:(NSArray *)songsToSkip
{
	// If songsToSkip == nil, just cancel all handlers
	if (!songsToSkip)
	{
		[self cancelAllStreams];
		return;
	}
	
	// Gather the handler objects to cancel
	NSMutableArray *handlersToSkip = [NSMutableArray arrayWithCapacity:[songsToSkip count]];
	for (Song *aSong in songsToSkip)
	{
		ISMSStreamHandler *handler = [self handlerForSong:aSong];
		if (handler)
			[handlersToSkip addObject:[self handlerForSong:aSong]];
	}
	
	// Cancel the other handlers
	[self cancelAllStreamsExcept:handlersToSkip];
}

// Convenience method
- (void)cancelAllStreamsExceptForSong:(Song *)aSong
{
	// If aSong == nil, just cancel all handlers
	if (![self handlerForSong:aSong])
	{
		[self cancelAllStreams];
		return;
	}
	
	// Create the handler array with the one object
	NSArray *handlersToSkip = @[[self handlerForSong:aSong]];
	
	// Cancel the other handlers
	[self cancelAllStreamsExcept:handlersToSkip];
}

// Convenience method
- (void)cancelAllStreams
{
	[self cancelAllStreamsExcept:[NSArray new]];
}

// Main worker method
- (void)cancelStreamAtIndex:(NSInteger)index
{
	if (index < [self.handlerStack count])
	{
		// Find the handler object and cancel it
		ISMSStreamHandler *handler = [self.handlerStack objectAtIndexSafe:index];
		
		[handler cancel];
		
		// If we're trying to resume, cancel the request
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
												 selector:@selector(resumeHandler:)
												   object:handler];
	}
	
	[self saveHandlerStack];
}

// Convenience method
- (void)cancelStream:(ISMSStreamHandler *)handler
{
	// If handler == nil, do nothing
	if (!handler)
		return;
	
	// Get the handler index
	NSInteger index = [self.handlerStack indexOfObject:handler];
	
	// Cancel the handler
	[self cancelStreamAtIndex:index];
}

// Convenience method
- (void)cancelStreamForSong:(Song *)aSong
{
	// If aSong == nil, do nothing
	if (!aSong)
		return;
	
	// Cancel the handler
	[self cancelStream:[self handlerForSong:aSong]];
}

// Main worker method
- (void)removeAllStreamsExcept:(NSArray *)handlersToSkip
{
	// Remove the handlers
	NSArray *handlers = [NSArray arrayWithArray:self.handlerStack];
	for (ISMSStreamHandler *handler in handlers)
	{
		if (![handlersToSkip containsObject:handler])
		{
            [self cancelStream:handler];
            [self.handlerStack removeObject:handler];
            
            if (!handler.song.isFullyCached && !handler.song.isTempCached && !([CacheQueueManager.si.currentSong isEqual:handler.song] && CacheQueueManager.si.isDownloading))
            {
                DLog(@"Removing song from cached songs table: %@", handler.song);
                [handler.song deleteCache];
                //[[Playlist downloadedSongs] removeSongWithSong:handler.song notify:YES];
            }
		}
	}
	
	// Start the next handler
	if ([self.handlerStack count] > 0)
	{
		// Get the first handler
		ISMSStreamHandler *handler = [self.handlerStack firstObject];
		
		// If it's not already downloading, start downloading
		if (!handler.isDownloading)
		{
			[handler start];
		}
	}
	
	[self saveHandlerStack];
}

// Convenience method
- (void)removeAllStreamsExceptForSongs:(NSArray *)songsToSkip
{
	// If songsToSkip == nil, remove all handlers
	if (!songsToSkip)
	{
		[self removeAllStreams];
		return;
	}
	
	// Gather the handler objects to skip
	NSMutableArray *handlersToSkip = [NSMutableArray arrayWithCapacity:[songsToSkip count]];
	for (Song *aSong in songsToSkip)
	{
		ISMSStreamHandler *handler = [self handlerForSong:aSong];
		if (handler) 
			[handlersToSkip addObject:[self handlerForSong:aSong]];
	}
	
	// Remove the other handlers
	[self removeAllStreamsExcept:handlersToSkip];
}

// Convenience method
- (void)removeAllStreamsExceptForSong:(Song *)aSong
{
	// If aSong == nil, remove all handlers
	if (![self handlerForSong:aSong])
	{
		[self removeAllStreams];
		return;
	}
	
	// Get the handler to skip
	NSArray *handlersToSkip = @[[self handlerForSong:aSong]];
	
	// Remove the other handlers
	[self removeAllStreamsExcept:handlersToSkip];
}

// Convenience method
- (void)removeAllStreams
{
	[self cancelAllStreams];
	[self removeAllStreamsExcept:[NSArray new]];
}

// Main worker method
- (void)removeStreamAtIndex:(NSInteger)index
{
	if (index < [self.handlerStack count])
	{
		[self cancelStreamAtIndex:index];
		
		ISMSStreamHandler *handler = [self.handlerStack objectAtIndex:index];
		if (!handler.song.isFullyCached && !handler.song.isTempCached && !([CacheQueueManager.si.currentSong isEqual:handler.song] && CacheQueueManager.si.isDownloading))
        {
            DLog(@"Removing song from cached songs table: %@", handler.song);
            [handler.song deleteCache];
            //[[Playlist downloadedSongs] removeSongWithSong:handler.song notify:YES];
        }
        [self.handlerStack removeObjectAtIndexSafe:index];
        
        [self saveHandlerStack];
	}
}

// Convenience method
- (void)removeStream:(ISMSStreamHandler *)handler
{
	// If handler == nil, do nothing
	if (!handler)
		return;
	
	// Remove the handler
	[self removeStreamAtIndex:[self.handlerStack indexOfObject:handler]];
}

// Convenience method
- (void)removeStreamForSong:(Song *)aSong
{
	// If aSong == nil, do nothing
	if (!aSong)
		return;
	
	// Remove the handler
	[self removeStream:[self handlerForSong:aSong]];
}

- (void)resumeQueue
{
	[self resumeHandler:[self.handlerStack firstObjectSafe]];
}

- (void)resumeHandler:(ISMSStreamHandler *)handler
{
	if (!handler)
		return; 
	
	// As an added check, verify that this handler is still in the stack
	if ([self isSongInQueue:handler.song])
	{
		if (CacheQueueManager.si.isDownloading && [CacheQueueManager.si.currentSong isEqual:handler.song])
		{
			// This song is already being downloaded by the cache queue, so just start the player
			[self ISMSStreamHandlerStartPlayback:handler];
			
			// Remove the handler from the stack
			[self removeStream:handler];
			
			// Start the next handler which is now the first object
			if ([self.handlerStack count] > 0)
			{
				ISMSStreamHandler *handler = [self.handlerStack firstObjectSafe];
				[self startHandler:handler];
			}
		}
		else
		{
			[handler start:YES];
		}
	}
}

- (void)startHandler:(ISMSStreamHandler *)handler resume:(BOOL)resume
{
	if (!handler)
		return;
	
	if (CacheQueueManager.si.isDownloading && [CacheQueueManager.si.currentSong isEqual:handler.song])
	{
		// This song is already being downloaded by the cache queue, so just start the player
		[self ISMSStreamHandlerStartPlayback:handler];
		
		// Remove the handler from the stack
		[self removeStream:handler];
		
		// Start the next handler which is now the first object
		if ([self.handlerStack count] > 0)
		{
			ISMSStreamHandler *handler = [self.handlerStack firstObjectSafe];
			[self startHandler:handler];
		}
	}
	else
	{
		[handler start:resume];
	}
}

- (void)startHandler:(ISMSStreamHandler *)handler
{
	if (!handler)
		return;
	
	DDLogVerbose(@"[ISMSStreamManager] starting handler, handlerStack: %@", self.handlerStack);
	
	[self startHandler:handler resume:NO];
}

- (void)saveHandlerStack
{
    // TODO: Rewrite this
//	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.handlerStack];
//	if (data)
//	{
//		[[NSUserDefaults standardUserDefaults] setObject:data forKey:@"handlerStack"];
//		[[NSUserDefaults standardUserDefaults] synchronize];
//	}
}

- (void)loadHandlerStack
{
    // TODO: Rewrite this
//	NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"handlerStack"];
//	if (data) 
//		self.handlerStack = [NSKeyedUnarchiver unarchiveObjectWithData:data];
//
//	for (ISMSStreamHandler *handler in self.handlerStack)
//	{
//		handler.delegate = self;
//	}
//	
//	DDLogVerbose(@"[ISMSStreamManager] load handler stack, handlerStack: %@", self.handlerStack);

}

#pragma mark - Handler Stealing

// Hand of handler to cache queue
- (void)stealHandlerForCacheQueue:(ISMSStreamHandler *)handler
{
	DDLogInfo(@"[ISMSStreamManager] cache queue manager stole handler for: %@", handler.song.title);
	[self.handlerStack removeObject:handler];
	[self saveHandlerStack];
	[self fillStreamQueue];
}

#pragma mark Download

- (void)queueStreamForSong:(Song *)song byteOffset:(unsigned long long)byteOffset atIndex:(NSInteger)index isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload
{
	if (!song)
		return;
	
	ISMSStreamHandler *handler = [[URLSessionStreamHandler alloc] initWithSong:song byteOffset:byteOffset isTemp:isTemp delegate:self];
	if (![self.handlerStack containsObject:handler])
	{
		[self.handlerStack insertObject:handler atIndex:index];
		
		if ([self.handlerStack count] == 1 && isStartDownload)
		{
			[self startHandler:handler];
		}
		
		// Preheat cover art
		if (song.coverArtId)
		{
            // TODO: Reimplement this using CachedImage
//			ISMSCoverArtLoader *playerArt = [[ISMSCoverArtLoader alloc] initWithDelegate:self coverArtId:song.coverArtId isLarge:YES];
//			[playerArt downloadArtIfNotExists];
//			//if (![playerArt downloadArtIfNotExists])
//			//	;
//			
//			ISMSCoverArtLoader *tableArt = [[ISMSCoverArtLoader alloc] initWithDelegate:self coverArtId:song.coverArtId isLarge:NO];
//			[tableArt downloadArtIfNotExists];
//			//if (![tableArt downloadArtIfNotExists])
//			//	;
		}
	}
	
	[self saveHandlerStack];
}

- (BOOL)isSongInQueue:(Song *)aSong
{
	BOOL isSongInQueue = NO;
	for (ISMSStreamHandler *handler in self.handlerStack)
	{
		if ([handler.song isEqual:aSong])
		{
			isSongInQueue = YES;
			break;
		}
	}
	return isSongInQueue;
}

- (void)fillStreamQueue:(BOOL)isStartDownload {
	NSInteger numStreamsToQueue = 1;
	if (SavedSettings.si.isSongCachingEnabled && SavedSettings.si.isNextSongCacheEnabled) {
		numStreamsToQueue = ISMSNumberOfStreamsToQueue;
	}
    
    for (int i = 0; i < numStreamsToQueue; i++) {
        Song *aSong = [PlayQueue.si songAtIndex:[PlayQueue.si indexAtOffsetFromCurrentIndex:i]];
        
        // Check if the song is already in this position in the queue
        ISMSStreamHandler *handler = [self.handlerStack objectAtIndexSafe: i];
        if (![aSong isEqual:handler.song]) {
            
            // Song didn't match, so remove whatever is in the queue from this position forward
            for (int j = i; j < numStreamsToQueue; j++) {
                [self removeStreamAtIndex:j];
            }
            
            // Add song to stream queue
            if (aSong && aSong.basicContentTypeObjC == 1 &&
                ![self isSongInQueue:aSong] &&
                ![self.lastTempCachedSong isEqual:aSong] &&
                !aSong.isFullyCached &&
                !SavedSettings.si.isOfflineMode &&
                ![CacheQueueManager.si.currentSong isEqual:aSong]) {
                
                // Queue the song for download
                [self queueStreamForSong:aSong byteOffset:0 atIndex:[self.handlerStack count] isTempCache:!SavedSettings.si.isSongCachingEnabled isStartDownload:isStartDownload];
            }
        }
    }
    
    DDLogVerbose(@"[ISMSStreamManager] fill stream queue, handlerStack: %@", self.handlerStack);
}

- (void)fillStreamQueue
{
	[self fillStreamQueue:YES];
}

- (void)songCachingToggled
{
	if (SavedSettings.si.isSongCachingEnabled)
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(fillStreamQueue) 
													 name:ISMSNotification_SongPlaybackEnded 
												   object:nil];
	else
		[[NSNotificationCenter defaultCenter] removeObserver:self 
														name:ISMSNotification_SongPlaybackEnded 
													  object:nil];
}

- (void)currentPlaylistIndexChanged
{
	// TODO: Fix this logic, it's wrong
	// Verify that the last song is not constantly retrying to connect, 
	// so the current song can download and play
	[self removeStreamForSong:PlayQueue.si.previousSong];
}

- (void)currentPlaylistOrderChanged
{
	Song *currentSong = PlayQueue.si.currentSong;
	Song *nextSong = PlayQueue.si.nextSong;
	NSMutableArray *songsToSkip = [NSMutableArray arrayWithCapacity:2];
	if (currentSong) [songsToSkip addObject:currentSong];
	if (nextSong) [songsToSkip addObject:nextSong];
	
	[self removeAllStreamsExceptForSongs:songsToSkip];
	[self fillStreamQueue:PlayQueue.si.isStarted];
}

#pragma mark - ISMSStreamHandler delegate

- (void)ISMSStreamHandlerStarted:(ISMSStreamHandler *)handler
{
	if (handler.isTempCache)
		self.lastTempCachedSong = nil;
}

- (void)ISMSStreamHandlerStartPlayback:(ISMSStreamHandler *)handler
{	
	// Update the last cached song
	self.lastCachedSong = handler.song;
    
    Song *currentSong = PlayQueue.si.currentSong;
	if ([handler.song isEqual:currentSong])
	{
        // TODO: Stop interacting directly with AudioEngine
		[AudioEngine.si startSong:currentSong index:PlayQueue.si.currentIndex];
		
		// Only for temp cached files
		if (handler.isTempCache)
		{
			// TODO: get rid of this ugly hack
			[EX2Dispatch timerInMainQueueAfterDelay:1.0 withName:@"temp song set byteOffset/seconds" repeats:NO performBlock:^
             {
                 AudioEngine.si.player.startByteOffset = handler.byteOffset;
             }];
		}
	}
	
	[self saveHandlerStack];
}

- (void)ISMSStreamHandlerConnectionFailed:(ISMSStreamHandler *)handler withError:(NSError *)error
{
	//DLog(@"stream handler failed: %@", handler);
	if (handler.numOfReconnects < maxNumOfReconnects)
	{
		//DLog(@"retrying stream handler");
		// Less than max number of reconnections, so try again 
		handler.numOfReconnects++;
		// Retry connection after a delay to prevent a tight loop
		[self performSelector:@selector(resumeHandler:) withObject:handler afterDelay:1.5];
		//[self startHandler:handler resume:YES];
	}
	else
	{
		//DLog(@"removing stream handler");
		//DLog(@"handlerStack: %@", self.handlerStack);
		// Tried max number of times so remove
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_StreamHandlerSongFailed];
		[self removeStream:handler];
	}
}

- (void)ISMSStreamHandlerConnectionFinished:(ISMSStreamHandler *)handler
{	
	BOOL isSuccess = YES;

	if (handler.totalBytesTransferred == 0)
	{
		// Not a trial issue, but no data was returned at all
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Uh oh!" message:@"We asked for a song, but the server didn't send anything!\n\nIt's likely that Subsonic's transcoding failed.\n\nIf you need help, please tap the Support button on the Home tab." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [AppDelegate.si.sidePanelController presentViewController:alert animated:true completion:nil];

		[[NSFileManager defaultManager] removeItemAtPath:handler.filePath error:NULL];
		isSuccess = NO;
	}
	else if (handler.totalBytesTransferred < 1000)
	{
		BOOL isLicenseIssue = NO;
		// Verify that it's a license issue
		NSData *receivedData = [NSData dataWithContentsOfFile:handler.filePath];
        RXMLElement *root = [[RXMLElement alloc] initFromXMLData:receivedData];
        if (root.isValid) {
            RXMLElement *error = [root child:@"error"];
            if (error.isValid) {
                NSString *code = [error attribute:@"code"];
                if ([code isEqualToString:@"60"]) {
                    isLicenseIssue = YES;
                }
            }
        }
		
		if (isLicenseIssue)
		{
			// This is a trial period message, alert the user and stop streaming
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Subsonic API Trial Expired" message:@"You can purchase a license for Subsonic by logging in to the web interface and clicking the red Donate link on the top right.\n\nPlease remember, iSub is a 3rd party client for Subsonic, and this license and trial is for Subsonic and not iSub.\n\nIf you didn't know about the Subsonic license requirement, and do not wish to purchase it, please tap the Support button on the Home tab and contact iSub support for a refund." preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [AppDelegate.si.sidePanelController presentViewController:alert animated:true completion:nil];

			[[NSFileManager defaultManager] removeItemAtPath:handler.filePath error:NULL];
			isSuccess = NO;
		}	
	}
	
	if (isSuccess)
	{
		//DLog(@"finished downloading song: %@", handler.song.title);
		
		// Mark song as cached
		if (!handler.isTempCache)
        {
            if ([CacheQueueManager.si containsWithSong:handler.song])
            {
                //handler.song.isDownloaded = YES;
                [[Playlist downloadQueue] removeWithSong:handler.song notify:YES];
            }
            
            DLog(@"Marking isFullyCached = YES for %@", handler.song);
			handler.song.isFullyCached = YES;
		}
		
		// Update the last cached song
		self.lastCachedSong = handler.song;
		
		if (handler.isTempCache)
			self.lastTempCachedSong = handler.song;
		
		// Remove the handler from the stack
		[self removeStream:handler];
		
		// Start the next handler which is now the first object
		if ([self.handlerStack count] > 0)
		{
			ISMSStreamHandler *handler = [self.handlerStack firstObjectSafe];
			[self startHandler:handler];
		}
		
		// Keep the queue filled
		[self fillStreamQueue];
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@(handler.song.songId) forKey:@"songId"];
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_StreamHandlerSongDownloaded 
													  userInfo:userInfo];
	}
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
//DLog(@"received memory warning");
	
}

#pragma mark - Singleton methods

- (void)delayedSetup
{
	for (ISMSStreamHandler *handler in self.handlerStack)
	{
		// Resume any handlers that were downloading when iSub closed
		if (handler.isDownloading && !handler.isTempCache)
		{
			DDLogVerbose(@"[ISMSStreamManager] resuming starting handler");
			[handler start:YES];
		}
	}
}

- (void)setup
{
	// Load the handler stack, it may have been full when iSub was closed
	[self loadHandlerStack];
	self.handlerStack = self.handlerStack ? self.handlerStack : [[NSMutableArray alloc] initWithCapacity:0];
	if ([self.handlerStack count] > 0)
	{
		if ([(ISMSStreamHandler *)[self.handlerStack firstObject] isTempCache])
		{
			[self removeAllStreams];
		}
		else
		{
			for (ISMSStreamHandler *handler in self.handlerStack)
			{
				// Resume any handlers that were downloading when iSub closed
				if (handler.isDownloading && !handler.isTempCache)
				{
					[handler start:YES];
				}
			}
		}
	}
	
	self.lastCachedSong = nil;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(songCachingToggled) name:ISMSNotification_SongCachingEnabled object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(songCachingToggled) name:ISMSNotification_SongCachingDisabled object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentPlaylistIndexChanged) name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	
	if (SavedSettings.si.isSongCachingEnabled)
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fillStreamQueue) name:ISMSNotification_SongPlaybackEnded object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentPlaylistOrderChanged) name:ISMSNotification_RepeatModeChanged object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentPlaylistOrderChanged) name:ISMSNotification_CurrentPlaylistOrderChanged object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentPlaylistOrderChanged) name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	
#ifdef IOS
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
}

+ (instancetype)si
{
    static ISMSStreamManager *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}


@end
