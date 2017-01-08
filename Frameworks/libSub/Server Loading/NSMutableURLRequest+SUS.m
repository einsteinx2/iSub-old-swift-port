//
//  NSMutableURLRequest+SUS.m
//  iSub
//
//  Created by Benjamin Baron on 10/31/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NSMutableURLRequest+SUS.h"
#import "iSub-Swift.h"
#import "Imports.h"

@implementation NSMutableURLRequest (SUS)

+ (NSMutableURLRequest *)requestWithSUSAction:(NSString *)action urlString:(NSString *)url username:(NSString *)user password:(NSString *)pass parameters:(NSDictionary *)parameters fragment:(NSString *)fragment byteOffset:(NSUInteger)offset
{
    NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@/rest/%@.view", url, action];
    if ([action isEqualToString:@"hls"])
        urlString = [NSMutableString stringWithFormat:@"%@/rest/%@.m3u8", url, action];
    if (fragment.hasValue) {
        [urlString appendFormat:@"#%@", fragment];
    }
    
	NSString *username = [user URLEncodeString];
    
    // Generate unique token and salt for this request. To get a long random salt, We'll generate a large
    // random number, get its string value, and md5 it. Then to get the token, we do md5(password + salt)
    NSString *salt = [[[@(arc4random_uniform(UINT32_MAX)) stringValue] md5] lowercaseString];
	NSString *token = [[[pass stringByAppendingString:salt] md5] lowercaseString];
    
    // Only support Subsonic version 5.3 and later
	NSString *version = @"1.13.0";
		
	// Setup the POST parameters
	NSMutableString *postString = [NSMutableString stringWithFormat:@"v=%@&c=iSub&u=%@&t=%@&s=%@", version, username, token, salt];
	if (parameters != nil)
	{
		for (NSString *key in [parameters allKeys])
		{
			if ((NSNull *)[parameters objectForKey:key] == [NSNull null])
			{
				if ([NSThread respondsToSelector:@selector(callStackSymbols)])
					DLog(@"Received a null parameter for key: %@ for action: %@  stack trace:\n%@", key, action, [NSThread callStackSymbols]);
			}
			else
			{
				id value = [parameters objectForKey:key];
				if ([value isKindOfClass:[NSArray class]])
				{
					// handle multiple values for key
					for (id subValue in (NSArray*)value)
					{
						if ([subValue isKindOfClass:[NSString class]])
						{
							// handle single value for key
							[postString appendFormat:@"&%@=%@", [key URLEncodeString], [(NSString*)subValue URLEncodeString]];
						}
                        else if ([subValue isKindOfClass:[NSNumber class]])
                        {
                            // Convert numbers to strings
							[postString appendFormat:@"&%@=%@", [key URLEncodeString], [[(NSNumber *)subValue stringValue] URLEncodeString]];
                        }
					}
				}
				else if ([value isKindOfClass:[NSString class]])
				{
					// handle single value for key
					[postString appendFormat:@"&%@=%@", [key URLEncodeString], [(NSString*)value URLEncodeString]];
				}
                else if ([value isKindOfClass:[NSNumber class]])
                {
                    // handle single value for key
                    [postString appendFormat:@"&%@=%@", [key URLEncodeString], [(NSNumber*)value stringValue]];
                }
			}
		}
	}
	//DLog(@"post string: %@", postString);
	
	// Handle special case when loading playlists
	NSTimeInterval loadingTimeout = ISMSLoadingTimeout;
	if ([action isEqualToString:@"getPlaylist"])
	{
		loadingTimeout = 3600.0; // Timeout set to 60 mins to prevent timeout errors
	}
	else if ([action isEqualToString:@"ping"])
	{
		loadingTimeout = ISMSServerCheckTimeout;
	}
	
	if ([url isEqualToString:@"https://one.ubuntu.com/music"])
	{
		// This is Ubuntu One, send as GET request
		[urlString appendFormat:@"?%@", postString];
	}
	
	// Create the request
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString] 
									  cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData 
								  timeoutInterval:loadingTimeout];
	
	if ([url isEqualToString:@"https://one.ubuntu.com/music"])
	{
		[request setHTTPMethod:@"GET"]; 
	}
	else
	{
		[request setHTTPMethod:@"POST"]; 
		[request setHTTPBody:[postString dataUsingEncoding:NSUTF8StringEncoding]];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	}
	
	// Set the HTTP Basic Auth
	if (SavedSettings.si.isBasicAuthEnabled)
	{
		//DLog(@"using basic auth!");
		NSString *authStr = [NSString stringWithFormat:@"%@:%@", username, [pass URLEncodeString]];
		NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
		NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64EncodedStringWithOptions:0]];
		[request setValue:authValue forHTTPHeaderField:@"Authorization"];
	}
	
	if (offset > 0)
	{
		NSString *rangeString = [NSString stringWithFormat:@"bytes=%ld-", (long)offset];
		[request setValue:rangeString forHTTPHeaderField:@"Range"];
	}
    
    // Turn off request caching
    [request setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
	
	//DLog(@"request: %@", request);
    
    return request;
}

+ (NSMutableURLRequest *)requestWithSUSAction:(NSString *)action parameters:(NSDictionary *)parameters fragment:(NSString *)fragment byteOffset:(NSUInteger)offset
{
	NSString *urlString = SavedSettings.si.currentServer.url;
	if (SavedSettings.si.redirectUrlString)
	{
		// The redirect URL has been found, so use it
		urlString = SavedSettings.si.redirectUrlString;
	}
	
//DLog(@"username: %@   password: %@", SavedSettings.si.username, SavedSettings.si.password);
	
    Server *currentServer = SavedSettings.si.currentServer;
    return [NSMutableURLRequest requestWithSUSAction:action
                                           urlString:urlString
                                            username:currentServer.username
                                            password:currentServer.password
                                          parameters:parameters
                                            fragment: fragment
                                          byteOffset:offset];
}

+ (NSMutableURLRequest *)requestWithSUSAction:(NSString *)action parameters:(NSDictionary *)parameters fragment:(NSString *)fragment
{
    return [NSMutableURLRequest requestWithSUSAction:action parameters:parameters fragment:fragment byteOffset:0];
}

+ (NSMutableURLRequest *)requestWithSUSAction:(NSString *)action parameters:(NSDictionary *)parameters
{
	return [NSMutableURLRequest requestWithSUSAction:action parameters:parameters fragment:nil byteOffset:0];
}

@end
