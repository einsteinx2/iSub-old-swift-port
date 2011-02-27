//
//  PlayingXMLParser.m
//  XML
//
//  Created by iPhone SDK Articles on 11/23/08.
//  Copyright 2008 www.iPhoneSDKArticles.com.
//  -------------------------------------------
//
//  Modified /heavily/ by Ben Baron for the iSub project.
//

#import "PlayingXMLParser.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "Song.h"
#import "ServerListViewController.h"

@implementation PlayingXMLParser


- (PlayingXMLParser *) initXMLParser 
{	
	[super init];	
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	return self;
}


- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:message delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	[alert show];
	[alert release];
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
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
}


- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName 
	attributes:(NSDictionary *)attributeDict {
	
	if([elementName isEqualToString:@"error"])
	{
		[self subsonicErrorCode:[attributeDict objectForKey:@"code"] message:[attributeDict objectForKey:@"message"]];
	}
	else if([elementName isEqualToString:@"entry"]) 
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
		NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
		if([attributeDict objectForKey:@"duration"])
			aSong.duration = [numberFormatter numberFromString:[attributeDict objectForKey:@"duration"]];
		if([attributeDict objectForKey:@"bitRate"])
			aSong.bitRate = [numberFormatter numberFromString:[attributeDict objectForKey:@"bitRate"]];
		if([attributeDict objectForKey:@"track"])
			aSong.track = [numberFormatter numberFromString:[attributeDict objectForKey:@"track"]];
		if([attributeDict objectForKey:@"year"])
			aSong.year = [numberFormatter numberFromString:[attributeDict objectForKey:@"year"]];
		aSong.size = [numberFormatter numberFromString:[attributeDict objectForKey:@"size"]];
		
		if([attributeDict objectForKey:@"playerName"])
			[viewObjects.listOfPlayingSongs addObject:[NSArray arrayWithObjects:aSong, [attributeDict objectForKey:@"username"], [attributeDict objectForKey:@"playerName"], [numberFormatter numberFromString:[attributeDict objectForKey:@"minutesAgo"]], nil]];
		else
			[viewObjects.listOfPlayingSongs addObject:[NSArray arrayWithObjects:aSong, [attributeDict objectForKey:@"username"], @"", [numberFormatter numberFromString:[attributeDict objectForKey:@"minutesAgo"]], nil]];
		
		[aSong release];
		[numberFormatter release];
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
	[currentElementValue release];
	[super dealloc];
}

@end
