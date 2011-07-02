//
//  URLCheckConnectionDelegate.m
//  iSub
//
//  Created by Ben Baron on 7/11/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "URLCheckConnectionDelegate.h"


@implementation URLCheckConnectionDelegate

@synthesize redirectUrl, connectionFinished;

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
	{
		return YES; // Self-signed cert will be accepted
		// Note: it doesn't seem to matter what you return for a proper SSL cert, only self-signed certs
	}
	// If no other authentication is required, return NO for everything else
	// Otherwise maybe YES for NSURLAuthenticationMethodDefault and etc.
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

- (NSURLRequest *)connection:(NSURLConnection *)connection  willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse
{
	//DLog(@"%@", [[redirectResponse URL] absoluteString]);
	
	self.redirectUrl = [[redirectResponse URL] absoluteString];
	
	return request;
}


- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	DLog(@"didFailWithError");
	connectionFinished = YES;
}	


- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	DLog(@"connectionDidFinishLoading");
	connectionFinished = YES;
}

@end
