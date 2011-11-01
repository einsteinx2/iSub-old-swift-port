//
//  Loader.m
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSLoader.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "Song.h"
#import "NSError-ISMSError.h"

@implementation SUSLoader

@synthesize connection, receivedData;
@synthesize delegate, loadError;

- (void)setup
{
    loadError = nil;
    delegate = nil;
}

- (id)init
{
    self = [super init];
    if (self) 
	{
        [self setup];
    }
    
    return self;
}

- (id)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate
{
	self = [super init];
    if (self) 
	{
        [self setup];
		delegate = theDelegate;
        DLog(@"init with delegate %@", delegate);
	}
	
	return self;
}

- (void)dealloc
{
	[loadError release]; loadError = nil;
    [super dealloc];
}

- (void)startLoad
{
	[NSException raise:NSInternalInconsistencyException 
				format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
}

- (void)cancelLoad
{
	// Clean up connection objects
	[self.connection cancel];
	self.connection = nil;
	self.receivedData = nil;
}

- (void) subsonicErrorCode:(NSInteger)errorCode message:(NSString *)message
{
	DLog(@"Subsonic error: %@", message);
	
	NSDictionary *dict = [NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey];
	NSError *error = [NSError errorWithDomain:SUSErrorDomain code:errorCode userInfo:dict];
	[self.delegate loadingFailed:self withError:error];
	
	/*if ([parseState isEqualToString: @"allAlbums"])
	{
		DLog(@"Subsonic error: %@", message);
	}
	else
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:appDelegate cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	 alert.tag = 1;
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
	
	SavedSettings *settings = [SavedSettings sharedInstance];
	NSString *urlString = settings.urlString;
	NSString *username = settings.username;
	NSString *password = settings.password;
	NSDictionary *settingsDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:@"settingsDictionary"];
	MusicSingleton *musicControls = [MusicSingleton sharedInstance];
		
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
		return [NSString stringWithFormat:@"%@/rest/getLyrics.view?u=%@&p=%@&v=1.2.0&c=iSub", urlString, [encodedUserName autorelease], [encodedPassword autorelease]];
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


#pragma mark - Connection Delegate

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [self.receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	self.receivedData = nil;
	self.connection = nil;
	
	// Inform the delegate that loading failed
	[self.delegate loadingFailed:self withError:error];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	self.receivedData = nil;
	self.connection = nil;
	
	// Notify the delegate that the loading is finished
	[self.delegate loadingFinished:self];
}


@end
