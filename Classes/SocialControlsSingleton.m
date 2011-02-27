//
//  SocialControlsSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SocialControlsSingleton.h"
#import "SA_OAuthTwitterEngine.h"
#import "SA_OAuthTwitterController.h"

// Twitter secret keys
#define kOAuthConsumerKey				@"nYKAEcLstFYnI9EEnv6g"
#define kOAuthConsumerSecret			@"wXSWVvY7GN1e8Z2KFaR9A5skZKtHzpchvMS7Elpu0"

static SocialControlsSingleton *sharedInstance = nil;

@implementation SocialControlsSingleton

// Twitter
@synthesize twitterEngine;

#pragma mark -
#pragma mark Class instance methods

#pragma mark -
#pragma mark Twitter
#pragma mark -

- (void) createTwitterEngine
{
	if (twitterEngine)
		return;
	
	self.twitterEngine = [[SA_OAuthTwitterEngine alloc] initOAuthWithDelegate: self];
	self.twitterEngine.consumerKey = kOAuthConsumerKey;
	self.twitterEngine.consumerSecret = kOAuthConsumerSecret;
}

//=============================================================================================================================
// SA_OAuthTwitterEngineDelegate
- (void) storeCachedTwitterOAuthData:(NSString *)data forUsername:(NSString *)username 
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	[defaults setObject:data forKey:@"twitterAuthData"];
	[defaults synchronize];
}

- (NSString *) cachedTwitterOAuthDataForUsername:(NSString *)username 
{
	return [[NSUserDefaults standardUserDefaults] objectForKey:@"twitterAuthData"];
}

//=============================================================================================================================
// SA_OAuthTwitterControllerDelegate
- (void) OAuthTwitterController:(SA_OAuthTwitterController *)controller authenticatedWithUsername:(NSString *)username 
{
	//NSLog(@"Authenicated for %@", username);
	[[NSNotificationCenter defaultCenter] postNotificationName:@"twitterAuthenticated" object:nil];
}

- (void) OAuthTwitterControllerFailed:(SA_OAuthTwitterController *)controller 
{
	//NSLog(@"Authentication Failed!");
	self.twitterEngine = nil;
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Twitter Error" message:@"Failed to authenticate user. Try logging in again." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
	[alert release];
}

- (void) OAuthTwitterControllerCanceled:(SA_OAuthTwitterController *)controller 
{
	//NSLog(@"Authentication Canceled.");
	self.twitterEngine = nil;
}

//=============================================================================================================================
// TwitterEngineDelegate
- (void) requestSucceeded:(NSString *)requestIdentifier 
{
	//NSLog(@"Request %@ succeeded", requestIdentifier);
}

- (void) requestFailed:(NSString *)requestIdentifier withError:(NSError *) error 
{
	//NSLog(@"Request %@ failed with error: %@", requestIdentifier, error);
}

#pragma mark -
#pragma mark Singleton methods

+ (SocialControlsSingleton*)sharedInstance
{
    @synchronized(self)
    {
        if (sharedInstance == nil)
			[[self alloc] init];
    }
    return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (sharedInstance == nil) {
            sharedInstance = [super allocWithZone:zone];
            return sharedInstance;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

-(id)init 
{
	self = [super init];
	sharedInstance = self;
	
	//initialize here
	self.twitterEngine = nil;
	
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain {
    return self;
}

- (unsigned)retainCount {
    return UINT_MAX;  // denotes an object that cannot be released
}

- (void)release {
    //do nothing
}

- (id)autorelease {
    return self;
}

@end
