//
//  Loader.m
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "Loader.h"
#import "DefaultSettings.h"
#import "MusicControlsSingleton.h"
#import "Song.h"

@implementation Loader

@synthesize loadError, results;

- (id)init
{
    self = [super init];
    if (self) 
	{
		results = nil;
		loadError = nil;
		delegate_ = nil;
    }
    
    return self;
}

- (id)initWithDelegate:(id <LoaderDelegate>)delegate
{
	self = [super init];
    if (self) 
	{
		results = nil;
		loadError = nil;
		delegate_ = [delegate retain];
	}
	
	return self;
}

- (void)dealloc
{
	[results release]; results = nil;
	[loadError release]; loadError = nil;
	[delegate_ release]; delegate_ = nil;
    [super dealloc];
}

- (void)startLoad
{
	[NSException raise:NSInternalInconsistencyException 
				format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
}

- (void)cancelLoad
{
	[NSException raise:NSInternalInconsistencyException 
				format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
}

- (void)setDelegate:(id <LoaderDelegate>)delegate
{
	delegate_ = [delegate retain];
}

- (id <LoaderDelegate>)delegate
{
	return delegate_;
}

- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	DLog(@"Subsonic error: %@", message);
	
	/*if ([parseState isEqualToString: @"allAlbums"])
	{
		DLog(@"Subsonic error: %@", message);
	}
	else
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:appDelegate cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
		[alert show];
		[alert release];
	}*/
}

- (NSString *)getBaseUrlString:(NSString *)action
{	
	// If the user used a hostname, implement the IP address caching and create the urlstring
	/*if ([[defaultUrl componentsSeparatedByString:@"."] count] == 1)
	 {
	 // Check to see if it's been an hour since the last IP check. If it has, update the cached IP.
	 if ([self getHour] > cachedIPHour)
	 {
	 cachedIP = [[NSString alloc] initWithString:[self getIPAddressForHost:defaultUrl]];
	 cachedIPHour = [self getHour];
	 }
	 
	 // Grab the http (or https for the future) and the port (if there is one)
	 NSArray *subStrings = [defaultUrl componentsSeparatedByString:@":"];
	 if ([subStrings count] == 2)
	 urlString = [NSString stringWithFormat:@"%@://%@", [subStrings objectAtIndex:0], cachedIP];
	 else if ([subStrings count] == 3)
	 urlString = [NSString stringWithFormat:@"%@://%@:%@", [subStrings objectAtIndex:0], cachedIP, [subStrings objectAtIndex:2]];
	 }
	 else 
	 {
	 // If the user used an IP address, just use the defaultUrl as is.
	 urlString = defaultUrl;
	 }*/
	
	DefaultSettings *settings = [DefaultSettings sharedInstance];
	NSString *urlString = settings.urlString;
	NSString *username = settings.username;
	NSString *password = settings.password;
	NSDictionary *settingsDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:@"settingsDictionary"];
	MusicControlsSingleton *musicControls = [MusicControlsSingleton sharedInstance];
		
	NSString *encodedUserName = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)username, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
	NSString *encodedPassword = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)password, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
	
	//DLog(@"username: %@    password: %@", encodedUserName, encodedPassword);
	
	// Return the base URL
	if ([action isEqualToString:@"getIndexes.view"] || [action isEqualToString:@"search.view"] || [action isEqualToString:@"search2.view"] || [action isEqualToString:@"getNowPlaying.view"] || [action isEqualToString:@"getPlaylists.view"] || [action isEqualToString:@"getMusicFolders.view"] || [action isEqualToString:@"createPlaylist.view"])
	{
		return [NSString stringWithFormat:@"%@/rest/%@?u=%@&p=%@&v=1.1.0&c=iSub", urlString, action, [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else if ([action isEqualToString:@"stream.view"] && [[settingsDictionary objectForKey:@"maxBitrateSetting"] intValue] != 7)
	{
		return [NSString stringWithFormat:@"%@/rest/stream.view?maxBitRate=%i&u=%@&p=%@&v=1.2.0&c=iSub&id=", urlString, [musicControls maxBitrateSetting], [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else if ([action isEqualToString:@"addChatMessage.view"])
	{
		return [NSString stringWithFormat:@"%@/rest/addChatMessage.view?&u=%@&p=%@&v=1.2.0&c=iSub&message=", urlString, [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else if ([action isEqualToString:@"getLyrics.view"])
	{
		NSString *encodedArtist = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)musicControls.currentSongObject.artist, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
		NSString *encodedTitle = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)musicControls.currentSongObject.title, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
		
		return [NSString stringWithFormat:@"%@/rest/getLyrics.view?artist=%@&title=%@&u=%@&p=%@&v=1.2.0&c=iSub", urlString, [encodedArtist autorelease], [encodedTitle autorelease], [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else if ([action isEqualToString:@"getRandomSongs.view"] || [action isEqualToString:@"getAlbumList.view"] || [action isEqualToString:@"jukeboxControl.view"])
	{
		return [NSString stringWithFormat:@"%@/rest/%@?u=%@&p=%@&v=1.2.0&c=iSub", urlString, action, [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else
	{
		return [NSString stringWithFormat:@"%@/rest/%@?u=%@&p=%@&v=1.1.0&c=iSub&id=", urlString, action, [encodedUserName autorelease], [encodedPassword autorelease]];
	}
}


@end
