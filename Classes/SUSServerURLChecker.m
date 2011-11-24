//
//  ServerURLChecker.m
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSServerURLChecker.h"
#import "TBXML.h"
#import "NSError+ISMSError.h"
#import "NSMutableURLRequest+SUS.h"
#import "SavedSettings.h"

@implementation SUSServerURLChecker

@synthesize receivedData, delegate, request;

- (id) init
{
	self = [super init];
	return self;
}

- (id)initWithDelegate:(NSObject<SUSServerURLCheckerDelegate> *)theDelegate
{
    if ((self = [super init]))
	{
        delegate = theDelegate;
	}	
	return self;
}

- (void)checkURL:(NSURL *)url
{
    self.receivedData = [NSMutableData dataWithCapacity:0];
    
    self.request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:30.0];
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
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
    //DLog(@"received: %@", [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding]);
	TBXML *tbxml = [[TBXML alloc] initWithXMLData:receivedData];
    TBXMLElement *root = tbxml.rootXMLElement;
    if (root) 
	{
        if ([[TBXML elementName:root] isEqualToString:@"subsonic-response"])
        {
            // This is a Subsonic server, so pass
            [delegate SUSServerURLCheckPassed:self];
        }
        else
        {
            // This is not a Subsonic server, so fail
            NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotASubsonicServer];
            [delegate SUSServerURLCheckFailed:self withError:error];
        }
    }
    else
    {
        // This is not XML, so fail
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
        [delegate SUSServerURLCheckFailed:self withError:error];
    }
    
	[theConnection release];
    self.receivedData = nil;
}

- (void) dealloc
{
    [receivedData release]; receivedData = nil;
	[super dealloc];
}

@end
