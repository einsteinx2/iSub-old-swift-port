//
//  MusicControlsSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//



@class iSubAppDelegate, DatabaseSingleton, ViewObjectsSingleton, Song, AudioStreamer, BBSimpleConnectionQueue;

@interface MusicSingleton : NSObject 
{
	iSubAppDelegate *appDelegate;
	DatabaseSingleton *databaseControls;
	ViewObjectsSingleton *viewObjects;
	
	// Audio streamer objects and variables
	//
	AudioStreamer *streamer;
	double streamerProgress;
	NSTimer *progressUpdateTimer;
	NSInteger repeatMode;
	BOOL isShuffle;
	BOOL isPlaying;
	float seekTime;
	NSInteger buffersUsed;
	
	// Music player objects
	//
	Song *currentSongObject; //the current playing song
	Song *nextSongObject; //the current downloading song
	Song *queueSongObject; //the current downloading cache queue song
	NSString *currentSongLyrics;
	NSInteger currentPlaylistPosition;
	BOOL isNewSong;
	NSURL *songUrl;
	NSURL *nextSongUrl;
	NSURL *queueSongUrl;
	NSURL *coverArtUrl;
	NSTimer *progressTimer;
	
	// New player stuff
	//
	NSString *documentsPath;
	NSString *audioFolderPath;
	NSString *tempAudioFolderPath;
	
	UInt32 tempDownloadByteOffset; // The byte offset that we originally started the temp download
	
	NSMutableData *receivedDataA;
	NSString *downloadFileNameA;
	NSString *downloadFileNameHashA;
	NSFileHandle *audioFileA;
	UInt32 downloadedLengthA; // Keeps track of the number of bytes downloaded
	
	NSMutableData *receivedDataB;
	NSString *downloadFileNameB;
	NSString *downloadFileNameHashB;
	NSFileHandle *audioFileB;
	UInt32 downloadedLengthB; // Keeps track of the number of bytes downloaded
	BOOL reportDownloadedLengthB;
	
	NSMutableData *receivedDataQueue;
	NSURLConnection *downloadQueue;
	NSString *downloadFileNameQueue;
	NSString *downloadFileNameHashQueue;
	NSFileHandle *audioFileQueue;
	UInt32 downloadedLengthQueue; // Keeps track of the number of bytes downloaded
	BOOL isQueueListDownloading;
	
	UInt32 bitRate;
	BOOL isTempDownload;

	BOOL showNowPlayingIcon;	
	
	Song *songB;
	
	BOOL jukeboxIsPlaying;
	float jukeboxGain;
	
	//BOOL showPlayerIcon;
	
	BBSimpleConnectionQueue *connectionQueue;
	
	BOOL isAutoNextNotificationOn;
}

// Audio streamer objects and variables
//
@property (nonatomic, retain) AudioStreamer *streamer;
@property double streamerProgress;
@property NSInteger repeatMode;
@property BOOL isShuffle;
@property BOOL isPlaying;
@property float seekTime;
@property NSInteger buffersUsed;

// Music player objects
//
@property (nonatomic, retain) Song *currentSongObject;
@property (nonatomic, retain) Song *nextSongObject;
@property (nonatomic, retain) Song *queueSongObject;
@property (nonatomic, retain) NSString *currentSongLyrics;
@property NSInteger currentPlaylistPosition;
@property BOOL isNewSong;
@property (nonatomic, retain) NSURL *songUrl;
@property (nonatomic, retain) NSURL *nextSongUrl;
@property (nonatomic, retain) NSURL *queueSongUrl;
@property (nonatomic, retain) NSURL *coverArtUrl;

// Song caching stuff
//
@property (nonatomic, retain) NSString *documentsPath;
@property (nonatomic, retain) NSString *audioFolderPath;
@property (nonatomic, retain) NSString *tempAudioFolderPath;
@property UInt32 tempDownloadByteOffset;
@property (nonatomic, retain) NSMutableData *receivedDataA;
@property (nonatomic, retain) NSString *downloadFileNameA;
@property (nonatomic, retain) NSString *downloadFileNameHashA;
@property (nonatomic, retain) NSFileHandle *audioFileA;
@property UInt32 downloadedLengthA;
@property (nonatomic, retain) NSMutableData *receivedDataB;
@property (nonatomic, retain) NSString *downloadFileNameB;
@property (nonatomic, retain) NSString *downloadFileNameHashB;
@property (nonatomic, retain) NSFileHandle *audioFileB;
@property UInt32 downloadedLengthB;
@property BOOL reportDownloadedLengthB;
@property (nonatomic, retain) NSMutableData *receivedDataQueue;
@property (nonatomic, retain) NSURLConnection *downloadQueue;
@property (nonatomic, retain) NSString *downloadFileNameQueue;
@property (nonatomic, retain) NSString *downloadFileNameHashQueue;
@property (nonatomic, retain) NSFileHandle *audioFileQueue;
@property UInt32 downloadedLengthQueue;
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

- (void)startDownloadA;
- (void)stopDownloadA;
- (void)resumeDownloadA:(UInt32)byteOffset;

- (void)startTempDownloadA:(UInt32)byteOffset;

- (void)startDownloadB;
- (void)stopDownloadB;
- (void)resumeDownloadB:(UInt32)byteOffset;
- (void)resumeDownloadB:(UInt32)byteOffset withSong:(Song *)song;

- (void)downloadNextQueuedSong;
- (void)startDownloadQueue;
- (void)stopDownloadQueue;
- (void)resumeDownloadQueue:(UInt32)byteOffset;

- (NSInteger) maxBitrateSetting;

- (void)createProgressTimer;
- (void)createStreamer;
- (void)createStreamerWithOffset;
- (void)destroyStreamer;
- (void)playPauseSong;
- (void)playSongAtPosition:(NSInteger)position;
- (void)nextSong;
- (void)nextSongAuto;
- (void)prevSong;

//- (void)checkCache;
- (void)resumeSong;

- (void) loadLyricsForArtistAndTitle:(NSArray *)artistAndTitle;

- (void)showPlayer;

- (void)removeAutoNextNotification;
- (void)addAutoNextNotification;

// Jukebox control methods
- (void)jukeboxPlaySongAtPosition:(NSUInteger)position;
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

- (void)scrobbleSong:(NSString*)songId isSubmission:(BOOL)isSubmission;

@end
