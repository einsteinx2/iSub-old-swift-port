//
//  AudioEngine.m
//  iSub
//
//  Created by Ben Baron on 11/16/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "AudioEngine.h"
#import "Song.h"
#import "PlaylistSingleton.h"
#import "NSString+cStringUTF8.h"
#import "BassParamEqValue.h"
#import "BassEffectHandle.h"
#import "NSNotificationCenter+MainThread.h"
#include <AudioToolbox/AudioToolbox.h>
#include "MusicSingleton.h"
#import "BassEffectDAO.h"
#import <sys/stat.h>
#import "BassUserInfo.h"
#import "SavedSettings.h"
#import "SUSStreamSingleton.h"
#import "NSMutableURLRequest+SUS.h"
#import "MusicSingleton.h"

@implementation AudioEngine
@synthesize isEqualizerOn, startByteOffset, startSecondsOffset, currPlaylistDAO, fftDataThread, isFftDataThreadToTerminate, isPlaying, isFastForward, audioQueueShouldStopWaitingForData, state, bassReinitSampleRate, presilenceStream;

// BASS plugins
extern void BASSFLACplugin;

// Singleton object
static AudioEngine *sharedInstance = nil;

#pragma mark - Helper Functions

- (NSString *)stringFromStreamType:(DWORD)ctype plugin:(HPLUGIN)plugin
{
	if (plugin) 
	{ 
		// using a plugin
		const BASS_PLUGININFO *pinfo=BASS_PluginGetInfo(plugin); // get plugin info
		int a;
		for (a=0;a<pinfo->formatc;a++) 
		{
			if (pinfo->formats[a].ctype==ctype) // found a "ctype" match...
				return [NSString stringWithFormat:@"%s", pinfo->formats[a].name]; // return it's name
		}
	}
	// check built-in stream formats...
	if (ctype==BASS_CTYPE_STREAM_OGG) return @"Ogg Vorbis";
	if (ctype==BASS_CTYPE_STREAM_MP1) return @"MPEG layer 1";
	if (ctype==BASS_CTYPE_STREAM_MP2) return @"MPEG layer 2";
	if (ctype==BASS_CTYPE_STREAM_MP3) return @"MPEG layer 3";
	if (ctype==BASS_CTYPE_STREAM_AIFF) return @"Audio IFF";
	if (ctype==BASS_CTYPE_STREAM_WAV_PCM) return @"PCM WAVE";
	if (ctype==BASS_CTYPE_STREAM_WAV_FLOAT) return @"Floating-point WAVE";
	if (ctype&BASS_CTYPE_STREAM_WAV) return @"WAVE";
	if (ctype==BASS_CTYPE_STREAM_CA) 
	{
		// CoreAudio codec
		static char buf[100];
		const TAG_CA_CODEC *codec=(TAG_CA_CODEC*)BASS_ChannelGetTags(fileStream1,BASS_TAG_CA_CODEC); // get codec info
		snprintf(buf,sizeof(buf),"CoreAudio: %s",codec->name);
		return [NSString stringWithFormat:@"%s", buf];
	}
	return @"?";
}

NSString *NSStringFromOSStatus(OSStatus errCode)
{
    if (errCode == noErr)
        return @"noErr";
    char message[5] = {0};
    *(UInt32*) message = CFSwapInt32HostToBig(errCode);
    return [NSString stringWithCString:message encoding:NSASCIIStringEncoding];
}

NSString *NSStringFromBassErrorCode(NSInteger errorCode)
{
	switch (errorCode)
	{
		case BASS_OK:				return @"No error! All OK";
		case BASS_ERROR_MEM:		return @"Memory error";
		case BASS_ERROR_FILEOPEN:	return @"Can't open the file";
		case BASS_ERROR_DRIVER:		return @"Can't find a free/valid driver";
		case BASS_ERROR_BUFLOST:	return @"The sample buffer was lost";
		case BASS_ERROR_HANDLE:		return @"Invalid handle";
		case BASS_ERROR_FORMAT:		return @"Unsupported sample format";
		case BASS_ERROR_POSITION:	return @"Invalid position";
		case BASS_ERROR_INIT:		return @"BASS_Init has not been successfully called";
		case BASS_ERROR_START:		return @"BASS_Start has not been successfully called";
		case BASS_ERROR_ALREADY:	return @"Already initialized/paused/whatever";
		case BASS_ERROR_NOCHAN:		return @"Can't get a free channel";
		case BASS_ERROR_ILLTYPE:	return @"An illegal type was specified";
		case BASS_ERROR_ILLPARAM:	return @"An illegal parameter was specified";
		case BASS_ERROR_NO3D:		return @"No 3D support";
		case BASS_ERROR_NOEAX:		return @"No EAX support";
		case BASS_ERROR_DEVICE:		return @"Illegal device number";
		case BASS_ERROR_NOPLAY:		return @"Not playing";
		case BASS_ERROR_FREQ:		return @"Illegal sample rate";
		case BASS_ERROR_NOTFILE:	return @"The stream is not a file stream";
		case BASS_ERROR_NOHW:		return @"No hardware voices available";
		case BASS_ERROR_EMPTY:		return @"The MOD music has no sequence data";
		case BASS_ERROR_NONET:		return @"No internet connection could be opened";
		case BASS_ERROR_CREATE:		return @"Couldn't create the file";
		case BASS_ERROR_NOFX:		return @"Effects are not available";
		case BASS_ERROR_NOTAVAIL:	return @"Requested data is not available";
		case BASS_ERROR_DECODE:		return @"The channel is a 'decoding channel'";
		case BASS_ERROR_DX:			return @"A sufficient DirectX version is not installed";
		case BASS_ERROR_TIMEOUT:	return @"Connection timedout";
		case BASS_ERROR_FILEFORM:	return @"Unsupported file format";
		case BASS_ERROR_SPEAKER:	return @"Unavailable speaker";
		case BASS_ERROR_VERSION:	return @"Invalid BASS version (used by add-ons)";
		case BASS_ERROR_CODEC:		return @"Codec is not available/supported";
		case BASS_ERROR_ENDED:		return @"The channel/file has ended";
		case BASS_ERROR_BUSY:		return @"The device is busy";
		case BASS_ERROR_UNKNOWN:
		default:					return @"Unknown error.";
	}
}

void BASSLogError()
{
	NSInteger errorCode = BASS_ErrorGetCode();
	DLog(@"BASS error: %i - %@", errorCode, NSStringFromBassErrorCode(errorCode));
}

- (void)printChannelInfo:(HSTREAM)channel
{
	BASS_CHANNELINFO i;
	BASS_ChannelGetInfo(fileStream1, &i);
	QWORD bytes = BASS_ChannelGetLength(channel, BASS_POS_BYTE);
	DWORD time = BASS_ChannelBytes2Seconds(channel, bytes);
	DLog("channel type = %x (%@)\nlength = %llu (%u:%02u)  flags: %i  freq: %i  origres: %i", i.ctype, [self stringFromStreamType:i.ctype plugin:i.plugin], bytes, time/60, time%60, i.flags, i.freq, i.origres);
}

- (void)preSilenceLengthInternal:(Song *)aSong
{
	// Create a decode channel
	const char *file = [aSong.localPath cStringUTF8];
	presilenceStream = BASS_StreamCreateFile(FALSE, file, 0, 0, BASS_STREAM_DECODE); // create decoding channel
	if (!presilenceStream) presilenceStream = BASS_StreamCreateFile(FALSE, file, 0, 0, BASS_SAMPLE_SOFTWARE|BASS_STREAM_DECODE);
}

- (QWORD)preSilenceLengthForSong:(Song *)aSong
{
	// Create a decode channel
	[self performSelectorOnMainThread:@selector(preSilenceLengthInternal:) withObject:aSong waitUntilDone:YES];
	/*if (BASS_Init(0, 44100, 0, NULL, NULL)) 	// Initialize default device.
	{
		// Create a decode channel
		const char *file = [aSong.localPath cStringUTF8];
		HSTREAM presilenceStream = BASS_StreamCreateFile(FALSE, file, 0, 0, BASS_STREAM_DECODE); // create decoding channel
		if (!presilenceStream) presilenceStream = BASS_StreamCreateFile(FALSE, file, 0, 0, BASS_SAMPLE_SOFTWARE|BASS_STREAM_DECODE);
	}
	else
	{
		DLog(@"Can't initialize BASS in background thread");
	}*/
	
	if (presilenceStream)
	{
		// Determine the silence length
		BYTE buf[10000];
		QWORD count=0;
		while (BASS_ChannelIsActive(presilenceStream)) 
		{
			int a,b = BASS_ChannelGetData(presilenceStream, buf, 10000); // decode some data
			for (a = 0; a < b && !buf[a]; a++) ; // count silent bytes
			count += a; // add number of silent bytes
			if (a < b) break; // sound has begun!
		}
		
		// Free the channel
		BASS_StreamFree(presilenceStream);
		
		DLog(@"silence: %llu", count);
		return count;
	}
	else
	{
		BASSLogError();
		return NSUIntegerMax;
	}
}

#pragma mark - Decode Stream Callbacks

void CALLBACK MyStreamFreeCallback(HSYNC handle, DWORD channel, DWORD data, void *user)
{
	if (user == NULL)
		return;
	
	// Stream is done, release the user info object
	BassUserInfo *userInfo = (BassUserInfo *)user;
	[userInfo release];
}

void CALLBACK MyFileCloseProc(void *user)
{	
	if (user == NULL)
		return;
	
	// Close the file handle
	BassUserInfo *userInfo = (BassUserInfo *)user;
	if (userInfo.myFileHandle == NULL)
		return;
	
	fclose(userInfo.myFileHandle);	
}

QWORD CALLBACK MyFileLenProc(void *user)
{
	if (user == NULL)
		return 0;
	
	@autoreleasepool
	{
		@synchronized([AudioEngine class])
		{
			BassUserInfo *userInfo = (BassUserInfo *)user;
			if (userInfo.myFileHandle == NULL)
				return 0;
			
			PlaylistSingleton *currentPlaylistDAO = sharedInstance.currPlaylistDAO;
			
			Song *theSong = [currentPlaylistDAO currentSong];
			if ([userInfo.mySong isEqualToSong:theSong])
			{
				// It's the current song
				//DLog(@"Checking file length for current song");
			}
			else
			{
				// It's not the current song so it's the next song
				//DLog(@"Checking file length for next song");
				theSong = [currentPlaylistDAO nextSong];
			}
			
			QWORD length = 0;
			if (theSong.isFullyCached || theSong.isTempCached)
			{
				// Return actual file size on disk
				NSString *path = theSong.isTempCached ? theSong.localTempPath : theSong.localPath;
				length = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL] fileSize];
			}
			else
			{
				// Return server reported file size
				length = [theSong.size longLongValue];
			}
			//DLog(@"File Length: %llu   isFullyCached: %@", length, NSStringFromBOOL(theSong.isFullyCached));
			return length;
		}
	}
}

DWORD CALLBACK MyFileReadProc(void *buffer, DWORD length, void *user)
{
	if (buffer == NULL || user == NULL)
		return 0;
	
	@autoreleasepool
	{
		// Read from the file
		BassUserInfo *userInfo = (BassUserInfo *)user;
		if (userInfo.myFileHandle == NULL)
			return 0;
		
		DWORD bytesRead = fread(buffer, 1, length, userInfo.myFileHandle);	
		
		if (bytesRead < length)
		{
			// Don't ever block the UI thread
			if (![[NSThread currentThread] isEqual:[NSThread mainThread]])
			{
				BassUserInfo *userInfo = (BassUserInfo *)user;
				PlaylistSingleton *currentPlaylistDAO = sharedInstance.currPlaylistDAO;
				
				Song *theSong = [currentPlaylistDAO currentSong];
				if ([userInfo.mySong isEqualToSong:theSong])
				{
					// It's the current song
					//DLog(@"Checking file length for current song");
				}
				else
				{
					// It's not the current song so it's the next song
					//DLog(@"Checking file length for next song");
					theSong = [currentPlaylistDAO nextSong];
				}
				
				SUSStreamSingleton *streamManager = [SUSStreamSingleton sharedInstance];
				if (!theSong.isFullyCached)
				{
					// Set the audio queue state to waiting for data
					sharedInstance.state = ISMS_AE_STATE_waitingForData;
					
					DLog(@"trying to read %i bytes,   bytes read: %i", length, bytesRead);
					// Clear the EOF indicator from the stream so it will resume reading
					// when more data is available
					fpos_t pos; 
					fgetpos(userInfo.myFileHandle, &pos);
					fpos_t newpos = pos - bytesRead;
					fsetpos(userInfo.myFileHandle, &newpos);
					
					[sharedInstance playPause];
					
					// We received less than we asked for, but the stream is not over
					// so we'll need to wait until more of the file is ready to play
					unsigned long long size = theSong.localFileSize;
					unsigned long long neededSize = size + ISMS_AQBytesToWaitForAudioData;
					NSTimeInterval sleepTime = 1.0; // Sleep for 1 second at a time
					DLog(@"AQ asked for: %i  got: %i  file size: %llu", length, bytesRead, theSong.localFileSize);
					while (!sharedInstance.audioQueueShouldStopWaitingForData 
						   && !theSong.isFullyCached && theSong.localFileSize < neededSize
						   && (theSong.isTempCached && ![theSong isEqualToSong:streamManager.lastTempCachedSong]))
					{
						// As long as audioQueueShouldStopWaitingForData is false, the song is not fully cached, and
						// the file size is less than the current size + 10 buffers worth of data, then wait
						DLog(@"Not enough data, sleeping for %f", sleepTime);
						[NSThread sleepForTimeInterval:sleepTime];
					}
					
					// Handle the case of a temp cached song that has ended
					if (theSong.isTempCached && ![theSong isEqualToSong:streamManager.lastTempCachedSong])
					{
						sharedInstance.state = ISMS_AE_STATE_finishedWaitingForData;
						return 0;
					}
					
					// The loop finished, so unless audioQueueShouldStopWaitingForData is true (meaning the wait was cancelled)
					// then call the queue callback again to enqueue more data
					if (!sharedInstance.audioQueueShouldStopWaitingForData)
					{
						// Do the read again
						bytesRead = fread(buffer, 1, length, userInfo.myFileHandle);
						DLog(@"trying again asked for: %i  got: %i  file size: %llu", length, bytesRead, theSong.localFileSize);
						
						if (sharedInstance.state != ISMS_AE_STATE_waitingForDataNoResume)
						{
							sharedInstance.state = ISMS_AE_STATE_finishedWaitingForData;
							[sharedInstance playPause];
						}
					}
					else
					{
						DLog(@"wait was cancelled, not calling the queue callback again");
						// Change the audio queue state
						sharedInstance.state = ISMS_AE_STATE_finishedWaitingForData;
					}
				}
			}
		}
		return bytesRead;
	}
}

BOOL CALLBACK MyFileSeekProc(QWORD offset, void *user)
{	
	if (user == NULL)
		return NO;
	
	// Seek to the requested offset (returns false if data not downloaded that far)
	BassUserInfo *userInfo = (BassUserInfo *)user;
	if (userInfo.myFileHandle == NULL)
		return NO;
	
	BOOL success = !fseek(userInfo.myFileHandle, offset, SEEK_SET);
	
	DLog(@"File Seek to %llu  success: %@", offset, NSStringFromBOOL(success));
	
	return success;
}

BASS_FILEPROCS fileProcs = {MyFileCloseProc, MyFileLenProc, MyFileReadProc, MyFileSeekProc};

#pragma mark - Output stream callbacks

- (DWORD)bassGetOutputData:(void *)buffer length:(DWORD)length
{	
	DWORD r;
	
	if (BASS_ChannelIsActive(self.currentStream))
	{		
		r = BASS_ChannelGetData(self.currentReadingStream, buffer, length);
		
		// Check if stream is now complete
		if (!BASS_ChannelIsActive(self.currentStream))
		{
			// Stream is done, free the stream
			DLog(@"current stream: %u  currentStreamTempo: %u", self.currentStream, self.currentStreamTempo); 
			if (self.currentStreamTempo) BASS_StreamFree(self.currentStreamTempo);
			BASS_StreamFree(self.currentStream);
			DLog(@"freed current stream: %u  currentStreamTempo: %u", self.currentStream, self.currentStreamTempo); 
			
			// Increment current playlist index
			[currPlaylistDAO incrementIndex];
			
			// Send song end notification
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackEnded];
			
			// Flip the current/next streams
			BASSisFilestream1 = !BASSisFilestream1;
			
			// Check if the frequency of this stream matches the BASS output
			if (self.bassReinitSampleRate)
			{
				// The sample rates don't match, so re-init bass
				[self performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
				
				r = BASS_STREAMPROC_END;
			}
			else
			{
				startSecondsOffset = 0;
				startByteOffset = 0;
				
				// Send song start notification
				[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackStarted];
				
				// Prepare the next song for playback
				[self prepareNextSongStreamInBackground];
				
				r = [self bassGetOutputData:buffer length:length];
				
				// Mark the last played time in the database for cache cleanup
				currPlaylistDAO.currentSong.playedDate = [NSDate date];
			}
		}
	}
	else
	{
		DLog(@"Stream not active, freeing BASS");
		r = BASS_STREAMPROC_END;
		[self performSelectorOnMainThread:@selector(bassFree) withObject:nil waitUntilDone:NO];
		
		// Handle song caching being disabled
		SavedSettings *settings = [SavedSettings sharedInstance];
		if (!settings.isSongCachingEnabled || !settings.isNextSongCacheEnabled)
		{
			MusicSingleton *musicControls = [MusicSingleton sharedInstance];
			[musicControls performSelectorOnMainThread:@selector(startSong) withObject:nil waitUntilDone:NO];
		}
	}
	
	return r;
}

DWORD CALLBACK MyStreamProc(HSTREAM handle, void *buffer, DWORD length, void *user)
{
	return [sharedInstance bassGetOutputData:buffer length:length];
}

#pragma mark - Audio Session methods

void audioRouteChangeListenerCallback(void *inUserData, AudioSessionPropertyID inPropertyID, UInt32 inPropertyValueSize, const void *inPropertyValue) 
{	
	AudioEngine *selfRef = inUserData;
	
    DLog(@"audioRouteChangeListenerCallback called");
	
    // ensure that this callback was invoked for a route change
    if (inPropertyID != kAudioSessionProperty_AudioRouteChange) 
		return;
	
	if ([selfRef isPlaying])
	{
		// Determines the reason for the route change, to ensure that it is not
		// because of a category change.
		CFDictionaryRef routeChangeDictionary = inPropertyValue;
		CFNumberRef routeChangeReasonRef = CFDictionaryGetValue (routeChangeDictionary, CFSTR (kAudioSession_AudioRouteChangeKey_Reason));
		SInt32 routeChangeReason;
		CFNumberGetValue (routeChangeReasonRef, kCFNumberSInt32Type, &routeChangeReason);
		
        // "Old device unavailable" indicates that a headset was unplugged, or that the
        // device was removed from a dock connector that supports audio output. This is
        // the recommended test for when to pause audio.
        if (routeChangeReason == kAudioSessionRouteChangeReason_OldDeviceUnavailable) 
		{
			[selfRef playPause];
			
            DLog (@"Output device removed, so application audio was paused.");
        }
		else 
		{
            DLog (@"A route change occurred that does not require pausing of application audio.");
        }
    }
	else 
	{	
        DLog (@"Audio route change while application audio is stopped.");
        return;
    }
}

void audioInterruptionListenerCallback (void *inUserData, AudioSessionPropertyID inPropertyID, UInt32 inPropertyValueSize, const void *inPropertyValue) 
{
	DLog(@"audio interrupted");
	AudioEngine *selfRef = inUserData;
	[selfRef pause];
}

/*void interruptionListenerCallback (void    *inUserData, UInt32  interruptionState) 
{
    if (interruptionState == kAudioSessionBeginInterruption) 
	{
		DLog(@"audio session begin interruption");		
    } 
	else if (interruptionState == kAudioSessionEndInterruption) 
	{
        DLog(@"audio session interruption ended");
    }
}*/

- (NSInteger)audioSessionSampleRate
{
	Float64 sampleRate;
	UInt32 size = sizeof(Float64);
	OSStatus status = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, 
											  &size, 
											  &sampleRate);
	DLog(@"sample rate: %i   status: %@", (NSUInteger)sampleRate, NSStringFromOSStatus(status));
	
	return (NSUInteger)sampleRate;
}

- (void)setAudioSessionSampleRate:(NSInteger)audioSessionSampleRate
{
	Float64 sampleRateFloat = (Float64)audioSessionSampleRate;
	AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareSampleRate, 
							sizeof(sampleRateFloat), 
							&sampleRateFloat);
}

#pragma mark - BASS methods

- (void)bassSetGainLevel:(float)gain
{
	BASS_BFX_VOLUME volumeParamsInit = {0, gain};
	BASS_BFX_VOLUME *volumeParams = &volumeParamsInit;
	BASS_FXSetParameters(volumeFx, volumeParams);
}

- (void)bassInit:(NSUInteger)sampleRate
{
	// Sample rate doesn't matter now that an audio queue is used for output
	
	// Destroy any existing BASS instance
	[self bassFree];
	
	// Initialize BASS
	BASS_SetConfig(BASS_CONFIG_IOS_MIXAUDIO, 0); // Disable mixing.	To be called before BASS_Init.
	DWORD updatePeriod = BASS_GetConfig(BASS_CONFIG_UPDATEPERIOD); // get update period
	BASS_SetConfig(BASS_CONFIG_BUFFER, updatePeriod + 200); // set the buffer length to the minimum amount + 200ms
	DLog(@"buffer size: %i", BASS_GetConfig(BASS_CONFIG_BUFFER));
	BASS_SetConfig(BASS_CONFIG_FLOATDSP, true); // set DSP effects to use floating point math to avoid clipping within the effects chain
	if (!BASS_Init(-1, sampleRate, 0, NULL, NULL)) 	// Initialize default device.
	{
		DLog(@"Can't initialize device");
	}
	BASS_PluginLoad(&BASSFLACplugin, 0); // load the FLAC plugin
	
	BASS_INFO info;
	BASS_GetInfo(&info);
	DLog(@"bassInit:%i  bass freq: %i", sampleRate, info.freq);
	
	// Add the callbacks for headphone removal and other audio takeover
	AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, audioRouteChangeListenerCallback, self);
	AudioSessionAddPropertyListener(kAudioSessionProperty_OtherAudioIsPlaying, audioInterruptionListenerCallback, self);
}

- (void)bassInit
{
	// Default to 44.1 KHz
    [self bassInit:ISMS_defaultSampleRate];
}

- (BOOL)bassFree
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(retryStartAtOffset:) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(prepareNextSongStreamInBackground) object:nil];
	
	BOOL success = BASS_Free();
	fileStream1 = 0;
	fileStreamTempo1 = 0;
	fileStream2 = 0;
	fileStreamTempo2 = 0;
	outStream = 0;
	volumeFx = 0;
	bassReinitSampleRate = 0;
	
	return success;
}

- (NSInteger)bassSampleRate
{
	static BASS_INFO info;
	if (BASS_GetInfo(&info))
		return info.freq;
	
	return 0;
}

- (NSInteger)bassStreamSampleRate:(HSTREAM)stream
{
	float sampleRate = 0;
	BASS_ChannelGetAttribute(stream, BASS_ATTRIB_FREQ, &sampleRate);
	DLog(@"BASS Stream sample rate: %i", (NSUInteger)sampleRate);
	return (NSInteger)sampleRate;
}

#pragma mark - Audio Engine methods

- (NSInteger)preferredSampleRate:(NSUInteger)sampleRate
{
	NSInteger preferredSampleRate = 0;
	if (sampleRate < 48000)
		preferredSampleRate = sampleRate;
	else if (sampleRate % 44100 == 0)
		preferredSampleRate = 44100;
	else
		preferredSampleRate = 48000;
	
	DLog(@"sample rate: %i preferred sample rate: %i", sampleRate, preferredSampleRate);
	
	return preferredSampleRate;
}

- (void)seekToPositionInBytes:(QWORD)bytes inStream:(HSTREAM)stream
{
	//DLog(@"fileStream1: %i   fileStream2: %i    currentStream: %i", fileStream1, fileStream2, self.currentStream);
	if (BASS_ChannelSetPosition(stream, bytes, BASS_POS_BYTE))
	{
		startByteOffset = bytes;
	}
	else
	{
		BASSLogError();
	}
}

- (void)seekToPositionInBytes:(QWORD)bytes
{
	[self seekToPositionInBytes:bytes inStream:self.currentStream];
}

- (void)seekToPositionInSeconds:(NSUInteger)seconds inStream:(HSTREAM)stream
{
	NSUInteger bytes = BASS_ChannelSeconds2Bytes(stream, seconds);
	DLog(@"seconds: %i   bytes: %i", seconds, bytes);
	[self seekToPositionInBytes:bytes inStream:stream];
}

- (void)seekToPositionInSeconds:(NSUInteger)seconds
{
	[self seekToPositionInSeconds:seconds inStream:self.currentStream];
}

- (void)retryPrepareNextSongStreamInBackground
{
	@autoreleasepool 
	{
		[self performSelector:@selector(prepareNextSongStreamInBackground) withObject:nil afterDelay:RETRY_DELAY];
	}
}

- (void)prepareNextSongStreamInBackground
{
	@autoreleasepool 
	{
		[self performSelectorInBackground:@selector(prepareNextSongStream) withObject:nil];
	}
}

- (void)prepareNextSongStream
{
	@autoreleasepool 
	{
		Song *nextSong = currPlaylistDAO.nextSong;
		if (nextSong.fileExists)
		{
			NSUInteger silence = [self preSilenceLengthForSong:nextSong];
			if (silence == NSUIntegerMax && !nextSong.isFullyCached && nextSong.localFileSize < MIN_FILESIZE_TO_FAIL)
			{
				DLog(@"------failed to get silence, retrying in 2 seconds------");
				[self performSelectorOnMainThread:@selector(retryPrepareNextSongStreamInBackground) withObject:nil waitUntilDone:NO];
			}
			else
			{
				DLog(@"found silence length for next song, calling prepareNextSongStreamInternal:");
				if (silence == NSUIntegerMax)
					silence = 0;
				[self performSelectorOnMainThread:@selector(prepareNextSongStreamInternal:) withObject:[NSNumber numberWithInt:silence] waitUntilDone:NO];
			}
		}
		else
		{
			DLog(@"next song file does not exist");
		}
	}
}

// main thread
- (void)prepareNextSongStreamInternal:(NSNumber *)silence
{
	self.bassReinitSampleRate = 0;
	
	DLog(@"preparing next song stream internally");
	Song *nextSong = currPlaylistDAO.nextSong;
	
	BassUserInfo *userInfo = [[BassUserInfo alloc] init];
	userInfo.mySong = nextSong;
	userInfo.myFileHandle = fopen([nextSong.currentPath cStringUTF8], "rb");
		
	// Try hardware and software mixing
	self.nextStream = BASS_StreamCreateFileUser(STREAMFILE_NOBUFFER, BASS_STREAM_DECODE, &fileProcs, userInfo);
	if(!self.nextStream) self.nextStream = BASS_StreamCreateFileUser(STREAMFILE_NOBUFFER, BASS_SAMPLE_SOFTWARE|BASS_STREAM_DECODE, &fileProcs, userInfo);

	if (self.nextStream)
	{
		// Set the stream free sync
		BASS_ChannelSetSync(self.nextStream, BASS_SYNC_FREE, 0, MyStreamFreeCallback, userInfo);
		
		// Verify we're using the best sample rate
		NSInteger streamSampleRate = [self bassStreamSampleRate:fileStream1];
		NSInteger preferredSampleRate = [self preferredSampleRate:streamSampleRate];
		NSInteger bassSampleRate = [self bassSampleRate];
		
		if (bassSampleRate != preferredSampleRate)
		{
			// Set a flag to know to re-init BASS later
			self.bassReinitSampleRate = preferredSampleRate;
		}
		else
		{
			// Check to see if the output sample rate is the same as the stream sample rate
			// and the stream sample rate is higher than 96KHz
			if (bassSampleRate != streamSampleRate && streamSampleRate > 96000)
			{
				// It's a high sample rate file, so to prevent a lot of whitenoise, use a mixer
				// stream and apply the resampling filter
				self.nextStreamTempo = BASS_Mixer_StreamCreate(bassSampleRate, 
															   2, 
															   BASS_STREAM_DECODE|BASS_MIXER_END);
				if (self.nextStreamTempo)
				{
					BASS_Mixer_StreamAddChannel(self.nextStreamTempo, 
												self.nextStream, 
												BASS_MIXER_FILTER|BASS_MIXER_BUFFER|BASS_MIXER_NORAMPIN);
				}
				else
				{
					BASSLogError();
				}
			}
			
			// Seek to the silence offset
			[self seekToPositionInBytes:[silence unsignedLongLongValue] inStream:self.nextStream];
		}
	}
	else
	{
		NSInteger errorCode = BASS_ErrorGetCode();
		DLog(@"nextSong stream: %i error: %i - %@", self.nextStream, errorCode, NSStringFromBassErrorCode(errorCode));
	}
	
	DLog(@"nextSong: %i", self.nextStream);
}

- (BOOL)prepareFileStream1
{
	Song *currentSong = currPlaylistDAO.currentSong;
	if (currentSong.fileExists)
	{	
		// Create the user info object for the stream
		BassUserInfo *userInfo = [[BassUserInfo alloc] init];
		userInfo.mySong = currentSong;
		userInfo.myFileHandle = fopen([currentSong.currentPath cStringUTF8], "rb");
		if (userInfo.myFileHandle == NULL)
		{
			// File failed to open
			DLog(@"File failed to open");
			return NO;
		}
				
		// Create the stream
		fileStream1 = BASS_StreamCreateFileUser(STREAMFILE_NOBUFFER, BASS_STREAM_DECODE, &fileProcs, userInfo);
		if(!fileStream1) fileStream1 = BASS_StreamCreateFileUser(STREAMFILE_NOBUFFER, BASS_SAMPLE_SOFTWARE|BASS_STREAM_DECODE, &fileProcs, userInfo);
		if (fileStream1)
		{
			// Add the stream free callback
			BASS_ChannelSetSync(fileStream1, BASS_SYNC_FREE, 0, MyStreamFreeCallback, userInfo);
			
			// Stream successfully created
			return YES;
		}
		
		// Failed to create the stream
		DLog(@"failed to create stream");
		return NO;
	}
	
	// File doesn't exist
	return NO;
}

- (void)retryStartAtOffset:(NSDictionary *)parameters
{
	NSNumber *byteOffset = [parameters objectForKey:@"byteOffset"];
	NSNumber *seconds = [parameters objectForKey:@"seconds"]; 
	
	[self startWithOffsetInBytes:byteOffset orSeconds:seconds];
}

- (void)startWithOffsetInBytes:(NSNumber *)byteOffset orSeconds:(NSNumber *)seconds
{	
	NSInteger count = currPlaylistDAO.count;
	if (currPlaylistDAO.currentIndex >= count) currPlaylistDAO.currentIndex = count - 1;
	
	Song *currentSong = currPlaylistDAO.currentSong;
	if (!currentSong)
		return;
	
	startByteOffset = 0;
	startSecondsOffset = 0;
	BASSisFilestream1 = YES;
	
	[self bassInit];
	
	if (currentSong.fileExists)
	{
		if ([self prepareFileStream1])
		{
			// Verify we're using the best sample rate
			NSInteger streamSampleRate = [self bassStreamSampleRate:fileStream1];
			NSInteger preferredSampleRate = [self preferredSampleRate:streamSampleRate];
			NSInteger bassSampleRate = [self bassSampleRate];
			
			// Check if the output sample rate equals the preferred sample rate
			if (bassSampleRate != preferredSampleRate)
			{
				// Reinitialize BASS to the preferred sample rate
				[self bassInit:preferredSampleRate];
				
				// Reinitialize stream 1
				[self prepareFileStream1];
				
				// Update the values
				bassSampleRate = [self bassSampleRate];
				streamSampleRate = [self bassStreamSampleRate:fileStream1];
			}
			
			// Check again to see if the output sample rate is the same as the stream sample rate
			// and the stream sample rate is higher than 96KHz
			if (bassSampleRate != streamSampleRate && streamSampleRate > 96000)
			{
				// It's a high sample rate file, so to prevent a lot of whitenoise, use a mixer
				// stream and apply the resampling filter
				fileStreamTempo1 = BASS_Mixer_StreamCreate(bassSampleRate, 
														   2, 
														   BASS_STREAM_DECODE|BASS_MIXER_END);
				if (fileStreamTempo1)
				{
					BASS_Mixer_StreamAddChannel(fileStreamTempo1, 
												fileStream1, 
												BASS_MIXER_FILTER|BASS_MIXER_BUFFER|BASS_MIXER_NORAMPIN);
				}
				else
				{
					BASSLogError();
				}
			}
			
			// Skip to the byte offset
			if (byteOffset)
			{
				startByteOffset = [byteOffset unsignedLongLongValue];
				if (startByteOffset > 0)
					[self seekToPositionInBytes:startByteOffset inStream:fileStream1];
			}
			else if (seconds)
			{
				startSecondsOffset = [seconds doubleValue];
				if (startSecondsOffset > 0.0)
					[self seekToPositionInSeconds:startSecondsOffset inStream:fileStream1];
			}
			
			// Create the output stream
			BASS_CHANNELINFO info;
			BASS_ChannelGetInfo(self.currentReadingStream, &info);
			outStream = BASS_StreamCreate(info.freq, info.chans, 0, &MyStreamProc, 0);
			
			// Enable the equalizer if it's turned on
			if (isEqualizerOn)
			{
				[self applyEqualizerValues:eqValueArray toStream:outStream];
			}
			
			// Add gain amplification
			volumeFx = BASS_ChannelSetFX(outStream, BASS_FX_BFX_VOLUME, 1);
			
			// Start playback
			BASS_ChannelPlay(outStream, FALSE);
			isPlaying = YES;
			
			// Prepare the next song
			[self performSelectorInBackground:@selector(prepareNextSongStream) withObject:nil];
			
			// Notify listeners that playback has started
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackStarted];
			
			currentSong.playedDate = [NSDate date];
		}
		else if (!fileStream1 && !currentSong.isFullyCached && currentSong.localFileSize < MIN_FILESIZE_TO_FAIL)
		{
			// Failed to create the stream, retrying
			DLog(@"------failed to create stream, retrying in 2 seconds------");
			NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:2];
			if (byteOffset) [parameters setObject:byteOffset forKey:@"byteOffset"];
			if (seconds) [parameters setObject:seconds forKey:@"seconds"];
			[self performSelector:@selector(retryStartAtOffset:) withObject:parameters afterDelay:RETRY_DELAY];
		}
	}
}

- (void)start
{
	[self startWithOffsetInBytes:[NSNumber numberWithInt:0] orSeconds:nil];
}

- (void)stop
{
    if (self.isPlaying) 
	{
		BASS_Pause();
		isPlaying = NO;
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
		DLog(@"Pausing");
		BASS_Pause();
		isPlaying = NO;
		
		if (state != ISMS_AE_STATE_waitingForData)
		{
			state = ISMS_AE_STATE_paused;
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackPaused];
		}
	} 
	else 
	{
		if (self.currentStream == 0)
		{
			DLog(@"starting new stream");
			NSInteger count = currPlaylistDAO.count;
			if (currPlaylistDAO.currentIndex >= count) currPlaylistDAO.currentIndex = count;
			[[MusicSingleton sharedInstance] startSongAtOffsetInBytes:startByteOffset 
														   andSeconds:startSecondsOffset];
		}
		else if (state == ISMS_AE_STATE_waitingForData)
		{
			state = ISMS_AE_STATE_waitingForDataNoResume;
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackPaused];
		}
		else
		{
			DLog(@"Playing");
			BASS_Start();
			isPlaying = YES;
			
			if (state != ISMS_AE_STATE_finishedWaitingForData)
			{
				[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackStarted];
			}

			state = ISMS_AE_STATE_playing;
		}
	}
}

#pragma mark - Audio Engine Properties

- (NSInteger)bitRate
{
	HSTREAM stream = self.currentStream;
	
	QWORD startFilePosition = BASS_StreamGetFilePosition(stream, BASS_FILEPOS_START);
	QWORD currentFilePosition = BASS_StreamGetFilePosition(stream, BASS_FILEPOS_CURRENT);
	
	QWORD filePosition = currentFilePosition - startFilePosition;
	QWORD decodedPosition = BASS_ChannelGetPosition(stream, BASS_POS_BYTE|BASS_POS_DECODE); // decoded PCM position
	double bitrate = filePosition * 8 / BASS_ChannelBytes2Seconds(stream, decodedPosition);
	
	NSUInteger retBitrate = (NSUInteger)(bitrate / 1000);

	return retBitrate > 1000000 ? -1 : retBitrate;
}

- (QWORD)currentByteOffset
{
	return BASS_StreamGetFilePosition(self.currentStream, BASS_FILEPOS_CURRENT) + startByteOffset;
}

- (double)progress
{	
	NSUInteger pcmBytePosition = BASS_ChannelGetPosition(self.currentStream, BASS_POS_BYTE|BASS_POS_DECODE);// + startByteOffset;
	double seconds = BASS_ChannelBytes2Seconds(self.currentStream, pcmBytePosition);
	if (seconds < 0 && self.currentStream != 0)
		BASSLogError();

	return seconds + startSecondsOffset;
}

- (HSTREAM)currentStream
{
	return BASSisFilestream1 ? fileStream1 : fileStream2;
}

- (void)setCurrentStream:(HSTREAM)stream
{
	if (BASSisFilestream1)
		fileStream1 = stream;
	else
		fileStream2 = stream;
}

- (HSTREAM)currentStreamTempo
{
	return BASSisFilestream1 ? fileStreamTempo1 : fileStreamTempo2;
}

- (void)setCurrentStreamTempo:(HSTREAM)stream
{
	if (BASSisFilestream1)
		fileStreamTempo1 = stream;
	else
		fileStreamTempo2 = stream;
}

- (HSTREAM)currentReadingStream
{
	return self.currentStreamTempo ? self.currentStreamTempo : self.currentStream;
}

- (HSTREAM)nextStream
{
	return BASSisFilestream1 ? fileStream2 : fileStream1;
}

- (void)setNextStream:(HSTREAM)stream
{
	if (BASSisFilestream1)
		fileStream2 = stream;
	else
		fileStream1 = stream;
}

- (HSTREAM)nextStreamTempo
{
	return BASSisFilestream1 ? fileStreamTempo2 : fileStreamTempo1;
}

- (void)setNextStreamTempo:(HSTREAM)stream
{
	if (BASSisFilestream1)
		fileStreamTempo2 = stream;
	else
		fileStreamTempo1 = stream;
}

- (HSTREAM)nextReadingStream
{
	return self.nextStreamTempo ? self.nextStreamTempo : self.nextStream;
}

#pragma mark - Equalizer and Visualizer Methods

- (void)clearEqualizerValuesFromStream:(HSTREAM)stream
{
	int i = 0;
	for (BassEffectHandle *handle in eqHandleArray)
	{
		BASS_ChannelRemoveFX(stream, handle.effectHandle);
		i++;
	}
	
	for (BassParamEqValue *value in eqValueArray)
	{
		value.handle = 0;
	}
	
	DLog(@"removed %i effect channels", i);
	[eqHandleArray removeAllObjects];
	isEqualizerOn = NO;
}

- (void)clearEqualizerValues
{
	//[self clearEqualizerValuesFromStream:fileStream1];
	//[self clearEqualizerValuesFromStream:fileStream2];
	[self clearEqualizerValuesFromStream:outStream];
}

- (void)applyEqualizerValues:(NSArray *)values toStream:(HSTREAM)stream
{
	if (values == nil)
		return;
	else if ([values count] == 0)
		return;
	
	for (BassParamEqValue *value in eqValueArray)
	{
		HFX handle = BASS_ChannelSetFX(stream, BASS_FX_DX8_PARAMEQ, 0);
		BASS_DX8_PARAMEQ p = value.parameters;
		BASS_FXSetParameters(handle, &p);
		
		value.handle = handle;
		
		[eqHandleArray addObject:[BassEffectHandle handleWithEffectHandle:handle]];
	}
	isEqualizerOn = YES;
}

- (void)applyEqualizerValues:(NSArray *)values
{
	//[self applyEqualizerValues:values toStream:fileStream1];
	//[self applyEqualizerValues:values toStream:fileStream2];
	[self applyEqualizerValues:values toStream:outStream];
}

- (void)updateEqParameter:(BassParamEqValue *)value
{
	[eqValueArray replaceObjectAtIndex:value.arrayIndex withObject:value]; 
	
	if (isEqualizerOn)
	{
		BASS_DX8_PARAMEQ p = value.parameters;
		DLog(@"updating eq for handle: %i   new freq: %f   new gain: %f", value.handle, p.fCenter, p.fGain);
		BASS_FXSetParameters(value.handle, &p);
	}
}

- (BassParamEqValue *)addEqualizerValue:(BASS_DX8_PARAMEQ)value
{
	NSUInteger newIndex = [eqValueArray count];
	BassParamEqValue *eqValue = [BassParamEqValue valueWithParams:value arrayIndex:newIndex];
	[eqValueArray addObject:eqValue];
	
	if (isEqualizerOn)
	{
		HFX handle = BASS_ChannelSetFX(self.currentStream, BASS_FX_DX8_PARAMEQ, 0);
		BASS_FXSetParameters(handle, &value);
		eqValue.handle = handle;
		
		[eqHandleArray addObject:[BassEffectHandle handleWithEffectHandle:handle]];
	}
	
	return eqValue;
}

- (NSArray *)removeEqualizerValue:(BassParamEqValue *)value
{
	if (isEqualizerOn)
	{
		// Disable the effect channel
		BASS_ChannelRemoveFX(self.currentStream, value.handle);
	}
	
	// Remove the handle
	[eqHandleArray removeObject:[BassEffectHandle handleWithEffectHandle:value.handle]];
	
	// Remove the value
	[eqValueArray removeObject:value];
	for (int i = value.arrayIndex; i < [eqValueArray count]; i++)
	{
		// Adjust the arrayIndex values for the other objects
		BassParamEqValue *aValue = [eqValueArray objectAtIndex:i];
		aValue.arrayIndex = i;
	}
	
	return self.equalizerValues;
}

- (void)removeAllEqualizerValues
{
	[self clearEqualizerValues];
	
	[eqValueArray removeAllObjects];
}

- (BOOL)toggleEqualizer
{
	if (isEqualizerOn)
	{
		[self clearEqualizerValues];
		return NO;
	}
	else
	{
		[self applyEqualizerValues:eqValueArray];
		return YES;
	}
}

- (NSArray *)equalizerValues
{
	return [NSArray arrayWithArray:eqValueArray];
}

- (float)fftData:(NSUInteger)index
{
	return fftData[index];
}

- (short)lineSpecData:(NSUInteger)index
{
    return lineSpecBuf[index];
}

- (void)stopReadingEqData
{
	eqDataType = ISMS_BASS_EQ_DATA_TYPE_none;
}

- (void)startReadingEqData:(ISMS_BASS_EQ_DATA_TYPE)type
{	
	eqDataType = type;
}

- (void)readEqData
{
	[self performSelector:@selector(readEqDataInternal) onThread:fftDataThread withObject:nil waitUntilDone:NO];
}

- (void)readEqDataInternal
{
	// Get the FFT data for visualizer
	if (eqDataType == ISMS_BASS_EQ_DATA_TYPE_fft)
		BASS_ChannelGetData(outStream, fftData, BASS_DATA_FFT2048);
	
	// Get the data for line spec visualizer
	if (eqDataType == ISMS_BASS_EQ_DATA_TYPE_line)
		BASS_ChannelGetData(outStream, lineSpecBuf, lineSpecBufSize);
}

#pragma mark - Singleton methods

- (void)setup
{	
	bassReinitSampleRate = 0;
	state = ISMS_AE_STATE_stopped;
	audioQueueShouldStopWaitingForData = NO;
	BASSisFilestream1 = YES;
	fileStream1 = 0;
	fileStreamTempo1 = 0;
	fileStream2 = 0;
	fileStreamTempo2 = 0;
	outStream = 0;
	eqDataType = ISMS_BASS_EQ_DATA_TYPE_none;
	isFastForward = NO;
	isPlaying = NO;
	isEqualizerOn = NO;
    startByteOffset = 0;
    currPlaylistDAO = [PlaylistSingleton sharedInstance];
    
	eqValueArray = [[NSMutableArray alloc] initWithCapacity:4];
	eqHandleArray = [[NSMutableArray alloc] initWithCapacity:4];
	BassEffectDAO *effectDAO = [[BassEffectDAO alloc] initWithType:BassEffectType_ParametricEQ];
	[effectDAO selectPresetId:effectDAO.selectedPresetId];
	
	fftDataThread = [[NSThread alloc] initWithTarget:self selector:@selector(fftDataThreadEntryPoint) object:nil];
	[fftDataThread start];
	if (SCREEN_SCALE() == 1.0 && !IS_IPAD())
		lineSpecBufSize = 256 * sizeof(short);
	else
		lineSpecBufSize = 512 * sizeof(short);
	lineSpecBuf = malloc(lineSpecBufSize);
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepareNextSongStreamInBackground) name:ISMSNotification_RepeatModeChanged object:nil];
	
	/*// On iOS 4.0+ only, listen for background notification
	if(&UIApplicationDidEnterBackgroundNotification != nil)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bassEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
	}
	
	// On iOS 4.0+ only, listen for foreground notification
	if(&UIApplicationWillEnterForegroundNotification != nil)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bassEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
	}*/
}

+ (AudioEngine *)sharedInstance
{
    @synchronized(self)
    {
		if (sharedInstance == nil)
		{
			[[self alloc] init];
		}
    }
    return sharedInstance;
}

-(id)init 
{
	if ((self = [super init]))
	{
		sharedInstance = self;
		[self setup];
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

- (void)fftDataThreadEntryPoint
{
	 NSAutoreleasePool* thePool = [[NSAutoreleasePool alloc] init];
	
	isFftDataThreadToTerminate = NO;

	// Create a scheduled timer to keep runloop alive
	NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(fftThreadEmptyMethod) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
	
	// Start a runloop so we can call performSelector:onThread: to use this thread
	NSTimeInterval resolution = 300.0;
	BOOL isRunning;
	do 
	{
		// Run the loop!
		NSDate* theNextDate = [NSDate dateWithTimeIntervalSinceNow:resolution]; 
		isRunning = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:theNextDate]; 
		
		// Clear the autorelease pool after each run of the loop to prevent a memory leak
		[thePool release];
		thePool = [[NSAutoreleasePool alloc] init];            
	} 
	while(isRunning && !isFftDataThreadToTerminate);
}
- (void)fftThreadEmptyMethod {}

@end