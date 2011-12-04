//
//  ServerURLChecker.m
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSServerChecker.h"
#import "TBXML.h"
#import "NSError+ISMSError.h"
#import "NSMutableURLRequest+SUS.h"
#import "SavedSettings.h"

@implementation SUSServerChecker

@synthesize receivedData, delegate, request, isNewSearchAPI;

- (id)init
{
	if ((self = [super init]))
	{
		isNewSearchAPI = NO;	
	}
	return self;
}

- (id)initWithDelegate:(NSObject<SUSServerURLCheckerDelegate> *)theDelegate
{
    if ((self = [super init]))
	{
        delegate = theDelegate;
		isNewSearchAPI = NO;
	}	
	return self;
}

- (void)checkServerUrlString:(NSString *)urlString username:(NSString *)username password:(NSString *)password
{
    self.receivedData = [NSMutableData dataWithCapacity:0];
    
	self.request = [NSMutableURLRequest requestWithSUSAction:@"ping" forUrlString:urlString username:username password:password andParameters:nil];
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	
	if (!connection)
    {
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
        [delegate SUSServerURLCheckFailed:self withError:error];
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
	[receivedData setLength:0];
}

- (NSURLRequest *)connection:(NSURLConnection *)inConnection willSendRequest:(NSURLRequest *)inRequest redirectResponse:(NSURLResponse *)inRedirectResponse
{
    if (inRedirectResponse) 
    {
        // Notify the delegate
        if ([delegate respondsToSelector:@selector(SUSServerURLCheckRedirected:redirectUrl:)])
        {
             [delegate SUSServerURLCheckRedirected:self redirectUrl:[inRequest URL]];
        }
        
        NSMutableURLRequest *r = [[request mutableCopy] autorelease]; // original request
        [r setURL:[inRequest URL]];
        return r;
    } 
    else 
    {
        DLog(@"returning inRequest");
        return inRequest;
    }
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
	[receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{    
    [theConnection release];
    self.receivedData = nil;
	
	[delegate SUSServerURLCheckFailed:self withError:error];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ISMSNotification_ServerCheckFailed object:nil];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	DLog(@"receivedData: %@", [[[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding] autorelease]);
	TBXML *tbxml = [[TBXML alloc] initWithXMLData:receivedData];
    TBXMLElement *root = tbxml.rootXMLElement;
    if (root) 
	{
        if ([[TBXML elementName:root] isEqualToString:@"subsonic-response"])
        {
			NSString *version = [TBXML valueOfAttributeNamed:@"version" forElement:root];
			if (version)
			{
				NSArray *splitVersion = [version componentsSeparatedByString:@"."];
				if ([splitVersion count] == 1)
				{
					NSUInteger ver = [[splitVersion objectAtIndex:0] intValue];
					if (ver >= 2)
						isNewSearchAPI = YES;
					else
						isNewSearchAPI = NO;
				}
				else if ([splitVersion count] > 1)
				{
					NSUInteger ver1 = [[splitVersion objectAtIndex:0] intValue];
					NSUInteger ver2 = [[splitVersion objectAtIndex:1] intValue];
					if ((ver1 >= 1 && ver2 >= 4) || (ver1 >= 2))
						isNewSearchAPI = YES;
					else
						isNewSearchAPI = NO;
				}				
			}
			
			TBXMLElement *error = [TBXML childElementNamed:@"error" parentElement:root];
			if (error)
			{
				if ([[TBXML valueOfAttributeNamed:@"code" forElement:error] isEqualToString:@"40"])
				{
					// Incorrect credentials, so fail
					NSError *anError = [NSError errorWithISMSCode:ISMSErrorCode_IncorrectCredentials];
					[delegate SUSServerURLCheckFailed:self withError:anError];
					[[NSNotificationCenter defaultCenter] postNotificationName:ISMSNotification_ServerCheckFailed object:nil];
				}
				else
				{
					// This is a Subsonic server, so pass
					[delegate SUSServerURLCheckPassed:self];
					[[NSNotificationCenter defaultCenter] postNotificationName:ISMSNotification_ServerCheckPassed object:nil];
				}
			}
			else
			{
				// This is a Subsonic server, so pass
				[delegate SUSServerURLCheckPassed:self];
				[[NSNotificationCenter defaultCenter] postNotificationName:ISMSNotification_ServerCheckPassed object:nil];
			}
        }
        else
        {
            // This is not a Subsonic server, so fail
            NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotASubsonicServer];
			[delegate SUSServerURLCheckFailed:self withError:error];
			[[NSNotificationCenter defaultCenter] postNotificationName:ISMSNotification_ServerCheckFailed object:nil];
        }
    }
    else
    {
        // This is not XML, so fail
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
		[delegate SUSServerURLCheckFailed:self withError:error];
		[[NSNotificationCenter defaultCenter] postNotificationName:ISMSNotification_ServerCheckFailed object:nil];
    }
	[tbxml release];
    
	[theConnection release];
    self.receivedData = nil;
}

- (void) dealloc
{
    [receivedData release]; receivedData = nil;
	[super dealloc];
}

@end
