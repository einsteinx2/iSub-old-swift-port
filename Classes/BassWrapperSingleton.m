//
//  BassWrapperSingleton.m
//  iSub
//
//  Created by Ben Baron on 11/16/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "BassWrapperSingleton.h"
#import "Song.h"
#import "SUSCurrentPlaylistDAO.h"
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

@implementation BassWrapperSingleton
@synthesize isEqualizerOn, startByteOffset, currPlaylistDAO, fftDataThread, isFftDataThreadToTerminate, isPlaying, isFastForward;

// BASS plugins
extern void BASSFLACplugin;

// Singleton object
static BassWrapperSingleton *sharedInstance = nil;

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

- (QWORD)preSilenceLengthForSong:(Song *)aSong
{
	// Create a decode channel
	const char *file = [aSong.localPath cStringUTF8];
	HSTREAM chan = BASS_StreamCreateFile(FALSE, file, 0, 0, BASS_STREAM_DECODE); // create decoding channel
	if (!chan) chan = BASS_StreamCreateFile(FALSE, file, 0, 0, BASS_SAMPLE_SOFTWARE|BASS_STREAM_DECODE);
	
	if (chan)
	{
		// Determine the silence length
		BYTE buf[10000];
		QWORD count=0;
		while (BASS_ChannelIsActive(chan)) 
		{
			int a,b = BASS_ChannelGetData(chan, buf, 10000); // decode some data
			for (a = 0; a < b && !buf[a]; a++) ; // count silent bytes
			count += a; // add number of silent bytes
			if (a < b) break; // sound has begun!
		}
		
		// Free the channel
		BASS_StreamFree(chan);
		
		DLog(@"silence: %llu", count);
		return count;
	}
	else
	{
		DLog(@"getsilencelength error: %i", BASS_ErrorGetCode());
		return NSUIntegerMax;
	}
}

#pragma mark - Decode Stream Callbacks

void CALLBACK MyStreamStallProc(HSYNC handle, DWORD channel, DWORD data, void *user)
{
	if (data)
		DLog(@"BASS stream resumed");
	DLog(@"BASS stream stalled");
}

void CALLBACK MyStreamFreeCallback(HSYNC handle, DWORD channel, DWORD data, void *user)
{
	// Stream is done, release the user info object
	BassUserInfo *userInfo = (BassUserInfo *)user;
	[userInfo release];
}

void CALLBACK MyFileCloseProc(void *user)
{	
	// Close the file handle
	BassUserInfo *userInfo = (BassUserInfo *)user;
	fclose(userInfo.myFileHandle);	
}

QWORD CALLBACK MyFileLenProc(void *user)
{
	@autoreleasepool
	{
		@synchronized([BassWrapperSingleton class])
		{
			BassUserInfo *userInfo = (BassUserInfo *)user;
			SUSCurrentPlaylistDAO *currentPlaylistDAO = sharedInstance.currPlaylistDAO;
			
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
	// Read from the file
	BassUserInfo *userInfo = (BassUserInfo *)user;
	return fread(buffer, 1, length, userInfo.myFileHandle);
}

BOOL CALLBACK MyFileSeekProc(QWORD offset, void *user)
{	
	// Seek to the requested offset (returns false if data not downloaded that far)
	BassUserInfo *userInfo = (BassUserInfo *)user;
	BOOL success = !fseek(userInfo.myFileHandle, offset, SEEK_SET);
	DLog(@"File Seek to %llu  success: %@", offset, NSStringFromBOOL(success));
	
	return success;
}

#pragma mark - Audio Queue Services output stream callbacks

- (DWORD)bassGetOutputData:(void *)buffer length:(DWORD)length
{	
	DWORD r;	
	if (BASSisFilestream1 && BASS_ChannelIsActive(fileStream1)) 
	{
		// Read data from stream1
		if (fileStreamTempo1)
			r = BASS_ChannelGetData(fileStreamTempo1, buffer, length);
		else
			r = BASS_ChannelGetData(fileStream1, buffer, length);			
		
		// Check if stream1 is now complete
		if (!BASS_ChannelIsActive(fileStream1))
		{				
			// Stream1 is done, free the stream
			DLog(@"stream 1 is done");
			BASS_StreamFree(fileStream1);
			if (fileStreamTempo1) BASS_StreamFree(fileStreamTempo1);
			fileStreamTempo1 = 0;
			
			// Increment current playlist index
			[currPlaylistDAO performSelectorOnMainThread:@selector(incrementIndex) withObject:nil waitUntilDone:YES];
			
			// Send song end notification
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackEnded];
			
			// Check to see if there is another song to play
			DLog(@"fileStream2: %i", fileStream2);
			if (BASS_ChannelIsActive(fileStream2))
			{				
				DLog(@"TEST starting stream2: %i", fileStream2);
				
				// Send song start notification
				[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackStarted];
				
				// Read data from stream2
				[self setStartByteOffset:0];
				BASSisFilestream1 = NO;
				if (fileStreamTempo2)
					r = BASS_ChannelGetData(fileStreamTempo2, buffer, length);
				else
					r = BASS_ChannelGetData(fileStream2, buffer, length);
				DLog(@"error code: %i", BASS_ErrorGetCode());
				
				// Prepare the next song for playback
				[self prepareNextSongStreamInBackground];
			}
		}
	}
	else if (BASS_ChannelIsActive(fileStream2)) 
	{
		// Read data from stream2
		if (fileStreamTempo2)
			r = BASS_ChannelGetData(fileStreamTempo2, buffer, length);
		else
			r = BASS_ChannelGetData(fileStream2, buffer, length);
		
		// Check if stream2 is now complete
		if (!BASS_ChannelIsActive(fileStream2))
		{			
			// Stream2 is done, free the stream
			DLog(@"stream 2 is done");
			BASS_StreamFree(fileStream2);
			if (fileStreamTempo2) BASS_StreamFree(fileStreamTempo2);
			fileStreamTempo2 = 0;
			
			// Increment current playlist index
			[currPlaylistDAO performSelectorOnMainThread:@selector(incrementIndex) withObject:nil waitUntilDone:YES];
			
			// Send song done notification
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackEnded];
			
			DLog(@"fileStream1: %i", fileStream1);
			if (BASS_ChannelIsActive(fileStream1))
			{				
				DLog(@"TEST starting stream1: %i", fileStream1);
				// Send song start notification
				[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackStarted];
				
				[self setStartByteOffset:0];
				BASSisFilestream1 = YES;
				if (fileStreamTempo1)
					r = BASS_ChannelGetData(fileStreamTempo1, buffer, length);
				else
					r = BASS_ChannelGetData(fileStream1, buffer, length);
				DLog(@"error code: %i", BASS_ErrorGetCode());
				
				[self prepareNextSongStreamInBackground];
			}
		}
	}
	else
	{
		r = BASS_STREAMPROC_END;
		[self performSelectorOnMainThread:@selector(bassFree) withObject:nil waitUntilDone:NO];
	}
		
	return r;
}

//BOOL doPutData = YES;
- (void)queueCallback:(AudioQueueRef)outAQ buffer:(AudioQueueBufferRef)outBuffer
{	
	// Specify how many bytes we're providing and grab the data
    DWORD length = ISMS_AQBufferSizeInFrames * audioQueueOutputFormat.mBytesPerFrame;
	DWORD actualLength = [self bassGetOutputData:outBuffer->mAudioData length:length];
	//if (self.isFastForward)
	//	actualLength = [self bassGetOutputData:outBuffer->mAudioData length:length];
	outBuffer->mAudioDataByteSize = actualLength;
	
	if (eqDataType != ISMS_BASS_EQ_DATA_TYPE_none)
	{
		
		//if (doPutData)
			BASS_StreamPutData(fftStream, outBuffer->mAudioData, outBuffer->mAudioDataByteSize);
		//doPutData = !doPutData;
	}
	
    // Enqueue the buffer
    AudioQueueEnqueueBuffer(audioQueue, outBuffer, 0, NULL); 
}


static void MyQueueCallbackProc(void* userData, AudioQueueRef outAQ, AudioQueueBufferRef outBuffer)
{
	BassWrapperSingleton *selfRef = userData;
	[selfRef queueCallback:outAQ buffer:outBuffer];
}

void audioRouteChangeListenerCallback(void *inUserData, AudioSessionPropertyID inPropertyID, UInt32 inPropertyValueSize, const void *inPropertyValue) 
{	
	BassWrapperSingleton *selfRef = inUserData;
	
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
	BassWrapperSingleton *selfRef = inUserData;
	[selfRef pause];
}

void interruptionListenerCallback (void    *inUserData, UInt32  interruptionState) 
{
    if (interruptionState == kAudioSessionBeginInterruption) 
	{
		DLog(@"audio session begin interruption");		
    } 
	else if (interruptionState == kAudioSessionEndInterruption) 
	{
        DLog(@"audio session interruption ended");
    }
}

#pragma mark - Equalizer and Visualizer Methods

- (void)clearEqualizerValuesFromStream:(HSTREAM)stream
{
	int i = 0;
	for (BassEffectHandle *handle in eqHandleArray)
	{
		BASS_ChannelRemoveFX(self.currentStream, handle.effectHandle);
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
	[self clearEqualizerValuesFromStream:fileStream1];
	[self clearEqualizerValuesFromStream:fileStream2];
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
	[self applyEqualizerValues:values toStream:fileStream1];
	[self applyEqualizerValues:values toStream:fileStream2];
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
	BASS_StreamFree(fftStream);
}

- (void)startReadingEqData:(ISMS_BASS_EQ_DATA_TYPE)type
{
	[self stopReadingEqData];
	BASS_CHANNELINFO *info = malloc(sizeof(BASS_CHANNELINFO));
	BASS_ChannelGetInfo(self.currentStream, info);
	
	fftStream = BASS_StreamCreate(info->freq, info->chans, BASS_STREAM_DECODE, STREAMPROC_PUSH, 0);
	BASS_ChannelSetAttribute(fftStream, BASS_ATTRIB_NOBUFFER, YES);
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
		BASS_ChannelGetData(fftStream, fftData, BASS_DATA_FFT2048);
	
	// Get the data for line spec visualizer
	if (eqDataType == ISMS_BASS_EQ_DATA_TYPE_line)
		BASS_ChannelGetData(fftStream, lineSpecBuf, lineSpecBufSize);
}

#pragma mark - Player Controls

- (void)seekToPositionInBytes:(QWORD)bytes inStream:(HSTREAM)stream
{
	//DLog(@"fileStream1: %i   fileStream2: %i    currentStream: %i", fileStream1, fileStream2, self.currentStream);
	if (!BASS_ChannelSetPosition(stream, bytes, BASS_POS_BYTE))
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
			if (BASS_Init(0, 44100, 0, NULL, NULL))
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
				BASS_Free();
			}
			else
			{
				DLog(@"bass init failed in background thread");
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
	DLog(@"preparing next song stream internally");
	Song *nextSong = currPlaylistDAO.nextSong;
	
	BassUserInfo *userInfo = [[BassUserInfo alloc] init];
	userInfo.mySong = nextSong;
	NSString *path = nextSong.isTempCached ? nextSong.localTempPath : nextSong.localPath;
	userInfo.myFileHandle = fopen([path cStringUTF8], "rb");
	
	BASS_FILEPROCS fileProcs = {MyFileCloseProc, MyFileLenProc, MyFileReadProc, MyFileSeekProc}; // callback table
	
	// Try hardware and software mixing
	HSTREAM stream = BASS_StreamCreateFileUser(STREAMFILE_NOBUFFER, BASS_STREAM_DECODE, &fileProcs, userInfo);
	if(!stream) stream = BASS_StreamCreateFileUser(STREAMFILE_NOBUFFER, BASS_SAMPLE_SOFTWARE|BASS_STREAM_DECODE, &fileProcs, userInfo);
	
	if (stream)
	{
		BASS_ChannelSetSync(stream, BASS_SYNC_FREE, 0, MyStreamFreeCallback, userInfo);

		// Seek to the silence offset
		[self seekToPositionInBytes:[silence unsignedLongLongValue] inStream:stream];
		
		if (BASSisFilestream1)
		{
			fileStream2 = stream;
		}
		else
		{
			fileStream1 = stream;
		}
		
		if (isEqualizerOn)
		{
			[self applyEqualizerValues:eqValueArray toStream:stream];
		}
	}
	else
	{
		NSInteger errorCode = BASS_ErrorGetCode();
		DLog(@"nextSong stream: %i error: %i - %@", stream, errorCode, NSStringFromBassErrorCode(errorCode));
	}
	
	DLog(@"nextSong: %i", stream);
}

- (NSInteger)audioQueueSampleRate
{
	Float64 sampleRate;
	UInt32 size = sizeof(Float64);
	OSStatus status = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &sampleRate);
	DLog(@"sample rate: %i   status: %@", (NSUInteger)sampleRate, NSStringFromOSStatus(status));
	
	return (NSUInteger)sampleRate;
}

- (NSInteger)bassStreamSampleRate:(HSTREAM)stream
{
	float sampleRate = 0;
	BASS_ChannelGetAttribute(stream, BASS_ATTRIB_FREQ, &sampleRate);
	DLog(@"BASS Stream sample rate: %i", (NSUInteger)sampleRate);
	return (NSInteger)sampleRate;
}

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

// Create the audio queue
- (BOOL)aqsInit:(NSUInteger)sampleRate
{
	BOOL success = YES;
	for (int buf=0; buf<ISMS_AQNumBuffers; buf++) 
	{
		audioQueueBuffers[buf] = NULL;
	}
	
	DLog(@"Creating audio queue with %i sample rate", sampleRate);
	audioQueueOutputFormat.mSampleRate = sampleRate;
	audioQueueOutputFormat.mFormatID = kAudioFormatLinearPCM;
	audioQueueOutputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	audioQueueOutputFormat.mFramesPerPacket = 1;
	audioQueueOutputFormat.mChannelsPerFrame = 2;
	//audioQueueOutputFormat.mBytesPerPacket = audioQueueOutputFormat.mBytesPerFrame = sizeof(UInt16) * 2;
	audioQueueOutputFormat.mBitsPerChannel = 16;
	audioQueueOutputFormat.mBytesPerFrame    = audioQueueOutputFormat.mChannelsPerFrame * audioQueueOutputFormat.mBitsPerChannel/8; 
	audioQueueOutputFormat.mBytesPerPacket   = audioQueueOutputFormat.mBytesPerFrame * audioQueueOutputFormat.mFramesPerPacket;
	//audioQueueOutputFormat.mReserved = 0;
	
	OSStatus result = AudioQueueNewOutput(&audioQueueOutputFormat, MyQueueCallbackProc, self, NULL, kCFRunLoopCommonModes, 0, &audioQueue);
	
	if (result < 0)
	{
		DLog("ERROR: %lu", result);
		success = NO;
	}
	else
	{
		// Allocate buffers for the audio
		UInt32 bufferSizeBytes = ISMS_AQBufferSizeInFrames * audioQueueOutputFormat.mBytesPerFrame;
		for (int buf=0; buf<ISMS_AQNumBuffers; buf++) 
		{
			OSStatus result = AudioQueueAllocateBuffer(audioQueue, bufferSizeBytes, &audioQueueBuffers[buf]);
			if (result) 
			{ 
				DLog( "ERROR: %lu", result); 
				success = NO;
			}
			else
			{
				// Prime the buffers
				DLog(@"Priming audio queue buffer");
				MyQueueCallbackProc(self, audioQueue, audioQueueBuffers[buf]);
			}
		}
	}
	
	[self audioQueueSampleRate];
	
	return success;
}

- (BOOL)aqsStart
{
	DLog(@"starting audio queue");
	OSStatus result = AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, 1.0);
    if (result) printf("ERROR: %d\n", (int)result);
	
	// Start the queue
	result = AudioQueueStart(audioQueue, NULL);
	if (result)
	{
		// There was an error
		DLog("ERROR: %lu", result);
		isPlaying = NO;
	}
	else
	{
		isPlaying = YES;
	}
	
	return isPlaying;
}

- (BOOL)aqsPause
{
	OSStatus result = AudioQueuePause(audioQueue);
	if (result)
	{
		// There was an error
		DLog("ERROR: %lu", result);
	}
	else
	{
		isPlaying = NO;
	}
	
	return !isPlaying;
}

- (BOOL)aqsStop
{
	OSStatus result = AudioQueueStop(audioQueue, true);
    if (result)
	{
		// There was an error
		DLog("ERROR: %lu", result);
	}
	else
	{
		isPlaying = NO;
	}
	
	return !isPlaying;
}

#pragma mark - TEST

/*- (id)initWithSampleRate:(Float64)sampleRate channels:(UInt32)channels bitsPerChannel:(UInt32)bitsPerChannel packetsPerBuffer:(UInt32)packetsPerBuffer_
{
	if ((self = [super init]))
	{
		isPlaying = NO;
		audioQueue = NULL;
		
		audioQueueOutputFormat.mFormatID         = kAudioFormatLinearPCM;
		audioQueueOutputFormat.mSampleRate       = sampleRate;
		audioQueueOutputFormat.mChannelsPerFrame = channels;
		audioQueueOutputFormat.mBitsPerChannel   = bitsPerChannel;
		audioQueueOutputFormat.mFramesPerPacket  = 1;  // uncompressed audio
		audioQueueOutputFormat.mBytesPerFrame    = audioQueueOutputFormat.mChannelsPerFrame * audioQueueOutputFormat.mBitsPerChannel/8; 
		audioQueueOutputFormat.mBytesPerPacket   = audioQueueOutputFormat.mBytesPerFrame * audioQueueOutputFormat.mFramesPerPacket;
		audioQueueOutputFormat.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked; 

		[self setUpAudio];
	}
	return self;
}

- (void)setUpAudio
{
	if (playQueue == NULL)
	{
		[self setUpAudioSession];
		[self setUpPlayQueue];
		[self setUpPlayQueueBuffers];
	}
}

- (void)tearDownAudio
{
	if (playQueue != NULL)
	{
		[self stop];
		[self tearDownPlayQueue];
		[self tearDownAudioSession];
	}
}

- (void)setUpAudioSession
{
	AudioSessionInitialize(NULL, NULL, interruptionListenerCallback, self);
	
	UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
	AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
	
	AudioSessionSetActive(true);
}

- (void)tearDownAudioSession
{
	AudioSessionSetActive(false);
}

- (void)setUpPlayQueue
{
	AudioQueueNewOutput(
						&audioFormat,
						playCallback,
						self, 
						NULL,                   // run loop
						kCFRunLoopCommonModes,  // run loop mode
						0,                      // flags
						&playQueue
						);
	
	self.gain = 1.0;
}

- (void)tearDownPlayQueue
{
	AudioQueueDispose(playQueue, YES);
	playQueue = NULL;
}

- (void)setUpPlayQueueBuffers
{
	for (int t = 0; t < ISMS_AQNumBuffers; ++t)
	{
		AudioQueueAllocateBuffer(audioQueue, bytesPerBuffer, &audioQueueBuffers[t]);
	}
}

- (void)primePlayQueueBuffers
{
	for (int t = 0; t < ISMS_AQNumBuffers; ++t)
	{
		MyQueueCallbackProc(self, playQueue, audioQueueBuffers[t]);
	}
}

- (void)start
{
	if (!self.isPlaying)
	{
		playing = YES;
		[self primePlayQueueBuffers];
		AudioQueueStart(audioQueue, NULL);
	}
}

- (void)stop
{
	if (!self.isPlaying)
	{
		AudioQueueStop(audioQueue, TRUE);
		playing = NO;
	}
}
*/

#pragma mark - END TEST

- (void)startWithOffsetInBytes:(NSNumber *)byteOffset
{	
	if (currPlaylistDAO.currentIndex >= currPlaylistDAO.count)
		currPlaylistDAO.currentIndex = currPlaylistDAO.count - 1;
	
	Song *currentSong = currPlaylistDAO.currentSong;
	DLog(@"currentSong localSize: %llu", currentSong.localFileSize);
	
	if (!currentSong)
		return;
    
    startByteOffset = [byteOffset intValue];
	
	[self bassInit];
	
	BASS_INFO info;
	if (!BASS_GetInfo(&info))
		DLog(@"error: %i", BASS_ErrorGetCode());
	
	if (currentSong.fileExists)
	{	
		BassUserInfo *userInfo = [[BassUserInfo alloc] init];
		userInfo.mySong = currentSong;
		NSString *path = currentSong.isTempCached ? currentSong.localTempPath : currentSong.localPath;
		DLog(@"path: %@", path);
		userInfo.myFileHandle = fopen([path cStringUTF8], "rb");
		
		//DLog(@"userInfo.localPath: %s ", userInfo->localPath);
		BASS_FILEPROCS fileProcs = {MyFileCloseProc, MyFileLenProc, MyFileReadProc, MyFileSeekProc}; // callback table
		
		fileStream1 = BASS_StreamCreateFileUser(STREAMFILE_NOBUFFER, BASS_STREAM_DECODE, &fileProcs, userInfo);
		if(!fileStream1) fileStream1 = BASS_StreamCreateFileUser(STREAMFILE_NOBUFFER, BASS_SAMPLE_SOFTWARE|BASS_STREAM_DECODE, &fileProcs, userInfo);
		
		if (!fileStream1 && !currentSong.isFullyCached && currentSong.localFileSize < MIN_FILESIZE_TO_FAIL)
		{
			DLog(@"------failed to create stream, retrying in 2 seconds------");
			[self performSelector:@selector(startWithOffsetInBytes:) withObject:byteOffset afterDelay:RETRY_DELAY];
		}
		else
		{
			if (fileStream1)
			{
				fileStreamTempo1 = 0;
				BASSisFilestream1 = YES;
				
				// Add the stream free callback
				BASS_ChannelSetSync(fileStream1, BASS_SYNC_FREE, 0, MyStreamFreeCallback, userInfo);
				// Add the stream stall callback
				BASS_ChannelSetSync(fileStream1, BASS_SYNC_STALL, 0, MyStreamStallProc, NULL);
				
				// Skip to the byte offset
				[self seekToPositionInBytes:[byteOffset unsignedLongLongValue] inStream:fileStream1];
				
				// Enable the equalizer if it's turned on
				if (isEqualizerOn)
				{
					[self applyEqualizerValues:eqValueArray toStream:fileStream1];
				}
				
				// Add gain amplification
				volumeFx = BASS_ChannelSetFX(fileStream1, BASS_FX_BFX_VOLUME, 1);
				
				// Choose the proper sample rate
				NSInteger streamSampleRate = [self bassStreamSampleRate:fileStream1];
				NSInteger preferredSampleRate = [self preferredSampleRate:streamSampleRate];
				
				// Initialize the audio queue with the preferred sample rate
				[self aqsInit:preferredSampleRate];
				
				// Check the actual sample rate and modify the stream if necessary
				NSInteger audioQueueSampleRate = [self audioQueueSampleRate];
				DLog(@"audioQueueSampleRate: %i   streamSampleRate: %i", audioQueueSampleRate, streamSampleRate);
				if (audioQueueSampleRate != streamSampleRate)
				{
					fileStreamTempo1 = BASS_Mixer_StreamCreate(audioQueueSampleRate, 2, BASS_STREAM_DECODE|BASS_MIXER_END);
					if (!fileStreamTempo1)
						DLog(@"mixer error: %@", NSStringFromBassErrorCode(BASS_ErrorGetCode()));
					BASS_Mixer_StreamAddChannel(fileStreamTempo1, fileStream1, 0);// BASS_MIXER_FILTER);
					DLog(@"creating mixer stream: %i", fileStreamTempo1);
				}
				
				// Start the audio queue
				[self aqsStart];
								
				// Prepare the next song
				[self performSelectorInBackground:@selector(prepareNextSongStream) withObject:nil];
				
				[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackStarted];
			}
			else
			{
				DLog(@"BASS error: %i", BASS_ErrorGetCode());
			}
		}
	}
}

- (void)start
{
	[self startWithOffsetInBytes:[NSNumber numberWithInt:0]];
}

- (void)stop
{
    if (self.isPlaying) 
	{
		BASS_Pause();
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
		//BASS_Pause();
		[self aqsPause];
		
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackPaused];
	} 
	else 
	{
		if (self.currentStream == 0)
		{
			DLog(@"starting new stream");
			if (currPlaylistDAO.currentIndex >= currPlaylistDAO.count)
				currPlaylistDAO.currentIndex = currPlaylistDAO.count - 1;
			[[MusicSingleton sharedInstance] playSongAtPosition:currPlaylistDAO.currentIndex];
		}
		else
		{
			DLog(@"Playing");
			//BASS_Start();
			[self aqsStart];
			
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackStarted];
		}
	}
}

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
	BASS_SetConfig(BASS_CONFIG_BUFFER, updatePeriod + 1); // set the buffer length to the minimum amount
	BASS_SetConfig(BASS_CONFIG_FLOATDSP, true); // set DSP effects to use floating point math to avoid clipping within the effects chain
	if (!BASS_Init(0, sampleRate, 0, NULL, NULL)) 	// Initialize default device.
	{
		DLog(@"Can't initialize device");
	}
	BASS_PluginLoad(&BASSFLACplugin, 0); // load the FLAC plugin
	
	// Set up audio session
	AudioSessionInitialize(NULL, NULL, interruptionListenerCallback, self);
	UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
	AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
	AudioSessionSetActive(true);
	
	// Add the callbacks for headphone removal and other audio takeover
	AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, audioRouteChangeListenerCallback, self);
	AudioSessionAddPropertyListener(kAudioSessionProperty_OtherAudioIsPlaying, audioInterruptionListenerCallback, self);
}

- (void)bassInit
{
	// Default to 44.1 KHz
    [self bassInit:ISMS_defaultSampleRate];
}

/*- (void)bassEnterBackground
{
	BASS_SetConfig(BASS_CONFIG_BUFFER, ISMS_BASSBufferSizeBackground);
}

- (void)bassEnterForeground
{
	BASS_SetConfig(BASS_CONFIG_BUFFER, ISMS_BASSBufferSizeForeground);
}*/

- (BOOL)bassFree
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startWithOffsetInBytes:) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(prepareNextSongStreamInBackground) object:nil];
	
	// Audio Queue
	[self aqsStop];
	if (audioQueue)
	{
		// AudioQueueDispose also chucks any audio buffers it has
		DLog(@"disposing of audio queue");
		AudioQueueDispose(audioQueue, true);
	}
	audioQueue = NULL;
	AudioSessionSetActive(false);
	
	BOOL success = BASS_Free();
	fileStream1 = 0;
	fileStream2 = 0;
	
	return success;
}

#pragma mark - Properties

/*- (BOOL)isPlaying
{	
	return (BASS_ChannelIsActive(outStream) == BASS_ACTIVE_PLAYING);
}*/

- (NSUInteger)bitRate
{
	HSTREAM stream = self.currentStream;
	
	QWORD filePosition = BASS_StreamGetFilePosition(stream, BASS_FILEPOS_CURRENT); // current file position
	QWORD decodedPosition = BASS_ChannelGetPosition(stream, BASS_POS_BYTE|BASS_POS_DECODE); // decoded PCM position
	double bitrate = filePosition * 8 / BASS_ChannelBytes2Seconds(stream, decodedPosition);
	return (NSUInteger)(bitrate / 1000);
}

- (QWORD)currentByteOffset
{
	return self.bitRate * 128 * self.progress;
}

- (double)progress
{	
	NSUInteger bytePosition = BASS_ChannelGetPosition(self.currentStream, BASS_POS_BYTE);// + startByteOffset;
	double seconds = BASS_ChannelBytes2Seconds(self.currentStream, bytePosition);
	if (seconds < 0 && self.currentStream != 0)
		DLog(@"error: %i", BASS_ErrorGetCode());
		
	return seconds;// + (startByteOffset / (self.bitRate * 1024 / 8));
	
	/*QWORD decodedPosition = BASS_ChannelGetPosition(self.currentStream, BASS_POS_BYTE|BASS_POS_DECODE); // decoded PCM position
	double seconds = BASS_ChannelBytes2Seconds(self.currentStream, decodedPosition);
	return seconds;*/
}

- (HSTREAM)currentStream
{
	return BASSisFilestream1 ? fileStream1 : fileStream2;
}

- (HSTREAM)currentStreamTempo
{
	return BASSisFilestream1 ? fileStreamTempo1 : fileStreamTempo2;
}

- (HSTREAM)nextStream
{
	return BASSisFilestream1 ? fileStream2 : fileStream1;
}

- (HSTREAM)nextStreamTempo
{
	return BASSisFilestream1 ? fileStreamTempo2 : fileStreamTempo1;
}

#pragma mark - Singleton methods

- (void)setup
{	
	//selfRef = self;
	BASSisFilestream1 = YES;
	fileStream1 = 0;
	fileStreamTempo1 = 0;
	fileStream2 = 0;
	fileStreamTempo2 = 0;
	eqDataType = ISMS_BASS_EQ_DATA_TYPE_none;
	isFastForward = NO;
	isPlaying = NO;
	isEqualizerOn = NO;
    startByteOffset = 0;
    currPlaylistDAO = [[SUSCurrentPlaylistDAO alloc] init];
    
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

+ (BassWrapperSingleton *)sharedInstance
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






/*DWORD GetSilenceLength(const char *file)
 {
 BYTE buf[10000];
 DWORD count=0;
 HSTREAM chan = BASS_StreamCreateFile(FALSE, file, 0, 0, BASS_STREAM_DECODE); // create decoding channel
 if (!chan)
 DLog(@"getsilencelength error: %i", BASS_ErrorGetCode());
 while (BASS_ChannelIsActive(chan)) 
 {
 int a,b = BASS_ChannelGetData(chan, buf, 10000); // decode some data
 for (a = 0; a < b && !buf[a]; a++) ; // count silent bytes
 count += a; // add number of silent bytes
 if (a < b) break; // sound has begun!
 }
 DLog(@"silence: %i", count);
 BASS_StreamFree(chan);
 return count;
 }*/




/*DWORD DataForStream(void *buffer, DWORD length, void *user)
 {
 DWORD r;
 
 @autoreleasepool 
 {
 HSTREAM stream = self.currentStream;
 HSTREAM otherStream = self.nextStream;
 
 // Read data from stream
 r = BASS_ChannelGetData(stream, buffer, length);
 
 // Check if stream is now complete
 if (!BASS_ChannelIsActive(stream))
 {		
 // Stream is done, free the stream
 BASS_StreamFree(stream);
 
 // Increment current playlist index
 [SUSCurrentPlaylistDAO dataModel].currentIndex++;
 
 // Send song end notification
 [selfRef performSelectorOnMainThread:@selector(sendSongEndNotification) withObject:nil waitUntilDone:NO];
 
 // Check to see if there is another song to play
 if (BASS_ChannelIsActive(otherStream))
 {
 // Send song start notification
 [selfRef performSelectorOnMainThread:@selector(sendSongStartNotification) withObject:nil waitUntilDone:NO];
 
 // Read data from stream2
 isStartFromOffset = NO;
 isFilestream1 = !isFilestream1;
 r = BASS_ChannelGetData(otherStream, buffer, length);
 
 // Prepare the next song for playback
 [selfRef performSelectorInBackground:@selector(prepareNextSongStream) withObject:nil];
 }
 }
 }
 
 return r;
 }
 
 DWORD CALLBACK MyStreamProc(HSTREAM handle, void *buffer, DWORD length, void *user)
 {
 DWORD r;
 
 @autoreleasepool 
 {
 if (isFilestream1 && BASS_ChannelIsActive(fileStream1)) 
 {
 r = DataForStream(&buffer, length, &user);
 }
 else if (BASS_ChannelIsActive(fileStream2)) 
 {
 r = DataForStream(&buffer, length, &user);
 }
 else
 {
 //DLog(@"no more data, ending");
 r = BASS_STREAMPROC_END;
 }
 }
 
 return r;
 }*/
