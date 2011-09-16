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
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		viewObjects = [ViewObjectsSingleton sharedInstance];
		
		listOfAlbums = [[NSMutableArray alloc] init];
		listOfSongs = [[NSMutableArray alloc] init];
    }
	
    return self;
}


- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	alert.tag = 1;
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
	[alert release];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Subsonic Error" message:@"There was an error parsing the XML response. Maybe you forgot to set the right port for your server?" delegate:appDelegate cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
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
			if([attributeDict objectForKey:@"size"])
				aSong.size = [numberFormatter numberFromString:[attributeDict objectForKey:@"size"]];
			
			//Add song object to lookup dictionary
			if (aSong.path)
			{
				[self.listOfSongs addObject:aSong];
				//DLog(@"listOfSongs count: %i", [self.listOfSongs count]);
			}
			
			[aSong release];
			[numberFormatter release];
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
