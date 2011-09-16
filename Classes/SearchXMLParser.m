//
//  SearchXMLParser.m
//  iSub
//
//  Created by bbaron on 10/21/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SearchXMLParser.h"
#import "iSubAppDelegate.h"
#import "Song.h"
#import "Album.h"
#import "Artist.h"
#import "CustomUIAlertView.h"

@implementation SearchXMLParser

@synthesize listOfArtists, listOfAlbums, listOfSongs;

- (id) initXMLParser 
{	
	if ((self = [super init]))
	{
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		listOfArtists = [[NSMutableArray alloc] init];
		listOfAlbums = [[NSMutableArray alloc] init];
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
}


- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subsonic Error" message:@"There was an error parsing the XML response. Subsonic may have had an error performing the search." delegate:appDelegate cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	alert.tag = 1;
	[alert show];
	[alert release];
}


- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName 
	attributes:(NSDictionary *)attributeDict 
{
	if ([elementName isEqualToString:@"match"] || [elementName isEqualToString:@"song"])
	{
		if (![[attributeDict objectForKey:@"isVideo"] isEqualToString:@"true"])
		{
			Song *aSong = [[Song alloc] initWithAttributeDict:attributeDict];
		
			if (aSong.path)
			{
				[listOfSongs addObject:aSong];
			}
		
			[aSong release];
		}
	}
	else if ([elementName isEqualToString:@"album"])
	{
		Album *anAlbum = [[Album alloc] initWithAttributeDict:attributeDict];
		
		[listOfAlbums addObject:anAlbum];
		
		[anAlbum release];
	}
	else if ([elementName isEqualToString:@"artist"])
	{
		Artist *anArtist = [[Artist alloc] initWithAttributeDict:attributeDict];
		
		[listOfArtists addObject:anArtist];
		
		[anArtist release];
	}
}


- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string 
{ 

}


- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName 
{
	
	
}


- (void) dealloc 
{
	[super dealloc];
	[listOfArtists release];
	[listOfAlbums release];
	[listOfSongs release];
}

@end
