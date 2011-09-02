//
//  NSURLConnectionDelegateQueueArtwork.m
//  iSub
//
//  Created by bbaron on 11/12/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "NSURLConnectionDelegateQueueArtwork.h"
#import "DatabaseSingleton.h"
#import "MusicSingleton.h"
#import "Song.h"
#import "NSString-md5.h"
#import "FMDatabase.h"

@implementation NSURLConnectionDelegateQueueArtwork

@synthesize receivedData, is320;

- (id) init
{
	self = [super init];
	if (self != nil)
	{
		databaseControls = [DatabaseSingleton sharedInstance];
		musicControls = [MusicSingleton sharedInstance];
		is320 = YES;
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

}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    // Append the data chunk to the file and update the downloaded length
	
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	DLog(@"didFailWithError, resuming download");
	
	[theConnection release];
	[receivedData release];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	//DLog(@"connectionDidFinishLoading");
	
	if([UIImage imageWithData:receivedData])
	{
		//DLog(@"image is good so caching it");
		if (is320)
			[databaseControls.coverArtCacheDb320 executeUpdate:@"INSERT INTO coverArtCache (id, data) VALUES (?, ?)", [NSString md5:musicControls.queueSongObject.coverArtId], receivedData];
		else
			[databaseControls.coverArtCacheDb60 executeUpdate:@"INSERT INTO coverArtCache (id, data) VALUES (?, ?)", [NSString md5:musicControls.queueSongObject.coverArtId], receivedData];
	}
	
	[theConnection release];
	[receivedData release];
}

@end