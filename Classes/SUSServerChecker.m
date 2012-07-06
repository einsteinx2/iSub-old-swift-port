//
//  SUSServerChecker.m
//  iSub
//
//  Created by Benjamin Baron on 6/14/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSServerChecker.h"
#import "NSMutableURLRequest+SUS.h"
#import "TBXML.h"
#import "NSError+ISMSError.h"
#import "NSNotificationCenter+MainThread.h"

@implementation SUSServerChecker

- (void)checkServerUrlString:(NSString *)urlString username:(NSString *)username password:(NSString *)password
{
    self.receivedData = [NSMutableData dataWithCapacity:0];
    
	NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithSUSAction:@"ping" 
																   urlString:urlString 
																	   username:username 
																	   password:password 
																  parameters:nil];
	[theRequest setTimeoutInterval:ISMSServerCheckTimeout];
	self.request = theRequest;
	self.connection = [NSURLConnection connectionWithRequest:self.request delegate:self];
	if (self.connection)
	{
		[self performSelector:@selector(checkTimedOut) withObject:nil afterDelay:25.0];
	}
	else
    {
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
        [self.delegate ISMSServerURLCheckFailed:self withError:error];
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

- (NSURLRequest *)connection:(NSURLConnection *)inConnection willSendRequest:(NSURLRequest *)inRequest redirectResponse:(NSURLResponse *)inRedirectResponse
{
    if (inRedirectResponse) 
    {
        // Notify the delegate
        if ([self.delegate respondsToSelector:@selector(ISMSServerURLCheckRedirected:redirectUrl:)])
        {
			[self.delegate ISMSServerURLCheckRedirected:self redirectUrl:[inRequest URL]];
        }
        
        NSMutableURLRequest *r = [self.request mutableCopy]; // original request
		[r setTimeoutInterval:ISMSServerCheckTimeout];
        [r setURL:[inRequest URL]];
        return r;
    } 
    else 
    {
        //DLog(@"returning inRequest");
        return inRequest;
    }
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
	[self.receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{    
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
    self.connection = nil;
	self.request = nil;
    self.receivedData = nil;
	
	[self.delegate ISMSServerURLCheckFailed:self withError:error];
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ServerCheckFailed];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	DLog(@"receivedData: %@", [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);
	
	NSError *error;
    TBXML *tbxml = [[TBXML alloc] initWithXMLData:self.receivedData error:&error];
	if (error)
	{
		// This is not XML, so fail
		[self.delegate ISMSServerURLCheckFailed:self withError:error];
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ServerCheckFailed];
	}
	else
	{
		TBXMLElement *root = tbxml.rootXMLElement;
		
        if ([[TBXML elementName:root] isEqualToString:@"subsonic-response"])
        {
			self.versionString = [TBXML valueOfAttributeNamed:@"version" forElement:root];
			if (self.versionString)
			{
				NSArray *splitVersion = [self.versionString componentsSeparatedByString:@"."];
				if ([splitVersion count] > 0)
				{
					self.majorVersion = [[splitVersion objectAtIndexSafe:0] intValue];
					if (self.majorVersion >= 2)
						self.isNewSearchAPI = YES;
					
					if ([splitVersion count] > 1)
					{
						self.minorVersion = [[splitVersion objectAtIndexSafe:1] intValue];
						if ((self.majorVersion >= 1 && self.minorVersion >= 4))
							self.isNewSearchAPI = YES;
					}	
				}			
			}
			
			//DLog(@"versionString: %@   majorVersion: %i  minorVersion: %i", self.versionString, self.majorVersion, self.minorVersion);
			
			TBXMLElement *error = [TBXML childElementNamed:@"error" parentElement:root];
			if (error)
			{
				if ([[TBXML valueOfAttributeNamed:@"code" forElement:error] isEqualToString:@"40"])
				{
					// Incorrect credentials, so fail
					NSError *anError = [NSError errorWithISMSCode:ISMSErrorCode_IncorrectCredentials];
					[self.delegate ISMSServerURLCheckFailed:self withError:anError];
					[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ServerCheckFailed];
				}
				else
				{
					// This is a Subsonic server, so pass
					[self.delegate ISMSServerURLCheckPassed:self];
					[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ServerCheckPassed];
				}
			}
			else
			{
				// This is a Subsonic server, so pass
				[self.delegate ISMSServerURLCheckPassed:self];
				[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ServerCheckPassed];
			}
        }
        else
        {
            // This is not a Subsonic server, so fail
            NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotASubsonicServer];
			[self.delegate ISMSServerURLCheckFailed:self withError:error];
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ServerCheckFailed];
        }
    }
    
	self.receivedData = nil;
	self.connection = nil;
    self.receivedData = nil;
}

@end
