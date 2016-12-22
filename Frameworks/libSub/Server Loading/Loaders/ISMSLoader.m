//
//  Loader.m
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoader.h"
#import "ISMSLoader_Subclassing.h"
#import "LibSub.h"
#import "ISMSLoaderDelegate.h"
#import "ISMSLoaderManager.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"

@interface ISMSLoader ()
@property (nonatomic, strong) ISMSLoader *selfRef;
@property (nonatomic, strong) NSURL *redirectUrl;
@property (nonatomic, strong) NSString *redirectUrlString;
@property (readwrite) ISMSLoaderState loaderState;

// From ISMSLoader_Subclassing
@property (nullable, nonatomic, strong) NSURLConnection *connection;
@property (nullable, nonatomic, strong) NSURLRequest *request;
@property (nullable, nonatomic, strong) NSURLResponse *response;
@property (nullable, nonatomic, strong) NSMutableData *receivedData;
@end

@implementation ISMSLoader

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
		_delegate = theDelegate;
	}
	
	return self;
}

- (id)initWithCallbackBlock:(LoaderCallback)theBlock
{
	self = [super init];
    if (self)
	{
        [self setup];
		_callbackBlock = [theBlock copy];
	}
	
	return self;
}

- (ISMSLoaderType)type
{
    return ISMSLoaderType_Generic;
}

- (void)startLoad
{
    // Do nothing if already loading
    if (self.loaderState == ISMSLoaderState_Loading)
        return;
    
    self.request = [self createRequest];
    if (self.request)
    {
        self.connection = [NSURLConnection connectionWithRequest:self.request delegate:self];
        if (self.connection)
        {
            // Create the NSMutableData to hold the received data.
            // receivedData is an instance variable declared elsewhere.
            self.receivedData = [NSMutableData data];
            
            self.loaderState = ISMSLoaderState_Loading;
            
            if (!self.selfRef)
                self.selfRef = self;
        }
        else
        {
            self.loaderState = ISMSLoaderState_Failed;
            
            // Inform the delegate that the loading failed.
            NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
            [self informDelegateLoadingFailed:error];
        }
    }
    else
    {
        self.loaderState = ISMSLoaderState_Failed;
        
        // Inform the delegate that the loading failed.
		NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
		[self informDelegateLoadingFailed:error];
    }
}

- (void)cancelLoad
{
    if (self.loaderState == ISMSLoaderState_Loading)
    {
        // Clean up connection objects
        [self.connection cancel];
        self.connection = nil;
        self.receivedData = nil;
        
        self.loaderState = ISMSLoaderState_Canceled;
        
        self.selfRef = nil;
    }
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
	NSDictionary *dict = [NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey];
	NSError *error = [NSError errorWithDomain:SUSErrorDomain code:errorCode userInfo:dict];
	[self informDelegateLoadingFailed:error];
}

- (void)informDelegateLoadingFailed:(NSError *)error
{
    self.loaderState = ISMSLoaderState_Failed;
    
	if ([self.delegate respondsToSelector:@selector(loadingFailed:withError:)])
	{
		[self.delegate loadingFailed:self withError:error];
	}
    
    if (self.callbackBlock)
    {
        self.callbackBlock(NO, error, self);
    }
        
    self.selfRef = nil;
}

- (void)informDelegateLoadingFinished
{
    self.loaderState = ISMSLoaderState_Finished;
    
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[self.delegate loadingFinished:self];
	}
    
    if (self.callbackBlock)
    {
        self.callbackBlock(YES, nil, self);
    }
	
	self.selfRef = nil;
}

#pragma mark Connection Delegate

- (NSURLRequest *)connection:(NSURLConnection *)inConnection willSendRequest:(NSURLRequest *)inRequest redirectResponse:(NSURLResponse *)inRedirectResponse
{
    if (inRedirectResponse)
    {
        NSURL *url = [inRequest URL];
        NSMutableString *redirectUrlString = [NSMutableString stringWithFormat:@"%@://%@", url.scheme, url.host];
        if (url.port)
            [redirectUrlString appendFormat:@":%@", url.port];
        
        if ([url.pathComponents count] > 3)
        {
            for (NSString *component in url.pathComponents)
            {
                if ([component isEqualToString:@"api"] || [component isEqualToString:@"rest"])
                    break;
                
                if (![component isEqualToString:@"/"])
                {
                    [redirectUrlString appendFormat:@"/%@", component];
                }
            }
        }

        self.redirectUrlString = redirectUrlString;
        self.redirectUrl = url;
        
        // Notify the delegate
        if ([self.delegate respondsToSelector:@selector(loadingRedirected:redirectUrl:)])
        {
			[self.delegate loadingRedirected:self redirectUrl:url];
        }
        
        NSMutableURLRequest *r = [self.request mutableCopy]; // original request
		[r setTimeoutInterval:ISMSServerCheckTimeout];
        [r setURL:url];
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
    self.response = response;
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
    //DLog(@"loader type: %li response:\n%@", self.type, [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);
	[self processResponse];
	
	// Clean up the connection
	self.connection = nil;
	self.receivedData = nil;
}

@end
