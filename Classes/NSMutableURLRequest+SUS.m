//
//  NSMutableURLRequest+SUS.m
//  iSub
//
//  Created by Benjamin Baron on 10/31/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NSMutableURLRequest+SUS.h"
#import "SavedSettings.h"
#import "NSString+URLEncode.h"
#import "NSData+Base64.h"

@implementation NSMutableURLRequest (SUS)

static NSArray *ver1_0_0 = nil;
static NSArray *ver1_2_0 = nil;
static NSArray *ver1_3_0 = nil;
static NSArray *ver1_4_0 = nil;
static NSArray *ver1_5_0 = nil;
static NSArray *ver1_6_0 = nil;
static NSSet *setOfVersions = nil;

__attribute__((constructor))
static void initialize_versionArrays() 
{
    ver1_0_0 = [[NSArray alloc] initWithObjects:@"ping", @"getLicense", @"getMusicFolders", @"getNowPlaying", @"getIndexes", @"getMusicDirectory", @"search", @"getPlaylists", @"getPlaylist", @"download", @"stream", @"getCoverArt", @"1.0.0", nil];
    ver1_2_0 = [[NSArray alloc] initWithObjects:@"createPlaylist", @"deletePlaylist", @"getChatMessages", @"addChatMessage", @"getAlbumList", @"getRandomSongs", @"getLyrics", @"jukeboxControl", @"1.2.0", nil];
    ver1_3_0 = [[NSArray alloc] initWithObjects:@"getUser", @"deleteUser", @"1.3.0", nil];
    ver1_4_0 = [[NSArray alloc] initWithObjects:@"search2", @"1.4.0", nil];
    ver1_5_0 = [[NSArray alloc] initWithObjects:@"scrobble", @"1.5.0", nil];
    ver1_6_0 = [[NSArray alloc] initWithObjects:@"getPodcasts", @"getShares", @"createShare", @"updateShare", @"deleteShare", @"setRating", @"1.6.0", nil];
    setOfVersions = [[NSSet alloc] initWithObjects:ver1_0_0, ver1_2_0, ver1_3_0, ver1_4_0, ver1_5_0, ver1_6_0, nil];
}

__attribute__((destructor))
static void destroy_versionArrays() 
{
    [ver1_0_0 release]; ver1_0_0 = nil;
    [ver1_2_0 release]; ver1_2_0 = nil;
    [ver1_3_0 release]; ver1_3_0 = nil;
    [ver1_4_0 release]; ver1_4_0 = nil;
    [ver1_5_0 release]; ver1_5_0 = nil;
    [ver1_6_0 release]; ver1_6_0 = nil;
    [setOfVersions release]; setOfVersions = nil;
}

+ (NSMutableURLRequest *)requestWithSUSAction:(NSString *)action andParameters:(NSDictionary *)parameters byteOffset:(NSUInteger)offset
{
    SavedSettings *settings = [SavedSettings sharedInstance];
    NSString *urlString = [NSString stringWithFormat:@"%@/rest/%@.view", settings.urlString, action];
    if (settings.redirectUrlString)
    {
        // The redirect URL has been found, so use it
        urlString = [NSString stringWithFormat:@"%@/rest/%@.view", settings.redirectUrlString, action];
    }
	NSString *username = [settings.username URLEncodeString];
	NSString *password = [settings.password URLEncodeString];
    NSString *version = nil;
    
    // Set the API version for this call by checking the arrays
    for (NSArray *versionArray in setOfVersions)
    {
        if ([versionArray containsObject:action])
        {
            version = [versionArray lastObject];
            break;
        }
    }
    NSAssert(version != nil, @"SUS URL API version not set!");
    
    // Setup the POST parameters
    NSMutableString *postString = [NSMutableString stringWithFormat:@"v=%@&c=iSub", version];
    if (parameters != nil)
    {
        for (NSString *key in [parameters allKeys])
        {
			if ((NSNull *)[parameters objectForKey:key] == [NSNull null])
			{
				//DLog(@"Received a null parameter for key: %@ for action: %@", key, action);
				DLog(@"Received a null parameter for key: %@ for action: %@  stack trace:\n%@", key, action, [NSThread callStackSymbols]);
			}
			else
			{
				[postString appendFormat:@"&%@=%@", [key URLEncodeString], [[parameters objectForKey:key] URLEncodeString]];
			}
        }
    }
    
    // Handle special case when loading playlists
    NSTimeInterval loadingTimeout = kLoadingTimeout;
    if ([action isEqualToString:@"getPlaylist"])
    {
        loadingTimeout = 3600.0; // Timeout set to 60 mins to prevent timeout errors
    }
    
    // Create the request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString] 
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData 
                                                       timeoutInterval:loadingTimeout];
    [request setHTTPMethod:@"POST"]; 
    [request setHTTPBody:[postString dataUsingEncoding:NSUTF8StringEncoding]];
    
    // Set the HTTP Basic Auth
    NSString *authStr = [NSString stringWithFormat:@"%@:%@", username, password];
    NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64EncodingWithLineLength:0]];
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
	
	if (offset > 0)
	{
		NSString *rangeString = [NSString stringWithFormat:@"bytes=%i-", offset];
		[request setValue:rangeString forHTTPHeaderField:@"Range"];
	}
    
    return request;
}

+ (NSMutableURLRequest *)requestWithSUSAction:(NSString *)action andParameters:(NSDictionary *)parameters
{
	return [NSMutableURLRequest requestWithSUSAction:action andParameters:parameters byteOffset:0];
}

@end
