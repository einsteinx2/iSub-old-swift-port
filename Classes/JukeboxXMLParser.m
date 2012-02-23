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
#import "NSNotificationCenter+MainThread.h"

@implementation JukeboxXMLParser

@synthesize currentIndex, isPlaying, gain, listOfSongs;

- (id)initXMLParser 
{	
	if ((self = [super init]))
	{
		listOfSongs = [[NSMutableArray alloc] init];
	}
	
	return self;
}


- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:appDelegateS cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	alert.tag = 1;
	[alert show];
	[alert release];
	
	if ([errorCode isEqualToString:@"50"])
	{
		settingsS.isJukeboxEnabled = NO;
		appDelegateS.window.backgroundColor = viewObjectsS.windowColor;
		[NSNotificationCenter postNotificationToMainThreadWithName:@"JukeboxTurnedOff"];
	}
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Subsonic Error" message:@"There was an error parsing the Jukebox XML response." delegate:appDelegateS cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
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
		
		[databaseS resetJukeboxPlaylist];
	}
	else if ([elementName isEqualToString:@"entry"])
	{
		Song *aSong = [[Song alloc] initWithAttributeDict:attributeDict];
		if (aSong.path)
			[aSong addToCurrentPlaylist];
		[aSong release];
	}
}



- (void)dealloc
{
	[listOfSongs release];

	[super dealloc];
}

@end
