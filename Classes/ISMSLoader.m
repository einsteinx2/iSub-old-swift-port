//
//  Loader.m
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoader.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "Song.h"

@implementation ISMSLoader

@synthesize connection, receivedData;
@synthesize delegate;

+ (id)loader
{
	[NSException raise:NSInternalInconsistencyException 
				format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
	
	return nil;
}

+ (id)loaderWithDelegate:(id <ISMSLoaderDelegate>)theDelegate
{
	[NSException raise:NSInternalInconsistencyException 
				format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
	
	return nil;
}

- (void)setup
{
    
}

- (id)init
{
    self = [super init];
    if (self) 
	{
        [self setup];
    }
    
    return self;
}

- (id)initWithDelegate:(id <ISMSLoaderDelegate>)theDelegate
{
	self = [super init];
    if (self) 
	{
        [self setup];
		delegate = theDelegate;
	}
	
	return self;
}


- (ISMSLoaderType)type
{
    return ISMSLoaderType_Generic;
}

- (void)startLoad
{
    self.request = [self createRequest];
	self.connection = [NSURLConnection connectionWithRequest:self.request delegate:self];
	if (self.connection)
	{
		// Create the NSMutableData to hold the received data.
		// receivedData is an instance variable declared elsewhere.
		self.receivedData = [NSMutableData data];
	} 
	else 
	{
		// Inform the delegate that the loading failed.
		NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
		[self informDelegateLoadingFailed:error];
	}
}

- (void)cancelLoad
{
	// Clean up connection objects
	[self.connection cancel];
	self.connection = nil;
	self.receivedData = nil;
}

- (NSURLRequest *)createRequest
{
	[NSException raise:NSInternalInconsistencyException 
				format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
	return nil;
}

- (void)processResponse
{
	[NSException raise:NSInternalInconsistencyException 
				format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
}

- (void)subsonicErrorCode:(NSInteger)errorCode message:(NSString *)message
{
//DLog(@"Subsonic error: %@", message);
	
	NSDictionary *dict = [NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey];
	NSError *error = [NSError errorWithDomain:SUSErrorDomain code:errorCode userInfo:dict];
	[self informDelegateLoadingFailed:error];
	
	/*if ([parseState isEqualToString: @"allAlbums"])
	{
	//DLog(@"Subsonic error: %@", message);
	}
	else
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:appDelegateS cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	 alert.tag = 1;
		[alert show];
		[alert release];
	}*/
}

- (BOOL)informDelegateLoadingFailed:(NSError *)error
{
	if ([self.delegate respondsToSelector:@selector(loadingFailed:withError:)])
	{
		[self.delegate loadingFailed:self withError:error];
		return YES;
	}
	
//DLog(@"delegate (%@) did not respond to loading failed", self.delegate);
	return NO;
}

- (BOOL)informDelegateLoadingFinished
{
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[self.delegate loadingFinished:self];
		return YES;
	}
	
	//DLog(@"delegate (%@) did not respond to loading finished", self.delegate);
	return NO;
}

#pragma mark Connection Delegate

- (NSURLRequest *)connection:(NSURLConnection *)inConnection willSendRequest:(NSURLRequest *)inRequest redirectResponse:(NSURLResponse *)inRedirectResponse
{
    if (inRedirectResponse)
    {
        // Notify the delegate
        if ([self.delegate respondsToSelector:@selector(loadingRedirected:redirectUrl:)])
        {
			[self.delegate loadingRedirected:self redirectUrl:inRequest.URL];
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

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [self.receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	self.receivedData = nil;
	self.connection = nil;
	
	// Inform the delegate that loading failed
	[self informDelegateLoadingFailed:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{			
	[self processResponse];
	
	// Clean up the connection
	self.connection = nil;
	self.receivedData = nil;
}

@end
