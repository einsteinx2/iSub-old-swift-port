//
//  SUSCoverArtLoader.m
//  iSub
//
//  Created by Ben Baron on 11/1/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSPlayerCoverArtLoader.h"
#import "DatabaseSingleton.h"
#import "ViewObjectsSingleton.h"
#import "NSString+md5.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

@implementation SUSPlayerCoverArtLoader

@synthesize coverArtId;

#pragma mark - Lifecycle

- (void)setup
{
    [super setup];
	databaseControls = [DatabaseSingleton sharedInstance];
	viewObjects = [ViewObjectsSingleton sharedInstance];
}

- (void)dealloc
{
	[super dealloc];
}

- (SUSLoaderType)type
{
    return SUSLoaderType_PlayerCoverArt;
}

#pragma mark - Private DB Methods

#pragma mark - Properties

- (FMDatabase *)db
{
    if (IS_IPAD())
        return [databaseControls coverArtCacheDb540];
    else
        return [databaseControls coverArtCacheDb320];
}

- (BOOL)isCoverArtCached
{
    return [self.db intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [coverArtId md5]] >= 0;
}

#pragma mark - Data loading

- (void)startLoad
{
	// Cache the album art if it exists
	if (coverArtId && !viewObjects.isOfflineMode)
	{
		NSString *size = nil;

        if (IS_IPAD())
        {
            size = @"540";
        }
        else
        {
            if (SCREEN_SCALE() == 2.0)
            {
                size = @"640";
            }
            else
            {	
                size = @"320";
            }
        }
		
		NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:n2N(size), @"size", n2N(coverArtId), @"id", nil];
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getCoverArt" andParameters:parameters];
		
		self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
		if (self.connection)
		{
			self.receivedData = [NSMutableData data];
		} 
		else 
		{
			// Inform the delegate that the loading failed.
			NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
			[self.delegate loadingFailed:self withError:error];
		}
	}
}

// TODO Add cancel load
- (void)cancelLoad
{
    [super cancelLoad];
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
	[self.delegate loadingFailed:self withError:error];
	
	self.receivedData = nil;
	self.connection = nil;
	
	// Inform the delegate that loading failed
	[self.delegate loadingFailed:self withError:error];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	    
    if([UIImage imageWithData:self.receivedData])
	{
		[self.db executeUpdate:@"INSERT INTO coverArtCache (id, data) VALUES (?, ?)", [coverArtId md5], self.receivedData];
	}
	
	self.receivedData = nil;
	self.connection = nil;
	
	// Notify the delegate that the loading is finished
	[self.delegate loadingFinished:self];
}

@end
