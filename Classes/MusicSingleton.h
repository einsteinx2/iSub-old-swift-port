//
//  musicSSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#define musicS [MusicSingleton sharedInstance]

#import "SUSLoaderDelegate.h"

@class Song, BBSimpleConnectionQueue;

@interface MusicSingleton : NSObject <SUSLoaderDelegate>
{		
	BOOL isAutoNextNotificationOn;
}

@property (retain) Song *queueSongObject;

@property (retain) NSMutableData *receivedDataQueue;
@property (retain) NSURLConnection *downloadQueue;
@property (retain) NSString *downloadFileNameQueue;
@property (retain) NSString *downloadFileNameHashQueue;
@property (retain) NSFileHandle *audioFileQueue;
@property UInt32 downloadedLengthQueue; // Keeps track of the number of bytes downloaded
@property BOOL isQueueListDownloading;

@property BOOL jukeboxIsPlaying;
@property float jukeboxGain;

@property (readonly) BOOL showPlayerIcon;

@property (retain) BBSimpleConnectionQueue *connectionQueue;

+ (MusicSingleton*)sharedInstance;

- (void)downloadNextQueuedSong;
- (void)startDownloadQueue;
- (void)stopDownloadQueue;
- (void)resumeDownloadQueue:(UInt32)byteOffset;

- (void)startSongAtOffsetInBytes:(unsigned long long)bytes andSeconds:(double)seconds;
- (void)startSong;
- (void)playSongAtPosition:(NSInteger)position;
- (void)nextSong;
- (void)prevSong;

- (void)resumeSong;

- (void)showPlayer;

- (void)updateLockScreenInfo;

// Jukebox control methods
- (void)jukeboxPlaySongAtPosition:(NSNumber *)position;
- (void)jukeboxPlay;
- (void)jukeboxStop;
- (void)jukeboxPrevSong;
- (void)jukeboxNextSong;
- (void)jukeboxSetVolume:(float)level;
- (void)jukeboxAddSong:(NSString*)songId;
- (void)jukeboxAddSongs:(NSArray*)songIds;
- (void)jukeboxReplacePlaylistWithLocal;
- (void)jukeboxRemoveSong:(NSString*)songId;
- (void)jukeboxClearPlaylist;
- (void)jukeboxClearRemotePlaylist;
- (void)jukeboxShuffle;
- (void)jukeboxGetInfo;

@end
