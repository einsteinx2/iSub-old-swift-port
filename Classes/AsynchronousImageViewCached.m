//
//  AsynchronousImageView.m
//  GLOSS
//
//  Created by Слава on 22.10.09.
//  Copyright 2009 Slava Bushtruk. All rights reserved.
//  ---------------------------------------------------
//
//  Modified by Ben Baron for the iSub project.
//

#import "AsynchronousImageViewCached.h"
#import "iSubAppDelegate.h"
#import "DatabaseSingleton.h"
#import "NSString+md5.h"
#import "FMDatabaseAdditions.h"
#import "NSMutableURLRequest+SUS.h"
#import "ViewObjectsSingleton.h"

@implementation AsynchronousImageViewCached

@synthesize coverArtId;

// TODO: rewrite this to get DB calls out of this class
- (void)loadImageFromCoverArtId:(NSString *)artId
{
	self.coverArtId = artId;
	
	
	NSString *size = nil;
	if (artId)
	{
		if ([databaseS.coverArtCacheDb60 intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [artId md5]] == 1)
		{
			// If the image is already in the cache dictionary, load it
			self.image = [UIImage imageWithData:[databaseS.coverArtCacheDb60 dataForQuery:@"SELECT data FROM coverArtCache WHERE id = ?", [artId md5]]];
		}
		else 
		{	
			if (viewObjectsS.isOfflineMode)
			{
				// Image not cached and we're offline so display the default image
				self.image = [UIImage imageNamed:@"default-album-art-small.png"];
			}
			else
			{
				// If not, grab it and cache it
				if (SCREEN_SCALE() == 2.0)
				{
					size = @"120";
				}
				else 
				{
					size = @"60";
				}
				
				NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:n2N(size), @"size", n2N(artId), @"id", nil];
				NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getCoverArt" andParameters:parameters];
				
				connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
				receivedData = [[NSMutableData data] retain];
			}
		}
	}
	else
	{
		self.image = [UIImage imageNamed:@"default-album-art-small.png"];
	}
}


- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
	{
		return YES; // Self-signed cert will be accepted
		// Note: it doesn't seem to matter what you return for a proper SSL cert, only self-signed certs
	}
	// If no other authentication is required, return NO for everything else
	// Otherwise maybe YES for NSURLAuthenticationMethodDefault and etc.
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
	DLog(@"Connection to album art failed");
	self.image = [UIImage imageNamed:@"default-album-art-small.png"];
	[receivedData release];
	[connection release];
}	


- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	// Check to see if the data is a valid image. If so, use it; if not, use the default image.
	if([UIImage imageWithData:receivedData])
	{
		[databaseS.coverArtCacheDb60 executeUpdate:@"INSERT OR REPLACE INTO coverArtCache (id, data) VALUES (?, ?)", [coverArtId md5], receivedData];

        self.image = [UIImage imageWithData:receivedData];
	}
	else 
	{
		self.image = [UIImage imageNamed:@"default-album-art-small.png"];
	}
	
	[coverArtId release];
	[receivedData release];
	[connection release];
}


- (void)dealloc {
    [super dealloc];
}


@end
