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

@implementation BassWrapperSingleton
@synthesize isEqualizerOn, startByteOffset, isTempDownload, currPlaylistDAO;

// BASS plugins
extern void BASSFLACplugin;

// References for C functions
static BassWrapperSingleton *selfRef;
static SUSCurrentPlaylistDAO *currPlaylistDAORef;

// BASS stream variables
static BOOL BASSisFilestream1 = YES;
static HSTREAM fileStream1, fileStream2, outStream;
static NSThread *playbackThread = nil;

// Equalizer variables
static NSMutableArray *eqValueArray, *eqHandleArray;
static float fftData[1024];
short *lineSpecBuf;
int lineSpecBufSize;

// Failure Retry Values
#define RETRY_DELAY 2.0
#define MIN_FILESIZE_TO_FAIL (1024 * 1024 * 3)

#pragma mark - Decode Stream Callbacks

void CALLBACK MyFileCloseProc(void *user)
{
	// close the file
	FILE *file = ((ISMS_BASS_USERINFO *)user)->file;
	fclose(file);
	//fclose((FILE*)user);
}

// TODO: return next song length when appropriate
// TODO: when song is fully cached, return actual length from disk for precise seeking
QWORD CALLBACK MyFileLenProc(void *user)
{
	@autoreleasepool
	{
		ISMS_BASS_USERINFO *userInfo = user;
		DLog(@"user.localPath: %s", userInfo->localPath);
		NSString *localPath = [NSString stringWithFormat:@"%s", userInfo->localPath];
		DLog(@"localPath: %@", localPath);
		Song *theSong = [currPlaylistDAORef currentSong];
		DLog(@"TEST using current song: %@   localPath: %@", theSong, theSong.localPath);
		if (![localPath isEqualToString:theSong.localPath])
		{
			// It's not the current song so it's the next song
			theSong = [currPlaylistDAORef nextSong];
			DLog(@"TEST using next song: %@   localPath: %@", theSong, theSong.localPath);
		}
		
		if (theSong.isFullyCached)
		{
			DLog(@"TEST song is fully cached, using size on disk");
			// Return actual file size on disk
			struct stat s;
			fstat(fileno(userInfo->file), &s);
			DLog(@"TEST file length: %llu", s.st_size);
			return s.st_size;
		}
		else
		{
			DLog(@"TEST song not fully cached, using server reported file size");
			// Return server reported file size
			QWORD length = length = [theSong.size longLongValue];
			DLog(@"TEST file length: %llu", length);
			return length;
		}
	}
}

DWORD CALLBACK MyFileReadProc(void *buffer, DWORD length, void *user)
{
	// Read from the file
	FILE *file = ((ISMS_BASS_USERINFO *)user)->file;
	return fread(buffer, 1, length, file); 
	//return fread(buffer, 1, length, (FILE*)user); 
}

BOOL CALLBACK MyFileSeekProc(QWORD offset, void *user)
{	
	FILE *file = ((ISMS_BASS_USERINFO *)user)->file;
	BOOL success = !fseek(file, offset, SEEK_SET);
	//BOOL success = !fseek((FILE*)user, offset, SEEK_SET);
	DLog(@"TEST seeking to offset: %llu   success: %i", offset, success);
	// Seek to the requested offset (returns false if data not downloaded that far)
	return success; 
}

#pragma mark - Output Stream Callbacks

DWORD CALLBACK MyStreamProc(HSTREAM handle, void *buffer, DWORD length, void *user)
{
	if (!playbackThread)
		playbackThread = [NSThread currentThread];
	
	DWORD r;
	
	if (BASSisFilestream1 && BASS_ChannelIsActive(fileStream1)) 
	{
		// Read data from stream1
		r = BASS_ChannelGetData(fileStream1, buffer, length);
		
		// Check if stream1 is now complete
		if (!BASS_ChannelIsActive(fileStream1))
		{				
			// Stream1 is done, free the stream
			DLog(@"stream 1 is done");
			BASS_StreamFree(fileStream1);
			
			// Increment current playlist index
			[currPlaylistDAORef performSelectorOnMainThread:@selector(incrementIndex) withObject:nil waitUntilDone:YES];
			
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
				[selfRef setStartByteOffset:0];
				[selfRef setIsTempDownload:NO];
				BASSisFilestream1 = NO;
				r = BASS_ChannelGetData(fileStream2, buffer, length);
				DLog(@"error code: %i", BASS_ErrorGetCode());
				
				// Prepare the next song for playback
				[selfRef prepareNextSongStreamInBackground];
			}
		}
	}
	else if (BASS_ChannelIsActive(fileStream2)) 
	{
		// Read data from stream2
		r = BASS_ChannelGetData(fileStream2, buffer, length);
		
		// Check if stream2 is now complete
		if (!BASS_ChannelIsActive(fileStream2))
		{			
			// Stream2 is done, free the stream
			DLog(@"stream 2 is done");
			BASS_StreamFree(fileStream2);
			
			// Increment current playlist index
			[currPlaylistDAORef performSelectorOnMainThread:@selector(incrementIndex) withObject:nil waitUntilDone:YES];
			
			// Send song done notification
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackEnded];
			
			DLog(@"fileStream1: %i", fileStream1);
			if (BASS_ChannelIsActive(fileStream1))
			{				
				DLog(@"TEST starting stream1: %i", fileStream1);
				// Send song start notification
				[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackStarted];
				
				[selfRef setStartByteOffset:0];
				[selfRef setIsTempDownload:NO];
				BASSisFilestream1 = YES;
				r = BASS_ChannelGetData(fileStream1, buffer, length);
				DLog(@"error code: %i", BASS_ErrorGetCode());
				
				[selfRef prepareNextSongStreamInBackground];
			}
		}
	}
	else
	{
		r = BASS_STREAMPROC_END;
		[selfRef performSelectorOnMainThread:@selector(bassFree) withObject:nil waitUntilDone:NO];
	}
	
	return r;
}

void audioRouteChangeListenerCallback (void *inUserData, AudioSessionPropertyID inPropertyID, UInt32 inPropertyValueSize, const void *inPropertyValue) 
{
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
}

#pragma mark - Helper Functions

// translate a CTYPE value to text
const char *GetCTypeString(DWORD ctype, HPLUGIN plugin)
{
	if (plugin) 
	{ 
		// using a plugin
		const BASS_PLUGININFO *pinfo=BASS_PluginGetInfo(plugin); // get plugin info
		int a;
		for (a=0;a<pinfo->formatc;a++) 
		{
			if (pinfo->formats[a].ctype==ctype) // found a "ctype" match...
				return pinfo->formats[a].name; // return it's name
		}
	}
	// check built-in stream formats...
	if (ctype==BASS_CTYPE_STREAM_OGG) return "Ogg Vorbis";
	if (ctype==BASS_CTYPE_STREAM_MP1) return "MPEG layer 1";
	if (ctype==BASS_CTYPE_STREAM_MP2) return "MPEG layer 2";
	if (ctype==BASS_CTYPE_STREAM_MP3) return "MPEG layer 3";
	if (ctype==BASS_CTYPE_STREAM_AIFF) return "Audio IFF";
	if (ctype==BASS_CTYPE_STREAM_WAV_PCM) return "PCM WAVE";
	if (ctype==BASS_CTYPE_STREAM_WAV_FLOAT) return "Floating-point WAVE";
	if (ctype&BASS_CTYPE_STREAM_WAV) return "WAVE";
	if (ctype==BASS_CTYPE_STREAM_CA) 
	{
		// CoreAudio codec
		static char buf[100];
		const TAG_CA_CODEC *codec=(TAG_CA_CODEC*)BASS_ChannelGetTags(fileStream1,BASS_TAG_CA_CODEC); // get codec info
		snprintf(buf,sizeof(buf),"CoreAudio: %s",codec->name);
		return buf;
	}
	return "?";
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
	DLog("channel type = %x (%s)\nlength = %llu (%u:%02u)  flags: %i  freq: %i  origres: %i", i.ctype, GetCTypeString(i.ctype,i.plugin), bytes, time/60, time%60, i.flags, i.freq, i.origres);
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

#pragma mark - Equalizer Methods

- (void)clearEqualizer
{
	int i = 0;
	for (BassEffectHandle *handle in eqHandleArray)
	{
		BASS_ChannelRemoveFX(outStream, handle.effectHandle);
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

- (void)applyEqualizer:(NSArray *)values
{
	if (values == nil)
		return;
	else if ([values count] == 0)
		return;
	
	int i = 0;
	for (BassParamEqValue *value in eqValueArray)
	{
		HFX handle = BASS_ChannelSetFX(outStream, BASS_FX_DX8_PARAMEQ, 0);
		BASS_DX8_PARAMEQ p = value.parameters;
		BASS_FXSetParameters(handle, &p);
		
		value.handle = handle;
		
		DLog(@"applying eq for handle: %i  new values: center: %f   gain: %f   bandwidth: %f", value.handle, p.fCenter, p.fGain, p.fBandwidth);
		
		[eqHandleArray addObject:[BassEffectHandle handleWithEffectHandle:handle]];
		i++;
	}
	DLog(@"applied %i eq values", i);
	isEqualizerOn = YES;
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
		HFX handle = BASS_ChannelSetFX(outStream, BASS_FX_DX8_PARAMEQ, 0);
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
		BASS_ChannelRemoveFX(outStream, value.handle);
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
	[self clearEqualizer];
	
	[eqValueArray removeAllObjects];
}

- (BOOL)toggleEqualizer
{
	if (isEqualizerOn)
	{
		[self clearEqualizer];
		return NO;
	}
	else
	{
		[self applyEqualizer:eqValueArray];
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

- (void)readEqData
{
	// Get the FFT data for visualizer
	BASS_ChannelGetData(outStream, fftData, BASS_DATA_FFT2048);
	
	// Get the data for line spec visualizer
	BASS_ChannelGetData(outStream, lineSpecBuf, lineSpecBufSize);
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
		DLog(@"nextSong: %@   fileExists: %i", nextSong, nextSong.fileExists);
		if (nextSong.fileExists)
		{
			DLog(@"next song file exists");
			if (BASS_Init(0, 44100, 0, NULL, NULL))
			{
				DLog(@"ran bass init in background to check next song silence");
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
					[self performSelector:@selector(prepareNextSongStreamInternal:) onThread:playbackThread withObject:[NSNumber numberWithInt:silence] waitUntilDone:NO];
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

// playback thread
- (void)prepareNextSongStreamInternal:(NSNumber *)silence
{
	@autoreleasepool 
	{
		Song *nextSong = currPlaylistDAO.nextSong;
		
		//FILE *file = fopen([nextSong.localPath cStringUTF8], "rb");
		const ISMS_BASS_USERINFO userInfoInit = {
			.localPath = [nextSong.localPath cStringUTF8],
			.file = fopen([nextSong.localPath cStringUTF8], "rb")
		};
		ISMS_BASS_USERINFO *userInfo = malloc(sizeof(ISMS_BASS_USERINFO));
		*userInfo = userInfoInit;
		BASS_FILEPROCS fileProcs = {MyFileCloseProc, MyFileLenProc, MyFileReadProc, MyFileSeekProc}; // callback table
		
		// Try hardware and software mixing
		HSTREAM stream = BASS_StreamCreateFileUser(STREAMFILE_NOBUFFER, BASS_STREAM_DECODE, &fileProcs, userInfo);
		if(!stream) stream = BASS_StreamCreateFileUser(STREAMFILE_NOBUFFER, BASS_SAMPLE_SOFTWARE|BASS_STREAM_DECODE, &fileProcs, userInfo);
		
		if (stream)
		{
			// Seek to the silence offset
			[self seekToPositionInBytes:[silence unsignedLongLongValue] inStream:stream];
			
			if (BASSisFilestream1)
				fileStream2 = stream;
			else
				fileStream1 = stream;
		}
		else
		{
			NSInteger errorCode = BASS_ErrorGetCode();
			DLog(@"nextSong stream: %i error: %i - %@", stream, errorCode, NSStringFromBassErrorCode(errorCode));
		}
		
		DLog(@"nextSong: %i", stream);
	}
}

- (void)startWithOffsetInBytes:(NSNumber *)byteOffset
{	
	if (currPlaylistDAO.currentIndex >= currPlaylistDAO.count)
		currPlaylistDAO.currentIndex = currPlaylistDAO.count - 1;
	
	Song *currentSong = currPlaylistDAO.currentSong;
	DLog(@"currentSong localSize: %llu", currentSong.localFileSize);
	
	if (!currentSong)
		return;
    
    startByteOffset = [byteOffset intValue];
    isTempDownload = NO;
	
	[self bassInit];
	
	BASS_INFO info;
	if (!BASS_GetInfo(&info))
		DLog(@"error: %i", BASS_ErrorGetCode());
	
	if (currentSong.fileExists)
	{	
		const ISMS_BASS_USERINFO userInfoInit = {
			.localPath = [currentSong.localPath cStringUTF8],
			.file = fopen([currentSong.localPath cStringUTF8], "rb")
		};
		ISMS_BASS_USERINFO *userInfo = malloc(sizeof(ISMS_BASS_USERINFO));
		*userInfo = userInfoInit;
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
				DLog(@"currentSong: %i", fileStream1);
				BASSisFilestream1 = YES;
				
				// Skip to the byte offset
				[self seekToPositionInBytes:[byteOffset unsignedLongLongValue] inStream:fileStream1];
				
				BASS_CHANNELINFO info;
				BASS_ChannelGetInfo(fileStream1, &info);
				outStream = BASS_StreamCreate(info.freq, info.chans, 0, &MyStreamProc, 0); // create the output stream
				
				if (isEqualizerOn)
				{
					[self applyEqualizer:eqValueArray];
				}
				
				BASS_ChannelPlay(outStream, FALSE);
				
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

- (void)playPause
{
	if (self.isPlaying) 
	{
		DLog(@"Pausing");
		BASS_Pause();
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackPaused];
	} 
	else 
	{
		if (outStream == 0)
		{
			DLog(@"starting new stream");
			if (currPlaylistDAO.currentIndex >= currPlaylistDAO.count)
				currPlaylistDAO.currentIndex = currPlaylistDAO.count - 1;
			[[MusicSingleton sharedInstance] playSongAtPosition:currPlaylistDAO.currentIndex];
		}
		else
		{
			DLog(@"Playing");
			BASS_Start();
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackStarted];
		}
	}
}

- (void)bassInit:(NSUInteger)sampleRate
{
	isTempDownload = NO;
    
	[self bassFree];
	
	BASS_SetConfig(BASS_CONFIG_IOS_MIXAUDIO, 0); // Disable mixing.	To be called before BASS_Init.
	BASS_SetConfig(BASS_CONFIG_BUFFER, ISMS_BASSBufferSize);
	BASS_SetConfig(BASS_CONFIG_FLOATDSP, true);
	
	// Initialize default device.
	if (!BASS_Init(-1, sampleRate, 0, NULL, NULL)) 
	{
		DLog(@"Can't initialize device");
	}
	
	BASS_PluginLoad(&BASSFLACplugin, 0);
	
	AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, audioRouteChangeListenerCallback, self);
	AudioSessionAddPropertyListener(kAudioSessionProperty_OtherAudioIsPlaying, audioInterruptionListenerCallback, self);

	// Log actual sample rate
	Float64 actualSampleRate;
	UInt32 size = sizeof(Float64);
	OSStatus status = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &actualSampleRate);
	NSLog(@"sample rate: %f   status: %@", actualSampleRate, NSStringFromOSStatus(status));
}

- (void)bassInit
{
	// Default to 44.1 KHz
    [self bassInit:44100];
}

- (BOOL)bassFree
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startWithOffsetInBytes:) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(prepareNextSongStreamInBackground) object:nil];
	
	playbackThread = nil;
    isTempDownload = NO;
	BOOL success = BASS_Free();
	outStream = 0;
	return success;
}

#pragma mark - Properties

- (BOOL)isPlaying
{	
	return (BASS_ChannelIsActive(outStream) == BASS_ACTIVE_PLAYING);
}

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
	NSUInteger bytePosition = BASS_ChannelGetPosition(self.currentStream, BASS_POS_BYTE) + startByteOffset;
	double seconds = BASS_ChannelBytes2Seconds(self.currentStream, bytePosition);
	//DLog(@"bytePosition: %i   seconds: %f", bytePosition, seconds);
	if (seconds < 0 && self.currentStream != 0)
		DLog(@"error: %i", BASS_ErrorGetCode());
	return seconds;
}

- (HSTREAM)currentStream
{
	return BASSisFilestream1 ? fileStream1 : fileStream2;
}

- (HSTREAM)nextStream
{
	return BASSisFilestream1 ? fileStream2 : fileStream1;
}

#pragma mark - Singleton methods

static BassWrapperSingleton *sharedInstance = nil;

- (void)setup
{
	selfRef = self;
	isEqualizerOn = NO;
	isTempDownload = NO;
    startByteOffset = 0;
    currPlaylistDAO = [[SUSCurrentPlaylistDAO alloc] init];
	currPlaylistDAORef = currPlaylistDAO;
    
	eqValueArray = [[NSMutableArray alloc] initWithCapacity:4];
	eqHandleArray = [[NSMutableArray alloc] initWithCapacity:4];
	BassEffectDAO *effectDAO = [[BassEffectDAO alloc] initWithType:BassEffectType_ParametricEQ];
	[effectDAO selectPresetId:effectDAO.selectedPresetId];
	
	if (SCREEN_SCALE() == 1.0 && !IS_IPAD())
		lineSpecBufSize = 256 * sizeof(short);
	else
		lineSpecBufSize = 512 * sizeof(short);
	lineSpecBuf = malloc(lineSpecBufSize);
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepareNextSongStreamInBackground) name:ISMSNotification_RepeatModeChanged object:nil];
}

+ (BassWrapperSingleton *)sharedInstance
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
