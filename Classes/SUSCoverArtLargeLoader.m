//
//  SUSCoverArtLargeLoader.m
//  iSub
//
//  Created by Benjamin Baron on 11/22/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSCoverArtLargeLoader.h"
#import "DatabaseSingleton.h"
#import "NSString+md5.h"
#import "FMDatabaseAdditions.h"
#import "NSNotificationCenter+MainThread.h"

@implementation SUSCoverArtLargeLoader
@synthesize coverArtId;

#pragma mark - Lifecycle

- (void)setup
{
	[super setup];
}

- (void)dealloc
{
	[super dealloc];
}

- (FMDatabase *)db
{
    if (IS_IPAD())
        return [DatabaseSingleton sharedInstance].coverArtCacheDb540;
    else
        return [DatabaseSingleton sharedInstance].coverArtCacheDb320;
}

- (SUSLoaderType)type
{
    return SUSLoaderType_ServerPlaylist;
}

#pragma mark - Loader Methods

- (void)startLoad
{
    [self loadCoverArtId:self.coverArtId];
}

- (void)loadCoverArtId:(NSString *)artId
{
	self.coverArtId = artId;
	
	NSString *size = nil;
	if (IS_IPAD())
        size = @"540";
	else
		if (SCREEN_SCALE() == 2.0)
            size = @"640";
		else
            size = @"320";
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:n2N(size), @"size", n2N(artId), @"id", nil];
	DLog(@"parameters: %@", parameters);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getCoverArt" andParameters:parameters];
	
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	self.receivedData = [NSMutableData data];
}

#pragma mark - Connection delegate

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
    DLog(@"art loading failed for: %@", coverArtId);
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_AlbumArtLargeFailed];
	
    self.receivedData = nil;
	self.connection = nil;
	
	// Inform the delegate that loading failed
	[self informDelegateLoadingFailed:error];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	// Check to see if the data is a valid image. If so, use it; if not, use the default image.
	if([UIImage imageWithData:self.receivedData])
	{
        DLog(@"art loading completed for: %@", coverArtId);
        [self.db synchronizedExecuteUpdate:@"INSERT OR REPLACE INTO coverArtCache (id, data) VALUES (?, ?)", [coverArtId md5], self.receivedData];
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_AlbumArtLargeDownloaded];
        
		// Notify the delegate that the loading is finished
		[self informDelegateLoadingFinished];
	}
    else
    {
        DLog(@"art loading failed for: %@", coverArtId);
        [self connection:theConnection didFailWithError:nil];
    }
	
	self.receivedData = nil;
	self.connection = nil;
}

@end
