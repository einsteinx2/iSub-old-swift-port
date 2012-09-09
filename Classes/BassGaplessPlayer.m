//
//  BassGaplessPlayer.m
//  Anghami
//
//  Created by Ben Baron on 6/29/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "BassGaplessPlayer.h"
#import "Song+DAO.h"
#import "PlaylistSingleton.h"
#import "MusicSingleton.h"
#import "SavedSettings.h"
#import "ViewObjectsSingleton.h"
#import "ISMSStreamManager.h"
#import "SocialSingleton.h"

@implementation BassGaplessPlayer
@synthesize delegate;
@synthesize streamGcdQueue;
@synthesize ringBuffer, stopFillingRingBuffer;
@synthesize streamQueue, outStream, mixerStream;
@synthesize isPlaying, isStarted, bitRate, currentByteOffset, waitLoopStream;
@synthesize startByteOffset, startSecondsOffset;
@synthesize equalizer, visualizer;

LOG_LEVEL_ISUB_DEFAULT

#define ISMS_BASSBufferSize 800
#define ISMS_defaultSampleRate 44100

// Stream create failure retry values
#define ISMS_BassStreamRetryDelay 2.0
#define ISMS_BassStreamMinFilesizeToFail BytesFromMiB(3)

#define startSongRetryTimer @"startSong"
#define nextSongRetryTimer @"nextSong"

- (id)init
{
	if ((self = [super init]))
	{
		streamQueue = [NSMutableArray arrayWithCapacity:5];
		streamGcdQueue = dispatch_queue_create("com.anghami.BassStreamQueue", NULL);
		ringBuffer = [EX2RingBuffer ringBufferWithLength:BytesFromKiB(640)];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepareNextSongStream) name:ISMSNotification_RepeatModeChanged object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepareNextSongStream) name:ISMSNotification_CurrentPlaylistOrderChanged object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepareNextSongStream) name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	}
	
    return self;
}

- (id)initWithDelegate:(id<BassGaplessPlayerDelegate>)theDelegate
{
    if (([self init]))
    {
        delegate = theDelegate;
    }
    return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Decode Stream Callbacks

void CALLBACK MyStreamEndCallback(HSYNC handle, DWORD channel, DWORD data, void *user)
{
	@autoreleasepool 
	{
		// Free and remove the channel
		//BASS_Mixer_ChannelRemove(channel);
		//BASS_StreamFree(channel);
		
		BassStream *userInfo = (__bridge BassStream *)user;
		if (userInfo)
		{
			NSUInteger index = [userInfo.player.streamQueue indexOfObject:userInfo];
			if (index == 0)
			{
				// This is the current playing song, remove this one
				//[sharedInstance.streamQueue removeObjectAtIndex:0];
				userInfo.bufferSpaceTilSongEnd = userInfo.player.ringBuffer.filledSpaceLength;
				userInfo.isEnded = YES;
				
				// Plug in the next one
				userInfo = [userInfo.player.streamQueue objectAtIndexSafe:1];
				if (userInfo)
				{
					// There's another stream so play it
					BASS_Mixer_StreamAddChannel(userInfo.player.mixerStream, userInfo.stream, 0);
				}
			}
			else
			{
				// Not sure why this would happen, just remove this stream from the queue
				//ssert(0 && "somehow this stream ended but was not the current playing stream");
				//[sharedInstance.streamQueue removeObjectAtIndex:index];
			}
		}
	}
}

void CALLBACK MyFileCloseProc(void *user)
{	
	if (user == NULL)
		return;
	
	@autoreleasepool 
	{
		// Get the user info object
		BassStream *userInfo = (__bridge BassStream *)user;
		
		// Tell the read wait loop to break in case it's waiting
		userInfo.shouldBreakWaitLoop = YES;
		userInfo.shouldBreakWaitLoopForever = YES;
		
		// Close the file handle
		if (userInfo.fileHandle)
			[userInfo.fileHandle closeFile];
	}
}

QWORD CALLBACK MyFileLenProc(void *user)
{
	if (user == NULL)
		return 0;
	
	@autoreleasepool
	{
		BassStream *userInfo = (__bridge BassStream *)user;
		if (!userInfo.fileHandle)
			return 0;
		
		QWORD length = 0;
		Song *theSong = userInfo.song;
		if (userInfo.shouldBreakWaitLoopForever)
		{
			return 0;
		}
		else if (theSong.isFullyCached || userInfo.isTempCached)
		{
			// Return actual file size on disk
			length = theSong.localFileSize;
		}
		else
		{
			// Return server reported file size
			length = [theSong.size longLongValue];
		}
		
		DDLogCVerbose(@"checking %@ length: %llu", theSong.title, length);
		return length;
	}
}

DWORD CALLBACK MyFileReadProc(void *buffer, DWORD length, void *user)
{
	if (buffer == NULL || user == NULL)
		return 0;
	
	@autoreleasepool
	{
		BassStream *userInfo = (__bridge BassStream *)user;
		if (!userInfo.fileHandle)
			return 0;
		
		// Read from the file
		
		NSData *readData;
		@try 
		{
			readData = [userInfo.fileHandle readDataOfLength:length];
		}
		@catch (NSException *exception) {
			readData = nil;
		}
		
		DWORD bytesRead = readData.length;
		if (bytesRead > 0)
		{
			// Copy the data to the buffer
			[readData getBytes:buffer length:bytesRead];
		}
		
		if (bytesRead < length && userInfo.isSongStarted && !userInfo.wasFileJustUnderrun)
		{
			userInfo.isFileUnderrun = YES;
		}
		
		userInfo.wasFileJustUnderrun = NO;
		
		return bytesRead;
	}
}

BOOL CALLBACK MyFileSeekProc(QWORD offset, void *user)
{	
	if (user == NULL)
		return NO;
	
	@autoreleasepool 
	{
		// Seek to the requested offset (returns false if data not downloaded that far)
		BassStream *userInfo = (__bridge BassStream *)user;
		if (!userInfo.fileHandle)
			return NO;
		
		BOOL success = YES;
		
		@try {
			[userInfo.fileHandle seekToFileOffset:offset];
		}
		@catch (NSException *exception) {
			success = NO;
		}
		
		DDLogCVerbose(@"seeking to %llu  success: %@", offset, NSStringFromBOOL(success));
		
		return success;
	}
}

static BASS_FILEPROCS fileProcs = {MyFileCloseProc, MyFileLenProc, MyFileReadProc, MyFileSeekProc};

#pragma mark - Output Stream

DWORD CALLBACK MyStreamProc(HSTREAM handle, void *buffer, DWORD length, void *user)
{
	@autoreleasepool
	{
		BassGaplessPlayer *player = (__bridge BassGaplessPlayer *)user;
		return [player bassGetOutputData:buffer length:length];
	}
}

- (DWORD)bassGetOutputData:(void *)buffer length:(DWORD)length
{
    // Done at end now
	//[socialS playerHandleSocial];
	
	BassStream *userInfo = self.currentStream;
	
	NSUInteger bytesRead = [self.ringBuffer drainBytes:buffer length:length];
	
	if (userInfo.isEnded)
	{
		userInfo.bufferSpaceTilSongEnd -= bytesRead;
		if (userInfo.bufferSpaceTilSongEnd <= 0)
		{
			[self songEnded:userInfo];
		}
	}
	
	Song *currentSong = userInfo.song;
	if (bytesRead == 0 && !BASS_ChannelIsActive(userInfo.stream) && (currentSong.isFullyCached || currentSong.isTempCached))
	{
		self.isPlaying = NO;
		
		if (!userInfo.isEndedCalled)
		{
			// Somehow songEnded: was never called
			[userInfo.player songEnded:userInfo];
		}
		
		// The stream should end, because there is no more music to play
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackEnded];
		
		DDLogVerbose(@"Stream not active, freeing BASS");
		[self performSelectorOnMainThread:@selector(bassFree) withObject:nil waitUntilDone:NO];
		
		// Start the next song if for some reason this one isn't ready
		[musicS performSelectorOnMainThread:@selector(startSong) withObject:nil waitUntilDone:NO];
		
		return BASS_STREAMPROC_END;
	}
	
	return bytesRead;
}

- (void)moveToNextSong
{
	if (playlistS.nextSong)
	{
		[musicS playSongAtPosition:playlistS.nextIndex];
	}
	else
	{
		[self bassFree];
	}
}

// songEnded: is called AFTER MyStreamEndCallback, so the next song is already actually decoding into the ring buffer
- (void)songEnded:(BassStream *)userInfo
{
	@autoreleasepool 
	{
		userInfo.isEndedCalled = YES;
        
        if ([self.delegate respondsToSelector:@selector(bassSongEndedCalled)])
        {
            [self.delegate bassSongEndedCalled];
        }
		
		// Remove the stream from the queue
		if (userInfo)
		{
			BASS_StreamFree(userInfo.stream);
		}
		[self.streamQueue removeObjectAtIndexSafe:0];
		
		// Increment current playlist index
		[playlistS incrementIndex];
		
		// Get the next song in the queue
		[self prepareNextSongStream:playlistS.nextSong];
		
		Song *endedSong = userInfo.song;
        
        if ([self.delegate respondsToSelector:@selector(bassSongEndedPlaylistIncremented:)])
        {
            [self.delegate bassSongEndedPlaylistIncremented:endedSong];
        }
		
		// Send song end notification
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackEnded];
		
		if (self.isPlaying)
		{
			DDLogInfo(@"songEnded: self.isPlaying = YES");
			startSecondsOffset = 0;
			startByteOffset = 0;
			
			// Send song start notification
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackStarted];
            
            // Mark the last played time in the database for cache cleanup
			self.currentStream.song.playedDate = [NSDate date];
            
            if ([self.delegate respondsToSelector:@selector(bassSongEndedFinishedIsPlaying)])
            {
                [self.delegate bassSongEndedFinishedIsPlaying];
            }
		}
		else
		{
			DDLogInfo(@"songEnded: self.isPlaying = NO");
			[EX2Dispatch runInMainThread:^
			 {
				 [musicS startSong];
			 }];
		}
	}
}

- (void)keepRingBufferFilled
{
	[self performSelectorInBackground:@selector(keepRingBufferFilledInternal) withObject:nil];
}

- (void)keepRingBufferFilledInternal
{
	@autoreleasepool 
	{
		NSUInteger readSize = BytesFromKiB(64);
		while (!self.stopFillingRingBuffer)
		{						
			// Fill the buffer if there is empty space
			if (self.ringBuffer.freeSpaceLength > readSize)
			{
				@autoreleasepool 
				{
					//if (BASS_ChannelIsActive(self.outStream))
					{
						/* 
						 * Read data to fill the buffer
						 */ 
						
						BassStream *userInfo = self.currentStream;
						
						void *tempBuffer = malloc(sizeof(char) * readSize);
						DWORD tempLength = BASS_ChannelGetData(self.mixerStream, tempBuffer, readSize);
						if (tempLength) 
						{
							userInfo.isSongStarted = YES;
							
							[self.ringBuffer fillWithBytes:tempBuffer length:tempLength];
						}
						free(tempBuffer);
						
						/*
						 * Handle pausing to wait for more data
						 */ 
						
						if (userInfo.isFileUnderrun && BASS_ChannelIsActive(userInfo.stream))
						{
							// Get a strong reference to the current song's userInfo object, so that
							// if the stream is freed while the wait loop is sleeping, the object will
							// still be around to respond to shouldBreakWaitLoop
							self.waitLoopStream = userInfo;
							
							// Mark the stream as waiting
							userInfo.isWaiting = YES;
							userInfo.isFileUnderrun = NO;
							userInfo.wasFileJustUnderrun = YES;
							
							// Handle waiting for additional data
							Song *theSong = userInfo.song;
							if (!theSong.isFullyCached)
							{
								if (viewObjectsS.isOfflineMode)
								{
									// This is offline mode and the song can not continue to play
									[self moveToNextSong];
								}
								else
								{
									// Calculate the needed size:
									// Choose either the current player bitrate, or if for some reason it is not detected properly, 
									// use the best estimated bitrate. Then use that to determine how much data to let download to continue.
									
									unsigned long long size = theSong.localFileSize;
									NSUInteger bitrate = [BassWrapper estimateBitrate:userInfo];
									
									unsigned long long bytesToWait = BytesForSecondsAtBitrate(settingsS.audioEngineBufferNumberOfSeconds, bitrate);
									userInfo.neededSize = size + bytesToWait;
									
									DDLogCVerbose(@"audioEngineBufferNumberOfSeconds: %u", settingsS.audioEngineBufferNumberOfSeconds);
									DDLogCVerbose(@"AUDIO ENGINE - waiting for %llu   neededSize: %llu", bytesToWait, userInfo.neededSize);
									
									// Sleep for 10000 microseconds, or 1/100th of a second
#define sleepTime 10000
									// Check file size every second, so 1000000 microseconds
#define fileSizeCheckWait 1000000
									QWORD totalSleepTime = 0;
									while (YES)
									{
										// Check if we should break every 100th of a second
										usleep(sleepTime);
										totalSleepTime += sleepTime;
										if (userInfo.shouldBreakWaitLoop || userInfo.shouldBreakWaitLoopForever)
											break;
										
										// Only check the file size every second
										if (totalSleepTime >= fileSizeCheckWait)
										{
											@autoreleasepool 
											{
												totalSleepTime = 0;
												
												// If enough of the file has downloaded, break the loop
												if (userInfo.localFileSize >= userInfo.neededSize)
													break;
												// Handle temp cached songs ending. When they end, they are set as the last temp cached song, so we know it's done and can stop waiting for data.
												else if (theSong.isTempCached && [theSong isEqualToSong:streamManagerS.lastTempCachedSong])
													break;
												// If the song has finished caching, we can stop waiting
												else if (theSong.isFullyCached)
													break;
												// If we're not in offline mode, stop waiting and try next song
												else if (viewObjectsS.isOfflineMode)
												{
													[self moveToNextSong];
													break;
												}
											}
										}
									}
									DDLogCVerbose(@"done waiting");
								}
							}
							
							userInfo.isWaiting = NO;
							userInfo.shouldBreakWaitLoop = NO;
							self.waitLoopStream = nil;
						}
					}
				}
			}
			
			// Sleep for 1/4th of a second to prevent a tight loop
			usleep(150000);
		}
	}
}

#pragma mark - BASS methods

extern void BASSFLACplugin, BASSWVplugin, BASS_APEplugin, BASS_MPCplugin;

- (void)bassInit:(NSUInteger)sampleRate
{
	sampleRate = ISMS_defaultSampleRate;
	
	// Destroy any existing BASS instance
	[self bassFree];
	
	// Initialize BASS
	BASS_SetConfig(BASS_CONFIG_IOS_MIXAUDIO, 0); // Disable mixing.	To be called before BASS_Init.
	BASS_SetConfig(BASS_CONFIG_BUFFER, BASS_GetConfig(BASS_CONFIG_UPDATEPERIOD) + ISMS_BASSBufferSize); // set the buffer length to the minimum amount + 200ms
	BASS_SetConfig(BASS_CONFIG_FLOATDSP, true); // set DSP effects to use floating point math to avoid clipping within the effects chain
	if (!BASS_Init(-1, sampleRate, 0, NULL, NULL)) 	// Initialize default device.
	{
		DDLogError(@"Can't initialize device");
	}
    
    BASS_PluginLoad(&BASSFLACplugin, 0); // load the Flac plugin
    BASS_PluginLoad(&BASSWVplugin, 0); // load the WavePack plugin
    BASS_PluginLoad(&BASS_APEplugin, 0); // load the Monkey's Audio plugin
    BASS_PluginLoad(&BASS_MPCplugin, 0); // load the MusePack plugin
	
	self.stopFillingRingBuffer = NO;
	
	self.equalizer = [[BassEqualizer alloc] init];
	self.visualizer = [[BassVisualizer alloc] init];
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_BassInitialized];
}

- (void)bassInit
{
	// Default to 44.1 KHz
    [self bassInit:ISMS_defaultSampleRate];
}

- (BOOL)bassFree
{
	@synchronized(self.visualizer)
	{
		[EX2Dispatch cancelTimerBlockWithName:startSongRetryTimer];
		[EX2Dispatch cancelTimerBlockWithName:nextSongRetryTimer];
		
		self.stopFillingRingBuffer = YES;
		
		for (BassStream *userInfo in self.streamQueue)
		{
			userInfo.shouldBreakWaitLoopForever = YES;
		}
		
		self.equalizer = nil;
		self.visualizer = nil;
		
		BOOL success = BASS_Free();
		self.isPlaying = NO;
		
		[self.ringBuffer reset];
		
		[socialS playerHandleSocial];
		[socialS playerClearSocial];
		
		[self.streamQueue removeAllObjects];
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_BassFreed];
		
		return success;
	}
}

- (BassStream *)prepareStreamForSong:(Song *)aSong
{
	DDLogVerbose(@"preparing stream for %@  file: %@", aSong.title, aSong.currentPath);
	if (aSong.fileExists)
	{	
		// Create the user info object for the stream
		BassStream *userInfo = [[BassStream alloc] init];
		userInfo.song = aSong;
		userInfo.writePath = aSong.currentPath;
		userInfo.isTempCached = aSong.isTempCached;
		userInfo.fileHandle = [NSFileHandle fileHandleForReadingAtPath:userInfo.writePath];
		if (!userInfo.fileHandle)
		{
			// File failed to open
			DDLogError(@"File failed to open");
			return nil;
		}
		
		// Create the stream
		HSTREAM fileStream = BASS_StreamCreateFileUser(STREAMFILE_NOBUFFER, BASS_STREAM_DECODE|BASS_SAMPLE_FLOAT, &fileProcs, (__bridge void*)userInfo);
		if(!fileStream) fileStream = BASS_StreamCreateFileUser(STREAMFILE_NOBUFFER, BASS_STREAM_DECODE|BASS_SAMPLE_SOFTWARE|BASS_SAMPLE_FLOAT, &fileProcs, (__bridge void *)userInfo);
		if (fileStream)
		{
			// Add the stream free callback
			BASS_ChannelSetSync(fileStream, BASS_SYNC_END, 0, MyStreamEndCallback, (__bridge void*)userInfo);
			
			// Stream successfully created
			userInfo.stream = fileStream;
			userInfo.player = self;
			return userInfo;
		}
		
		// Failed to create the stream
		DDLogError(@"failed to create stream for song: %@  filename: %@", aSong.title, aSong.currentPath);
		return nil;
	}
	
	// File doesn't exist
	return nil;
}

- (void)startWithOffsetInBytes:(NSNumber *)byteOffset orSeconds:(NSNumber *)seconds
{
	[EX2Dispatch runInQueue:streamGcdQueue waitUntilDone:NO block:^
	 {
		 NSInteger count = playlistS.count;
		 if (playlistS.currentIndex >= count) playlistS.currentIndex = count - 1;
		 
		 Song *currentSong = playlistS.currentSong;
		 if (!currentSong)
			 return;
		 
		 self.startByteOffset = 0;
		 self.startSecondsOffset = 0;
		 
		 [self bassInit];
		 
		 if (currentSong.fileExists)
		 {
			 BassStream *userInfo = [self prepareStreamForSong:currentSong];
			 if (userInfo)
			 {
				 self.mixerStream = BASS_Mixer_StreamCreate(ISMS_defaultSampleRate, 2, BASS_STREAM_DECODE);//|BASS_MIXER_END);
				 BASS_Mixer_StreamAddChannel(self.mixerStream, userInfo.stream, 0);
				 self.outStream = BASS_StreamCreate(ISMS_defaultSampleRate, 2, 0, &MyStreamProc, (__bridge void*)self);
				 
				 self.visualizer.channel = self.outStream;
				 
				 self.equalizer.channel = self.outStream;
				 
				 // Enable the equalizer if it's turned on
				 if (settingsS.isEqualizerOn)
				 {
					 BassEffectDAO *effectDAO = [[BassEffectDAO alloc] initWithType:BassEffectType_ParametricEQ];
					 [effectDAO selectPresetId:effectDAO.selectedPresetId];
					 [self.equalizer applyEqualizerValues];
				 }
				 
				 // Add gain amplification
				 [self.equalizer createVolumeFx];
				 
				 // Add the stream to the queue
				 [self.streamQueue addObject:userInfo];
				 
				 // Skip to the byte offset
				 if (byteOffset)
				 {
					 self.startByteOffset = byteOffset.unsignedLongLongValue;
					 
					 if (seconds)
					 {
						 [self seekToPositionInSeconds:seconds.doubleValue];
					 }
					 else
					 {
						 if (self.startByteOffset > 0)
							 [self seekToPositionInBytes:self.startByteOffset];
					 }
				 }
				 else if (seconds)
				 {
					 self.startSecondsOffset = seconds.doubleValue;
					 if (self.startSecondsOffset > 0.0)
						 [self seekToPositionInSeconds:self.startSecondsOffset];
				 }
				 
				 // Start filling the ring buffer
				 [self keepRingBufferFilled];
				 
				 // Start playback
				 BASS_ChannelPlay(self.outStream, FALSE);
				 self.isPlaying = YES;
                 
                 if ([self.delegate respondsToSelector:@selector(bassFirstStreamStarted)])
                 {
                     [self.delegate bassFirstStreamStarted];
                 }
				 
				 // Prepare the next song
				 [self prepareNextSongStream];
				 
				 // Notify listeners that playback has started
				 [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackStarted];
				 
				 currentSong.playedDate = [NSDate date];
			 }
			 else if (!userInfo && !currentSong.isFullyCached && currentSong.localFileSize < ISMS_BassStreamMinFilesizeToFail)
			 {
				 if (viewObjectsS.isOfflineMode)
				 {
					 [self moveToNextSong];
				 }
				 else if (!currentSong.fileExists)
				 {
					 DDLogError(@"Stream for song %@ failed, file is not on disk, so calling [musicS startSong]", userInfo.song.title);
					 // File was removed, most likely because the decryption failed, so start again normally
					 [currentSong removeFromCachedSongsTableDbQueue];
					 [musicS performSelectorOnMainThread:@selector(startSong) withObject:nil waitUntilDone:NO];
				 }
				 else
				 {
					 // Failed to create the stream, retrying
					 DDLogError(@"------failed to create stream, retrying in 2 seconds------");
					 
					 [EX2Dispatch timerInMainQueueAfterDelay:ISMS_BassStreamRetryDelay 
												   withName:startSongRetryTimer
                                                    repeats:NO
											   performBlock:^{ [self startWithOffsetInBytes:byteOffset orSeconds:seconds]; }];
				 }
			 }
			 else
			 {
				 [currentSong removeFromCachedSongsTableDbQueue];
				 [musicS performSelectorOnMainThread:@selector(startSong) withObject:nil waitUntilDone:NO];
			 }
		 }
	 }];
}

- (void)prepareNextSongStream
{
	[self prepareNextSongStream:nil];
}

- (void)prepareNextSongStream:(Song *)nextSong
{
	[EX2Dispatch runInQueue:streamGcdQueue waitUntilDone:NO block:^
	 {
		 // Remove any additional streams
		 NSUInteger count = self.streamQueue.count;
		 while (count > 2)
		 {
			 BassStream *userInfo = [self.streamQueue lastObject];
			 BASS_StreamFree(userInfo.stream);
			 [self.streamQueue removeLastObject];
			 count = self.streamQueue.count; 
		 }
		 
		 Song *theSong = nextSong ? nextSong : playlistS.nextSong;
		 
		 DDLogVerbose(@"nextSong.localFileSize: %llu", theSong.localFileSize);
		 if (theSong.localFileSize == 0)
			 return;
		 
		 DDLogVerbose(@"preparing next song stream for %@  file: %@", theSong.title, theSong.currentPath);
		 
		 BOOL success = NO;
		 if (theSong.fileExists)
		 {
			 BassStream *userInfo = [self prepareStreamForSong:theSong];
			 if (userInfo)
			 {
				 DDLogVerbose(@"nextSong: %i\n   ", userInfo.stream);
				 [self.streamQueue addObject:userInfo];
				 success = YES;
			 }
		 }
		 
		 if (!success)
		 {
#ifdef DEBUG
			 NSInteger errorCode = BASS_ErrorGetCode();
			 DDLogError(@"nextSong stream error: %i - %@", errorCode, [BassWrapper stringFromErrorCode:errorCode]);
#endif
			 
			 // If the stream is currently stuck in the wait loop for partial precaching
			 // tell the stream manager to download a few more seconds of data
			 [streamManagerS downloadMoreOfPrecacheStream];
			 
			 [EX2Dispatch timerInMainQueueAfterDelay:ISMS_BassStreamRetryDelay 
										   withName:nextSongRetryTimer
                                            repeats:NO
									   performBlock:^{ [self prepareNextSongStream:theSong]; }];
		 }
	 }];
}

#pragma mark - Audio Engine Properties

- (BOOL)isStarted
{
	return self.currentStream.stream != 0;
}

- (QWORD)currentByteOffset
{
	return BASS_StreamGetFilePosition(self.currentStream.stream, BASS_FILEPOS_CURRENT) + startByteOffset;
}

- (double)progress
{	
	if (!self.currentStream)
		return 0;
	
	NSInteger pcmBytePosition = BASS_Mixer_ChannelGetPosition(self.currentStream.stream, BASS_POS_BYTE);
	pcmBytePosition -= self.ringBuffer.filledSpaceLength;
	pcmBytePosition = pcmBytePosition < 0 ? 0 : pcmBytePosition; 
	double seconds = BASS_ChannelBytes2Seconds(self.currentStream.stream, pcmBytePosition);
	if (seconds < 0)
		return [playlistS.currentSong.duration doubleValue] + seconds;
	
	return seconds + startSecondsOffset;
}

- (BassStream *)currentStream
{
	return [self.streamQueue firstObjectSafe];
}

- (NSInteger)bitRate
{
	return [BassWrapper estimateBitrate:self.currentStream];
}

#pragma mark - Playback methods

- (void)start
{
	[self startWithOffsetInBytes:[NSNumber numberWithInt:0] orSeconds:nil];
}

- (void)stop
{
    if ([self.delegate respondsToSelector:@selector(bassStopped)])
    {
        [self.delegate bassStopped];
    }
	
    if (self.isPlaying) 
	{
		BASS_Pause();
		self.isPlaying = NO;
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackEnded];
	}
    
    [self bassFree];
}

- (void)pause
{
	if (self.isPlaying)
		[self playPause];
}

- (void)playPause
{	
	if (self.isPlaying) 
	{
		BASS_Pause();
		self.isPlaying = NO;
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackPaused];
	} 
	else 
	{
		if (self.currentStream == 0)
		{
			NSInteger count = playlistS.count;
			if (playlistS.currentIndex >= count) 
			{
				// The playlist finished
				playlistS.currentIndex = count - 1;
				startByteOffset = 0;
				startSecondsOffset = 0.;
			}
			[musicS startSongAtOffsetInBytes:startByteOffset andSeconds:startSecondsOffset];
		}
		else
		{
			BASS_Start();
			self.isPlaying = YES;
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackStarted];
		}
	}
	
	[musicS updateLockScreenInfo];
}

- (void)seekToPositionInBytes:(QWORD)bytes
{
	BassStream *userInfo = self.currentStream;
	if (!userInfo)
		return;
    
    if ([self.delegate respondsToSelector:@selector(bassSeekToPositionStarted)])
    {
        [self.delegate bassSeekToPositionStarted];
    }
	
	if (userInfo.isEnded)
	{
		userInfo.isEnded = NO;
		[self bassFree];
		[self startWithOffsetInBytes:[NSNumber numberWithUnsignedLongLong:bytes] orSeconds:nil];
	}
	else
	{
		BOOL didPause = NO;
		
		if (self.isPlaying)
		{
			[self pause];
			didPause = YES;
		}
		
		if (BASS_Mixer_ChannelSetPosition(userInfo.stream, bytes, BASS_POS_BYTE))
		{
			self.startByteOffset = bytes;
			
			userInfo.neededSize = ULLONG_MAX;
			if (userInfo.isWaiting)
			{
				userInfo.shouldBreakWaitLoop = YES;
			}
			
			[self.ringBuffer reset];
			
			if (didPause)
				[self playPause];
            
            if ([self.delegate respondsToSelector:@selector(bassSeekToPositionSuccess)])
            {
                [self.delegate bassSeekToPositionSuccess];
            }
		}
		else
		{
			[BassWrapper logError];
		}
	}
}

- (void)seekToPositionInSeconds:(double)seconds
{
	QWORD bytes = BASS_ChannelSeconds2Bytes(self.currentStream.stream, seconds);
	[self seekToPositionInBytes:bytes];
}

@end
