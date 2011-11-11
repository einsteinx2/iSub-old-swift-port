//
//  SUSStreamSingleton.m
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSStreamSingleton.h"
#import "DatabaseSingleton.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "Song.h"
#import "NSString-md5.h"
#import "NSMutableURLRequest+SUS.h"
#import "SavedSettings.h"
#import "NSString+URLEncode.h"
#import "MusicSingleton.h"

#define kThrottleTimeInterval 0.01

#define kMaxKilobitsPerSec3G 550
#define kMaxBytesPerSec3G ((kMaxKilobitsPerSec3G * 1024) / 8)
#define kMaxBytesPerInterval3G (kMaxBytesPerSec3G * kThrottleTimeInterval)

#define kMaxKilobitsPerSecWifi 8000
#define kMaxBytesPerSecWifi ((kMaxKilobitsPerSecWifi * 1024) / 8)
#define kMaxBytesPerIntervalWifi (kMaxBytesPerSecWifi * kThrottleTimeInterval)

#define kMinBytesToStartPlayback (1024 * 50)    // Number of bytes to wait before activating the player
#define kMinBytesToStartLimiting (1024 * 1024)   // Start throttling bandwidth after 1 MB downloaded for 192kbps files (adjusted accordingly by bitrate)

// Logging
#define isProgressLoggingEnabled NO
#define isThrottleLoggingEnabled NO

static SUSStreamSingleton *sharedInstance = nil;

@implementation SUSStreamSingleton
@synthesize throttlingDate, isDownloadA, isDownloadB, bytesTransferred;

- (BOOL) insertSong:(Song *)aSong intoGenreTable:(NSString *)table
{
    DatabaseSingleton *databaseControls = [DatabaseSingleton sharedInstance];
    
	[databaseControls.songCacheDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (md5, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", table], [aSong.path md5], aSong.title, aSong.songId, aSong.artist, aSong.album, aSong.genre, aSong.coverArtId, aSong.path, aSong.suffix, aSong.transcodedSuffix, aSong.duration, aSong.bitRate, aSong.track, aSong.year, aSong.size];
	
	if ([databaseControls.songCacheDb hadError]) {
		DLog(@"Err inserting song into genre table %d: %@", [databaseControls.songCacheDb lastErrorCode], [databaseControls.songCacheDb lastErrorMessage]);
	}
	
	return [databaseControls.songCacheDb hadError];
}

#pragma mark Connection factory

- (void)createConnectionForReadStreamRef:(CFReadStreamRef *)readStreamRef callback:(CFReadStreamClientCallBack)callback songId:(NSString *)songId offset:(UInt32)byteOffset
{
    MusicSingleton *musicControls = [MusicSingleton sharedInstance];
    SavedSettings *settings = [SavedSettings sharedInstance];
    
    NSString *username = [settings.username URLEncodeString];
	NSString *password = [settings.password URLEncodeString];
    
    NSString *urlString = nil;
    if ([musicControls maxBitrateSetting] != 0)
	{
        //urlString = [NSString stringWithFormat:@"%@/rest/stream.view?v=1.2.0&c=iSub&maxBitRate=%i&id=%@", settings.urlString, musicControls.maxBitrateSetting, songId];
        urlString = [NSString stringWithFormat:@"%@/rest/stream.view?u=%@&p=%@&v=1.2.0&c=iSub&maxBitRate=%i&id=%@", settings.urlString, username, password, musicControls.maxBitrateSetting, songId];
	}
    else
	{
        //urlString = [NSString stringWithFormat:@"%@/rest/stream.view?v=1.1.0&c=iSub&id=%@", settings.urlString, songId];
        urlString = [NSString stringWithFormat:@"%@/rest/stream.view?u=%@&p=%@&v=1.1.0&c=iSub&id=%@", settings.urlString, username, password, songId];
	}
    
    DLog(@"urlString: %@", urlString);
    NSURL *url = [NSURL URLWithString:urlString];
    
    CFHTTPMessageRef messageRef = NULL;
	CFStreamClientContext ctxt = {0, (void*)NULL, NULL, NULL, NULL};
    
	// Create the GET request
    messageRef = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("GET"), (CFURLRef)url, kCFHTTPVersion1_1);
	if (messageRef == NULL) 
        goto Bail;
	
	//	There are times when a server checks the User-Agent to match a well known browser.  This is what Safari used at the time the sample was written
	//CFHTTPMessageSetHeaderFieldValue( messageRef, CFSTR("User-Agent"), CFSTR("Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/125.5.5 (KHTML, like Gecko) Safari/125")); 
    
	// Set a no cache policy
	CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("Cache-Control"), CFSTR("no-cache"));
    
    if (byteOffset > 0)
    {
        // Add the HTTP header to resume the download
        DLog(@"----------------- byteOffset header: %@", [NSString stringWithFormat:@"bytes=%d-", byteOffset]);
        CFHTTPMessageSetHeaderFieldValue( messageRef, CFSTR("Range"), CFStringCreateWithFormat(NULL, NULL, CFSTR("bytes=%i-"), byteOffset)); 
    }
    
    // Handle Basic Auth
    //CFHTTPMessageAddAuthentication(messageRef, NULL, (CFStringRef)username, (CFStringRef)password, kCFHTTPAuthenticationSchemeBasic, FALSE);
    
    // Create the stream for the request.
	*readStreamRef = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, messageRef);
	if (*readStreamRef == NULL) 
        goto Bail;
	
	// Enable stream redirection
    if (CFReadStreamSetProperty(*readStreamRef, kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanTrue) == false)
		goto Bail;
	
	// Handle SSL connections
	if([[url absoluteString] rangeOfString:@"https"].location != NSNotFound)
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
		
		CFReadStreamSetProperty(*readStreamRef, kCFStreamPropertySSLSettings, sslSettings);
	}
	
	// Handle proxy
	CFDictionaryRef proxyDict = CFNetworkCopySystemProxySettings();
	CFReadStreamSetProperty(*readStreamRef, kCFStreamPropertyHTTPProxy, proxyDict);
	
	// Set the client notifier
	if (CFReadStreamSetClient(*readStreamRef, kNetworkEvents, callback, &ctxt) == false)
		goto Bail;
    
    // Print the message
    NSData *d = (NSData *)CFHTTPMessageCopySerializedMessage(messageRef);
    DLog(@"messageRef: %@", [[[NSString alloc] initWithBytes:[d bytes] length:[d length] encoding:NSUTF8StringEncoding] autorelease]);
    
	// Schedule the stream
	CFReadStreamScheduleWithRunLoop(*readStreamRef, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    
	// Start the HTTP connection
	if (CFReadStreamOpen(*readStreamRef) == false)
	    goto Bail;
	
	DLog(@"--- STARTING HTTP CONNECTION");
	
	if (messageRef != NULL) CFRelease(messageRef);
    return;
	
Bail:
	if (messageRef != NULL) CFRelease(messageRef);
	if (readStreamRef != NULL)
    {
        CFReadStreamSetClient(*readStreamRef, kCFStreamEventNone, NULL, NULL);
	    CFReadStreamUnscheduleFromRunLoop(*readStreamRef, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	    CFReadStreamClose(*readStreamRef);
        CFRelease(readStreamRef);
    }
	return;
}

#pragma mark Download
- (void)downloadCFNetA:(NSString *)songId
{
    DLog(@"downloadCFNetA");
    self.throttlingDate = nil;
	bytesTransferred = 0;
	
	isDownloadA = YES;
    
    [self createConnectionForReadStreamRef:&readStreamRefA callback:ReadStreamClientCallBackA songId:songId offset:0];
}

- (void)downloadCFNetB:(NSString *)songId
{
    DLog(@"downloadCFNetB");
	self.throttlingDate = nil;
	bytesTransferred = 0;
	
	isDownloadB = YES;
    
    [self createConnectionForReadStreamRef:&readStreamRefB callback:ReadStreamClientCallBackB songId:songId offset:0];
}

- (void)downloadCFNetTemp:(NSString *)songId
{
    DLog(@"downloadCFNetTemp");
	self.throttlingDate = nil;
	bytesTransferred = 0;
	
	isDownloadA = YES;
    
    [self createConnectionForReadStreamRef:&readStreamRefA callback:ReadStreamClientCallBackTemp songId:songId offset:0];
}

#pragma mark Resume
- (void)resumeCFNetA:(NSString *)songId offset:(UInt32)byteOffset
{
    DLog(@"resumeCFNetA");
    self.throttlingDate = [NSDate date];
	bytesTransferred = 0;
	
	isDownloadA = YES;
    
    [self createConnectionForReadStreamRef:&readStreamRefA callback:ReadStreamClientCallBackA songId:songId offset:byteOffset];
}

- (void)resumeCFNetB:(NSString *)songId offset:(UInt32)byteOffset
{
    DLog(@"resumeCFNetB");
	self.throttlingDate = [NSDate date];
	bytesTransferred = 0;
	
	isDownloadB = YES;
    
    [self createConnectionForReadStreamRef:&readStreamRefB callback:ReadStreamClientCallBackB songId:songId offset:byteOffset];
}

#pragma mark - SUSLoader delegate

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error
{
    [theLoader release]; theLoader = nil;
}

- (void)loadingFinished:(SUSLoader*)theLoader
{
    [theLoader release]; theLoader = nil;
}

#pragma mark - Singleton methods

- (void)setup
{
    isDownloadA = NO;
    isDownloadB = NO;
    bytesTransferred = 0;
}

+ (SUSStreamSingleton *)sharedInstance
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
		[self setup];
		sharedInstance = self;
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
