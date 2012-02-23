//
//  JukeboxConnectionDelegate.m
//  iSub
//
//  Created by Ben Baron on 12/14/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "JukeboxConnectionDelegate.h"
#import "JukeboxXMLParser.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "BBSimpleConnectionQueue.h"
#import "CustomUIAlertView.h"
#import "PlaylistSingleton.h"
#import "NSNotificationCenter+MainThread.h"

@implementation JukeboxConnectionDelegate

@synthesize receivedData, isGetInfo;

- (id) init
{
	self = [super init];
	if (self != nil)
	{
		
		receivedData = [[NSMutableData data] retain];
		
		isGetInfo = NO;
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
	[receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
	[receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	[musicS.connectionQueue connectionFinished:theConnection];
	
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"There was an error controlling the Jukebox.\n\nError %i: %@", [error code], [error localizedDescription]] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	[alert release];
	
	[theConnection release];
	[receivedData release]; receivedData = nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{			
	[musicS.connectionQueue connectionFinished:theConnection];
	
	if (isGetInfo)
	{
		NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:receivedData];
		JukeboxXMLParser *parser = (JukeboxXMLParser*)[[JukeboxXMLParser alloc] initXMLParser];
		[xmlParser setDelegate:parser];
		[xmlParser parse];
				
		playlistS.currentIndex = parser.currentIndex;
		musicS.jukeboxGain = parser.gain;
		musicS.jukeboxIsPlaying = parser.isPlaying;
		
		[xmlParser release];
		[parser release];
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackStarted];
	}
	else
	{
		NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:receivedData];
		JukeboxXMLParser *parser = (JukeboxXMLParser*)[[JukeboxXMLParser alloc] initXMLParser];
		[xmlParser setDelegate:parser];
		[xmlParser parse];
		
		[xmlParser release];
		[parser release];
		
		[musicS jukeboxGetInfo];
	}
	
	[theConnection release];
	[receivedData release]; receivedData = nil;
}

- (void) dealloc
{
	[super dealloc];
	[receivedData release];
}

@end
