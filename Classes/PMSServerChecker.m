//
//  PMSServerChecker.m
//  iSub
//
//  Created by Benjamin Baron on 6/14/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "PMSServerChecker.h"
#import "NSMutableURLRequest+PMS.h"
#import "NSError+ISMSError.h"
#import "NSNotificationCenter+MainThread.h"
#import "SBJson.h"

@implementation PMSServerChecker

- (void)checkServerUrlString:(NSString *)urlString username:(NSString *)username password:(NSString *)password
{
    self.receivedData = [NSMutableData dataWithCapacity:0];
    
	NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithPMSAction:@"status"
																		   item:nil 
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
	
	NSString *responseString = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
	DLog(@"%@", [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);
	
	NSDictionary *response = [responseString JSONValue];
	
	if ([response objectForKey:@"error"] == [NSNull null])
	{
		[self.delegate ISMSServerURLCheckFailed:self withError:nil];
	}
	else
	{
		[self.delegate ISMSServerURLCheckPassed:self];
	}
    
	self.receivedData = nil;
	self.connection = nil;
    self.receivedData = nil;
}

@end
