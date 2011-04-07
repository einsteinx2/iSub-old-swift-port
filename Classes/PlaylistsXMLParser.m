//
//  PlaylistsXMLParser.m
//  XML
//
//  Created by iPhone SDK Articles on 11/23/08.
//  Copyright 2008 www.iPhoneSDKArticles.com.
//  -------------------------------------------
//
//  Modified /heavily/ by Ben Baron for the iSub project.
//

#import "PlaylistsXMLParser.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "Song.h"
#import "ServerListViewController.h"
#import "NSString-md5.h"
#import "CustomUIAlertView.h"

@implementation PlaylistsXMLParser


- (PlaylistsXMLParser *) initXMLParser 
{	
	if ((self = [super init]))
	{
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		viewObjects = [ViewObjectsSingleton sharedInstance];
		databaseControls = [DatabaseControlsSingleton sharedInstance];
		isPlaylist = YES;
		md5 = nil;
	}
	
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
}


- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:appDelegate cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	[alert show];
	[alert release];
}


- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName 
	attributes:(NSDictionary *)attributeDict {
	
	if([elementName isEqualToString:@"error"])
	{
		[self subsonicErrorCode:[attributeDict objectForKey:@"code"] message:[attributeDict objectForKey:@"message"]];
	}
	else if([elementName isEqualToString:@"playlists"]) 
	{
		//NSLog(@"hit playlists xml tag");
		viewObjects.listOfPlaylists = [NSMutableArray arrayWithCapacity:1];
		//viewObjects.listOfPlaylists = nil; viewObjects.listOfPlaylists = [[NSMutableArray alloc] init];
		isPlaylist = NO;
	}
	else if([elementName isEqualToString:@"playlist"]) 
	{
		//if([attributeDict objectForKey:@"id"])
		if (isPlaylist == NO)
		{
			//If it has an id field then it's a playlist, so add it to the list of playlists ///////// THIS IS NO LONGER VALID AS OF 4.1 BETA
			[viewObjects.listOfPlaylists addObject:[NSArray arrayWithObjects:[attributeDict objectForKey:@"id"], [attributeDict objectForKey:@"name"], nil]];
		}
		else 
		{
			//If there's no id field it means this is a list of the playlist songs so initialize the array and dictionary ///////// THIS IS NO LONGER VALID AS OF 4.1 BETA
			//viewObjects.listOfPlaylistSongs = [NSMutableArray arrayWithCapacity:1];
			//viewObjects.listOfPlaylistSongs = nil; viewObjects.listOfPlaylistSongs = [[NSMutableArray alloc] init];
			
			md5 = [[NSString md5:[viewObjects.subsonicPlaylist objectAtIndex:0]] retain];
			[databaseControls removeServerPlaylistTable:md5];
			[databaseControls createServerPlaylistTable:md5];
		}

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
		
		//Add song object to the list of songs
		//[viewObjects.listOfPlaylistSongs addObject:aSong];
		[databaseControls insertSongIntoServerPlaylist:aSong playlistId:md5];
		
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
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName 
{
	if([elementName isEqualToString:@"playlist"])
	{
		if(viewObjects.subsonicPlaylist)
		{
			/* After finished processing a playlist, add the list and dict to the album list cache
			if([appDelegate.albumListCache objectForKey:[appDelegate.subsonicPlaylist objectAtIndex:0]] == nil)
				[appDelegate.albumListCache setObject:[NSKeyedArchiver archivedDataWithRootObject:[NSArray arrayWithObjects:appDelegate.listOfPlaylistSongs, appDelegate.dictOfPlaylistSongs, nil]] forKey:[appDelegate.subsonicPlaylist objectAtIndex:0]];*/
			
			// After finished processing an album folder, add the lists and dicts to the album list cache
			//[appDelegate.albumListCacheDb executeUpdate:@"INSERT INTO albumListCache (id, data) VALUES (?, ?)", [NSString md5:appDelegate.subsonicPlaylist.albumId], [NSKeyedArchiver archivedDataWithRootObject:[NSArray arrayWithObjects:appDelegate.listOfPlaylistSongs, appDelegate.dictOfPlaylistSongs, nil]]];
			//if ([appDelegate.albumListCacheDb hadError]) {
			//	NSLog(@"Err %d: %@", [appDelegate.albumListCacheDb lastErrorCode], [appDelegate.albumListCacheDb lastErrorMessage]);
			//}
		}
	}
}


- (void) dealloc 
{
	[md5 release];
	[currentElementValue release];
	[super dealloc];
}

@end
