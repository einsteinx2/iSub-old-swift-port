//
//  QueueAlbumXMLParser.m
//  XML
//
//  Created by iPhone SDK Articles on 11/23/08.
//  Copyright 2008 www.iPhoneSDKArticles.com.
//  -------------------------------------------
//
//  Modified /heavily/ by Ben Baron for the iSub project.
//

#import "QueueAlbumXMLParser.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "ServerListViewController.h"
#import "Artist.h"
#import "Album.h"
#import "Song.h"
#import "CustomUIAlertView.h"

@implementation QueueAlbumXMLParser

@synthesize myArtist, listOfAlbums, listOfSongs;

- (id) initXMLParser 
{	
	if ((self = [super init]))
	{
        // your code here
		
		listOfAlbums = [[NSMutableArray alloc] init];
		listOfSongs = [[NSMutableArray alloc] init];
    }
	
    return self;
}

- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	alert.tag = 1;
	[alert show];
	[alert release];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Subsonic Error" message:@"There was an error parsing the XML response. Maybe you forgot to set the right port for your server?" delegate:appDelegateS cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
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
	else if([elementName isEqualToString:@"child"]) 
	{
		if ([[attributeDict objectForKey:@"isDir"] isEqualToString:@"true"])
		{
			Album *anAlbum = [[Album alloc] init];
			
			//Extract the attributes here.
			anAlbum.title = [attributeDict objectForKey:@"title"];
			anAlbum.albumId = [attributeDict objectForKey:@"id"];
			if([attributeDict objectForKey:@"coverArt"])
				anAlbum.coverArtId = [attributeDict objectForKey:@"coverArt"];
			anAlbum.artistName = myArtist.name;
			anAlbum.artistId = myArtist.artistId;
			
			//Add album object to lookup dictionary and list array
			if (![anAlbum.title isEqualToString:@".AppleDouble"])
			{
				[self.listOfAlbums addObject:anAlbum];
			}
			
			//DLog(@"%@", anAlbum.title);
			//DLog(@"%@", anAlbum.albumId);
			//DLog(@"%@", anAlbum.coverArtId);
			//DLog(@"%@", anAlbum.artistName);
			//DLog(@"%@", anAlbum.artistId);
			//DLog(@"  ");
			
			[anAlbum release];
		}
		else
		{
			BOOL isVideo = [[attributeDict objectForKey:@"isVideo"] boolValue];
			if (!isVideo)
			{
				Song *aSong = [[Song alloc] initWithAttributeDict:attributeDict];
				if (aSong.path)
					[self.listOfSongs addObject:aSong];
				[aSong release];
			}
		}
	}	
}


- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string { 
	
	if(!currentElementValue) 
		currentElementValue = [[NSMutableString alloc] initWithString:string];
	else
		[currentElementValue appendString:string];
}


- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName 
{
	// Do nothing for now
}


- (void) dealloc 
{
	[myArtist release];
	[currentElementValue release];
	[listOfAlbums release];
	[listOfSongs release];
	[super dealloc];
}

@end
