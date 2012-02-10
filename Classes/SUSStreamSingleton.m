//
//  SUSStreamSingleton.m
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSStreamSingleton.h"
#import "DatabaseSingleton.h"
#import "FMDatabase.h"
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
#import "FMDatabase+Synchronized.h"

#define maxNumOfReconnects 3

static SUSStreamSingleton *sharedInstance = nil;

@implementation SUSStreamSingleton
@synthesize handlerStack, lyricsDAO, currentPlaylistDAO, lastCachedSong, lastTempCachedSong;

- (SUSStreamHandler *)handlerForSong:(Song *)aSong
{
	for (SUSStreamHandler *handler in handlerStack)
	{
		if ([handler.mySong isEqualToSong:aSong])
		{
			return handler;
		}
	}
	return nil;
}

- (void)cancelAllStreamsExcept:(NSArray *)handlersToSkip
{
	for (SUSStreamHandler *handler in handlerStack)
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
	if (index < [handlerStack count])
	{
		// Find the handler object and cancel it
		SUSStreamHandler *handler = [handlerStack objectAtIndex:index];
		[handler cancel];
		
		// If we're trying to resume, cancel the request
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
												 selector:@selector(resumeHandler:)
												   object:handler];
	}
}

- (void)cancelStream:(SUSStreamHandler *)handler
{
	NSUInteger index = [handlerStack indexOfObject:handler];
	[self cancelStreamAtIndex:index];
}

- (void)cancelStreamForSong:(Song *)aSong
{
	[self cancelStream:[self handlerForSong:aSong]];
}

- (void)removeAllStreamsExcept:(NSArray *)handlersToSkip//(SUSStreamHandler *)handlerToSkip
{
	[self cancelAllStreamsExcept:handlersToSkip];
	NSArray *handlers = [NSArray arrayWithArray:handlerStack];
	for (SUSStreamHandler *handler in handlers)
	{
		if (![handlersToSkip containsObject:handler])
			[handlerStack removeObject:handler];
	}
}

- (void)removeAllStreamsExceptForSongs:(NSArray *)songsToSkip
{
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
	NSArray *handlersToSkip = [NSArray arrayWithObject:[self handlerForSong:aSong]];
	[self removeAllStreamsExcept:handlersToSkip];
}

- (void)removeAllStreams
{
	[self cancelAllStreams];
	[handlerStack removeAllObjects];
}

- (void)removeStreamAtIndex:(NSUInteger)index
{
    DLog(@"handlerStack count: %i", [handlerStack count]);
	if (index < [handlerStack count])
	{
		[self cancelStreamAtIndex:index];
		[handlerStack removeObjectAtIndex:index];
	}
    DLog(@"removed stream, new handlerStack count: %i", [handlerStack count]);
}

- (void)removeStream:(SUSStreamHandler *)handler
{
	[self cancelStream:handler];
	[handlerStack removeObject:handler];
}

- (void)removeStreamForSong:(Song *)aSong
{
	[self removeStream:[self handlerForSong:aSong]];
}

- (void)resumeHandler:(SUSStreamHandler *)handler
{
	// As an added check, verify that this handler is still in the stack
	if ([self isSongInQueue:handler.mySong])
	{
		[handler start:YES];
	}
}

- (void)startHandler:(SUSStreamHandler *)handler resume:(BOOL)resume
{
	[handler start:resume];
	[lyricsDAO loadLyricsForArtist:handler.mySong.artist andTitle:handler.mySong.title];
}

- (void)startHandler:(SUSStreamHandler *)handler
{
	[self startHandler:handler resume:NO];
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
	if (![handlerStack containsObject:handler])
	{
		[handlerStack insertObject:handler atIndex:index];
		[handler release];
		
		if ([handlerStack count] == 1)
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
}

- (void)queueStreamForSong:(Song *)song atIndex:(NSUInteger)index isTempCache:(BOOL)isTemp
{	
	[self queueStreamForSong:song byteOffset:0 secondsOffset:0.0 atIndex:index isTempCache:isTemp];
}

- (void)queueStreamForSong:(Song *)song byteOffset:(unsigned long long)byteOffset secondsOffset:(double)secondsOffset isTempCache:(BOOL)isTemp
{
	[self queueStreamForSong:song byteOffset:byteOffset secondsOffset:secondsOffset atIndex:[handlerStack count] isTempCache:isTemp];
}

- (void)queueStreamForSong:(Song *)song isTempCache:(BOOL)isTemp
{	
	[self queueStreamForSong:song byteOffset:0 secondsOffset:0.0 atIndex:[handlerStack count] isTempCache:isTemp];
}

- (BOOL)isSongInQueue:(Song *)aSong
{
	BOOL isSongInQueue = NO;
	for (SUSStreamHandler *handler in handlerStack)
	{
		if ([handler.mySong isEqualToSong:aSong])
		{
			isSongInQueue = YES;
			break;
		}
	}
	return isSongInQueue;
}

/*- (void)queueStreamForNextSong
{
	Song *nextSong = currentPlaylistDAO.nextSong;

	// The file doesn't exist or it's not fully cached, start downloading it from the beginning
	if (nextSong && ![self isSongInQueue:nextSong] && !nextSong.isFullyCached && 
		![ViewObjectsSingleton sharedInstance].isOfflineMode)
	{
		[self queueStreamForSong:nextSong isTempCache:NO];
	}
}*/

- (void)fillStreamQueue
{
	NSUInteger numStreamsToQueue = 1;
	if ([SavedSettings sharedInstance].isNextSongCacheEnabled)
	{
		numStreamsToQueue = ISMSNumberOfStreamsToQueue;
	}
	
	if ([handlerStack count] < numStreamsToQueue)
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
		if ([handlerStack count] > 0)
		{
			if (![[handlerStack objectAtIndex:0] isEqualToSong:nextSong])
			{
				if ([handlerStack count] > 1)
				{
					if (![[handlerStack objectAtIndex:1] isEqualToSong:nextSong])
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
	if (handler.isTempCache)
		self.lastTempCachedSong = nil;
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
		[audio start];
		audio.startByteOffset = bytes;
		audio.startSecondsOffset = seconds;
	}
	else if ([handler.mySong isEqualToSong:nextSong])
	{
		[audio prepareNextSongStream];
	}
}

- (void)SUSStreamHandlerConnectionFailed:(SUSStreamHandler *)handler withError:(NSError *)error
{
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
		DLog(@"handlerStack: %@", handlerStack);
		// Tried max number of times so remove
		[handlerStack removeObject:handler];
	}
}

- (void)SUSStreamHandlerConnectionFinished:(SUSStreamHandler *)handler
{	
	// Update the last cached song
	self.lastCachedSong = handler.mySong;
	
	if (handler.isTempCache)
		self.lastTempCachedSong = handler.mySong;
	DLog(@"handler.isTempCache: %@   lastTempCachedSong: %@", NSStringFromBOOL(handler.isTempCache), self.lastTempCachedSong);
	
	// Remove the handler from the stack
	[handlerStack removeObject:handler];
	
	DLog(@"stream handler finished: %@", handler);
	DLog(@"handlerStack: %@", handlerStack);
	
	// Start the next handler which is now the first object
	if ([handlerStack count] > 0)
	{
		DLog(@"starting first handler in stack");
		SUSStreamHandler *handler = (SUSStreamHandler *)[handlerStack firstObject];
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
	lastCachedSong = nil;
    handlerStack = [[NSMutableArray alloc] initWithCapacity:0];
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
