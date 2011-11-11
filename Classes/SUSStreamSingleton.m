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

static SUSStreamSingleton *sharedInstance = nil;

@implementation SUSStreamSingleton
@synthesize throttlingDate, isDownloadA, isDownloadB, bytesTransferred;

- (BOOL) insertSong:(Song *)aSong intoGenreTable:(NSString *)table
{
    DatabaseSingleton *databaseControls = [DatabaseSingleton sharedInstance];
    
	[databaseControls.songCacheDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (md5, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", table], [aSong.path md5], aSong.title, aSong.songId, aSong.artist, aSong.album, aSong.genre, aSong.coverArtId, aSong.path, aSong.suffix, aSong.transcodedSuffix, aSong.duration, aSong.bitRate, aSong.track, aSong.year, aSong.size];
	
	if ([databaseControls.songCacheDb hadError]) {
		DLog(@"Err inserting song into genre table %d: %@", [databaseControls.songCacheDb lastErrorCode], [databaseControls.songCacheDb lastErrorMessage]);
	}
	
	return [databaseControls.songCacheDb hadError];
}

#pragma mark Connection factory



#pragma mark Download
- (void)downloadCFNetA:(NSString *)songId
{
    DLog(@"downloadCFNetA");
    self.throttlingDate = nil;
	bytesTransferred = 0;
	
	isDownloadA = YES;
	
	// NOTE: Handler releases itself when done
	[[SUSStreamHandler alloc] initWithSongId:songId];
}

- (void)downloadCFNetB:(NSString *)songId
{
    DLog(@"downloadCFNetB");
	self.throttlingDate = nil;
	bytesTransferred = 0;
	
	isDownloadB = YES;
    
    [self createConnectionForReadStreamRef:&readStreamRefB callback:ReadStreamClientCallBackB songId:songId offset:0];
}

- (void)downloadCFNetTemp:(NSString *)songId
{
    DLog(@"downloadCFNetTemp");
	self.throttlingDate = nil;
	bytesTransferred = 0;
	
	isDownloadA = YES;
    
    [self createConnectionForReadStreamRef:&readStreamRefA callback:ReadStreamClientCallBackTemp songId:songId offset:0];
}

#pragma mark Resume
- (void)resumeCFNetA:(NSString *)songId offset:(UInt32)byteOffset
{
    DLog(@"resumeCFNetA");
    self.throttlingDate = [NSDate date];
	bytesTransferred = 0;
	
	isDownloadA = YES;
    
    [self createConnectionForReadStreamRef:&readStreamRefA callback:ReadStreamClientCallBackA songId:songId offset:byteOffset];
}

- (void)resumeCFNetB:(NSString *)songId offset:(UInt32)byteOffset
{
    DLog(@"resumeCFNetB");
	self.throttlingDate = [NSDate date];
	bytesTransferred = 0;
	
	isDownloadB = YES;
    
    [self createConnectionForReadStreamRef:&readStreamRefB callback:ReadStreamClientCallBackB songId:songId offset:byteOffset];
}

#pragma mark - Singleton methods

- (void)setup
{
    isDownloadA = NO;
    isDownloadB = NO;
    bytesTransferred = 0;
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
