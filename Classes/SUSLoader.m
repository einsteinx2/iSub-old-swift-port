//
//  Loader.m
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSLoader.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "Song.h"
#import "NSError-ISMSError.h"

@implementation SUSLoader

@synthesize connection, receivedData;
@synthesize delegate, loadError;

- (void)setup
{
    loadError = nil;
    delegate = nil;
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

- (id)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate
{
	self = [super init];
    if (self) 
	{
        [self setup];
		delegate = theDelegate;
        DLog(@"init with delegate %@", delegate);
	}
	
	return self;
}

- (void)dealloc
{
	[loadError release]; loadError = nil;
    [super dealloc];
}

- (void)startLoad
{
	[NSException raise:NSInternalInconsistencyException 
				format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
}

- (void)cancelLoad
{
	// Clean up connection objects
	[self.connection cancel];
	self.connection = nil;
	self.receivedData = nil;
}

- (void) subsonicErrorCode:(NSInteger)errorCode message:(NSString *)message
{
	DLog(@"Subsonic error: %@", message);
	
	NSDictionary *dict = [NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey];
	NSError *error = [NSError errorWithDomain:SUSErrorDomain code:errorCode userInfo:dict];
	[self.delegate loadingFailed:self withError:error];
	
	/*if ([parseState isEqualToString: @"allAlbums"])
	{
		DLog(@"Subsonic error: %@", message);
	}
	else
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:appDelegate cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	 alert.tag = 1;
		[alert show];
		[alert release];
	}*/
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

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [self.receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	self.receivedData = nil;
	self.connection = nil;
	
	// Inform the delegate that loading failed
	[self.delegate loadingFailed:self withError:error];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	self.receivedData = nil;
	self.connection = nil;
	
	// Notify the delegate that the loading is finished
	[self.delegate loadingFinished:self];
}


@end
