//
//  SUSChatDAO.m
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSChatDAO.h"
#import "NSString+rfcEncode.h"
#import "SUSChatLoader.h"
#import "NSError+ISMSError.h"
#import "NSMutableURLRequest+SUS.h"

@implementation SUSChatDAO
@synthesize loader, delegate, chatMessages, connection, receivedData;

#pragma mark - Lifecycle

- (void)setup
{
    loader = nil;
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
    if ((self = [super init])) 
	{
		delegate = theDelegate;
		[self setup];
    }
    
    return self;
}

- (void)dealloc
{
    [loader release]; loader = nil;
	[super dealloc];
}

#pragma mark - Public DAO Methods

- (void)sendChatMessage:(NSString *)message
{
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(message) forKey:@"message"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"addChatMessage" andParameters:parameters];

	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		self.receivedData = [NSMutableData data];
	} 
	else 
	{
		NSDictionary *dict = [NSDictionary dictionaryWithObject:message forKey:@"message"];
		NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotSendChatMessage withExtraAttributes:dict];
		[self.delegate loadingFailed:nil withError:error]; 
	}
	
	
	/*// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	// Form the URL and send the message
	NSString *encodedMessage = [message stringByAddingRFC3875PercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSURL *url = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@%@", [loader getBaseUrlString:@"addChatMessage.view"], encodedMessage]];
	ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
	[request startSynchronous];
	if ([request error])
	{
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error posting the message." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		alert.tag = 2;
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
		
		// Hide the loading screen
		[viewObjects performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:YES];
	}
	else
	{
		// Hide the loading screen
		//[viewObjects performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:YES];
		
		// Connection worked, reload the table
		[self performSelectorOnMainThread:@selector(loadData) withObject:nil waitUntilDone:NO];
	}
	[url release];
	
	[textInput performSelectorOnMainThread:@selector(setText:) withObject:@"" waitUntilDone:NO];
	[textInput performSelectorOnMainThread:@selector(resignFirstResponder) withObject:nil waitUntilDone:NO];
	
	[autoreleasePool release];*/
}

#pragma mark - Connection delegate for sending messages

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
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	self.receivedData = nil;
	self.connection = nil;
}


#pragma mark - Loader Manager Methods

- (void)restartLoad
{
    [self startLoad];
}

- (void)startLoad
{	
    self.loader = [[[SUSChatLoader alloc] initWithDelegate:self] autorelease];
    [loader startLoad];
}

- (void)cancelLoad
{
    [loader cancelLoad];
    self.loader = nil;
}

#pragma mark - Loader Delegate Methods

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error
{
	[self.delegate loadingFailed:theLoader withError:error];
}

- (void)loadingFinished:(SUSLoader*)theLoader
{
	self.chatMessages = [NSArray arrayWithArray:loader.chatMessages];
	[self.delegate loadingFinished:theLoader];
}

@end
