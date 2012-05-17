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
#import "JukeboxSingleton.h"

@implementation JukeboxConnectionDelegate

@synthesize receivedData, isGetInfo;

- (id) init
{
	self = [super init];
	if (self != nil)
	{
		receivedData = [[NSMutableData alloc] init];
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
	[self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
	[self.receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	[jukeboxS.connectionQueue connectionFinished:theConnection];
	
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"There was an error controlling the Jukebox.\n\nError %i: %@", [error code], [error localizedDescription]] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	
	self.receivedData = nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{			
	[jukeboxS.connectionQueue connectionFinished:theConnection];
	
	if (self.isGetInfo)
	{
		DLog(@"%@", [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding]);
		NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:receivedData];
		JukeboxXMLParser *parser = (JukeboxXMLParser*)[[JukeboxXMLParser alloc] initXMLParser];
		[xmlParser setDelegate:parser];
		[xmlParser parse];
				
		playlistS.currentIndex = parser.currentIndex;
		jukeboxS.jukeboxGain = parser.gain;
		jukeboxS.jukeboxIsPlaying = parser.isPlaying;
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackStarted];
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_JukeboxSongInfo];
	}
	else
	{
		NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:self.receivedData];
		JukeboxXMLParser *parser = (JukeboxXMLParser*)[[JukeboxXMLParser alloc] initXMLParser];
		[xmlParser setDelegate:parser];
		[xmlParser parse];
		
		[jukeboxS jukeboxGetInfo];
	}
	
	self.receivedData = nil;
}


@end
