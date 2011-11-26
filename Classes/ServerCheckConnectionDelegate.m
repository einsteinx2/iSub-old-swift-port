//
//  ServerCheckConnectionDelegate.m
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ServerCheckConnectionDelegate.h"
#import "TBXML.h"

@implementation ServerCheckConnectionDelegate

@synthesize receivedData, delegate;

- (id) init
{
	if ((self = [super init]))
	{
		receivedData = [[NSMutableData data] retain];
	}	
	return self;
}

- (id)initWithDelegate:(NSObject<ServerCheckDelegate> *)theDelegate
{
    if ((self = [super init]))
	{
		receivedData = [[NSMutableData data] retain];
        delegate = theDelegate;
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
    [theConnection release];
    self.receivedData = nil;
    
    [delegate serverCheckFailed];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	TBXML *tbxml = [[TBXML alloc] initWithXMLData:receivedData];
    TBXMLElement *root = tbxml.rootXMLElement;
    if (root) 
	{
        if ([(NSString*)(root->name) isEqualToString:@"subsonic-response"])
        {
            // This is a Subsonic server, so pass
            [delegate serverCheckPassed];
        }
        else
        {
            // This is not a Subsonic server, so fail
            [self connection:nil didFailWithError:nil];
        }
    }
    else
    {
        // This is not XML, so fail
        [self connection:nil didFailWithError:nil];
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

