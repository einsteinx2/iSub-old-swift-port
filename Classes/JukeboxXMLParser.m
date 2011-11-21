//
//  JukeboxXMLParser.m
//  iSub
//
//  Created by bbaron on 11/5/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "JukeboxXMLParser.h"
#import "iSubAppDelegate.h"
#import "Song.h"
#import "ServerListViewController.h"
#import "ViewObjectsSingleton.h"
#import "DatabaseSingleton.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"

@implementation JukeboxXMLParser

@synthesize currentIndex, isPlaying, gain, listOfSongs;

- (id)initXMLParser 
{	
	if ((self = [super init]))
	{
		appDelegate = (iSubAppDelegate*)[UIApplication sharedApplication].delegate;
		listOfSongs = [[NSMutableArray alloc] init];
	}
	
	return self;
}


- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:appDelegate cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	alert.tag = 1;
	[alert show];
	[alert release];
	
	if ([errorCode isEqualToString:@"50"])
	{
		[SavedSettings sharedInstance].isJukeboxEnabled = NO;
		appDelegate.window.backgroundColor = [ViewObjectsSingleton sharedInstance].windowColor;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"JukeboxTurnedOff" object:nil];
	}
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Subsonic Error" message:@"There was an error parsing the Jukebox XML response." delegate:appDelegate cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	alert.tag = 1;
	[alert show];
	[alert release];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName 
	attributes:(NSDictionary *)attributeDict 
{
	if([elementName isEqualToString:@"error"])
	{
		[self subsonicErrorCode:[attributeDict objectForKey:@"code"] message:[attributeDict objectForKey:@"message"]];
	}
	else if ([elementName isEqualToString:@"jukeboxPlaylist"])
	{
		currentIndex = [[attributeDict objectForKey:@"currentIndex"] intValue];
		isPlaying = [[attributeDict objectForKey:@"playing"] boolValue];
		gain = [[attributeDict objectForKey:@"gain"] floatValue];
		
		[[DatabaseSingleton sharedInstance] resetJukeboxPlaylist];
	}
	else if ([elementName isEqualToString:@"entry"])
	{
		//Initialize the Song.
		Song *aSong = [[Song alloc] init];
		
		//Extract the attributes here.
		aSong.title = [attributeDict objectForKey:@"title"];
		aSong.songId = [attributeDict objectForKey:@"id"];
		aSong.artist = [attributeDict objectForKey:@"artist"];
		if([attributeDict objectForKey:@"album"])
			aSong.album = [attributeDict objectForKey:@"album"];
		if([attributeDict objectForKey:@"genre"])
			aSong.genre = [attributeDict objectForKey:@"genre"];
		if([attributeDict objectForKey:@"coverArt"])
			aSong.coverArtId = [attributeDict objectForKey:@"coverArt"];
		aSong.path = [attributeDict objectForKey:@"path"];
		aSong.suffix = [attributeDict objectForKey:@"suffix"];
		if ([attributeDict objectForKey:@"transcodedSuffix"])
			aSong.transcodedSuffix = [attributeDict objectForKey:@"transcodedSuffix"];
		NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
		if([attributeDict objectForKey:@"duration"])
			aSong.duration = [numberFormatter numberFromString:[attributeDict objectForKey:@"duration"]];
		if([attributeDict objectForKey:@"bitRate"])
			aSong.bitRate = [numberFormatter numberFromString:[attributeDict objectForKey:@"bitRate"]];
		if([attributeDict objectForKey:@"track"])
			aSong.track = [numberFormatter numberFromString:[attributeDict objectForKey:@"track"]];
		if([attributeDict objectForKey:@"year"])
			aSong.year = [numberFormatter numberFromString:[attributeDict objectForKey:@"year"]];
		if ([attributeDict objectForKey:@"size"])
			aSong.size = [numberFormatter numberFromString:[attributeDict objectForKey:@"size"]];
		
		//[listOfSongs addObject:aSong];
		[aSong addToPlaylistQueue];
		
		[aSong release];
		[numberFormatter release];
	}
}



- (void)dealloc
{
	[listOfSongs release];

	[super dealloc];
}

@end
