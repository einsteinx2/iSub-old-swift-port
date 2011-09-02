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
#import "NSString-md5.h"
#import "FMDatabase.h"

@implementation AsynchronousImageViewCached

- (void)loadImageFromURLString:(NSString *)theUrlString coverArtId:(NSString *)artId
{
	coverArtId = [artId retain];
	[self.image release], self.image = nil;
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:theUrlString] cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:kLoadingTimeout];
	
	connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	data = [[NSMutableData data] retain];
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
	[data setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [data appendData:incrementalData];
}


- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	DLog(@"Connection to album art failed");
	self.image = [UIImage imageNamed:@"default-album-art-small.png"];
	[data release];
	[connection release];
}	


- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{
	DatabaseSingleton *databaseControls = [DatabaseSingleton sharedInstance];
	
	// Check to see if the data is a valid image. If so, use it; if not, use the default image.
	if([UIImage imageWithData:data])
	{
		[databaseControls.coverArtCacheDb60 executeUpdate:@"INSERT OR REPLACE INTO coverArtCache (id, data) VALUES (?, ?)", [NSString md5:coverArtId], data];

		if (SCREEN_SCALE() == 2.0)
		{
			//UIGraphicsBeginImageContextWithOptions(CGSizeMake(60.0,60.0), NO, 2.0);
			//[[UIImage imageWithData:data] drawInRect:CGRectMake(0,0,60,60)];
			//self.image = UIGraphicsGetImageFromCurrentImageContext();
			//UIGraphicsEndImageContext();
			self.image = [UIImage imageWithData:data];
		}
		else
		{
			self.image = [UIImage imageWithData:data];
		}
	}
	else 
	{
		self.image = [UIImage imageNamed:@"default-album-art-small.png"];
	}
	
	[coverArtId release];
	[data release];
	[connection release];
}


- (void)dealloc {
    [super dealloc];
}


@end
