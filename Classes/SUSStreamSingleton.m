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
#import "AudioStreamer.h"

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

#pragma mark Download

- (void)queueStreamForSong:(Song *)song offset:(NSUInteger)byteOffset atIndex:(NSUInteger)index
{
	SUSStreamHandler *handler = [[SUSStreamHandler alloc] initWithSong:song offset:byteOffset delegate:self];
	[handlerStack insertObject:handler atIndex:index];
	
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

#pragma mark - SUSStreamHandler delegate

- (void)SUSStreamHandlerStartPlayback:(SUSStreamHandler *)handler
{
	Song *currentSong = [SUSCurrentPlaylistDAO dataModel].currentSong;
	
	if ([handler.mySong isEqualToSong:currentSong])
	{
		// This handler is downloading the current song, so start playback
		MusicSingleton *musicControls = [MusicSingleton sharedInstance];
		musicControls.streamer = [[AudioStreamer alloc] initWithFileURL:[NSURL fileURLWithPath:currentSong.localPath]];
		if (musicControls.streamer)
		{
			musicControls.streamer.fileDownloadCurrentSize = currentSong.localFileSize;
			musicControls.streamer.fileDownloadComplete = YES;
			[musicControls.streamer start];
		}
	}
}

- (void)SUSStreamHandlerConnectionFailed:(SUSStreamHandler *)handler withError:(NSError *)error
{
	[handlerStack removeObject:handler];
	[handler release]; handler = nil;
}

- (void)SUSStreamHandlerConnectionFinished:(SUSStreamHandler *)handler
{
	[handlerStack removeObject:handler];
	[handler release]; handler = nil;
}

#pragma mark - Singleton methods

- (void)setup
{
    handlerStack = [[NSMutableArray alloc] initWithCapacity:0];
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
