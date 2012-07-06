//
//  BassEncryptedGaplessPlayer.m
//  Anghami
//
//  Created by Ben Baron on 7/2/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "BassEncryptedGaplessPlayer.h"
#import "Song.h"
#import "BassEncryptedStream.h"
#import "DDLog.h"
#import "GCDWrapper.h"
#import "SavedSettings.h"

static const int ddLogLevel = LOG_LEVEL_INFO;

extern BassGaplessPlayer *BassGaplessPlayerSelfRef;

@implementation BassEncryptedGaplessPlayer

- (id)init
{
	if ((self = [super init]))
	{
		BassGaplessPlayerSelfRef = self;
	}
	return self;
}

void CALLBACK EncryptedStreamEndCallback(HSYNC handle, DWORD channel, DWORD data, void *user)
{
	@autoreleasepool 
	{
		// Free and remove the channel
		BASS_StreamFree(channel);
		
		DDLogCVerbose(@"Stream end proc called");
		
		BassEncryptedStream *userInfo = (__bridge BassEncryptedStream *)user;
		if (userInfo)
		{
			DDLogCVerbose(@"stream end: user info exists for: %@", userInfo.song.title);
			NSUInteger index = [BassGaplessPlayerSelfRef.streamQueue indexOfObject:userInfo];
			if (index == 0)
			{
				// This is the current playing song, remove this one
				//[sharedInstance.streamQueue removeObjectAtIndex:0];
				DDLogCVerbose(@"stream end: this is the current playing song so set it to ended");
				userInfo.isEnded = YES;
				
				// Plug in the next one
				DDLogCVerbose(@"stream end: getting the next stream object");
				userInfo = [BassGaplessPlayerSelfRef.streamQueue objectAtIndexSafe:1];
				if (userInfo)
				{
					// There's another stream so play it
					DDLogCVerbose(@"stream end: next stream object found: %@  plugging stream %u into mixer %u", userInfo.song.title, BassGaplessPlayerSelfRef.mixerStream, userInfo.stream);
					BOOL success = BASS_Mixer_StreamAddChannel(BassGaplessPlayerSelfRef.mixerStream, userInfo.stream, 0);
					DDLogCVerbose(@"stream end, plugged next stream in with success: %@", NSStringFromBOOL(success));
				}
			}
			else
			{
				DDLogCVerbose(@"stream end: somehow this is now the stream at index 0");
				// Not sure why this would happen, just remove this stream from the queue
				//ssert(0 && "somehow this stream ended but was not the current playing stream");
				//[sharedInstance.streamQueue removeObjectAtIndex:index];
			}
		}
	}
}

void CALLBACK EncryptedFileCloseProc(void *user)
{	
	if (user == NULL)
		return;
	
	DDLogCVerbose(@"File close proc called");
	
	// Get the user info object
	BassEncryptedStream *userInfo = (__bridge BassEncryptedStream *)user;
	
	// Tell the read wait loop to break in case it's waiting
	userInfo.shouldBreakWaitLoop = YES;
	userInfo.shouldBreakWaitLoopForever = YES;
	
	// Close the file handle
	if (userInfo.decryptor)
		[userInfo.decryptor closeFile];
}

QWORD CALLBACK EncryptedFileLenProc(void *user)
{
	if (user == NULL)
		return 0;
	
	@autoreleasepool
	{
		BassEncryptedStream *userInfo = (__bridge BassEncryptedStream *)user;
		if (!userInfo.decryptor)
			return 0;
		
		QWORD length = 0;
		Song *theSong = userInfo.song;
		if (userInfo.shouldBreakWaitLoopForever)
		{
			return 0;
		}
		else if (theSong.isFullyCached || userInfo.isTempCached)
		{
			// Return decrypted file size on disk
			length = userInfo.decryptor.decryptedFileSizeOnDisk;
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

DWORD CALLBACK EncryptedFileReadProc(void *buffer, DWORD length, void *user)
{
	if (buffer == NULL || user == NULL)
		return 0;
	
	BassEncryptedStream *userInfo = (__bridge BassEncryptedStream *)user;
	if (!userInfo.decryptor)
		return 0;
	
	// Read from the file
	DWORD bytesRead = [userInfo.decryptor readBytes:buffer length:length];
	DDLogCVerbose(@"bytesRead: %u   length asked for: %u", bytesRead, length);
	
	if (bytesRead < length && userInfo.isSongStarted && !userInfo.wasFileJustUnderrun)
	{
		userInfo.isFileUnderrun = YES;
	}
	
	userInfo.wasFileJustUnderrun = NO;
	
	return bytesRead;
}

BOOL CALLBACK EncryptedFileSeekProc(QWORD offset, void *user)
{	
	if (user == NULL)
		return NO;
	
	// Seek to the requested offset (returns false if data not downloaded that far)
	BassEncryptedStream *userInfo = (__bridge BassEncryptedStream *)user;
	if (!userInfo.decryptor)
		return NO;
	
	BOOL success = [userInfo.decryptor seekToOffset:offset];
	DDLogCVerbose(@"seeking to %llu  success: %@", offset, NSStringFromBOOL(success));
	
	return success;
}

static BASS_FILEPROCS fileProcs = {EncryptedFileCloseProc, EncryptedFileLenProc, EncryptedFileReadProc, EncryptedFileSeekProc};

- (BassStream *)prepareStreamForSong:(Song *)aSong
{
	DDLogVerbose(@"preparing stream for %@  file: %@", aSong.title, aSong.currentPath);
	if (aSong.fileExists)
	{	
		// Create the user info object for the stream
		BassEncryptedStream *userInfo = [[BassEncryptedStream alloc] init];
		userInfo.song = aSong;
		userInfo.writePath = aSong.currentPath;
		userInfo.isTempCached = aSong.isTempCached;
		userInfo.decryptor = [[EX2FileDecryptor alloc] initWithPath:userInfo.writePath chunkSize:4096 key:settingsS.encryptionKey];
		if (!userInfo.decryptor)
		{
			// File failed to open
			DDLogError(@"File failed to open");
			return nil;
		}
		
		// Create the stream
		HSTREAM fileStream = BASS_StreamCreateFileUser(STREAMFILE_NOBUFFER, BASS_STREAM_DECODE|BASS_SAMPLE_FLOAT, &fileProcs, (__bridge void*)userInfo);
		if(!fileStream) fileStream = BASS_StreamCreateFileUser(STREAMFILE_NOBUFFER, BASS_SAMPLE_SOFTWARE|BASS_STREAM_DECODE|BASS_SAMPLE_FLOAT, &fileProcs, (__bridge void *)userInfo);
		if (fileStream)
		{
			// Add the stream free callback
			BASS_ChannelSetSync(fileStream, BASS_SYNC_END, 0, EncryptedStreamEndCallback, (__bridge void*)userInfo);
			
			// Stream successfully created
			userInfo.stream = fileStream;
			return userInfo;
		}
		
		// Failed to create the stream
		DDLogError(@"failed to create stream for song: %@  filename: %@", aSong.title, aSong.currentPath);
		return nil;
	}
	
	// File doesn't exist
	return nil;
}

@end
