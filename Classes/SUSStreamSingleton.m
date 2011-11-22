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
#import "NSString-md5.h"
#import "NSMutableURLRequest+SUS.h"
#import "SavedSettings.h"
#import "NSString+URLEncode.h"
#import "MusicSingleton.h"
#import "SUSStreamHandler.h"
#import "SUSCurrentPlaylistDAO.h"
#import "NSArray+FirstObject.h"
#import "BassWrapperSingleton.h"

#define maxNumOfReconnects 3

static SUSStreamSingleton *sharedInstance = nil;

@implementation SUSStreamSingleton
@synthesize handlerStack;

- (BOOL)insertSong:(Song *)aSong intoGenreTable:(NSString *)table
{
    DatabaseSingleton *databaseControls = [DatabaseSingleton sharedInstance];
    
	[databaseControls.songCacheDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (md5, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", table], [aSong.path md5], aSong.title, aSong.songId, aSong.artist, aSong.album, aSong.genre, aSong.coverArtId, aSong.path, aSong.suffix, aSong.transcodedSuffix, aSong.duration, aSong.bitRate, aSong.track, aSong.year, aSong.size];
	
	if ([databaseControls.songCacheDb hadError]) {
		DLog(@"Err inserting song into genre table %d: %@", [databaseControls.songCacheDb lastErrorCode], [databaseControls.songCacheDb lastErrorMessage]);
	}
	
	return [databaseControls.songCacheDb hadError];
}

- (void)cancelAllStreams
{
	for (SUSStreamHandler *handler in handlerStack)
	{
		[handler cancel];
	}
}

- (void)cancelStreamAtIndex:(NSUInteger)index
{
	if (index < [handlerStack count])
	{
		SUSStreamHandler *handler = [handlerStack objectAtIndex:index];
		[handler cancel];
	}
}

- (void)cancelStream:(SUSStreamHandler *)handler
{
	NSUInteger index = [handlerStack indexOfObject:handler];
	[self cancelStreamAtIndex:index];
}

- (void)removeAllStreams
{
	[self cancelAllStreams];
	[handlerStack removeAllObjects];
}

- (void)removeStreamAtIndex:(NSUInteger)index
{
    DLog(@"handlerStack count: %i", [handlerStack count]);
	[self cancelStreamAtIndex:index];
	[handlerStack removeObjectAtIndex:index];
    DLog(@"removed stream, new handlerStack count: %i", [handlerStack count]);
}

- (void)removeStream:(SUSStreamHandler *)handler
{
	[self cancelStream:handler];
	[handlerStack removeObject:handler];
}

#pragma mark Download

- (void)queueStreamForSong:(Song *)song offset:(NSUInteger)byteOffset atIndex:(NSUInteger)index
{
	SUSStreamHandler *handler = [[SUSStreamHandler alloc] initWithSong:song offset:byteOffset delegate:self];
	[handlerStack insertObject:handler atIndex:index];
	[handler release];
	
	if ([handlerStack count] == 1)
	{
		[handler start];
	}
}

- (void)queueStreamForSong:(Song *)song atIndex:(NSUInteger)index
{	
	[self queueStreamForSong:song offset:0 atIndex:index];
}

- (void)queueStreamForSong:(Song *)song
{	
	[self queueStreamForSong:song offset:0 atIndex:[handlerStack count]];
}

- (void)queueStreamForSong:(Song *)song offset:(NSUInteger)byteOffset
{
	[self queueStreamForSong:song offset:byteOffset atIndex:[handlerStack count]];
}

- (void)queueStreamForNextSong
{
	Song *nextSong = [SUSCurrentPlaylistDAO dataModel].nextSong;
	
	if (nextSong)
	{
		[self queueStreamForSong:nextSong];
	}
}

#pragma mark - SUSStreamHandler delegate

- (void)SUSStreamHandlerStartPlayback:(SUSStreamHandler *)handler startByteOffset:(NSUInteger)offset
{	
	Song *currentSong = [SUSCurrentPlaylistDAO dataModel].currentSong;
	Song *nextSong = [SUSCurrentPlaylistDAO dataModel].nextSong;
	BassWrapperSingleton *bassWrapper = [BassWrapperSingleton sharedInstance];
	
	DLog(@"currentSong: %@   mySong: %@", currentSong, handler.mySong);
	if ([handler.mySong isEqualToSong:currentSong])
	{
		[bassWrapper start];
        bassWrapper.startByteOffset = offset;
	}
	else if ([handler.mySong isEqualToSong:nextSong])
	{
		[bassWrapper prepareNextSongStream];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"setPauseButtonImage" object:nil];
}

- (void)SUSStreamHandlerConnectionFailed:(SUSStreamHandler *)handler withError:(NSError *)error
{
	DLog(@"stream handler failed: %@", handler);
	if (handler.numOfReconnects < maxNumOfReconnects)
	{
		DLog(@"retrying stream handler");
		// Less than max number of reconnections, so try again 
		handler.numOfReconnects++;
		[handler start];
	}
	else
	{
		DLog(@"removing stream handler");
		// Tried max number of times so remove
		[handlerStack removeObject:handler];
	}
}

- (void)SUSStreamHandlerConnectionFinished:(SUSStreamHandler *)handler
{
	DLog(@"stream handler finished: %@", handler);
	// Remove the handler from the stack
	[handlerStack removeObject:handler];
	
	// Start the next handler which is now the first object
	if ([handlerStack count] > 0)
	{
		[(SUSStreamHandler *)[handlerStack firstObject] start];
	}
}

#pragma mark - Singleton methods

- (void)setup
{
    handlerStack = [[NSMutableArray alloc] initWithCapacity:0];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(queueStreamForNextSong) name:ISMSNotification_SongPlaybackEnd object:nil];
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
