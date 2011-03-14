//
//  XMLParser.m
//  XML
//
//  Created by iPhone SDK Articles on 11/23/08.
//  Copyright 2008 www.iPhoneSDKArticles.com.
//  -------------------------------------------
//
//  Modified /heavily/ by Ben Baron for the iSub project.
//

#import "XMLParser.h"
#import "iSubAppDelegate.h"
#import "DatabaseControlsSingleton.h"
#import "ServerListViewController.h"
#import "Index.h"
#import "Artist.h"
#import "Album.h"
#import "Song.h"
#import "NSString-md5.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "ViewObjectsSingleton.h"
#import "LoadingScreen.h"
#import "CustomUIAlertView.h"

@implementation XMLParser

@synthesize parseState, myId, myArtist;
@synthesize indexes, listOfArtists, listOfAlbums, listOfSongs;
 
- (id) initXMLParser 
{	
	if (self = [super init])
	{	
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		viewObjects = [ViewObjectsSingleton sharedInstance];
		databaseControls = [DatabaseControlsSingleton sharedInstance];
		
		indexes = [[NSMutableArray alloc] init];
		listOfArtists = [[NSMutableArray alloc] init];
		shortcuts = [[NSMutableArray alloc] init];
		
		listOfAlbums = [[NSMutableArray alloc] init];
		listOfSongs = [[NSMutableArray alloc] init];
		
		loadedSongMD5s = [[NSMutableArray alloc] init];
	}

	return self;
}

- (void) updateMessage
{
	[viewObjects.allAlbumsLoadingScreen setMessage1Text:viewObjects.allAlbumsCurrentArtistName];
	[viewObjects.allAlbumsLoadingScreen setMessage2Text:[NSString stringWithFormat:@"%i", viewObjects.allAlbumsLoadingProgress]];
}


- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	if ([parseState isEqualToString: @"allAlbums"])
	{
		NSLog(@"Subsonic error: %@", message);
	}
	else
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:appDelegate cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
		[alert show];
		[alert release];
	}
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	if ([parseState isEqualToString: @"allAlbums"])
	{
		NSLog(@"%@", [NSString stringWithFormat:@"An error occured reading the response from Subsonic.\n\nIf you are loading the artist list, this can mean the server URL is wrong\n\nError: %@", parseError.localizedDescription]);
	}
	else
	{
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Subsonic Error" message:[NSString stringWithFormat:@"An error occured reading the response from Subsonic.\n\nIf you are loading the artist list, this can mean the server URL is wrong\n\nError: %@", parseError.localizedDescription] delegate:appDelegate cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
		[alert show];
		[alert release];
	}
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName 
	attributes:(NSDictionary *)attributeDict 
{
	if( [parseState isEqualToString:@"artists"] )
	{
		if([elementName isEqualToString:@"error"])
		{
			// If there's an error, display an alert showing the error
			[self subsonicErrorCode:[attributeDict objectForKey:@"code"] message:[attributeDict objectForKey:@"message"]];
		}
		else if([elementName isEqualToString:@"indexes"]) 
		{
			// Initialize the arrays and lookup dictionaries.
			isFirstIndex = YES;
			//NSLog(@"hit indexes tag");
		}
		else if ([elementName isEqualToString:@"shortcut"])
		{
			// If this is the first shortcut, add the shortcut index
			if ([shortcuts count] == 0)
				[indexes addObject:@"★"];
			
			Artist *anArtist = [[Artist alloc] initWithAttributeDict:attributeDict];
				
			// Add the shortcut object (actualy an artist object)
			[shortcuts addObject:anArtist];
			
			[anArtist release];
		}
		else if([elementName isEqualToString:@"index"]) 
		{
			// If this is the first index, add the shortcuts array to listOfArtists
			if (isFirstIndex && [shortcuts count] > 0)
			{
				[listOfArtists addObject:shortcuts];
				isFirstIndex = NO;
			}
			else
			{
				isFirstIndex = NO;
			}
			
			//Initialize the Index.
			anIndex = [[Index alloc] init];
		
			//Initialize the Artist array for this section
			artistsArray = [[NSMutableArray alloc] init];
		
			//Extract the attribute here.
			anIndex.name = [attributeDict objectForKey:@"name"];
			//NSLog(@"index: %@", anIndex.name);
		}
		else if([elementName isEqualToString:@"artist"]) 
		{
			Artist *anArtist = [[Artist alloc] initWithAttributeDict:attributeDict];
			
			//Add artist object to lookup dictionary and artist section array
			if (![anArtist.name isEqualToString:@".AppleDouble"])
			{
				[artistsArray addObject:anArtist];
			}
			
			//NSLog(@"artist: %@", anArtist.name);
			
			[anArtist release];
		}
	}
	else if ( [parseState isEqualToString: @"allAlbums"] )
	{
		if([elementName isEqualToString:@"error"])
		{
			[self subsonicErrorCode:[attributeDict objectForKey:@"code"] message:[attributeDict objectForKey:@"message"]];
		}
		else if([elementName isEqualToString:@"directory"]) 
		{
			// Set the artist name and id
			viewObjects.allAlbumsCurrentArtistName = nil; viewObjects.allAlbumsCurrentArtistName = [attributeDict objectForKey:@"name"];
			viewObjects.allAlbumsCurrentArtistId = nil; viewObjects.allAlbumsCurrentArtistId = [attributeDict objectForKey:@"id"];
		}
		else if([elementName isEqualToString:@"child"]) 
		{
			if ([[attributeDict objectForKey:@"isDir"] isEqualToString:@"true"])
			{				
				Album *anAlbum = [[Album alloc] initWithAttributeDict:attributeDict artist:[Artist artistWithName:viewObjects.allAlbumsCurrentArtistName andArtistId:viewObjects.allAlbumsCurrentArtistId]];
				
				//Add album object to the database
				if (![anAlbum.title isEqualToString:@".AppleDouble"])
				{
					[databaseControls insertAlbum:anAlbum intoTable:@"allAlbumsTemp" inDatabase:databaseControls.allAlbumsDb];
				}
				
				// Update the loading screen message
				viewObjects.allAlbumsLoadingProgress++;
				[self performSelectorOnMainThread:@selector(updateMessage) withObject:nil waitUntilDone:NO];
				
				[anAlbum release];
			}
		}		
	}		
	else if( [parseState isEqualToString: @"albums"] )
	{
		//NSLog(@"elementName: %@", elementName);
		if( [elementName isEqualToString:@"error"] )
		{
			[self subsonicErrorCode:[attributeDict objectForKey:@"code"] message:[attributeDict objectForKey:@"message"]];
		}
		else if( [elementName isEqualToString:@"directory"] ) 
		{
			//Initialize the arrays.
			[databaseControls.albumListCacheDb beginTransaction];
			[databaseControls.albumListCacheDb executeUpdate:@"DELETE FROM albumsCache WHERE folderId = ?", [NSString md5:myId]];
			[databaseControls.albumListCacheDb executeUpdate:@"DELETE FROM songsCache WHERE folderId = ?", [NSString md5:myId]];
			[databaseControls.albumListCacheDb commit];
		}
		else if( [elementName isEqualToString:@"child"] ) 
		{
			if ( [[attributeDict objectForKey:@"isDir"] isEqualToString:@"true"] )
			{
				Album *anAlbum = [[Album alloc] initWithAttributeDict:attributeDict artist:myArtist];
				
				//Add album object to lookup dictionary and list array
				if ( ![anAlbum.title isEqualToString:@".AppleDouble"] )
				{
					[databaseControls insertAlbumIntoFolderCache:anAlbum forId:myId];
				}
				
				[anAlbum release];
			}
			else
			{
				if (![[attributeDict objectForKey:@"isVideo"] isEqualToString:@"true"])
				{
					Song *aSong = [[Song alloc] initWithAttributeDict:attributeDict];
					
					//Add song object to lookup dictionary
					if ( aSong.path )
					{
						[databaseControls insertSongIntoFolderCache:aSong forId:myId];
					}
					
					[aSong release];
				}
			}
		}
	}
}


- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string 
{ 
	if(!currentElementValue) 
		currentElementValue = [[NSMutableString alloc] initWithString:string];
	else
		[currentElementValue appendString:string];
}


- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName 
{
	if( [parseState isEqualToString:@"artists"] )
	{
		if ([elementName isEqualToString:@"index"]) 
		{
			// After finished processing an section, add the array artists for that letter to the list of artists array
			// and add the section title to the index array
			[indexes addObject:anIndex.name];
			[listOfArtists addObject:artistsArray];
			
			[anIndex release];
			[artistsArray release];
		}
		else if ([elementName isEqualToString:@"indexes"])
		{
			// Check to see if the listOfArtists is empty, and add shortcuts array as first object if it has a count > 0
			// This fixes a bug where shortcuts were not displayed if there were only shortcuts and no actual artists
			if ( [listOfArtists count] == 0 && [shortcuts count] > 0 )
			{
				[listOfArtists addObject:shortcuts];
				[shortcuts release];
			}
		}
	}
}


- (void) dealloc 
{
	[currentElementValue release];
	[shortcuts release];
	
	[parseState release];
	[myId release];
	[myArtist release];
	
	[indexes release];
	[listOfArtists release];
	[listOfAlbums release];
	[listOfSongs release];
	
	[loadedSongMD5s release];
	
	[super dealloc];
}

@end
