//
//  SUSStreamSingleton.m
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSStreamSingleton.h"
#import "DatabaseSingleton.h"
#import "FMDatabaseAdditions.h"
#import "Song.h"
#import "NSString+md5.h"
#import "NSMutableURLRequest+SUS.h"
#import "SavedSettings.h"
#import "NSString+URLEncode.h"
#import "MusicSingleton.h"
#import "SUSStreamHandler.h"
#import "PlaylistSingleton.h"
#import "NSArray+FirstObject.h"
#import "AudioEngine.h"
#import "SUSCoverArtLargeDAO.h"
#import "SUSCoverArtLargeLoader.h"
#import "SUSLyricsDAO.h"
#import "ViewObjectsSingleton.h"
#import "NSArray+Additions.h"

#define maxNumOfReconnects 3

static SUSStreamSingleton *sharedInstance = nil;

@implementation SUSStreamSingleton
@synthesize handlerStack, lyricsDAO, currentPlaylistDAO, lastCachedSong, lastTempCachedSong;

- (SUSStreamHandler *)handlerForSong:(Song *)aSong
{
	if (!aSong)
		return nil;
	
	for (SUSStreamHandler *handler in self.handlerStack)
	{
		if ([handler.mySong isEqualToSong:aSong])
		{
			return handler;
		}
	}
	return nil;
}

- (BOOL)isSongFirstInQueue:(Song *)aSong
{
	if (!aSong)
		return NO;
	
	SUSStreamHandler *firstHandler = [self.handlerStack firstObjectSafe];
	return [aSong isEqualToSong:firstHandler.mySong];
}

- (BOOL)isSongDownloading:(Song *)aSong
{
	if (!aSong)
		return NO;
	
	return [self handlerForSong:aSong].isDownloading;
}

- (BOOL)isQueueDownloading
{
	for (SUSStreamHandler *handler in self.handlerStack)
	{
		if (handler.isDownloading)
			return YES;
	}
	return NO;
}

- (void)cancelAllStreamsExcept:(NSArray *)handlersToSkip
{
	if (!handlersToSkip)
		return;
	
	for (SUSStreamHandler *handler in self.handlerStack)
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
}

- (void)cancelAllStreamsExceptForSongs:(NSArray *)songsToSkip
{
	if (!songsToSkip)
		return;
	
	NSMutableArray *handlersToSkip = [NSMutableArray arrayWithCapacity:[songsToSkip count]];
	for (Song *aSong in songsToSkip)
	{
		SUSStreamHandler *handler = [self handlerForSong:aSong];
		if (handler)
			[handlersToSkip addObject:[self handlerForSong:aSong]];
	}
	[self cancelAllStreamsExcept:handlersToSkip];
}


- (void)cancelAllStreamsExceptForSong:(Song *)aSong
{
	if (![self handlerForSong:aSong])
		return;
	
	// Cancel any song resume requests
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	NSArray *handlersToSkip = [NSArray arrayWithObject:[self handlerForSong:aSong]];
	[self cancelAllStreamsExcept:handlersToSkip];
}

- (void)cancelAllStreams
{
	[self cancelAllStreamsExcept:nil];
}

- (void)cancelStreamAtIndex:(NSUInteger)index
{
	if (index < [self.handlerStack count])
	{
		// Find the handler object and cancel it
		SUSStreamHandler *handler = [self.handlerStack objectAtIndexSafe:index];
		[handler cancel];
		
		// If we're trying to resume, cancel the request
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
												 selector:@selector(resumeHandler:)
												   object:handler];
	}
}

- (void)cancelStream:(SUSStreamHandler *)handler
{
	if (!handler)
		return;
	
	NSUInteger index = [self.handlerStack indexOfObject:handler];
	[self cancelStreamAtIndex:index];
}

- (void)cancelStreamForSong:(Song *)aSong
{
	if (!aSong)
		return;
	
	[self cancelStream:[self handlerForSong:aSong]];
}

- (void)removeAllStreamsExcept:(NSArray *)handlersToSkip
{
	if (!handlersToSkip)
		return;
	
	[self cancelAllStreamsExcept:handlersToSkip];
	NSArray *handlers = [NSArray arrayWithArray:self.handlerStack];
	for (SUSStreamHandler *handler in handlers)
	{
		if (![handlersToSkip containsObject:handler])
			[self.handlerStack removeObject:handler];
	}
	
	if ([self.handlerStack count] > 0)
	{
		SUSStreamHandler *handler = [self.handlerStack firstObject];
		if (!handler.isDownloading)
		{
			[handler start];
		}
	}
}

- (void)removeAllStreamsExceptForSongs:(NSArray *)songsToSkip
{
	if (!songsToSkip)
		return;
	
	NSMutableArray *handlersToSkip = [NSMutableArray arrayWithCapacity:[songsToSkip count]];
	for (Song *aSong in songsToSkip)
	{
		SUSStreamHandler *handler = [self handlerForSong:aSong];
		if (handler) 
			[handlersToSkip addObject:[self handlerForSong:aSong]];
	}
	[self removeAllStreamsExcept:handlersToSkip];
}

- (void)removeAllStreamsExceptForSong:(Song *)aSong
{
	if (![self handlerForSong:aSong])
		return;
	
	NSArray *handlersToSkip = [NSArray arrayWithObject:[self handlerForSong:aSong]];
	[self removeAllStreamsExcept:handlersToSkip];
}

- (void)removeAllStreams
{
	[self cancelAllStreams];
	[self.handlerStack removeAllObjects];
	[self saveHandlerStack];
}

- (void)removeStreamAtIndex:(NSUInteger)index
{
    DLog(@"handlerStack count: %i", [self.handlerStack count]);
	if (index < [self.handlerStack count])
	{
		[self cancelStreamAtIndex:index];
		[self.handlerStack removeObjectAtIndex:index];
	}
    DLog(@"removed stream, new handlerStack count: %i", [self.handlerStack count]);
}

- (void)removeStream:(SUSStreamHandler *)handler
{
	if (!handler)
		return;
	
	[self cancelStream:handler];
	[self.handlerStack removeObject:handler];
		
	[self saveHandlerStack];
}

- (void)removeStreamForSong:(Song *)aSong
{
	if (!aSong)
		return;
	
	[self removeStream:[self handlerForSong:aSong]];
}

- (void)resumeQueue
{
	[self resumeHandler:[self.handlerStack firstObjectSafe]];
}

- (void)resumeHandler:(SUSStreamHandler *)handler
{
	if (!handler)
		return; 
	
	// As an added check, verify that this handler is still in the stack
	if ([self isSongInQueue:handler.mySong])
	{
		[handler start:YES];
	}
}

- (void)startHandler:(SUSStreamHandler *)handler resume:(BOOL)resume
{
	if (!handler)
		return;
	
	[handler start:resume];
	[lyricsDAO loadLyricsForArtist:handler.mySong.artist andTitle:handler.mySong.title];
}

- (void)startHandler:(SUSStreamHandler *)handler
{
	if (!handler)
		return;
	
	[self startHandler:handler resume:NO];
}

- (void)saveHandlerStack
{
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.handlerStack];
	if (data)
	{
		[[NSUserDefaults standardUserDefaults] setObject:data forKey:@"handlerStack"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}

- (void)loadHandlerStack
{	
	NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"handlerStack"];
	if (data) 
		self.handlerStack = [NSKeyedUnarchiver unarchiveObjectWithData:data];

	for (SUSStreamHandler *handler in self.handlerStack)
	{
		handler.delegate = self;
	}
}

#pragma mark Download

- (void)queueStreamForSong:(Song *)song byteOffset:(unsigned long long)byteOffset secondsOffset:(double)secondsOffset atIndex:(NSUInteger)index isTempCache:(BOOL)isTemp
{
	if (!song)
		return;
	
	SUSStreamHandler *handler = [[SUSStreamHandler alloc] initWithSong:song 
															byteOffset:byteOffset
														 secondsOffset:secondsOffset
																isTemp:isTemp
															  delegate:self];
	if (![self.handlerStack containsObject:handler])
	{
		[self.handlerStack insertObject:handler atIndex:index];
		[handler release];
		
		if ([self.handlerStack count] == 1)
		{
			[self startHandler:handler];
		}
		
		// Also download the album art
		if (song.coverArtId)
		{
			SUSCoverArtLargeDAO *artDataModel = [SUSCoverArtLargeDAO dataModel];
			if (![artDataModel coverArtExistsForId:song.coverArtId])
			{
				DLog(@"Cover art doesn't exist, loading for id: %@", song.coverArtId);
				SUSCoverArtLargeLoader *loader = [[SUSCoverArtLargeLoader alloc] initWithDelegate:self];
				[loader loadCoverArtId:song.coverArtId];
			}
		}
	}
	
	[self saveHandlerStack];
}

- (void)queueStreamForSong:(Song *)song atIndex:(NSUInteger)index isTempCache:(BOOL)isTemp
{	
	[self queueStreamForSong:song byteOffset:0 secondsOffset:0.0 atIndex:index isTempCache:isTemp];
}

- (void)queueStreamForSong:(Song *)song byteOffset:(unsigned long long)byteOffset secondsOffset:(double)secondsOffset isTempCache:(BOOL)isTemp
{
	[self queueStreamForSong:song byteOffset:byteOffset secondsOffset:secondsOffset atIndex:[self.handlerStack count] isTempCache:isTemp];
}

- (void)queueStreamForSong:(Song *)song isTempCache:(BOOL)isTemp
{	
	[self queueStreamForSong:song byteOffset:0 secondsOffset:0.0 atIndex:[self.handlerStack count] isTempCache:isTemp];
}

- (BOOL)isSongInQueue:(Song *)aSong
{
	BOOL isSongInQueue = NO;
	for (SUSStreamHandler *handler in self.handlerStack)
	{
		if ([handler.mySong isEqualToSong:aSong])
		{
			isSongInQueue = YES;
			break;
		}
	}
	return isSongInQueue;
}

- (void)fillStreamQueue
{
	NSUInteger numStreamsToQueue = 1;
	if ([SavedSettings sharedInstance].isNextSongCacheEnabled)
	{
		numStreamsToQueue = ISMSNumberOfStreamsToQueue;
	}
	
	if ([self.handlerStack count] < numStreamsToQueue)
	{
		NSInteger currentIndex = currentPlaylistDAO.currentIndex;
		for (int i = currentIndex; i < currentIndex + numStreamsToQueue; i++)
		{
			Song *aSong = [currentPlaylistDAO songForIndex:i];
			if (aSong && ![self isSongInQueue:aSong] && !aSong.isFullyCached
				&& ![ViewObjectsSingleton sharedInstance].isOfflineMode)
			{
				SavedSettings *settings = [SavedSettings sharedInstance];
				[self queueStreamForSong:aSong isTempCache:!settings.isSongCachingEnabled];
			}
		}
	}
}

- (void)songCachingToggled
{
	if ([SavedSettings sharedInstance].isSongCachingEnabled)
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
	[self removeStreamForSong:currentPlaylistDAO.prevSong];
}

- (void)currentPlaylistOrderChanged
{
	// First check to see if the upcoming song is being cached now or next
	/*BOOL fillQueue = NO;
	Song *nextSong = currentPlaylistDAO.nextSong;
	if ([self isSongInQueue:nextSong])
	{
		if ([self.handlerStack count] > 0)
		{
			if (![[self.handlerStack objectAtIndexSafe:0] isEqualToSong:nextSong])
			{
				if ([self.handlerStack count] > 1)
				{
					if (![[self.handlerStack objectAtIndexSafe:1] isEqualToSong:nextSong])
					{
						fillQueue = YES;
					}
				}
			}
		}
	}
	
	if (fillQueue)
	{
		[self removeAllStreamsExceptForSong:currentPlaylistDAO.currentSong];
		[self fillStreamQueue];
	}*/
	
	Song *currentSong = currentPlaylistDAO.currentSong;
	Song *nextSong = currentPlaylistDAO.nextSong;
	NSMutableArray *songsToSkip = [NSMutableArray arrayWithCapacity:2];
	if (currentSong) [songsToSkip addObject:currentSong];
	if (nextSong) [songsToSkip addObject:nextSong];
	
	[self removeAllStreamsExceptForSongs:songsToSkip];
	[self fillStreamQueue];
}

#pragma mark - SUSStreamHandler delegate

- (void)SUSStreamHandlerStarted:(SUSStreamHandler *)handler
{
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	if (handler.isTempCache)
		self.lastTempCachedSong = nil;
}

- (void)SUSStreamHandlerPartialPrecachePaused:(SUSStreamHandler *)handler
{
	if (![MusicSingleton sharedInstance].isQueueListDownloading)
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)SUSStreamHandlerPartialPrecacheUnpaused:(SUSStreamHandler *)handler
{
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)SUSStreamHandlerStartPlayback:(SUSStreamHandler *)handler byteOffset:(unsigned long long)bytes secondsOffset:(double)seconds
{	
	// Update the last cached song
	self.lastCachedSong = handler.mySong;
	
	Song *currentSong = currentPlaylistDAO.currentSong;
	Song *nextSong = currentPlaylistDAO.nextSong;
	AudioEngine *audio = [AudioEngine sharedInstance];
	
	DLog(@"currentSong: %@   mySong: %@", currentSong, handler.mySong);
	if ([handler.mySong isEqualToSong:currentSong])
	{
		//[audio startWithOffsetInBytes:[NSNumber numberWithUnsignedLongLong:bytes] orSeconds:[NSNumber numberWithDouble:seconds]];
		DLog(@"calling audio start");
		[audio start];
		DLog(@"audio start called");
		audio.startByteOffset = bytes;
		audio.startSecondsOffset = seconds;
		DLog(@"set byte and second offset");
	}
	else if ([handler.mySong isEqualToSong:nextSong])
	{
		[audio prepareNextSongStream];
	}
	
	[self saveHandlerStack];
}

- (void)SUSStreamHandlerConnectionFailed:(SUSStreamHandler *)handler withError:(NSError *)error
{
	if (![MusicSingleton sharedInstance].isQueueListDownloading)
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	DLog(@"stream handler failed: %@", handler);
	if (handler.numOfReconnects < maxNumOfReconnects)
	{
		DLog(@"retrying stream handler");
		// Less than max number of reconnections, so try again 
		handler.numOfReconnects++;
		// Retry connection after a delay to prevent a tight loop
		[self performSelector:@selector(resumeHandler:) withObject:handler afterDelay:1.5];
		//[self startHandler:handler resume:YES];
	}
	else
	{
		DLog(@"removing stream handler");
		DLog(@"handlerStack: %@", self.handlerStack);
		// Tried max number of times so remove
		[self removeStream:handler];
	}
}

- (void)SUSStreamHandlerConnectionFinished:(SUSStreamHandler *)handler
{	
	if (![MusicSingleton sharedInstance].isQueueListDownloading)
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	
	// Update the last cached song
	self.lastCachedSong = handler.mySong;
	
	DLog(@"stream handler finished: %@", handler);
	
	if (handler.isTempCache)
		self.lastTempCachedSong = handler.mySong;
	DLog(@"handler.isTempCache: %@   lastTempCachedSong: %@", NSStringFromBOOL(handler.isTempCache), self.lastTempCachedSong);

	// Remove the handler from the stack
	DLog(@"handlerStack: %@  about to remove the stream", self.handlerStack);
	[self removeStream:handler];
	
	DLog(@"handlerStack: %@", self.handlerStack);
	
	// Start the next handler which is now the first object
	if ([self.handlerStack count] > 0)
	{
		DLog(@"starting first handler in stack");
		SUSStreamHandler *handler = (SUSStreamHandler *)[self.handlerStack firstObjectSafe];
		[self startHandler:handler];
	}
}

#pragma mark - SUSLoader handler

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error
{
	theLoader.delegate = nil;
    [theLoader release];
}

- (void)loadingFinished:(SUSLoader *)theLoader
{
	theLoader.delegate = nil;
    [theLoader release];
}

#pragma mark - Singleton methods

- (void)setup
{
	// Load the handler stack, it may have been full when iSub was closed
	[self loadHandlerStack];
	handlerStack = handlerStack ? handlerStack : [[NSMutableArray alloc] initWithCapacity:0];
	if ([handlerStack count] > 0)
	{
		for (SUSStreamHandler *handler in handlerStack)
		{
			// Resume any handlers that were downloading when iSub closed
			if (handler.isDownloading)
				[handler start:YES];
		}
	}
	
	lastCachedSong = nil;
	lyricsDAO = [[SUSLyricsDAO alloc] initWithDelegate:self]; 
	currentPlaylistDAO = [PlaylistSingleton sharedInstance];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(songCachingToggled) 
												 name:ISMSNotification_SongCachingEnabled object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(songCachingToggled) 
												 name:ISMSNotification_SongCachingDisabled object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(currentPlaylistIndexChanged) 
												 name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	
	if ([SavedSettings sharedInstance].isSongCachingEnabled)
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(fillStreamQueue) 
													 name:ISMSNotification_SongPlaybackEnded object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(currentPlaylistOrderChanged) 
												 name:ISMSNotification_RepeatModeChanged object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(currentPlaylistOrderChanged) 
												 name:ISMSNotification_CurrentPlaylistOrderChanged object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(currentPlaylistOrderChanged) 
												 name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
}

+ (SUSStreamSingleton *)sharedInstance
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
