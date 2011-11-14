//
//  AudioStreamer.m
//  StreamingAudioPlayer
//
//  Created by Matt Gallagher on 27/09/08.
//  Copyright 2008 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//
#import "AudioStreamer.h"
#import "iSubAppDelegate.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "SocialSingleton.h"
#import "Song.h"
#import "SUSCurrentPlaylistDAO.h"
#import "SA_OAuthTwitterEngine.h"
#ifdef TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

NSString * const ASStatusChangedNotification = @"ASStatusChangedNotification";

NSString * const AS_NO_ERROR_STRING = @"No error.";
NSString * const AS_FILE_STREAM_GET_PROPERTY_FAILED_STRING = @"File stream get property failed.";
NSString * const AS_FILE_STREAM_SEEK_FAILED_STRING = @"File stream seek failed.";
NSString * const AS_FILE_STREAM_PARSE_BYTES_FAILED_STRING = @"Parse bytes failed.";
NSString * const AS_FILE_STREAM_OPEN_FAILED_STRING = @"Open audio file stream failed.";
NSString * const AS_FILE_STREAM_CLOSE_FAILED_STRING = @"Close audio file stream failed.";
NSString * const AS_AUDIO_QUEUE_CREATION_FAILED_STRING = @"Audio queue creation failed.";
NSString * const AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED_STRING = @"Audio buffer allocation failed.";
NSString * const AS_AUDIO_QUEUE_ENQUEUE_FAILED_STRING = @"Queueing of audio buffer failed.";
NSString * const AS_AUDIO_QUEUE_ADD_LISTENER_FAILED_STRING = @"Audio queue add listener failed.";
NSString * const AS_AUDIO_QUEUE_REMOVE_LISTENER_FAILED_STRING = @"Audio queue remove listener failed.";
NSString * const AS_AUDIO_QUEUE_START_FAILED_STRING = @"Audio queue start failed.";
NSString * const AS_AUDIO_QUEUE_BUFFER_MISMATCH_STRING = @"Audio queue buffers don't match.";
NSString * const AS_AUDIO_QUEUE_DISPOSE_FAILED_STRING = @"Audio queue dispose failed.";
NSString * const AS_AUDIO_QUEUE_PAUSE_FAILED_STRING = @"Audio queue pause failed.";
NSString * const AS_AUDIO_QUEUE_STOP_FAILED_STRING = @"Audio queue stop failed.";
NSString * const AS_AUDIO_DATA_NOT_FOUND_STRING = @"No audio data found.";
NSString * const AS_AUDIO_QUEUE_FLUSH_FAILED_STRING = @"Audio queue flush failed.";
NSString * const AS_GET_AUDIO_TIME_FAILED_STRING = @"Audio queue get current time failed.";
NSString * const AS_AUDIO_STREAMER_FAILED_STRING = @"Audio playback failed";
NSString * const AS_NETWORK_CONNECTION_FAILED_STRING = @"Network connection failed";

static AudioStreamer *__streamer = nil;

@interface AudioStreamer ()
@property (readwrite) AudioStreamerState state;

- (void)handlePropertyChangeForFileStream:(AudioFileStreamID)inAudioFileStream 
	fileStreamPropertyID:(AudioFileStreamPropertyID)inPropertyID
	ioFlags:(UInt32 *)ioFlags;
- (void)handleAudioPackets:(const void *)inInputData
	numberBytes:(UInt32)inNumberBytes
	numberPackets:(UInt32)inNumberPackets
	packetDescriptions:(AudioStreamPacketDescription *)inPacketDescriptions;
- (void)handleBufferCompleteForQueue:(AudioQueueRef)inAQ
	buffer:(AudioQueueBufferRef)inBuffer;
- (void)handlePropertyChangeForQueue:(AudioQueueRef)inAQ
	propertyID:(AudioQueuePropertyID)inID;

#ifdef TARGET_OS_IPHONE
- (void)handleInterruptionChangeToState:(AudioQueuePropertyID)inInterruptionState;
#endif

- (void)enqueueBuffer;
- (void)handleReadFromStream:(CFReadStreamRef)aStream eventType:(CFStreamEventType)eventType;

@end

#pragma mark Audio Callback Function Prototypes

void MyAudioQueueOutputCallback(void* inClientData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer);
void MyAudioQueueIsRunningCallback(void *inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID);
void MyPropertyListenerProc(	void *							inClientData,
								AudioFileStreamID				inAudioFileStream,
								AudioFileStreamPropertyID		inPropertyID,
								UInt32 *						ioFlags);
void MyPacketsProc(				void *							inClientData,
								UInt32							inNumberBytes,
								UInt32							inNumberPackets,
								const void *					inInputData,
								AudioStreamPacketDescription	*inPacketDescriptions);
OSStatus MyEnqueueBuffer(AudioStreamer* myData);

#ifdef TARGET_OS_IPHONE			
void MyAudioSessionInterruptionListener(void *inClientData, UInt32 inInterruptionState);
#endif

#pragma mark Audio Callback Function Implementations

//
// MyPropertyListenerProc
//
// Receives notification when the AudioFileStream has audio packets to be
// played. In response, this function creates the AudioQueue, getting it
// ready to begin playback (playback won't begin until audio packets are
// sent to the queue in MyEnqueueBuffer).
//
// This function is adapted from Apple's example in AudioFileStreamExample with
// kAudioQueueProperty_IsRunning listening added.
//
void MyPropertyListenerProc(	void *							inClientData,
								AudioFileStreamID				inAudioFileStream,
								AudioFileStreamPropertyID		inPropertyID,
								UInt32 *						ioFlags)
{	
	// this is called by audio file stream when it finds property values
	//AudioStreamer* streamer = (AudioStreamer *)inClientData;
	//if (streamer)
	//	[streamer handlePropertyChangeForFileStream:inAudioFileStream fileStreamPropertyID:inPropertyID ioFlags:ioFlags];
	[__streamer handlePropertyChangeForFileStream:inAudioFileStream fileStreamPropertyID:inPropertyID ioFlags:ioFlags];
}

//
// MyPacketsProc
//
// When the AudioStream has packets to be played, this function gets an
// idle audio buffer and copies the audio packets into it. The calls to
// MyEnqueueBuffer won't return until there are buffers available (or the
// playback has been stopped).
//
// This function is adapted from Apple's example in AudioFileStreamExample with
// CBR functionality added.
//
void MyPacketsProc(				void *							inClientData,
								UInt32							inNumberBytes,
								UInt32							inNumberPackets,
								const void *					inInputData,
								AudioStreamPacketDescription	*inPacketDescriptions)
{
	// this is called by audio file stream when it finds packets of audio
	//AudioStreamer* streamer = (AudioStreamer *)inClientData;
	//if (streamer)
	//	[streamer handleAudioPackets:inInputData numberBytes:inNumberBytes numberPackets:inNumberPackets packetDescriptions:inPacketDescriptions];
	[__streamer handleAudioPackets:inInputData numberBytes:inNumberBytes numberPackets:inNumberPackets packetDescriptions:inPacketDescriptions];
}

//
// MyAudioQueueOutputCallback
//
// Called from the AudioQueue when playback of specific buffers completes. This
// function signals from the AudioQueue thread to the AudioStream thread that
// the buffer is idle and available for copying data.
//
// This function is unchanged from Apple's example in AudioFileStreamExample.
//
void MyAudioQueueOutputCallback(	void*					inClientData, 
									AudioQueueRef			inAQ, 
									AudioQueueBufferRef		inBuffer)
{
	// this is called by the audio queue when it has finished decoding our data. 
	// The buffer is now free to be reused.
	//AudioStreamer* streamer = (AudioStreamer*)inClientData;
	//if (streamer)
	//	[streamer handleBufferCompleteForQueue:inAQ buffer:inBuffer];
	[__streamer handleBufferCompleteForQueue:inAQ buffer:inBuffer];
}

//
// MyAudioQueueIsRunningCallback
//
// Called from the AudioQueue when playback is started or stopped. This
// information is used to toggle the observable "isPlaying" property and
// set the "finished" flag.
//
void MyAudioQueueIsRunningCallback(void *inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID)
{
	//AudioStreamer* streamer = (AudioStreamer *)inUserData;
	//if (streamer)
	//	[streamer handlePropertyChangeForQueue:inAQ propertyID:inID];
	[__streamer handlePropertyChangeForQueue:inAQ propertyID:inID];
}

#ifdef TARGET_OS_IPHONE			
//
// MyAudioSessionInterruptionListener
//
// Invoked if the audio session is interrupted (like when the phone rings)
//
void MyAudioSessionInterruptionListener(void *inClientData, UInt32 inInterruptionState)
{
	DLog(@"MyAudioSessionInterruptionListener called");
	//AudioStreamer* streamer = (AudioStreamer *)inClientData;
	//if (streamer)
	//	[streamer handleInterruptionChangeToState:inInterruptionState];
	[__streamer handleInterruptionChangeToState:inInterruptionState];
}

// Audio session callback function for responding to audio route changes. If playing 
// back application audio when the headset is unplugged, this callback pauses 
// playback and displays an alert that allows the user to resume or stop playback.
//
// The system takes care of iPod audio pausing during route changes--this callback  
// is not involved with pausing playback of iPod audio.

void audioRouteChangeListenerCallback (void *inUserData, AudioSessionPropertyID inPropertyID, UInt32 inPropertyValueSize, const void *inPropertyValue) 
{
    DLog(@"audioRouteChangeListenerCallback called");
	
	//iSubAppDelegate *appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	MusicSingleton *musicControls = [MusicSingleton sharedInstance];
	
    // ensure that this callback was invoked for a route change
    if (inPropertyID != kAudioSessionProperty_AudioRouteChange) return;
	
    // if application sound is not playing, there's nothing to do, so return.
	//AudioStreamer* streamer = (AudioStreamer *)inUserData;
    //if ([streamer isPlaying] == NO )
	if (musicControls.isPlaying == NO)
	{	
        NSLog (@"Audio route change while application audio is stopped.");
        return;
    }
	else 
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
            [musicControls playPauseSong];
			
            NSLog (@"Output device removed, so application audio was paused.");
        } 
		else 
		{
            NSLog (@"A route change occurred that does not require pausing of application audio.");
        }
    }
}

#endif

#pragma mark CFReadStream Callback Function Implementations

//
// ReadStreamCallBack
//
// This is the callback for the CFReadStream from the network connection. This
// is where all network data is passed to the AudioFileStream.
//
// Invoked when an error occurs, the stream ends or we have data to read.
//
void ASReadStreamCallBack (CFReadStreamRef aStream, CFStreamEventType eventType, void *inClientInfo)
{
	//AudioStreamer* streamer = (AudioStreamer *)inClientInfo;
	//if (streamer)
	//	[streamer handleReadFromStream:aStream eventType:eventType];
	[__streamer handleReadFromStream:aStream eventType:eventType];
}

@implementation AudioStreamer

@synthesize errorCode;
@synthesize bitRate;
@synthesize offsetStart;
@synthesize stopReason;
@synthesize fileDownloadComplete;
@synthesize fileDownloadCurrentSize;
@synthesize fileDownloadBytesRead;
@dynamic progress;
@synthesize seekTime;

@synthesize tweetTimer;
@synthesize scrobbleTimer;

//
// initWithURL
//
// Init method for the object.
//
- (id)initWithURL:(NSURL *)aURL
{
	self = [super init];
	if (self != nil)
	{
		shouldInvalidateTweetTimer = NO;
		tweetTimer = nil;
		shouldInvalidateScrobbleTimer = NO;
		scrobbleTimer = nil;
		fileDownloadBytesRead = 0;
		fileDownloadComplete = NO;
		fileDownloadCurrentSize = 0;
		fixedLength = NO;
		url = [aURL retain];
		self.offsetStart = 0;
	}
	return self;
}

//
// initWithURL
//
// Init method for the playing a file on the file system.
//
- (id)initWithFileURL:(NSURL *)aURL 
{	
	[self initWithURL:aURL];
	if (self != nil)
	{
		offsetStart = 0;
		fixedLength = YES;
	}
	return self;
}

//
// dealloc
//
// Releases instance memory.
//
- (void)dealloc
{
	//DLog(@"------ audiostreamer dealloc called");
	shouldInvalidateTweetTimer = NO;
	[tweetTimer invalidate]; [tweetTimer release]; tweetTimer = nil;
	[scrobbleTimer invalidate]; [scrobbleTimer release]; scrobbleTimer = nil;
	[self stop];
	[notificationCenter release]; notificationCenter = nil;
	[url release]; url = nil;
	[super dealloc];
}

//
// isFinishing
//
// returns YES if the audio has reached a stopping condition.
//
- (BOOL)isFinishing
{
	@synchronized (self)
	{
		if ((errorCode != AS_NO_ERROR && state != AS_INITIALIZED) ||
			((state == AS_STOPPING || state == AS_STOPPED) &&
				stopReason != AS_STOPPING_TEMPORARILY))
		{
			return YES;
		}
	}
	
	return NO;
}

//
// runLoopShouldExit
//
// returns YES if the run loop should exit.
//
- (BOOL)runLoopShouldExit
{
	@synchronized(self)
	{
		if (errorCode != AS_NO_ERROR || (state == AS_STOPPED && stopReason != AS_STOPPING_TEMPORARILY))
		{
			return YES;
		}
	}
	
	return NO;
}

//
// stringForErrorCode:
//
// Converts an error code to a string that can be localized or presented
// to the user.
//
// Parameters:
//    anErrorCode - the error code to convert
//
// returns the string representation of the error code
//
+ (NSString *)stringForErrorCode:(AudioStreamerErrorCode)anErrorCode
{
	switch (anErrorCode)
	{
		case AS_NO_ERROR:
			return AS_NO_ERROR_STRING;
		case AS_FILE_STREAM_GET_PROPERTY_FAILED:
			return AS_FILE_STREAM_GET_PROPERTY_FAILED_STRING;
		case AS_FILE_STREAM_SEEK_FAILED:
			return AS_FILE_STREAM_SEEK_FAILED_STRING;
		case AS_FILE_STREAM_PARSE_BYTES_FAILED:
			return AS_FILE_STREAM_PARSE_BYTES_FAILED_STRING;
		case AS_AUDIO_QUEUE_CREATION_FAILED:
			return AS_AUDIO_QUEUE_CREATION_FAILED_STRING;
		case AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED:
			return AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED_STRING;
		case AS_AUDIO_QUEUE_ENQUEUE_FAILED:
			return AS_AUDIO_QUEUE_ENQUEUE_FAILED_STRING;
		case AS_AUDIO_QUEUE_ADD_LISTENER_FAILED:
			return AS_AUDIO_QUEUE_ADD_LISTENER_FAILED_STRING;
		case AS_AUDIO_QUEUE_REMOVE_LISTENER_FAILED:
			return AS_AUDIO_QUEUE_REMOVE_LISTENER_FAILED_STRING;
		case AS_AUDIO_QUEUE_START_FAILED:
			return AS_AUDIO_QUEUE_START_FAILED_STRING;
		case AS_AUDIO_QUEUE_BUFFER_MISMATCH:
			return AS_AUDIO_QUEUE_BUFFER_MISMATCH_STRING;
		case AS_FILE_STREAM_OPEN_FAILED:
			return AS_FILE_STREAM_OPEN_FAILED_STRING;
		case AS_FILE_STREAM_CLOSE_FAILED:
			return AS_FILE_STREAM_CLOSE_FAILED_STRING;
		case AS_AUDIO_QUEUE_DISPOSE_FAILED:
			return AS_AUDIO_QUEUE_DISPOSE_FAILED_STRING;
		case AS_AUDIO_QUEUE_PAUSE_FAILED:
			return AS_AUDIO_QUEUE_DISPOSE_FAILED_STRING;
		case AS_AUDIO_QUEUE_FLUSH_FAILED:
			return AS_AUDIO_QUEUE_FLUSH_FAILED_STRING;
		case AS_AUDIO_DATA_NOT_FOUND:
			return AS_AUDIO_DATA_NOT_FOUND_STRING;
		case AS_GET_AUDIO_TIME_FAILED:
			return AS_GET_AUDIO_TIME_FAILED_STRING;
		case AS_NETWORK_CONNECTION_FAILED:
			return AS_NETWORK_CONNECTION_FAILED_STRING;
		case AS_AUDIO_QUEUE_STOP_FAILED:
			return AS_AUDIO_QUEUE_STOP_FAILED_STRING;
		case AS_AUDIO_STREAMER_FAILED:
			return AS_AUDIO_STREAMER_FAILED_STRING;
		default:
			return AS_AUDIO_STREAMER_FAILED_STRING;
	}
	
	return AS_AUDIO_STREAMER_FAILED_STRING;
}

//
// failWithErrorCode:
//
// Sets the playback state to failed and logs the error.
//
// Parameters:
//    anErrorCode - the error condition
//
- (void)failWithErrorCode:(AudioStreamerErrorCode)anErrorCode
{
	@synchronized(self)
	{
		if (errorCode != AS_NO_ERROR)
		{
			// Only set the error once.
			return;
		}
		
		errorCode = anErrorCode;

		if (err)
		{
			char *errChars = (char *)&err;
			DLog(@"%@ err: %c%c%c%c %d\n",
				[AudioStreamer stringForErrorCode:anErrorCode],
				errChars[3], errChars[2], errChars[1], errChars[0],
				(int)err);
		}
		else
		{
			DLog(@"%@", [AudioStreamer stringForErrorCode:anErrorCode]);
		}

		if (state == AS_PLAYING ||
			state == AS_PAUSED ||
			state == AS_BUFFERING)
		{
			self.state = AS_STOPPING;
			stopReason = AS_STOPPING_ERROR;
			AudioQueueStop(audioQueue, true);
		}

/*#ifdef TARGET_OS_IPHONE			
		CustomUIAlertView *alert =
			[[[CustomUIAlertView alloc]
				initWithTitle:NSLocalizedStringFromTable(@"Audio Error", @"Errors", nil)
				message:NSLocalizedStringFromTable(@"Attempt to play streaming audio failed.", @"Errors", nil)
				delegate:self
				cancelButtonTitle:@"OK"
				otherButtonTitles: nil]
			autorelease];
		[alert 
			performSelector:@selector(show)
			onThread:[NSThread mainThread]
			withObject:nil
			waitUntilDone:NO];
#else
		NSAlert *alert =
			[NSAlert
				alertWithMessageText:NSLocalizedString(@"Audio Error", @"")
				defaultButton:NSLocalizedString(@"OK", @"")
				alternateButton:nil
				otherButton:nil
				informativeTextWithFormat:@"Attempt to play streaming audio failed."];
		[alert
			performSelector:@selector(runModal)
			onThread:[NSThread mainThread]
			withObject:nil
			waitUntilDone:NO];
#endif*/
	}
}

//
// setState:
//
// Sets the state and sends a notification that the state has changed.
//
// This method
//
// Parameters:
//    anErrorCode - the error condition
//
- (void)setState:(AudioStreamerState)aStatus
{
	@synchronized(self)
	{
		//DLog(@"sending change of state notification");
		if (state != aStatus)
		{
			state = aStatus;
			
			NSNotification *notification =
				[NSNotification
					notificationWithName:ASStatusChangedNotification
					object:self];
			[notificationCenter
				performSelector:@selector(postNotification:)
				onThread:[NSThread mainThread]
				withObject:notification
				waitUntilDone:NO];
		}
	}
}

- (AudioStreamerState)state
{
	return state;
}

//
// isPlaying
//
// returns YES if the audio currently playing.
//
- (BOOL)isPlaying
{
	if (state == AS_PLAYING)
	{
		return YES;
	}
	
	return NO;
}

//
// isPaused
//
// returns YES if the audio currently playing.
//
- (BOOL)isPaused
{
	if (state == AS_PAUSED)
	{
		return YES;
	}
	
	return NO;
}

//
// isWaiting
//
// returns YES if the AudioStreamer is waiting for a state transition of some
// kind.
//
- (BOOL)isWaiting
{
	@synchronized(self)
	{
		if ([self isFinishing] ||
			state == AS_STARTING_FILE_THREAD||
			state == AS_WAITING_FOR_DATA ||
			state == AS_WAITING_FOR_QUEUE_TO_START ||
			state == AS_BUFFERING)
		{
			return YES;
		}
	}
	
	return NO;
}

//
// isIdle
//
// returns YES if the AudioStream is in the AS_INITIALIZED state (i.e.
// isn't doing anything).
//
- (BOOL)isIdle
{
	if (state == AS_INITIALIZED)
	{
		return YES;
	}
	
	return NO;
}

//
// openFileStream
//
// Open the audioFileStream to parse data and the fileHandle as the data
// source.
//
- (BOOL)openFileStream
{
	@synchronized(self)
	{
		NSAssert(stream == nil && audioFileStream == nil,
			@"audioFileStream already initialized");
		
		//
		// Attempt to guess the file type from the URL. Reading the MIME type
		// from the CFReadStream would be a better approach since lots of
		// URL's don't have the right extension.
		//
		// If you have a fixed file-type, you may want to hardcode this.
		//
		NSString *fileExtension = [[url path] pathExtension];
		/*iSubAppDelegate *appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		NSString *fileExtension;
		if (appDelegate.currentSongObject.transcodedSuffix)
			fileExtension = appDelegate.currentSongObject.transcodedSuffix;
		else
			fileExtension = appDelegate.currentSongObject.suffix;
		DLog(@"fileExtension = %@", fileExtension);*/
		
		//AudioFileTypeID fileTypeHint = kAudioFileMP3Type;
		AudioFileTypeID fileTypeHint = kAudioFileMPEG4Type;
		if ([fileExtension isEqual:@"mp3"])
		{
			fileTypeHint = kAudioFileMP3Type;
		}
		else if ([fileExtension isEqual:@"wav"])
		{
			fileTypeHint = kAudioFileWAVEType;
		}
		else if ([fileExtension isEqual:@"aifc"])
		{
			fileTypeHint = kAudioFileAIFCType;
		}
		else if ([fileExtension isEqual:@"aiff"])
		{
			fileTypeHint = kAudioFileAIFFType;
		}
		else if ([fileExtension isEqual:@"m4a"])
		{
			fileTypeHint = kAudioFileM4AType;
		}
		else if ([fileExtension isEqual:@"mp4"])
		{
			fileTypeHint = kAudioFileMPEG4Type;
		}
		else if ([fileExtension isEqual:@"caf"])
		{
			fileTypeHint = kAudioFileCAFType;
		}
		else if ([fileExtension isEqual:@"aac"])
		{
			fileTypeHint = kAudioFileAAC_ADTSType;
		}
		//DLog(@"fileTypeHint: %@", fileTypeHint);

		// create an audio file stream parser
		err = AudioFileStreamOpen(self, MyPropertyListenerProc, MyPacketsProc, 
								fileTypeHint, &audioFileStream);
		if (err)
		{
			[self failWithErrorCode:AS_FILE_STREAM_OPEN_FAILED];
			return NO;
		}
		
		if (fixedLength) 
		{
			// Just open the file at the specified location
			//DLog(@"Opening file stream for %@", [url absoluteString] );
			stream = CFReadStreamCreateWithFile(kCFAllocatorDefault, (CFURLRef)url);
			if (!stream)
				DLog(@"Could not open file stream");
			if(!CFReadStreamSetProperty(stream, kCFStreamPropertyFileCurrentOffset, CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &offsetStart)))
				DLog(@"error setting the offset");
			//DLog(@"Stream created");
		} 
		else 
		{
			//
			// Create the GET request
			//
			//DLog(@"Opening HTTP stream");
			CFHTTPMessageRef message= CFHTTPMessageCreateRequest(NULL, (CFStringRef)@"GET", (CFURLRef)url, kCFHTTPVersion1_1);
			stream = CFReadStreamCreateForHTTPRequest(NULL, message);
			CFRelease(message);			
			//
			// Enable stream redirection
			//
			if (CFReadStreamSetProperty(
										stream,
										kCFStreamPropertyHTTPShouldAutoredirect,
										kCFBooleanTrue) == false)
			{
/*#ifdef TARGET_OS_IPHONE
				CustomUIAlertView *alert =
				[[CustomUIAlertView alloc]
				 initWithTitle:NSLocalizedStringFromTable(@"File Error", @"Errors", nil)
				 message:NSLocalizedStringFromTable(@"Unable to configure network read stream.", @"Errors", nil)
				 delegate:self
				 cancelButtonTitle:@"OK"
				 otherButtonTitles: nil];
				[alert
				 performSelector:@selector(show)
				 onThread:[NSThread mainThread]
				 withObject:nil
				 waitUntilDone:YES];
				[alert release];
#else
				NSAlert *alert =
				[NSAlert
				 alertWithMessageText:NSLocalizedStringFromTable(@"File Error", @"Errors", nil)
				 defaultButton:NSLocalizedString(@"OK", @"")
				 alternateButton:nil
				 otherButton:nil
				 informativeTextWithFormat:NSLocalizedStringFromTable(@"Unable to configure network read stream.", @"Errors", nil)];
				[alert
				 performSelector:@selector(runModal)
				 onThread:[NSThread mainThread]
				 withObject:nil
				 waitUntilDone:NO];
#endif*/
				return NO;
			}
			
			//
			// Handle SSL connections
			//
			if( [[url absoluteString] rangeOfString:@"https"].location != NSNotFound )
			{
				NSDictionary *sslSettings =
					[NSDictionary dictionaryWithObjectsAndKeys:
						(NSString *)kCFStreamSocketSecurityLevelNegotiatedSSL, kCFStreamSSLLevel,
						[NSNumber numberWithBool:YES], kCFStreamSSLAllowsExpiredCertificates,
						[NSNumber numberWithBool:YES], kCFStreamSSLAllowsExpiredRoots,
						[NSNumber numberWithBool:YES], kCFStreamSSLAllowsAnyRoot,
						[NSNumber numberWithBool:NO], kCFStreamSSLValidatesCertificateChain,
						[NSNull null], kCFStreamSSLPeerName,
					nil];

				CFReadStreamSetProperty(stream, kCFStreamPropertySSLSettings, sslSettings);
			}
		}
		
		//DLog(@"Ready to open stream");
		//
		// Open the stream
		//
		if (!CFReadStreamOpen(stream))
		{
			DLog(@"Failed to open stream");
			CFStreamError myErr = CFReadStreamGetError(stream);
			
			errorCode = AS_FILE_STREAM_OPEN_FAILED;
			
			DLog(@"Error domain = %ld, err = %ld", myErr.domain, myErr.error);
			CFRelease(stream);
			stream = nil;
/*#ifdef TARGET_OS_IPHONE
			CustomUIAlertView *alert =
			[[CustomUIAlertView alloc]
			 initWithTitle:NSLocalizedStringFromTable(@"File Error", @"Errors", nil)
			 message:NSLocalizedStringFromTable(@"Unable to configure network read stream.", @"Errors", nil)
			 delegate:self
			 cancelButtonTitle:@"OK"
			 otherButtonTitles: nil];
			[alert
			 performSelector:@selector(show)
			 onThread:[NSThread mainThread]
			 withObject:nil
			 waitUntilDone:YES];
			[alert release];
#else
			NSAlert *alert =
			[NSAlert
			 alertWithMessageText:NSLocalizedStringFromTable(@"File Error", @"Errors", nil)
			 defaultButton:NSLocalizedString(@"OK", @"")
			 alternateButton:nil
			 otherButton:nil
			 informativeTextWithFormat:NSLocalizedStringFromTable(@"Unable to configure network read stream.", @"Errors", nil)];
			[alert
			 performSelector:@selector(runModal)
			 onThread:[NSThread mainThread]
			 withObject:nil
			 waitUntilDone:NO];
#endif*/
			return NO;
		} 
		else 
		{
			//DLog(@"Opened the stream!");
			
			
			//
			// Set our callback function to receive the data
			//
			CFStreamClientContext context = {0, self, NULL, NULL, NULL};
			
			// The unfortunate thing about reading a file like this is that this it stops when it hits the EOF even if we
			// may still be writing to the file.  This means that we can't wait and continue playback when data is added to 
			// the file we are streaming from.
			CFReadStreamSetClient(
								  stream,
								  kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered,
								  ASReadStreamCallBack,
								  &context);
			CFReadStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
		}
	}
	
	return YES;
}

//
// startInternal
//
// This is the start method for the AudioStream thread. This thread is created
// because it will be blocked when there are no audio buffers idle (and ready
// to receive audio data).
//
// Activity in this thread:
//	- Creation and cleanup of all AudioFileStream and AudioQueue objects
//	- Receives data from the CFReadStream
//	- AudioFileStream processing
//	- Copying of data from AudioFileStream into audio buffers
//  - Stopping of the thread because of end-of-file
//	- Stopping due to error or failure
//
// Activity *not* in this thread:
//	- AudioQueue playback and notifications (happens in AudioQueue thread)
//  - Actual download of NSURLConnection data (NSURLConnection's thread)
//	- Creation of the AudioStreamer (other, likely "main" thread)
//	- Invocation of -start method (other, likely "main" thread)
//	- User/manual invocation of -stop (other, likely "main" thread)
//
// This method contains bits of the "main" function from Apple's example in
// AudioFileStreamExample.
//
- (void)startInternal
{
	DLog(@"------ audiostreamer startInternal called");
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	@synchronized(self)
	{
		if (state == AS_STOPPING)
		{
			self.state = AS_INITIALIZED;
			[pool release];
			return;
		}
		
		NSAssert(state == AS_STARTING_FILE_THREAD,
			@"Start illegally invoked on an audio stream that has already started.");
		
	#ifdef TARGET_OS_IPHONE			
		//
		// Set the audio session category so that we continue to play if the
		// iPhone/iPod auto-locks.
		//
		AudioSessionInitialize (
			NULL,                          // 'NULL' to use the default (main) run loop
			NULL,                          // 'NULL' to use the default run loop mode
			MyAudioSessionInterruptionListener,  // a reference to your interruption callback
			self                       // data to pass to your interruption listener callback
		);
		UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
		AudioSessionSetProperty (
			kAudioSessionProperty_AudioCategory,
			sizeof (sessionCategory),
			&sessionCategory
		);
		
		AudioSessionAddPropertyListener ( // Registers the audio route change listener callback function
			kAudioSessionProperty_AudioRouteChange,
			audioRouteChangeListenerCallback,
			self
		);
		AudioSessionSetActive(true);
		__streamer = self;
	#endif
	
		self.state = AS_WAITING_FOR_DATA;
		
		// initialize a mutex and condition so that we can block on buffers in use.
		pthread_mutex_init(&queueBuffersMutex, NULL);
		pthread_cond_init(&queueBufferReadyCondition, NULL);
		
		if (![self openFileStream])
		{
			goto cleanup;
		}
	}
		
	// Flag to indicate that we have gotten too close to the EOF before the entire file has
	// downloaded so we need throttle the playback.
	BOOL isThrottling = NO;
	
	//
	// Process the run loop until playback is finished or failed.
	//
	BOOL isRunning = YES;
	do
	{
		// If we are playing a fixed-length MP3 make sure we are not too close to the end of the file.  This prevents us from hitting the end of the file 
		// before it is fully downloaded.  Very useful when not on 3G since the song may be played faster than it is downloaded.
		//DLog(@"fileDownloadCurrentSize:  %i   (fileDownloadBytesRead + (kAQBufSize * kNumAQBufs):  %i", self.fileDownloadCurrentSize, (fileDownloadBytesRead + (kAQBufSize * kNumAQBufs)));
		if (!fixedLength || self.fileDownloadComplete || self.fileDownloadCurrentSize > (fileDownloadBytesRead + (kAQBufSize * kNumAQBufs))) 
		{	
			if (isThrottling) {
				//DLog(@"Stop throttling.");
				isThrottling = NO;
				AudioQueueStart(audioQueue, NULL);
				self.state = AS_PLAYING;
			}
			
			isRunning = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
			
			//
			// If there are no queued buffers, we need to check here since the
			// handleBufferCompleteForQueue:buffer: should not change the state
			// (may not enter the synchronized section).
			//
			if (buffersUsed == 0 && self.state == AS_PLAYING)
			{
				self.state = AS_BUFFERING;
			}
		} 
		else if (!isThrottling && self.state == AS_PLAYING) 
		{
			//DLog(@"Start throttling because we are too close to EOF.");
			
			self.state = AS_BUFFERING;
			
			AudioQueuePause(audioQueue);
			isThrottling = YES;
			
			// Sleep for a few seconds
			[NSThread sleepForTimeInterval:1.0];
		}
	} 
	while (isRunning && ![self runLoopShouldExit]);
	
cleanup:

	@synchronized(self)
	{
		//
		// Cleanup the read stream if it is still open
		//
		if (stream)
		{
			CFReadStreamClose(stream);
			CFRelease(stream);
			stream = nil;
		}
		
		//
		// Close the audio file stream
		//
		if (audioFileStream)
		{
			err = AudioFileStreamClose(audioFileStream);
			audioFileStream = nil;
			if (err)
			{
				[self failWithErrorCode:AS_FILE_STREAM_CLOSE_FAILED];
			}
		}
		
		//
		// Dispose of the Audio Queue
		//
		if (audioQueue)
		{
			err = AudioQueueDispose(audioQueue, true);
			audioQueue = nil;
			if (err)
			{
				[self failWithErrorCode:AS_AUDIO_QUEUE_DISPOSE_FAILED];
			}
		}

		pthread_mutex_destroy(&queueBuffersMutex);
		pthread_cond_destroy(&queueBufferReadyCondition);
		
#ifdef TARGET_OS_IPHONE
		AudioSessionSetActive(false);
#endif

		bytesFilled = 0;
		packetsFilled = 0;
		seekTime = 0;
		seekNeeded = NO;
		self.state = AS_INITIALIZED;
	}

	[pool release];
}

//
// start
//
// Calls startInternal in a new thread.
//
- (void)start
{
	MusicSingleton *musicControls = [MusicSingleton sharedInstance];
	
	DLog(@"------ audiostreamer start called");
	@synchronized (self)
	{
		if (state == AS_PAUSED)
		{
			[self pause];
		}
		else if (state == AS_INITIALIZED)
		{
			//if (musicControls.isPlaying)
			{
				NSAssert([[NSThread currentThread] isEqual:[NSThread mainThread]], @"Playback can only be started from the main thread.");
				notificationCenter = [[NSNotificationCenter defaultCenter] retain];
				self.state = AS_STARTING_FILE_THREAD;
				[NSThread detachNewThreadSelector:@selector(startInternal) toTarget:self withObject:nil];
			}
		}
	}
	
	// Start song tweeting timer for 30 seconds
	shouldInvalidateTweetTimer = YES;
	self.tweetTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(tweetSong) userInfo:nil repeats:NO];
	
	// Scrobbling timer
	SavedSettings *settings = [SavedSettings sharedInstance];
	SUSCurrentPlaylistDAO *dataModel = [SUSCurrentPlaylistDAO dataModel];
	Song *currentSong = dataModel.currentSong;
	shouldInvalidateScrobbleTimer = YES;
	NSTimeInterval scrobbleInterval = 30.0;
	if (currentSong.duration != nil)
	{
		//double scrobblePercent = [[appDelegate.settingsDictionary objectForKey:@"scrobblePercentSetting"] doubleValue];
		float scrobblePercent = settings.scrobblePercent;
		float duration = [currentSong.duration floatValue];
		scrobbleInterval = scrobblePercent * duration;
		DLog(@"duration: %f    percent: %f    scrobbleInterval: %f", duration, scrobblePercent, scrobbleInterval);
	}
	self.scrobbleTimer = [NSTimer scheduledTimerWithTimeInterval:scrobbleInterval target:self selector:@selector(scrobbleSong) userInfo:nil repeats:NO];
	
	// If scrobbling is enabled, send "now playing" call
	//if ([[appDelegate.settingsDictionary objectForKey:@"enableScrobblingSetting"] isEqualToString:@"YES"])
	if (settings.isScrobbleEnabled)
	{
		[musicControls scrobbleSong:currentSong.songId isSubmission:NO];
	}
}


- (void) tweetSong
{
	SocialSingleton *socialControls = [SocialSingleton sharedInstance];
	SavedSettings *settings = [SavedSettings sharedInstance];
	SUSCurrentPlaylistDAO *dataModel = [SUSCurrentPlaylistDAO dataModel];
	Song *currentSong = dataModel.currentSong;
	
	shouldInvalidateTweetTimer = NO;
	tweetTimer = nil;
	
	//if (socialControls.twitterEngine && [[appDelegate.settingsDictionary objectForKey:@"twitterEnabledSetting"] isEqualToString:@"YES"])
	if (socialControls.twitterEngine && settings.isTwitterEnabled)
	{
		if (currentSong.artist && currentSong.title)
		{
			DLog(@"------------- tweeting song --------------");
			NSString *tweet = [NSString stringWithFormat:@"is listening to \"%@\" by %@", currentSong.title, currentSong.artist];
			if ([tweet length] <= 140)
				[socialControls.twitterEngine sendUpdate:tweet];
			else
				[socialControls.twitterEngine sendUpdate:[tweet substringToIndex:140]];
		}
		else {
			//DLog(@"------------- not tweeting song because either no artist or no title --------------");
		}

	}
	else {
		//DLog(@"------------- not tweeting song because no engine or not enabled --------------");
	}

}

- (void) scrobbleSong
{
	shouldInvalidateScrobbleTimer = NO;
	scrobbleTimer = nil;
	
	//iSubAppDelegate *appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	//if ([[appDelegate.settingsDictionary objectForKey:@"enableScrobblingSetting"] isEqualToString:@"YES"])
	if ([SavedSettings sharedInstance].isScrobbleEnabled)
	{
		MusicSingleton *musicControls = [MusicSingleton sharedInstance];
		SUSCurrentPlaylistDAO *dataModel = [SUSCurrentPlaylistDAO dataModel];
		Song *currentSong = dataModel.currentSong;
		[musicControls scrobbleSong:currentSong.songId isSubmission:YES];
	}
}


// CODE FOR SEEKING THROUGH TRACK
- (void)startWithOffsetInSecs:(UInt32) offsetInSecs
{
	fixedLength = YES;
	seekTime = (double)offsetInSecs;
	
	MusicSingleton *musicControls = [MusicSingleton sharedInstance];
	
	//DLog(@"AudioStreamer::startAt - starting at second %d", offsetInSecs);
	
	if ([self isPlaying]) 
		[self stop];
	
	// bitrate is needed to calculate the number of bytes that is equivalent to 
	// the seconds value passed into this function. I could make the user pass that in
	// but it becomes a chicken and egg thing.  So I just open the file and start reading
	// at offset 0 until we have a bitRate read.  Then I stop processing, and re-open
	// at the correct offset, which I can now calculate thanks to the bitrate I read at
	// offset 0!   HACK CITY, USA!!!!!	
	/*if ( bitRate == 0 )
	{
		self.offsetStart = 0;
		[self start];	
		while ( !self.bitRate ) { DLog(@"stuck in bitrate loop");}
		[self stop];
		
		// This is needed or the iPhone cuts out on the second play, also can block never starting audio.   
		// I think it gets in a deadlock waiting for buffers that will never be not inuse
		// cause they were from the previous "start", so just mark them all as not used here.
		for (int i=0; i<kNumAQBufs;i++)
			inuse[i] = false;
		
		// apparently mp3 files can have headers or some junk at the beginning of the actual file.
		// by remembering the dataOffset reported when we asked for offset 0, and adding that
		// into our offset calculation below, we get a more accurate number.
		thisFileDataOffset = dataOffset;
	}*/
	bitRate = musicControls.bitRate;
	
	//DLog(@"AudioStreamer::startAt - this files total offset %d", thisFileDataOffset);
	
	// 1 kilobit == 128 bytes
	//DLog(@"self.bitrate = %d", self.bitRate);
	if (self.bitRate < 1000)
	{
		self.offsetStart = ( self.bitRate * 128 * offsetInSecs );// + thisFileDataOffset;
		//DLog(@"self.offsetStart: %i", self.offsetStart);
		
	}
	else
	{
		self.offsetStart = ( (self.bitRate / 1000) * 128 * offsetInSecs );// + thisFileDataOffset;
		//DLog(@"self.offsetStart: %i", self.offsetStart);
	}
	
	self.fileDownloadBytesRead = self.offsetStart;
	
	[self start];
	
	// This lovely hack has something to do with reading the data at arbitrary offsets into the file.
	// Apparently, if you choose an offset that is JUST right, the audio queue fails to create.  Best
	// I can tell this is when the sample rate has been misread.   Whenever it fails, the sample rate
	// is always reported as something other than what the file really is.   I figure we just chose an offset
	// that somehow split the bytes describing the sample rate, and the audio queue freaked out.  So the fix?
	// BACK THAT &%# UP!   Just subtract off 1000 bytes, and try again.   Still failed?   Back-back that thang up.
	// Its gross, but it works.  Much like listening to Juvenile.  DJ Jubilee 4 life.   
	BOOL keepWaiting = YES;
	while (keepWaiting)
	{
		//DLog(@"in the keepWaiting loop");
		if ([self queueFailed])
		{
			DLog(@"queueFailed");
			self.offsetStart -= 1000;
			self.fileDownloadBytesRead = self.offsetStart;
			err = 0;
			errorCode = 0;
			[self stop];
			[self start];
		}
		else if ( [self nonQueueError] )
			keepWaiting = NO;
		else
			keepWaiting = ![self isPlaying];
	}
	
}


- (BOOL)nonQueueError
{
	if ( errorCode && (errorCode != AS_AUDIO_QUEUE_CREATION_FAILED ) )
		return YES;
	
	return NO;
}


- (BOOL)queueFailed
{
	if (errorCode == AS_AUDIO_QUEUE_CREATION_FAILED )
		return YES;
	
	return NO;
} 


//
// progress
//
// returns the current playback progress. Will return zero if sampleRate has
// not yet been detected.
//
- (double)progress
{	
	@synchronized(self)
	{
		if (sampleRate > 0 && ![self isFinishing])
		{
			if (state != AS_PLAYING && state != AS_PAUSED && state != AS_BUFFERING)
			{
				return lastProgress;
			}

			AudioTimeStamp queueTime;
			Boolean discontinuity;
			err = AudioQueueGetCurrentTime(audioQueue, NULL, &queueTime, &discontinuity);
			if (err)
			{
				return lastProgress;
				// Had to remove the failWithErrorCode line as this was being called every time
				// the headphones were removed/reinserted while this method was being called
				//[self failWithErrorCode:AS_GET_AUDIO_TIME_FAILED];
			}

			double progress = seekTime + queueTime.mSampleTime / sampleRate;
			if (progress < 0.0)
			{
				progress = 0.0;
			}
			
			lastProgress = progress;
			return progress;
		}
	}
	
	return lastProgress;
}

//
// pause
//
// A togglable pause function.
//
- (void)pause
{
	@synchronized(self)
	{
		if (state == AS_PAUSED)
		{
			err = AudioQueueStart(audioQueue, NULL);
			if (err)
			{
				[self failWithErrorCode:AS_AUDIO_QUEUE_START_FAILED];
				return;
			}
			self.state = AS_PLAYING;
		}
		else
		{
			// Either the song is AS_PLAYING and the user wants to pause
			// Or the song is buffering and the user wants to pause
			err = AudioQueuePause(audioQueue);
			if (err)
			{
				[self failWithErrorCode:AS_AUDIO_QUEUE_PAUSE_FAILED];
				return;
			}
			self.state = AS_PAUSED;
		}
		
		/*if (state == AS_PLAYING)
		{
			err = AudioQueuePause(audioQueue);
			if (err)
			{
				[self failWithErrorCode:AS_AUDIO_QUEUE_PAUSE_FAILED];
				return;
			}
			self.state = AS_PAUSED;
		}
		else if (state == AS_PAUSED)
		{
			err = AudioQueueStart(audioQueue, NULL);
			if (err)
			{
				[self failWithErrorCode:AS_AUDIO_QUEUE_START_FAILED];
				return;
			}
			self.state = AS_PLAYING;
		}*/
	}
}

//
// shouldSeek
//
// Applies the logic to verify if seeking should occur.
//
// returns YES (seeking should occur) or NO (otherwise).
//
- (BOOL)shouldSeek
{
	@synchronized(self)
	{
		if (bitRate != 0 && seekNeeded &&
			(state == AS_PLAYING || state == AS_PAUSED || state == AS_BUFFERING))
		{
			return YES;
		}
	}
	return NO;
}

//
// stop
//
// This method can be called to stop downloading/playback before it completes.
// It is automatically called when an error occurs.
//
// If playback has not started before this method is called, it will toggle the
// "isPlaying" property so that it is guaranteed to transition to true and
// back to false 
//
- (void)stop
{
	if (shouldInvalidateTweetTimer)
	{
		[tweetTimer invalidate];
        [tweetTimer release];
        tweetTimer = nil;
	}
	
	if (shouldInvalidateScrobbleTimer)
	{
		[scrobbleTimer invalidate];
        [scrobbleTimer release];
        scrobbleTimer = nil;
	}
	
	@synchronized(self)
	{
		if (audioQueue &&
			(state == AS_PLAYING || state == AS_PAUSED ||
				state == AS_BUFFERING || state == AS_WAITING_FOR_QUEUE_TO_START))
		{
			self.state = AS_STOPPING;
			stopReason = AS_STOPPING_USER_ACTION;
			err = AudioQueueStop(audioQueue, true);
			if (err)
			{
				[self failWithErrorCode:AS_AUDIO_QUEUE_STOP_FAILED];
				return;
			}
		}
		else if (state != AS_INITIALIZED)
		{
			self.state = AS_STOPPED;
			stopReason = AS_STOPPING_USER_ACTION;
		}
	}
	
	while (state != AS_INITIALIZED)
	{
		[NSThread sleepForTimeInterval:0.1];
	}
}

//
// setVolume:
//
// Sets the volum on the Audio Queue.  This volume passed in should be between 0 and 1.
//
- (void)setVolume:(float)volume {
	AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, volume);	
}

//
// gettVolume
//
// Returns a value between 0 and 1.
//
- (float)getVolume {
	Float32 volumeValue;
	AudioQueueGetParameter(audioQueue, kAudioQueueParam_Volume, &volumeValue);	
	return volumeValue;
}

//
// handleReadFromStream:eventType:data:
//
// Reads data from the network file stream into the AudioFileStream
//
// Parameters:
//    aStream - the network file stream
//    eventType - the event which triggered this method
//
- (void)handleReadFromStream:(CFReadStreamRef)aStream eventType:(CFStreamEventType)eventType
{
	if (eventType == kCFStreamEventErrorOccurred)
	{
		[self failWithErrorCode:AS_AUDIO_DATA_NOT_FOUND];
	}
	else if (eventType == kCFStreamEventEndEncountered)
	{
		@synchronized(self)
		{
			if ([self isFinishing])
			{
				return;
			}
		}
		
		//
		// If there is a partially filled buffer, pass it to the AudioQueue for
		// processing
		//
		if (bytesFilled)
		{
			[self enqueueBuffer];
		}
		
		@synchronized(self)
		{
			if (state == AS_WAITING_FOR_DATA)
			{
				[self failWithErrorCode:AS_AUDIO_DATA_NOT_FOUND];
			}
			
			//
			// We left the synchronized section to enqueue the buffer so we
			// must check that we are !finished again before touching the
			// audioQueue
			//
			else if (![self isFinishing])
			{
				if (audioQueue)
				{
					//
					// Set the progress at the end of the stream
					//
					err = AudioQueueFlush(audioQueue);
					if (err)
					{
						[self failWithErrorCode:AS_AUDIO_QUEUE_FLUSH_FAILED];
						return;
					}
					
					self.state = AS_STOPPING;
					stopReason = AS_STOPPING_EOF;
					err = AudioQueueStop(audioQueue, false);
					if (err)
					{
						[self failWithErrorCode:AS_AUDIO_QUEUE_FLUSH_FAILED];
						return;
					}
				}
				else
				{
					self.state = AS_STOPPED;
					stopReason = AS_STOPPING_EOF;
				}
			}
		}
	}
	else if (eventType == kCFStreamEventHasBytesAvailable)
	{
		UInt8 bytes[kAQBufSize];
		CFIndex length;
		@synchronized(self)
		{
			if ([self isFinishing])
			{
				return;
			}
			
			//
			// Read the bytes from the stream
			//
			length = CFReadStreamRead(stream, bytes, kAQBufSize);
			
			
			if (length == -1)
			{
				[self failWithErrorCode:AS_AUDIO_DATA_NOT_FOUND];
				return;
			}
			
			if (length == 0)
			{
				return;
			}
			
			fileDownloadBytesRead += length;
		}

		if (discontinuous)
		{
			err = AudioFileStreamParseBytes(audioFileStream, length, bytes, kAudioFileStreamParseFlag_Discontinuity);
			if (err)
			{
				[self failWithErrorCode:AS_FILE_STREAM_PARSE_BYTES_FAILED];
				return;
			}
		}
		else
		{
			err = AudioFileStreamParseBytes(audioFileStream, length, bytes, 0);
			if (err)
			{
				[self failWithErrorCode:AS_FILE_STREAM_PARSE_BYTES_FAILED];
				return;
			}
		}
	}
}

//
// enqueueBuffer
//
// Called from MyPacketsProc and connectionDidFinishLoading to pass filled audio
// bufffers (filled by MyPacketsProc) to the AudioQueue for playback. This
// function does not return until a buffer is idle for further filling or
// the AudioQueue is stopped.
//
// This function is adapted from Apple's example in AudioFileStreamExample with
// CBR functionality added.
//
- (void)enqueueBuffer
{
	@synchronized(self)
	{
		if ([self isFinishing])
		{
			return;
		}
		
		inuse[fillBufferIndex] = true;		// set in use flag
		buffersUsed++;
		if (self.state == AS_BUFFERING)
		{
			self.state = AS_PLAYING;
		}
		
		// enqueue buffer
		AudioQueueBufferRef fillBuf = audioQueueBuffer[fillBufferIndex];
		fillBuf->mAudioDataByteSize = bytesFilled;
		
		if (packetsFilled)
		{
			err = AudioQueueEnqueueBuffer(audioQueue, fillBuf, packetsFilled, packetDescs);
		}
		else
		{
			err = AudioQueueEnqueueBuffer(audioQueue, fillBuf, 0, NULL);
		}
		
		
		/*//
		//
		// mAudioData test -- IT'S THE COMPRESSED MP3 DATA :(
		NSData *test = [[NSData alloc] initWithBytes:fillBuf->mAudioData length:fillBuf->mAudioDataByteSize];
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString *databaseFolderPath = [[paths objectAtIndex: 0] stringByAppendingPathComponent:@"database"];
		NSString *path = [NSString stringWithFormat:@"%@/test.wav", databaseFolderPath];

		BOOL isDir = NO;
		if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir]) 
		{
			[test writeToFile:path atomically:YES];
		}
		else
		{
			NSFileHandle *handle = [NSFileHandle fileHandleForUpdatingAtPath:path];
			[handle seekToEndOfFile];
			[handle writeData:test];
			[handle closeFile];
			[test release];
		}
		//
		//
		//*/
		
				
		/*//
		//
		// SoX Effects
		int tprofile;
		SInt16 *buffer = (SInt16 *)calloc(1, fillBuf->mAudioDataByteSize);
		static sox_format_t *in, *out;
		sox_effects_chain_t * chain;
		sox_effect_t * e;
		char *args[10];
		
		// All libSoX applications must start by initialising the SoX library
		assert(sox_init() == SOX_SUCCESS);
		
		// Open the input file (with default parameters)
		assert(in = sox_open_mem_read(fillBuf->mAudioData, fillBuf->mAudioDataByteSize, NULL, NULL, NULL));
		
		// Open the output file; we must specify the output signal characteristics.
		// Since we are using only simple effects, they are the same as the input
		// file characteristics
		assert(out = sox_open_mem_write(buffer, fillBuf->mAudioDataByteSize, &in->signal, NULL, NULL, NULL));
		
		// Create an effects chain; some effects need to know about the input
		// or output file encoding so we provide that information here
		chain = sox_create_effects_chain(&in->encoding, &out->encoding);
		
		// The first effect in the effect chain must be something that can source
		// samples; in this case, we use the built-in handler that inputs
		// data from an audio file
		e = sox_create_effect(sox_find_effect("input"));
		args[0] = (char *)in, assert(sox_effect_options(e, 1, args) == SOX_SUCCESS);
		// This becomes the first `effect' in the chain
		assert(sox_add_effect(chain, e, &in->signal, &in->signal) == SOX_SUCCESS);
		
		if (tprofile == 1) {
			
			e = sox_create_effect(sox_find_effect("lowpass"));
			args[0] = "2000", assert(sox_effect_options(e, 1, args) == SOX_SUCCESS);
			assert(sox_add_effect(chain, e, &in->signal, &in->signal) == SOX_SUCCESS);
			
			e = sox_create_effect(sox_find_effect("gain"));
			args[0] = "-10", assert(sox_effect_options(e, 1, args) == SOX_SUCCESS);
			assert(sox_add_effect(chain, e, &in->signal, &in->signal) == SOX_SUCCESS);
		}
		
		if (tprofile == 2) {
			
			e = sox_create_effect(sox_find_effect("lowpass"));
			args[0] = "1000", assert(sox_effect_options(e, 1, args) == SOX_SUCCESS);
			assert(sox_add_effect(chain, e, &in->signal, &in->signal) == SOX_SUCCESS);
			
			e = sox_create_effect(sox_find_effect("gain"));
			args[0] = "-25", assert(sox_effect_options(e, 1, args) == SOX_SUCCESS);
			assert(sox_add_effect(chain, e, &in->signal, &in->signal) == SOX_SUCCESS);
		}
		
		
		// Create the `vol' effect, and initialise it with the desired parameters:
		e = sox_create_effect(sox_find_effect("vol"));
		args[0] = "3dB", assert(sox_effect_options(e, 1, args) == SOX_SUCCESS);
		// Add the effect to the end of the effects processing chain:
		assert(sox_add_effect(chain, e, &in->signal, &in->signal) == SOX_SUCCESS);
		
		// Create the `flanger' effect, and initialise it with default parameters:
		e = sox_create_effect(sox_find_effect("flanger"));
		assert(sox_effect_options(e, 0, NULL) == SOX_SUCCESS);
		// Add the effect to the end of the effects processing chain:
		assert(sox_add_effect(chain, e, &in->signal, &in->signal) == SOX_SUCCESS);
		
		
		// The last effect in the effect chain must be something that only consumes
		// samples; in this case, we use the built-in handler that outputs
		// data to an audio file
		e = sox_create_effect(sox_find_effect("output"));
		args[0] = (char *)out, assert(sox_effect_options(e, 1, args) == SOX_SUCCESS);
		assert(sox_add_effect(chain, e, &in->signal, &in->signal) == SOX_SUCCESS);
		
		// Flow samples through the effects processing chain until EOF is reached
		sox_flow_effects(chain, NULL, NULL);
		
		// All done; tidy up:
		sox_delete_effects_chain(chain);
		sox_close(out);
		sox_close(in);
		sox_quit();
		
		memmove(fillBuf->mAudioData, buffer, fillBuf->mAudioDataByteSize);
		free(buffer);
		buffer = NULL;
		//
		//
		//*/
		
		if (err)
		{
			[self failWithErrorCode:AS_AUDIO_QUEUE_ENQUEUE_FAILED];
			return;
		}

		
		if (state == AS_BUFFERING ||
			state == AS_WAITING_FOR_DATA ||
			(state == AS_STOPPED && stopReason == AS_STOPPING_TEMPORARILY))
		{
			//
			// Fill all the buffers before starting. This ensures that the
			// AudioFileStream stays a small amount ahead of the AudioQueue to
			// avoid an audio glitch playing streaming files on iPhone SDKs < 3.0
			//
			if (buffersUsed == kNumAQBufs - 1)
			{
				self.state = AS_WAITING_FOR_QUEUE_TO_START;

				err = AudioQueueStart(audioQueue, NULL);
				if (err)
				{
					[self failWithErrorCode:AS_AUDIO_QUEUE_START_FAILED];
					return;
				}
			}
		}

		// go to next buffer
		if (++fillBufferIndex >= kNumAQBufs) fillBufferIndex = 0;
		bytesFilled = 0;		// reset bytes filled
		packetsFilled = 0;		// reset packets filled
	}

	// wait until next buffer is not in use
	pthread_mutex_lock(&queueBuffersMutex); 
	while (inuse[fillBufferIndex])
	{
		pthread_cond_wait(&queueBufferReadyCondition, &queueBuffersMutex);
	}
	pthread_mutex_unlock(&queueBuffersMutex);
}

//
// handlePropertyChangeForFileStream:fileStreamPropertyID:ioFlags:
//
// Object method which handles implementation of MyPropertyListenerProc
//
// Parameters:
//    inAudioFileStream - should be the same as self->audioFileStream
//    inPropertyID - the property that changed
//    ioFlags - the ioFlags passed in
//
- (void)handlePropertyChangeForFileStream:(AudioFileStreamID)inAudioFileStream
	fileStreamPropertyID:(AudioFileStreamPropertyID)inPropertyID
	ioFlags:(UInt32 *)ioFlags
{
	@synchronized(self)
	{
		if ([self isFinishing])
		{
			return;
		}
		
		if (inPropertyID == kAudioFileStreamProperty_ReadyToProducePackets)
		{
			discontinuous = true;
			
			AudioStreamBasicDescription asbd;
			UInt32 asbdSize = sizeof(asbd);
			
			// get the stream format.
			err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &asbdSize, &asbd);
			if (err)
			{
				[self failWithErrorCode:AS_FILE_STREAM_GET_PROPERTY_FAILED];
				return;
			}
			
			sampleRate = asbd.mSampleRate;
			
			// create the audio queue
			err = AudioQueueNewOutput(&asbd, MyAudioQueueOutputCallback, self, NULL, NULL, 0, &audioQueue);
			if (err)
			{
				[self failWithErrorCode:AS_AUDIO_QUEUE_CREATION_FAILED];
				return;
			}
			
		/*	/////////// HE-AAC Handling ////////////////
			if (inPropertyID == kAudioFileStreamProperty_FormatList)
			{
				Boolean outWriteable;
				UInt32 formatListSize;
				
				// Get the size of the format list
				err = AudioFileStreamGetPropertyInfo(inAudioFileStream,
													 kAudioFileStreamProperty_FormatList, &formatListSize, &outWriteable);
				if (err) 
				{ 
					// handle error 
				}
				
				// Get the list of formats itself
				AudioFormatListItem *formatList = malloc(formatListSize);
				err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_FormatList, &formatListSize, formatList);
				if (err) 
				{
					// handle error
				}
				
				// Look through the list of formats to find HE-AAC if present
				for (int i = 0;
					 i * sizeof(AudioFormatListItem) < formatListSize;
					 i += sizeof(AudioFormatListItem))
				{
					AudioStreamBasicDescription pasbd = formatList[i].mASBD;
					if (pasbd.mFormatID == kAudioFormatMPEG4AAC_HE)
					{
						// We've found HE-AAC, remember this to tell the audio queue
						// when we construct it.
#if !TARGET_IPHONE_SIMULATOR
						asbd = pasbd;
#endif
						break;
					}                                
				}
				free(formatList);
			}
			////////////////////////////////////////////
		 */
			
			// start the queue if it has not been started already
			// listen to the "isRunning" property
			err = AudioQueueAddPropertyListener(audioQueue, kAudioQueueProperty_IsRunning, MyAudioQueueIsRunningCallback, self);
			if (err)
			{
				[self failWithErrorCode:AS_AUDIO_QUEUE_ADD_LISTENER_FAILED];
				return;
			}
			
			// allocate audio queue buffers
			for (unsigned int i = 0; i < kNumAQBufs; ++i)
			{
				err = AudioQueueAllocateBuffer(audioQueue, kAQBufSize, &audioQueueBuffer[i]);
				if (err)
				{
					[self failWithErrorCode:AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED];
					return;
				}
			}

			// get the cookie size
			UInt32 cookieSize;
			Boolean writable;
			OSErr ignorableError;
			ignorableError = AudioFileStreamGetPropertyInfo(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable);
			if (ignorableError)
			{
				return;
			}

			// get the cookie data
			void* cookieData = calloc(1, cookieSize);
			ignorableError = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookieData);
			if (ignorableError)
			{
				return;
			}

			// set the cookie on the queue.
			ignorableError = AudioQueueSetProperty(audioQueue, kAudioQueueProperty_MagicCookie, cookieData, cookieSize);
			free(cookieData);
			if (ignorableError)
			{
				return;
			}
		}
		else if (inPropertyID == kAudioFileStreamProperty_DataOffset)
		{
			SInt64 offset;
			UInt32 offsetSize = sizeof(offset);
			err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataOffset, &offsetSize, &offset);
			dataOffset = offset;
			if (err)
			{
				[self failWithErrorCode:AS_FILE_STREAM_GET_PROPERTY_FAILED];
				return;
			}
		}
	}
}

//
// handleAudioPackets:numberBytes:numberPackets:packetDescriptions:
//
// Object method which handles the implementation of MyPacketsProc
//
// Parameters:
//    inInputData - the packet data
//    inNumberBytes - byte size of the data
//    inNumberPackets - number of packets in the data
//    inPacketDescriptions - packet descriptions
//
- (void)handleAudioPackets:(const void *)inInputData
	numberBytes:(UInt32)inNumberBytes
	numberPackets:(UInt32)inNumberPackets
	packetDescriptions:(AudioStreamPacketDescription *)inPacketDescriptions;
{
	@synchronized(self)
	{
		if ([self isFinishing])
		{
			return;
		}
		
		if (bitRate == 0)
		{
			UInt32 dataRateDataSize = sizeof(UInt32);
			err = AudioFileStreamGetProperty(
				audioFileStream,
				kAudioFileStreamProperty_BitRate,
				&dataRateDataSize,
				&bitRate);
			MusicSingleton *musicControls = [MusicSingleton sharedInstance];
			musicControls.bitRate = bitRate;
			if (err)
			{
				//
				// m4a and a few other formats refuse to parse the bitrate so
				// we need to set an "unparseable" condition here. If you know
				// the bitrate (parsed it another way) you can set it on the
				// class if needed.
				//
				bitRate = 192;
				musicControls.bitRate = bitRate;
				/*[self failWithErrorCode:AS_FILE_STREAM_GET_PROPERTY_FAILED];
				 return;*/
			}
		}
		
		// we have successfully read the first packests from the audio stream, so
		// clear the "discontinuous" flag
		discontinuous = false;
	}

	// the following code assumes we're streaming VBR data. for CBR data, the second branch is used.
	if (inPacketDescriptions)
	{
		for (int i = 0; i < inNumberPackets; ++i)
		{
			SInt64 packetOffset = inPacketDescriptions[i].mStartOffset;
			SInt64 packetSize   = inPacketDescriptions[i].mDataByteSize;
			
			@synchronized(self)
			{
				// If the audio was terminated before this point, then
				// exit.
				if ([self isFinishing])
				{
					return;
				}
				
				//
				// If we need to seek then unroll the stack back to the
				// appropriate point
				//
				if ([self shouldSeek])
				{
					return;
				}
			}

			// if the space remaining in the buffer is not enough for this packet, then enqueue the buffer.
			size_t bufSpaceRemaining = kAQBufSize - bytesFilled;
			if (bufSpaceRemaining < packetSize) {
				[self enqueueBuffer];
			}
			
			@synchronized(self)
			{
				// If the audio was terminated while waiting for a buffer, then
				// exit.
				if ([self isFinishing])
				{
					return;
				}
				
				//
				// If we need to seek then unroll the stack back to the
				// appropriate point
				//
				if ([self shouldSeek])
				{
					return;
				}
				 
				// copy data to the audio queue buffer
				AudioQueueBufferRef fillBuf = audioQueueBuffer[fillBufferIndex];
				memcpy((char*)fillBuf->mAudioData + bytesFilled, (const char*)inInputData + packetOffset, packetSize);

				// fill out packet description
				packetDescs[packetsFilled] = inPacketDescriptions[i];
				packetDescs[packetsFilled].mStartOffset = bytesFilled;
				// keep track of bytes filled and packets filled
				bytesFilled += packetSize;
				packetsFilled += 1;
			}
			
			// if that was the last free packet description, then enqueue the buffer.
			size_t packetsDescsRemaining = kAQMaxPacketDescs - packetsFilled;
			if (packetsDescsRemaining == 0) {
				[self enqueueBuffer];
			}
		}	
	}
	else
	{
		size_t offset = 0;
		while (inNumberBytes)
		{
			// if the space remaining in the buffer is not enough for this packet, then enqueue the buffer.
			size_t bufSpaceRemaining = kAQBufSize - bytesFilled;
			if (bufSpaceRemaining < inNumberBytes)
			{
				[self enqueueBuffer];
			}
			
			@synchronized(self)
			{
				// If the audio was terminated while waiting for a buffer, then
				// exit.
				if ([self isFinishing])
				{
					return;
				}
				
				//
				// If we need to seek then unroll the stack back to the
				// appropriate point
				//
				if ([self shouldSeek])
				{
					return;
				}
				
				// copy data to the audio queue buffer
				AudioQueueBufferRef fillBuf = audioQueueBuffer[fillBufferIndex];
				bufSpaceRemaining = kAQBufSize - bytesFilled;
				size_t copySize;
				if (bufSpaceRemaining < inNumberBytes)
				{
					copySize = bufSpaceRemaining;
				}
				else
				{
					copySize = inNumberBytes;
				}
				memcpy((char*)fillBuf->mAudioData + bytesFilled, (const char*)(inInputData + offset), copySize);


				// keep track of bytes filled and packets filled
				bytesFilled += copySize;
				packetsFilled = 0;
				inNumberBytes -= copySize;
				offset += copySize;
			}
		}
	}
}

//
// handleBufferCompleteForQueue:buffer:
//
// Handles the buffer completetion notification from the audio queue
//
// Parameters:
//    inAQ - the queue
//    inBuffer - the buffer
//
- (void)handleBufferCompleteForQueue:(AudioQueueRef)inAQ
	buffer:(AudioQueueBufferRef)inBuffer
{
	unsigned int bufIndex = -1;
	for (unsigned int i = 0; i < kNumAQBufs; ++i)
	{
		if (inBuffer == audioQueueBuffer[i])
		{
			bufIndex = i;
			break;
		}
	}
	
	if (bufIndex == -1)
	{
		[self failWithErrorCode:AS_AUDIO_QUEUE_BUFFER_MISMATCH];
		pthread_mutex_lock(&queueBuffersMutex);
		pthread_cond_signal(&queueBufferReadyCondition);
		pthread_mutex_unlock(&queueBuffersMutex);
		return;
	}
	
	// signal waiting thread that the buffer is free.
	pthread_mutex_lock(&queueBuffersMutex);
	inuse[bufIndex] = false;
	buffersUsed--;

//
//  Enable this logging to measure how many buffers are queued at any time.
//	DLog(@"Queued buffers: %ld", buffersUsed);
//
	
	pthread_cond_signal(&queueBufferReadyCondition);
	pthread_mutex_unlock(&queueBuffersMutex);
}

//
// handlePropertyChangeForQueue:propertyID:
//
// Implementation for MyAudioQueueIsRunningCallback
//
// Parameters:
//    inAQ - the audio queue
//    inID - the property ID
//
- (void)handlePropertyChangeForQueue:(AudioQueueRef)inAQ
	propertyID:(AudioQueuePropertyID)inID
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	@synchronized(self)
	{
		if (inID == kAudioQueueProperty_IsRunning)
		{
			if (state == AS_STOPPING)
			{
				self.state = AS_STOPPED;
			}
			else if (state == AS_WAITING_FOR_QUEUE_TO_START)
			{
				//
				// Note about this bug avoidance quirk:
				//
				// On cleanup of the AudioQueue thread, on rare occasions, there would
				// be a crash in CFSetContainsValue as a CFRunLoopObserver was getting
				// removed from the CFRunLoop.
				//
				// After lots of testing, it appeared that the audio thread was
				// attempting to remove CFRunLoop observers from the CFRunLoop after the
				// thread had already deallocated the run loop.
				//
				// By creating an NSRunLoop for the AudioQueue thread, it changes the
				// thread destruction order and seems to avoid this crash bug -- or
				// at least I haven't had it since (nasty hard to reproduce error!)
				//
				[NSRunLoop currentRunLoop];

				self.state = AS_PLAYING;
			}
			else
			{
				DLog(@"AudioQueue changed state in unexpected way.");
			}
		}
	}
	
	[pool release];
}

#ifdef TARGET_OS_IPHONE
//
// handleInterruptionChangeForQueue:propertyID:
//
// Implementation for MyAudioQueueInterruptionListener
//
// Parameters:
//    inAQ - the audio queue
//    inID - the property ID
//
/*- (void)handleInterruptionChangeToState:(AudioQueuePropertyID)inInterruptionState
{
	if (inInterruptionState == kAudioSessionBeginInterruption)
	{
		[self pause];
	}
	else if (inInterruptionState == ksudioSessionEndInterruption)
	{
		[self pause];
	}
}*/
- (void)handleInterruptionChangeToState:(AudioQueuePropertyID)inInterruptionState
{
	//DLog(@"handleInterruptionChangeToState called");
	MusicSingleton *musicControls = [MusicSingleton sharedInstance];
	if (inInterruptionState == kAudioSessionBeginInterruption)
	{
		//DLog(@"inInterruptionState == kAudioSessionBeginInterruption called");
		/*if(musicControls.isPlaying)
		{	
			musicControls.streamerProgress = [self progress];
			musicControls.seekTime += musicControls.streamerProgress;
		}*/
		//DLog(@"inInterruptionState == kAudioSessionBeginInterruption finished");
	}
	else if (inInterruptionState == kAudioSessionEndInterruption)
	{
		//DLog(@"inInterruptionState == kAudioSessionEndInterruption called");
		if(musicControls.isPlaying)
		{
			[self startWithOffsetInSecs:[self progress]];
		}
		//DLog(@"inInterruptionState == kAudioSessionEndInterruption finished");
	}
}
#endif


@end


