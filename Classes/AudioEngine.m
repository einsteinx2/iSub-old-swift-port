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
#import "ISMSStreamManager.h"
#import "NSMutableURLRequest+SUS.h"
#import "MusicSingleton.h"
#import "NSArray+Additions.h"
#import "SocialSingleton.h"

// TODO: verify secondsOffset usage

@implementation AudioEngine
@synthesize isEqualizerOn, startByteOffset, startSecondsOffset, fftDataThread, isFftDataThreadToTerminate, isPlaying, isFastForward, bassReinitSampleRate, presilenceStream, bufferLengthMillis, bassUpdatePeriod;
@synthesize fileStream1, fileStream2, fileStreamTempo1, fileStreamTempo2, volumeFx, outStream, BASSisFilestream1, currentStreamSyncObject;
@synthesize eqValueArray, eqHandleArray, eqDataType, eqReadSyncObject, bassUserInfoDict;//fileStreamUserInfo1, fileStreamUserInfo2;
@synthesize shouldResumeFromInterruption;
@synthesize startSongThread;
@synthesize hasTweeted, hasNotifiedSubsonic, hasScrobbled;

// BASS plugins
extern void BASSFLACplugin;

// Singleton object
static AudioEngine *sharedInstance = nil;

#pragma mark - Helper Functions

- (NSString *)stringFromStreamType:(DWORD)ctype plugin:(HPLUGIN)plugin
{
	/*if (plugin) 
	{ 
		// using a plugin
		const BASS_PLUGININFO *pinfo=BASS_PluginGetInfo(plugin); // get plugin info
		int a;
		for (a=0;a<pinfo->formatc;a++) 
		{
			if (pinfo->formats[a].ctype==ctype) // found a "ctype" match...
				return [NSString stringWithFormat:@"%s", pinfo->formats[a].name]; // return it's name
		}
	}*/ 
	// check built-in stream formats...
	if (ctype==BASS_CTYPE_STREAM_FLAC) return @"FLAC";
	if (ctype==BASS_CTYPE_STREAM_FLAC_OGG) return @"FLAC";
	if (ctype==BASS_CTYPE_STREAM_OGG) return @"OGG";
	if (ctype==BASS_CTYPE_STREAM_MP1) return @"MP1";
	if (ctype==BASS_CTYPE_STREAM_MP2) return @"MP2";
	if (ctype==BASS_CTYPE_STREAM_MP3) return @"MP3";
	if (ctype==BASS_CTYPE_STREAM_AIFF) return @"AIFF";
	if (ctype==BASS_CTYPE_STREAM_WAV_PCM) return @"PCM WAV";
	if (ctype==BASS_CTYPE_STREAM_WAV_FLOAT) return @"Float WAV";
	if (ctype&BASS_CTYPE_STREAM_WAV) return @"WAV";
	if (ctype==BASS_CTYPE_STREAM_CA) 
	{
		// CoreAudio codec
		const TAG_CA_CODEC *codec = (TAG_CA_CODEC*)BASS_ChannelGetTags(self.fileStream1, BASS_TAG_CA_CODEC); // get codec info
				
		const char *type;
		switch (codec->atype) 
		{
			case kAudioFormatLinearPCM:				type = "LPCM"; break;
			case kAudioFormatAC3:					type = "AC3"; break;
			case kAudioFormat60958AC3:				type = "AC3"; break;
			case kAudioFormatAppleIMA4:				type = "IMA4"; break;
			case kAudioFormatMPEG4AAC:				type = "AAC"; break;
			case kAudioFormatMPEG4CELP:				type = "CELP"; break;
			case kAudioFormatMPEG4HVXC:				type = "HVXC"; break;
			case kAudioFormatMPEG4TwinVQ:			type = "TwinVQ"; break;
			case kAudioFormatMACE3:					type = "MACE 3:1"; break;
			case kAudioFormatMACE6:					type = "MACE 6:1"; break;
			case kAudioFormatULaw:					type = "μLaw 2:1"; break;
			case kAudioFormatALaw:					type = "aLaw 2:1"; break;
			case kAudioFormatQDesign:				type = "QDMC"; break;
			case kAudioFormatQDesign2:				type = "QDM2"; break;
			case kAudioFormatQUALCOMM:				type = "QCPV"; break;
			case kAudioFormatMPEGLayer1:			type = "MP1"; break;
			case kAudioFormatMPEGLayer2:			type = "MP2"; break;
			case kAudioFormatMPEGLayer3:			type = "MP3"; break;
			case kAudioFormatTimeCode:				type = "TIME"; break;
			case kAudioFormatMIDIStream:			type = "MIDI"; break;
			case kAudioFormatParameterValueStream:	type = "APVS"; break;
			case kAudioFormatAppleLossless:			type = "ALAC"; break;
			case kAudioFormatMPEG4AAC_HE:			type = "AAC-HE"; break;
			case kAudioFormatMPEG4AAC_LD:			type = "AAC-LD"; break;
			case kAudioFormatMPEG4AAC_ELD:			type = "AAC-ELD"; break;
			case kAudioFormatMPEG4AAC_ELD_SBR:		type = "AAC-SBR"; break;
			case kAudioFormatMPEG4AAC_HE_V2:		type = "AAC-HEv2"; break;
			case kAudioFormatMPEG4AAC_Spatial:		type = "AAC-S"; break;
			case kAudioFormatAMR:					type = "AMR"; break;
			case kAudioFormatAudible:				type = "AUDB"; break;
			case kAudioFormatiLBC:					type = "iLBC"; break;
			case kAudioFormatDVIIntelIMA:			type = "ADPCM"; break;
			case kAudioFormatMicrosoftGSM:			type = "GSM"; break;
			case kAudioFormatAES3:					type = "AES3"; break;
			default:								type = " "; break;
		}
		
		return [NSString stringWithFormat:@"%s", type];
	}
	return @"";
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
#ifdef DEBUG
	NSInteger errorCode = BASS_ErrorGetCode();
	DLog(@"BASS error: %i - %@", errorCode, NSStringFromBassErrorCode(errorCode));
#endif
}

- (void)printChannelInfo:(HSTREAM)channel
{
#ifdef DEBUG
	BASS_CHANNELINFO i;
	BASS_ChannelGetInfo(self.fileStream1, &i);
	QWORD bytes = BASS_ChannelGetLength(channel, BASS_POS_BYTE);
	DWORD time = BASS_ChannelBytes2Seconds(channel, bytes);
	DLog("channel type = %x (%@)\nlength = %llu (%u:%02u)  flags: %i  freq: %i  origres: %i", i.ctype, [self stringFromStreamType:i.ctype plugin:i.plugin], bytes, time/60, time%60, i.flags, i.freq, i.origres);
#endif
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
		
		//DLog(@"silence: %llu", count);
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
	@autoreleasepool 
	{
		// Stream is done, remove the user info object from the dictionary
		DLog(@"removing user info from dict");
		DLog(@"%@", sharedInstance.bassUserInfoDict);
		[sharedInstance removeUserInfoForStream:channel];
		BassUserInfo *userInfo = (BassUserInfo*)user;
		[userInfo release];
		DLog(@"%@", sharedInstance.bassUserInfoDict);
	}
}

void CALLBACK MyFileCloseProc(void *user)
{	
	if (user == NULL)
		return;
	
	// Get the user info object
	BassUserInfo *userInfo = (BassUserInfo *)user;
	
	// Tell the read wait loop to break in case it's waiting
	userInfo.shouldBreakWaitLoop = YES;
	
	@autoreleasepool {
		DLog(@"closing file: %@", userInfo.mySong.title);
	}
	
	// Close the file handle
	if (userInfo.myFileHandle != NULL)
		fclose(userInfo.myFileHandle);	
}

QWORD CALLBACK MyFileLenProc(void *user)
{
	if (user == NULL)
		return 0;
	
	@autoreleasepool
	{
		BassUserInfo *userInfo = (BassUserInfo *)user;
		if (userInfo.myFileHandle == NULL)
			return 0;
				
		QWORD length = 0;
		Song *theSong = userInfo.mySong;
		if (theSong.isFullyCached || userInfo.isTempCached)
		{
			// Return actual file size on disk
			length = theSong.localFileSize;
		}
		else
		{
			// Return server reported file size
			length = [theSong.size longLongValue];
		}
		
		DLog(@"checking %@ length: %llu", theSong.title, length);
		return length;
	}
}

DWORD CALLBACK MyFileReadProc(void *buffer, DWORD length, void *user)
{
	if (buffer == NULL || user == NULL)
		return 0;
		
	BassUserInfo *userInfo = (BassUserInfo *)user;
	if (userInfo.myFileHandle == NULL)
		return 0;
	
	// Read from the file
	DWORD bytesRead = fread(buffer, 1, length, userInfo.myFileHandle);
	
	if (bytesRead < length)
	{		
		userInfo.isWaiting = YES;
		
		DLog(@"progress: %f  bytesRead: %u  length needed: %u", sharedInstance.progress, bytesRead, length);
		
		// Undo the read
		fpos_t pos; 
		fgetpos(userInfo.myFileHandle, &pos);
		fpos_t newpos = pos - bytesRead;
		fsetpos(userInfo.myFileHandle, &newpos);
		bytesRead = 0;
		
		// Handle waiting for additional data
		@autoreleasepool 
		{
			Song *theSong = userInfo.mySong;
			if (!theSong.isFullyCached)
			{
				// Calculate the needed size:
				// Choose either the current player bitrate, or if for some reason it is not detected properly, use the best estimated bitrate. Then use that to determine how much data to let download to continue.
				unsigned long long size = theSong.localFileSize;
				//NSUInteger bitrate = sharedInstance.bitRate > 0 ? sharedInstance.bitRate : theSong.estimatedBitrate;
				NSUInteger bitrate = theSong.estimatedBitrate;
				unsigned long long bytesToWait = BytesForSecondsAtBitrate(ISMS_NumSecondsToWaitForAudioData, bitrate);
				userInfo.neededSize = size + bytesToWait;
				DLog(@"waiting for %llu   neededSize: %llu", bytesToWait, userInfo.neededSize);
				
				NSTimeInterval totalSleepTime = 0.0;
				static const NSTimeInterval sleepTime = 0.01;
				static const NSTimeInterval fileSizeCheckWait = 1.0;
				while (1)
				{
					// Check if we should break every 100th of a second
					[NSThread sleepForTimeInterval:sleepTime];
					totalSleepTime += sleepTime;
					if (userInfo.shouldBreakWaitLoop)
						break;
						
					// Only check the file size every half a second
					if (totalSleepTime >= fileSizeCheckWait)
					{
						totalSleepTime = 0.0;
						
						// If the song has finished caching, we can stop waiting
						if (theSong.isFullyCached)
							break;
						
						// Handle temp cached songs ending. When they end, they are set as the last temp cached song, so we know it's done and can stop waiting for data.
						if (theSong.isTempCached && [theSong isEqualToSong:streamManagerS.lastTempCachedSong])
							break;
						
						// If enough of the file has downloaded, break the loop
						if (userInfo.localFileSize >= userInfo.neededSize)
							break;
					}
				}
				userInfo.isWaiting = NO;
				userInfo.shouldBreakWaitLoop = NO;
				
				DLog(@"done waiting");
				
				// Do the read again
				bytesRead = fread(buffer, 1, length, userInfo.myFileHandle);
			}
		}
	}
	
	return bytesRead;
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

static BASS_FILEPROCS fileProcs = {MyFileCloseProc, MyFileLenProc, MyFileReadProc, MyFileSeekProc};

#pragma mark - Output stream callbacks

- (void)clearSocial
{
	self.hasTweeted = NO;
	self.hasScrobbled = NO;
	self.hasNotifiedSubsonic = NO;
}

- (void)handleSocial
{
	if (!self.hasTweeted && self.progress >= socialS.tweetDelay)
	{
		self.hasTweeted = YES;
		[socialS tweetSong];
	}
	
	if (!self.hasScrobbled && self.progress >= socialS.scrobbleDelay)
	{
		self.hasScrobbled = YES;
		[socialS scrobbleSongAsSubmission];
	}
	
	if (!self.hasNotifiedSubsonic && self.progress >= socialS.subsonicDelay)
	{
		self.hasNotifiedSubsonic = YES;
		[socialS notifySubsonic];
	}
}

- (DWORD)bassGetOutputData:(void *)buffer length:(DWORD)length
{	
	DWORD r;

	@autoreleasepool 
	{
		if (BASS_ChannelIsActive(self.currentStream))
		{		
			//DLog(@"getting output data");
			r = BASS_ChannelGetData(self.currentReadingStream, buffer, length);
			
			[self handleSocial];
						
			// Check if stream is now complete
			if (!BASS_ChannelIsActive(self.currentReadingStream))
			{
				// Stream is done, free the stream
				//DLog(@"current stream: %u  currentStreamTempo: %u", self.currentStream, self.currentStreamTempo); 
				if (self.currentStreamTempo) BASS_StreamFree(self.currentStreamTempo);
				BASS_StreamFree(self.currentStream);
				//DLog(@"freed current stream: %u  currentStreamTempo: %u", self.currentStream, self.currentStreamTempo); 
				
				[self clearSocial];
				
				// Increment current playlist index
				[playlistS incrementIndex];
				
				// Send song end notification
				[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackEnded];
				
				// Flip the current/next streams
				self.BASSisFilestream1 = !self.BASSisFilestream1;

				// Check if the frequency of this stream matches the BASS output
				if (self.bassReinitSampleRate)
				{
					// The sample rates don't match, so re-init bass
					[self performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
					
					DLog(@"Must reinit bass");
					r = BASS_STREAMPROC_END;
				}
				else
				{
					startSecondsOffset = 0;
					startByteOffset = 0;
					
					// Send song start notification
					[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackStarted];
					
					// Prepare the next song for playback
					[self prepareNextSongStream];
					
					r = [self bassGetOutputData:buffer length:length];
					
					if (r) [socialS scrobbleSongAsPlaying];
					
					// Mark the last played time in the database for cache cleanup
					playlistS.currentSong.playedDate = [NSDate date];
				}
			}
		}
		else
		{
			// Send song end notification
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackEnded];
			
			DLog(@"Stream not active, freeing BASS");
			r = BASS_STREAMPROC_END;
			[self performSelectorOnMainThread:@selector(bassFree) withObject:nil waitUntilDone:NO];
			
			// Handle song caching being disabled
			if (!settingsS.isSongCachingEnabled || !settingsS.isNextSongCacheEnabled)
			{
				[musicS performSelectorOnMainThread:@selector(startSong) withObject:nil waitUntilDone:NO];
			}
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
	
    //DLog(@"audioRouteChangeListenerCallback called, propertyId: %lu  isMainThread: %@", inPropertyID, NSStringFromBOOL([NSThread isMainThread]));
	
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
		
		//DLog(@"route change reason: %li", routeChangeReason);
		
        // "Old device unavailable" indicates that a headset was unplugged, or that the
        // device was removed from a dock connector that supports audio output. This is
        // the recommended test for when to pause audio.
        if (routeChangeReason == kAudioSessionRouteChangeReason_OldDeviceUnavailable) 
		{
			[selfRef playPause];
			
            //DLog (@"Output device removed, so application audio was paused.");
        }
		else 
		{
            //DLog (@"A route change occurred that does not require pausing of application audio.");
        }
    }
	else 
	{	
        //DLog (@"Audio route change while application audio is stopped.");
        return;
    }
}

/*void audioInterruptionListenerCallback (void *inUserData, AudioSessionPropertyID inPropertyID, UInt32 inPropertyValueSize, const void *inPropertyValue) 
{
	DLog(@"audio interrupted");
	AudioEngine *selfRef = inUserData;
	[selfRef pause];
}*/

void interruptionListenerCallback(void *inUserData, UInt32 interruptionState) 
{
    if (interruptionState == kAudioSessionBeginInterruption) 
	{
		//DLog(@"audio session begin interruption");
		if ([sharedInstance isPlaying])
		{
			[sharedInstance setShouldResumeFromInterruption:YES];
			[sharedInstance pause];
		}
		else
		{
			[sharedInstance setShouldResumeFromInterruption:NO];
		}
    } 
	else if (interruptionState == kAudioSessionEndInterruption) 
	{
        //DLog(@"audio session interruption ended, isPlaying: %@   isMainThread: %@", NSStringFromBOOL([sharedInstance isPlaying]), NSStringFromBOOL([NSThread isMainThread]));
		if ([sharedInstance shouldResumeFromInterruption])
		{
			[sharedInstance playPause];
			
			// Reset the shouldResumeFromInterruption value
			[sharedInstance setShouldResumeFromInterruption:NO];
		}
    }
}

- (NSInteger)audioSessionSampleRate
{
	Float64 sampleRate;
	UInt32 size = sizeof(Float64);
	AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &sampleRate);
	
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
	BASS_FXSetParameters(self.volumeFx, volumeParams);
}

- (void)bassInit:(NSUInteger)sampleRate
{
	// Sample rate doesn't matter now that an audio queue is used for output
	
	// Destroy any existing BASS instance
	[self bassFree];
	
	// Initialize BASS
	BASS_SetConfig(BASS_CONFIG_IOS_MIXAUDIO, 0); // Disable mixing.	To be called before BASS_Init.
	BASS_SetConfig(BASS_CONFIG_BUFFER, self.bassUpdatePeriod + self.bufferLengthMillis); // set the buffer length to the minimum amount + 200ms
	//DLog(@"buffer size: %i", BASS_GetConfig(BASS_CONFIG_BUFFER));
	BASS_SetConfig(BASS_CONFIG_FLOATDSP, true); // set DSP effects to use floating point math to avoid clipping within the effects chain
	if (!BASS_Init(-1, sampleRate, 0, NULL, NULL)) 	// Initialize default device.
	{
		DLog(@"Can't initialize device");
	}
	BASS_PluginLoad(&BASSFLACplugin, 0); // load the FLAC plugin
			
	BASS_INFO info;
	BASS_GetInfo(&info);
	//DLog(@"bassInit:%i  bass freq: %i  minrate: %i   maxrate: %i  minbuf: %i  latency:%i ", sampleRate, info.freq, info.minrate, info.maxrate, info.minbuf, info.latency);
		
	// Add the callbacks for headphone removal and other audio takeover
	AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, audioRouteChangeListenerCallback, self);
	//AudioSessionAddPropertyListener(kAudioSessionProperty_OtherAudioIsPlaying, audioInterruptionListenerCallback, self);
}

- (void)bassInit
{
	// Default to 44.1 KHz
    [self bassInit:ISMS_defaultSampleRate];
}

- (BOOL)bassFree
{
	@synchronized(eqReadSyncObject)
	{		
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startWithOffsetInBytesorSecondsInternal:) object:nil];
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(prepareNextSongStreamInternal) object:nil];
		
		BOOL success = BASS_Free();
		self.fileStream1 = 0;
		self.fileStreamTempo1 = 0;
		self.fileStream2 = 0;
		self.fileStreamTempo2 = 0;
		self.outStream = 0;
		self.volumeFx = 0;
		self.bassReinitSampleRate = 0;
		self.isPlaying = NO;
		
		[self clearSocial];
		
		[self.bassUserInfoDict removeAllObjects];
				
		return success;
	}
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
	//DLog(@"BASS Stream sample rate: %i", (NSUInteger)sampleRate);
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
	
	//DLog(@"sample rate: %i preferred sample rate: %i", sampleRate, preferredSampleRate);
	
	return preferredSampleRate;
}

- (void)seekToPositionInBytes:(QWORD)bytes inStream:(HSTREAM)stream
{
	//DLog(@"fileStream1: %i   fileStream2: %i    currentStream: %i", fileStream1, fileStream2, self.currentStream);
	if (BASS_ChannelSetPosition(stream, bytes, BASS_POS_BYTE))
	{
		self.startByteOffset = bytes;
		
		BassUserInfo *userInfo = [self userInfoForStream:stream];
		userInfo.neededSize = ULLONG_MAX;
		if (userInfo.isWaiting)
		{
			userInfo.shouldBreakWaitLoop = YES;
		}
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

- (void)seekToPositionInSeconds:(double)seconds inStream:(HSTREAM)stream
{
	NSUInteger bytes = BASS_ChannelSeconds2Bytes(stream, seconds);
	//DLog(@"seconds: %i   bytes: %i", seconds, bytes);
	[self seekToPositionInBytes:bytes inStream:stream];
}

- (void)seekToPositionInSeconds:(double)seconds
{
	[self seekToPositionInSeconds:seconds inStream:self.currentStream];
}

- (void)prepareNextSongStream
{
	[self performSelector:@selector(prepareNextSongStreamInternal) 
				 onThread:startSongThread 
			   withObject:nil 
			waitUntilDone:NO];
}

- (void)prepareNextSongStreamInternal
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(prepareNextSongStreamInternal) object:nil];
	
	if (self.nextStream)
		BASS_StreamFree(self.nextStream);
	
	self.bassReinitSampleRate = 0;
	
	//DLog(@"preparing next song stream");
	Song *nextSong = playlistS.nextSong;
	
	//DLog(@"nextSong.localFileSize: %llu", nextSong.localFileSize);
	if (nextSong.localFileSize == 0)
		return;
	
	BassUserInfo *userInfo = [[BassUserInfo alloc] init];
	userInfo.mySong = nextSong;
	userInfo.writePath = nextSong.currentPath;
	userInfo.isTempCached = nextSong.isTempCached;
	userInfo.myFileHandle = fopen([userInfo.writePath cStringUTF8], "rb");
	
	// Try hardware and software mixing
	self.nextStream = BASS_StreamCreateFileUser(STREAMFILE_BUFFER, BASS_STREAM_DECODE, &fileProcs, userInfo);
	if(!self.nextStream) self.nextStream = BASS_StreamCreateFileUser(STREAMFILE_BUFFER, BASS_SAMPLE_SOFTWARE|BASS_STREAM_DECODE, &fileProcs, userInfo);
	
	if (self.nextStream)
	{
		// Add the user info object to the dictionary
		[self setUserInfo:userInfo forStream:self.nextStream];
		
		// Set the stream free sync
		BASS_ChannelSetSync(self.nextStream, BASS_SYNC_FREE, 0, MyStreamFreeCallback, userInfo);
		
		// Verify we're using the best sample rate
		NSInteger streamSampleRate = [self bassStreamSampleRate:self.fileStream1];
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
		}
	}
	else
	{
#ifdef DEBUG
		NSInteger errorCode = BASS_ErrorGetCode();
		DLog(@"nextSong stream: %i error: %i - %@", self.nextStream, errorCode, NSStringFromBassErrorCode(errorCode));
#endif
		
		[self performSelector:@selector(prepareNextSongStreamInternal) withObject:nil afterDelay:RETRY_DELAY];
	}
	
	DLog(@"nextSong: %i\n   ", self.nextStream);
}

- (BOOL)prepareFileStream1
{
	Song *currentSong = playlistS.currentSong;
	if (currentSong.fileExists)
	{	
		// Create the user info object for the stream
		BassUserInfo *userInfo = [[BassUserInfo alloc] init];
		userInfo.mySong = currentSong;
		userInfo.writePath = currentSong.currentPath;
		userInfo.isTempCached = currentSong.isTempCached;
		userInfo.myFileHandle = fopen([userInfo.writePath cStringUTF8], "rb");
		if (userInfo.myFileHandle == NULL)
		{
			// File failed to open
			//DLog(@"File failed to open");
			return NO;
		}
		
		// Create the stream
		self.fileStream1 = BASS_StreamCreateFileUser(STREAMFILE_BUFFER, BASS_STREAM_DECODE, &fileProcs, userInfo);
		if(!self.fileStream1) self.fileStream1 = BASS_StreamCreateFileUser(STREAMFILE_BUFFER, BASS_SAMPLE_SOFTWARE|BASS_STREAM_DECODE, &fileProcs, userInfo);
		if (self.fileStream1)
		{
			// Add the user info object to the dictionary
			[self setUserInfo:userInfo forStream:self.fileStream1];
			
			// Add the stream free callback
			BASS_ChannelSetSync(self.fileStream1, BASS_SYNC_FREE, 0, MyStreamFreeCallback, userInfo);
						
			// Stream successfully created
			return YES;
		}
				
		// Failed to create the stream
		//DLog(@"failed to create stream");
		return NO;
	}
	
	// File doesn't exist
	return NO;
}

// Run in background to prevent pausing the main thread
- (void)startWithOffsetInBytes:(NSNumber *)byteOffset orSeconds:(NSNumber *)seconds
{	
	NSMutableDictionary *bytesOrSeconds = [NSMutableDictionary dictionaryWithCapacity:2];
	if (byteOffset) [bytesOrSeconds setObject:byteOffset forKey:@"byteOffset"];
	if (seconds) [bytesOrSeconds setObject:seconds forKey:@"seconds"];
	
	[self performSelector:@selector(startWithOffsetInBytesorSecondsInternal:) 
				 onThread:startSongThread 
			   withObject:bytesOrSeconds 
			waitUntilDone:NO];
}

// Runs in background thread
- (void)startWithOffsetInBytesorSecondsInternal:(NSDictionary *)bytesOrSeconds
{
	NSInteger count = playlistS.count;
	if (playlistS.currentIndex >= count) playlistS.currentIndex = count - 1;
	
	Song *currentSong = playlistS.currentSong;
	if (!currentSong)
		return;
	
	NSNumber *byteOffset = [bytesOrSeconds objectForKey:@"byteOffset"];
	NSNumber *seconds = [bytesOrSeconds objectForKey:@"seconds"]; 
	
	self.startByteOffset = 0;
	self.startSecondsOffset = 0;
	self.BASSisFilestream1 = YES;
	
	[self bassInit];
	
	if (currentSong.fileExists)
	{
		if ([self prepareFileStream1])
		{
			// Verify we're using the best sample rate
			NSInteger streamSampleRate = [self bassStreamSampleRate:self.fileStream1];
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
				streamSampleRate = [self bassStreamSampleRate:self.fileStream1];
			}
			
			// Check again to see if the output sample rate is the same as the stream sample rate
			// and the stream sample rate is higher than 96KHz
			if (bassSampleRate != streamSampleRate && streamSampleRate > 96000)
			{
				// It's a high sample rate file, so to prevent a lot of whitenoise, use a mixer
				// stream and apply the resampling filter
				self.fileStreamTempo1 = BASS_Mixer_StreamCreate(bassSampleRate, 
																2, 
																BASS_STREAM_DECODE|BASS_MIXER_END);
				if (self.fileStreamTempo1)
				{
					BASS_Mixer_StreamAddChannel(self.fileStreamTempo1, 
												self.fileStream1, 
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
				self.startByteOffset = [byteOffset unsignedLongLongValue];
				
				if (seconds)
				{
					[self seekToPositionInSeconds:[seconds doubleValue] inStream:self.fileStream1];
				}
				else
				{
					if (self.startByteOffset > 0)
						[self seekToPositionInBytes:self.startByteOffset inStream:self.fileStream1];
				}
			}
			else if (seconds)
			{
				self.startSecondsOffset = [seconds doubleValue];
				if (self.startSecondsOffset > 0.0)
					[self seekToPositionInSeconds:self.startSecondsOffset inStream:self.fileStream1];
			}
			
			// Create the output stream
			BASS_CHANNELINFO info;
			BASS_ChannelGetInfo(self.currentReadingStream, &info);
			self.outStream = BASS_StreamCreate(info.freq, info.chans, 0, &MyStreamProc, 0);
			
			// Enable the equalizer if it's turned on
			if (self.isEqualizerOn)
			{
				[self applyEqualizerValues:self.eqValueArray toStream:self.outStream];
			}
			
			// Add gain amplification
			self.volumeFx = BASS_ChannelSetFX(self.outStream, BASS_FX_BFX_VOLUME, 1);
			
			// Start playback
			BASS_ChannelPlay(self.outStream, FALSE);
			self.isPlaying = YES;
			
			// This is a new song so notify Last.FM that it's playing
			[socialS scrobbleSongAsPlaying];
			
			// Prepare the next song
			[self prepareNextSongStream];
			
			// Notify listeners that playback has started
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackStarted];
			
			currentSong.playedDate = [NSDate date];
		}
		else if (!self.fileStream1 && !currentSong.isFullyCached 
				 && currentSong.localFileSize < MIN_FILESIZE_TO_FAIL)
		{
			// Failed to create the stream, retrying
			DLog(@"------failed to create stream, retrying in 2 seconds------");
			[self performSelector:@selector(startWithOffsetInBytesorSecondsInternal:) withObject:bytesOrSeconds afterDelay:RETRY_DELAY];
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

#pragma mark - Audio Engine Properties

- (BOOL)isStarted
{
	return self.currentStream;
}

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
	@synchronized(currentStreamSyncObject)
	{
		return self.BASSisFilestream1 ? self.fileStream1 : self.fileStream2;
	}
}

- (void)setCurrentStream:(HSTREAM)stream
{
	@synchronized(currentStreamSyncObject)
	{
		if (self.BASSisFilestream1)
			self.fileStream1 = stream;
		else
			self.fileStream2 = stream;
	}
}

- (HSTREAM)currentStreamTempo
{	
	@synchronized(currentStreamSyncObject)
	{
		return self.BASSisFilestream1 ? self.fileStreamTempo1 : self.fileStreamTempo2;
	}
}

- (void)setCurrentStreamTempo:(HSTREAM)stream
{
	@synchronized(currentStreamSyncObject)
	{
		if (self.BASSisFilestream1)
			self.fileStreamTempo1 = stream;
		else
			self.fileStreamTempo2 = stream;
	}
}

- (HSTREAM)currentReadingStream
{
	@synchronized(currentStreamSyncObject)
	{
		return self.currentStreamTempo ? self.currentStreamTempo : self.currentStream;
	}
}

- (HSTREAM)nextStream
{
	@synchronized(currentStreamSyncObject)
	{
		return self.BASSisFilestream1 ? self.fileStream2 : self.fileStream1;
	}
}

- (void)setNextStream:(HSTREAM)stream
{
	@synchronized(currentStreamSyncObject)
	{
		if (self.BASSisFilestream1)
			self.fileStream2 = stream;
		else
			self.fileStream1 = stream;
	}
}

- (HSTREAM)nextStreamTempo
{
	@synchronized(currentStreamSyncObject)
	{
		return self.BASSisFilestream1 ? self.fileStreamTempo2 : self.fileStreamTempo1;
	}
}	

- (void)setNextStreamTempo:(HSTREAM)stream
{
	@synchronized(currentStreamSyncObject)
	{
		if (self.BASSisFilestream1)
			self.fileStreamTempo2 = stream;
		else
			self.fileStreamTempo1 = stream;
	}
}

- (HSTREAM)nextReadingStream
{
	@synchronized(currentStreamSyncObject)
	{
		return self.nextStreamTempo ? self.nextStreamTempo : self.nextStream;
	}
}

- (BOOL)BASSisFilestream1
{
	@synchronized(currentStreamSyncObject)
	{
		return BASSisFilestream1;
	}
}

- (void)setBASSisFilestream1:(BOOL)isFilestream1
{
	@synchronized(currentStreamSyncObject)
	{
		BASSisFilestream1 = isFilestream1;
	}
}

- (Song *)currentStreamSong
{
	BassUserInfo *userInfo = [self userInfoForStream:self.currentStream];
	return [[userInfo.mySong copy] autorelease];
}

- (NSString *)currentStreamFormat
{
	BASS_CHANNELINFO i;
	BASS_ChannelGetInfo(self.fileStream1, &i);
	//QWORD bytes = BASS_ChannelGetLength(self.currentStream, BASS_POS_BYTE);
	//DWORD time = BASS_ChannelBytes2Seconds(self.currentStream, bytes);
	
	return [self stringFromStreamType:i.ctype plugin:i.plugin];
	
	//DLog("channel type = %x (%@)\nlength = %llu (%u:%02u)  flags: %i  freq: %i  origres: %i", i.ctype, [self stringFromStreamType:i.ctype plugin:i.plugin], bytes, time/60, time%60, i.flags, i.freq, i.origres);=
}

- (BassUserInfo *)userInfoForStream:(HSTREAM)stream
{
	NSString *key = [NSString stringWithFormat:@"%i", stream];
	return [bassUserInfoDict objectForKey:key];
}

- (void)setUserInfo:(BassUserInfo *)userInfo forStream:(HSTREAM)stream
{
	NSString *key = [NSString stringWithFormat:@"%i", stream];
	[bassUserInfoDict setObject:userInfo forKey:key];
}

- (void)removeUserInfoForStream:(HSTREAM)stream
{
	NSString *key = [NSString stringWithFormat:@"%i", stream];
	[bassUserInfoDict removeObjectForKey:key];
}

#pragma mark - Equalizer and Visualizer Methods

- (void)clearEqualizerValuesFromStream:(HSTREAM)stream
{
	int i = 0;
	for (BassEffectHandle *handle in self.eqHandleArray)
	{
		BASS_ChannelRemoveFX(stream, handle.effectHandle);
		i++;
	}
	
	for (BassParamEqValue *value in self.eqValueArray)
	{
		value.handle = 0;
	}
	
	//DLog(@"removed %i effect channels", i);
	[self.eqHandleArray removeAllObjects];
	self.isEqualizerOn = NO;
}

- (void)clearEqualizerValues
{
	[self clearEqualizerValuesFromStream:self.outStream];
}

- (void)applyEqualizerValues:(NSArray *)values toStream:(HSTREAM)stream
{
	if (values == nil)
		return;
	else if ([values count] == 0)
		return;
	
	for (BassParamEqValue *value in self.eqValueArray)
	{
		HFX handle = BASS_ChannelSetFX(stream, BASS_FX_DX8_PARAMEQ, 0);
		BASS_DX8_PARAMEQ p = value.parameters;
		BASS_FXSetParameters(handle, &p);
		
		value.handle = handle;
		
		[self.eqHandleArray addObject:[BassEffectHandle handleWithEffectHandle:handle]];
	}
	self.isEqualizerOn = YES;
}

- (void)applyEqualizerValues:(NSArray *)values
{
	[self applyEqualizerValues:values toStream:self.outStream];
}

- (void)updateEqParameter:(BassParamEqValue *)value
{
	[self.eqValueArray replaceObjectAtIndex:value.arrayIndex withObject:value]; 
	
	if (self.isEqualizerOn)
	{
		BASS_DX8_PARAMEQ p = value.parameters;
		//DLog(@"updating eq for handle: %i   new freq: %f   new gain: %f", value.handle, p.fCenter, p.fGain);
		BASS_FXSetParameters(value.handle, &p);
	}
}

- (BassParamEqValue *)addEqualizerValue:(BASS_DX8_PARAMEQ)value
{
	NSUInteger newIndex = [self.eqValueArray count];
	BassParamEqValue *eqValue = [BassParamEqValue valueWithParams:value arrayIndex:newIndex];
	[self.eqValueArray addObject:eqValue];
	
	if (self.isEqualizerOn)
	{
		HFX handle = BASS_ChannelSetFX(self.currentStream, BASS_FX_DX8_PARAMEQ, 0);
		BASS_FXSetParameters(handle, &value);
		eqValue.handle = handle;
		
		[self.eqHandleArray addObject:[BassEffectHandle handleWithEffectHandle:handle]];
	}
	
	return eqValue;
}

- (NSArray *)removeEqualizerValue:(BassParamEqValue *)value
{
	if (self.isEqualizerOn)
	{
		// Disable the effect channel
		BASS_ChannelRemoveFX(self.currentStream, value.handle);
	}
	
	// Remove the handle
	[self.eqHandleArray removeObject:[BassEffectHandle handleWithEffectHandle:value.handle]];
	
	// Remove the value
	[self.eqValueArray removeObject:value];
	for (int i = value.arrayIndex; i < [self.eqValueArray count]; i++)
	{
		// Adjust the arrayIndex values for the other objects
		BassParamEqValue *aValue = [self.eqValueArray objectAtIndexSafe:i];
		aValue.arrayIndex = i;
	}
	
	return self.equalizerValues;
}

- (void)removeAllEqualizerValues
{
	[self clearEqualizerValues];
	
	[self.eqValueArray removeAllObjects];
}

- (BOOL)toggleEqualizer
{
	if (self.isEqualizerOn)
	{
		[self clearEqualizerValues];
		return NO;
	}
	else
	{
		[self applyEqualizerValues:self.eqValueArray];
		return YES;
	}
}

- (NSArray *)equalizerValues
{
	return [NSArray arrayWithArray:self.eqValueArray];
}

- (float)fftData:(NSUInteger)index
{
	@synchronized(eqReadSyncObject)
	{
		return fftData[index];
	}
}

- (short)lineSpecData:(NSUInteger)index
{
	@synchronized(eqReadSyncObject)
	{
		return lineSpecBuf[index];
	}
}

- (void)stopReadingEqData
{
	self.eqDataType = ISMS_BASS_EQ_DATA_TYPE_none;
}

- (void)startReadingEqData:(ISMS_BASS_EQ_DATA_TYPE)type
{	
	self.eqDataType = type;
}

- (void)readEqData
{
	[self performSelector:@selector(readEqDataInternal) onThread:fftDataThread withObject:nil waitUntilDone:NO];
}

- (void)readEqDataInternal
{
	@synchronized(eqReadSyncObject)
	{
		if (!self.outStream)
			return;
		
		// Get the FFT data for visualizer
		if (self.eqDataType == ISMS_BASS_EQ_DATA_TYPE_fft)
			BASS_ChannelGetData(self.outStream, fftData, BASS_DATA_FFT2048);
		
		// Get the data for line spec visualizer
		if (self.eqDataType == ISMS_BASS_EQ_DATA_TYPE_line)
			BASS_ChannelGetData(self.outStream, lineSpecBuf, lineSpecBufSize);
	}
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
	DLog(@"received memory warning");
	
	
}

#pragma mark - Singleton methods

- (void)setup
{	
	startSongThread = [[NSThread alloc] initWithTarget:self selector:@selector(startSongThreadEntryPoint) object:nil];
	[startSongThread start];
	
	shouldResumeFromInterruption = NO;
	bassUserInfoDict = [[NSMutableDictionary alloc] initWithCapacity:2];
	bassUpdatePeriod = BASS_GetConfig(BASS_CONFIG_UPDATEPERIOD);
	bufferLengthMillis = ISMS_BASSBufferSize;
	bassReinitSampleRate = 0;
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
	currentStreamSyncObject = [[NSObject alloc] init];
	eqReadSyncObject = [[NSObject alloc] init];
    
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
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepareNextSongStream) name:ISMSNotification_RepeatModeChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepareNextSongStream) name:ISMSNotification_CurrentPlaylistOrderChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepareNextSongStream) name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(didReceiveMemoryWarning) 
												 name:UIApplicationDidReceiveMemoryWarningNotification 
											   object:nil];
	
	/*[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(enteredBackground)
												 name:UIApplicationDidEnterBackgroundNotification 
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(enteredForeground)
												 name:UIApplicationDidBecomeActiveNotification
											   object:nil];
	*/
	AudioSessionInitialize(NULL, NULL, interruptionListenerCallback, NULL);
}

/*- (void)enteredBackground
{
	DLog(@"entered background");
}

- (void)enteredForeground
{
	DLog(@"entered foreground");
}*/

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

- (id)init 
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
	
	self.isFftDataThreadToTerminate = NO;

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
	while(isRunning && !self.isFftDataThreadToTerminate);
}
- (void)fftThreadEmptyMethod {}

- (void)startSongThreadEntryPoint
{
	NSAutoreleasePool* thePool = [[NSAutoreleasePool alloc] init];
	
	self.isFftDataThreadToTerminate = NO;
	
	// Create a scheduled timer to keep runloop alive
	NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(startSongEmptyMethod) userInfo:nil repeats:YES];
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
	while(isRunning && !self.isFftDataThreadToTerminate);
}
- (void)startSongEmptyMethod {}

@end