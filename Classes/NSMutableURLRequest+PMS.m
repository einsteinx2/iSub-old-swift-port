//
//  NSMutableURLRequest+PMS.m
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "NSMutableURLRequest+PMS.h"
#import "SavedSettings.h"
#import "NSData+Base64.h"

@implementation NSMutableURLRequest (PMS)

+ (NSMutableURLRequest *)requestWithPMSAction:(NSString *)action item:(NSString *)item urlString:(NSString *)url username:(NSString *)user password:(NSString *)pass parameters:(NSDictionary *)parameters byteOffset:(NSUInteger)offset
{
	NSMutableString *urlString;
	if (item)
		urlString = [NSMutableString stringWithFormat:@"%@/api/%@/%@", url, action, item];
	else
		urlString = [NSMutableString stringWithFormat:@"%@/api/%@", url, action];
	DLog(@"urlString: %@", urlString);
	NSString *username = [user URLEncodeString];
	NSString *password = [pass URLEncodeString];
	NSString *version = @"1";
	
	// Setup the POST parameters
	NSMutableString *postString = [NSMutableString stringWithFormat:@"v=%@&c=iSub&u=%@&p=%@", version, username, password];
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
					}
				}
				else if ([value isKindOfClass:[NSString class]])
				{
					// handle single value for key
					[postString appendFormat:@"&%@=%@", [key URLEncodeString], [(NSString*)value URLEncodeString]];
				}
			}
		}
	}
	//DLog(@"post string: %@", postString);
	
	// Handle special case when loading playlists
	NSTimeInterval loadingTimeout = ISMSLoadingTimeout;
	
	// Create the request
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString] 
														   cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData 
													   timeoutInterval:loadingTimeout];
	
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:[postString dataUsingEncoding:NSUTF8StringEncoding]];
	
	// Set the HTTP Basic Auth
	if (settingsS.isBasicAuthEnabled)
	{
		//DLog(@"using basic auth!");
		NSString *authStr = [NSString stringWithFormat:@"%@:%@", username, password];
		NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
		NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64EncodingWithLineLength:0]];
		[request setValue:authValue forHTTPHeaderField:@"Authorization"];
	}
	
	if (offset > 0)
	{
		NSString *rangeString = [NSString stringWithFormat:@"bytes=%i-", offset];
		[request setValue:rangeString forHTTPHeaderField:@"Range"];
	}
	
	//DLog(@"request: %@", request);
    
    return request;
}

+ (NSMutableURLRequest *)requestWithPMSAction:(NSString *)action item:(NSString *)item urlString:(NSString *)url username:(NSString *)user password:(NSString *)pass parameters:(NSDictionary *)parameters
{
	return [NSMutableURLRequest requestWithPMSAction:action item:item urlString:url username:user password:pass parameters:nil byteOffset:0];
}

+ (NSMutableURLRequest *)requestWithPMSAction:(NSString *)action item:(NSString *)item parameters:(NSDictionary *)parameters byteOffset:(NSUInteger)offset
{
	NSString *urlString = settingsS.urlString;
	if (settingsS.redirectUrlString)
	{
		// The redirect URL has been found, so use it
		urlString = settingsS.redirectUrlString;
	}
	
	DLog(@"username: %@   password: %@", settingsS.username, settingsS.password);
	
	return [NSMutableURLRequest requestWithPMSAction:action 
												item:item
										urlString:urlString 
											username:settingsS.username
											password:settingsS.password 
									   parameters:parameters 
										  byteOffset:offset];
}

+ (NSMutableURLRequest *)requestWithPMSAction:(NSString *)action item:(NSString *)item parameters:(NSDictionary *)parameters
{
	return [NSMutableURLRequest requestWithPMSAction:action item:item parameters:parameters byteOffset:0];
}

+ (NSMutableURLRequest *)requestWithPMSAction:(NSString *)action item:(NSString *)item
{
	return [NSMutableURLRequest requestWithPMSAction:action item:item parameters:nil];
}

@end
