//
//  HomeXMLParser.m
//  XML
//
//  Created by iPhone SDK Articles on 11/23/08.
//  Copyright 2008 www.iPhoneSDKArticles.com.
//  -------------------------------------------
//
//  Modified /heavily/ by Ben Baron for the iSub project.
//

#import "HomeXMLParser.h"
#import "iSubAppDelegate.h"
#import "DatabaseControlsSingleton.h"
#import "ServerListViewController.h"
#import "Index.h"
#import "Album.h"
#import "Song.h"
#import "NSString+md5.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "ViewObjectsSingleton.h"
#import "NSString+hex.h"
#import "CustomUIAlertView.h"

@implementation HomeXMLParser

@synthesize myId;
@synthesize listOfAlbums;
 
- (HomeXMLParser *) initXMLParser 
{	
	[super init];	
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	databaseControls = [DatabaseControlsSingleton sharedInstance];
	
	listOfAlbums = [[NSMutableArray alloc] init];

	return self;
}

- (void)alertView:(CustomUIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if(buttonIndex == 1)
	{
		ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
		
		if (appDelegate.currentTabBarController.selectedIndex == 4)
		{
			[appDelegate.currentTabBarController.moreNavigationController pushViewController:serverListViewController animated:YES];
		}
		else
		{
			[(UINavigationController*)appDelegate.currentTabBarController.selectedViewController pushViewController:serverListViewController animated:YES];
		}
		
		[serverListViewController release];
	}	
	[self release];
}

- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:appDelegate cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	[alert show];
	[alert release];
}


- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Subsonic Error" message:@"There was an error parsing the XML response. Maybe you forgot to set the right port for your server?" delegate:appDelegate cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	[alert show];
	[alert release];
}


- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName 
	attributes:(NSDictionary *)attributeDict {

	if( [elementName isEqualToString:@"error"] )
	{
		[self subsonicErrorCode:[attributeDict objectForKey:@"code"] message:[attributeDict objectForKey:@"message"]];
	}
	else if( [elementName isEqualToString:@"album"] ) 
	{
		if ( [[attributeDict objectForKey:@"isDir"] isEqualToString:@"true"] )
		{
			Album *anAlbum = [[Album alloc] init];
			
			//Extract the attributes here.
			anAlbum.title = [attributeDict objectForKey:@"title"];
			anAlbum.albumId = [attributeDict objectForKey:@"id"];
			if([attributeDict objectForKey:@"coverArt"])
				anAlbum.coverArtId = [attributeDict objectForKey:@"coverArt"];

			// Synthesize the artist name and artist id from the album id
			NSString *path = [NSString stringFromHex:anAlbum.albumId];
			NSArray *splitPath;
			if ([path rangeOfString:@"/"].location == NSNotFound)
			{
				// No forward slashes found so split by backslash
				splitPath = [path componentsSeparatedByString:@"\\"];
			}
			else
			{
				splitPath = [path componentsSeparatedByString:@"/"];
			}
			
			//NSLog(@"splitPath: %@", splitPath);
			//NSLog(@"[splitPath objectAtIndex:[splitPath count] - 2]: %@", [splitPath objectAtIndex:[splitPath count] - 2]);
			if ([splitPath count] > 0 && [splitPath count] < 2)
			{
				anAlbum.artistName = [splitPath objectAtIndex:0];
			}
			else if ([splitPath count] >= 2)
			{
				anAlbum.artistName = [splitPath objectAtIndex:[splitPath count] - 2];
			}
			else
			{
				anAlbum.artistName = @"";
			}
			
			NSUInteger idLength = [anAlbum.albumId length];
			NSString *albumName = [splitPath objectAtIndex:[splitPath count] - 1];
			NSString *albumNameHex = [NSString stringToHex:albumName];
			NSUInteger albumNameHexLength = [albumNameHex length];
			NSUInteger index = idLength - albumNameHexLength;
			anAlbum.artistId = [anAlbum.albumId substringToIndex:index];			
			
			//Add album object to lookup dictionary and list array
			if ( ![anAlbum.title isEqualToString:@".AppleDouble"] )
			{
				[listOfAlbums addObject:anAlbum];
			}
						
			[anAlbum release];
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
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
	
	
}


- (void) dealloc 
{
	[myId release];
	[listOfAlbums release];
	[currentElementValue release];

	[super dealloc];
}

@end
