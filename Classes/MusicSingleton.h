//
//  MusicControlsSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SUSLoaderDelegate.h"

@class iSubAppDelegate, DatabaseSingleton, ViewObjectsSingleton, Song, BBSimpleConnectionQueue, BassWrapperSingleton;

@interface MusicSingleton : NSObject <SUSLoaderDelegate>
{
	iSubAppDelegate *appDelegate;
	DatabaseSingleton *databaseControls;
	ViewObjectsSingleton *viewObjects;
		
	BOOL isAutoNextNotificationOn;
	
	BassWrapperSingleton *bassWrapper;
}

// Audio streamer objects and variables
//
@property BOOL isShuffle;

// Music player objects
//
@property (nonatomic, retain) Song *queueSongObject;
@property (nonatomic, retain) NSURL *coverArtUrl;

@property (nonatomic, retain) NSMutableData *receivedDataQueue;
@property (nonatomic, retain) NSURLConnection *downloadQueue;
@property (nonatomic, retain) NSString *downloadFileNameQueue;
@property (nonatomic, retain) NSString *downloadFileNameHashQueue;
@property (nonatomic, retain) NSFileHandle *audioFileQueue;
@property UInt32 downloadedLengthQueue; // Keeps track of the number of bytes downloaded
@property BOOL isQueueListDownloading;
@property UInt32 bitRate;
@property BOOL isTempDownload;
@property BOOL showNowPlayingIcon;

@property (nonatomic, retain) Song *songB;

@property BOOL jukeboxIsPlaying;
@property float jukeboxGain;

@property (readonly) BOOL showPlayerIcon;

@property (nonatomic, retain) BBSimpleConnectionQueue *connectionQueue;

+ (MusicSingleton*)sharedInstance;

- (void)downloadNextQueuedSong;
- (void)startDownloadQueue;
- (void)stopDownloadQueue;
- (void)resumeDownloadQueue:(UInt32)byteOffset;

- (NSInteger) maxBitrateSetting;

- (void)startSongAtOffsetInSeconds:(NSUInteger)seconds;
- (void)startSong;
- (void)playSongAtPosition:(NSInteger)position;
- (void)nextSong;
//- (void)nextSongAuto;
- (void)prevSong;

//- (void)checkCache;
- (void)resumeSong;

- (void)showPlayer;

- (void)updateLockScreenInfo;

//- (void)removeAutoNextNotification;
//- (void)addAutoNextNotification;

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


- (float) findCurrentSongProgress;
- (float) findNextSongProgress;
//- (unsigned long long int) findCacheSize;
//- (unsigned long long int) findFreeSpace;

@end
