//
//  APICheckConnectionDelegate.m
//  iSub
//
//  Created by Ben Baron on 12/14/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "APICheckConnectionDelegate.h"
#import "APICheckXMLParser.h"
#import "CustomUIAlertView.h"
#import "ViewObjectsSingleton.h"

@implementation APICheckConnectionDelegate

@synthesize receivedData;

- (id) init
{
	if ((self = [super init]))
	{
		receivedData = [[NSMutableData data] retain];
	}	
	return self;
}

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

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
	[receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	//if (![ViewObjectsSingleton sharedInstance].isOfflineMode)
	//{
		//CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"There was an error checking the server version.\n\nError %i: %@", [error code], [error localizedDescription]] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		//[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		//[alert release];
		DLog(@"There was an error checking the server version.\n\nError %i: %@", [error code], [error localizedDescription]);
		
		[theConnection release];
		[receivedData release]; receivedData = nil;
	//}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:receivedData];
	APICheckXMLParser *parser = (APICheckXMLParser*)[[APICheckXMLParser alloc] initXMLParser];
	[xmlParser setDelegate:parser];
	[xmlParser parse];
	
	[xmlParser release];
	[parser release];
		
	[theConnection release];
	[receivedData release]; receivedData = nil;
}

- (void) dealloc
{
	[super dealloc];
	[receivedData release];
}

@end
