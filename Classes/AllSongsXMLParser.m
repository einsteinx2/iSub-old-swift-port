//
//  AllSongsXMLParser.m
//  XML
//
//  Created by iPhone SDK Articles on 11/23/08.
//  Copyright 2008 www.iPhoneSDKArticles.com.
//  -------------------------------------------
//
//  Modified /heavily/ by Ben Baron for the iSub project.
//

#import "AllSongsXMLParser.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "Album.h"
#import "Song.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "LoadingScreen.h"
#import "NSString+md5.h"
#import "ServerListViewController.h"

@implementation AllSongsXMLParser

@synthesize iteration, albumName;

- (AllSongsXMLParser *) initXMLParser 
{	
	[super init];	
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	databaseControls = [DatabaseControlsSingleton sharedInstance];
	return self;
}


- (void) updateMessage
{
	[viewObjects.allSongsLoadingScreen setMessage1Text:albumName];
	[viewObjects.allSongsLoadingScreen setMessage2Text:[NSString stringWithFormat:@"%i", viewObjects.allSongsLoadingProgress]];
}


- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	/*CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:appDelegate cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	[alert show];
	[alert release];*/
	NSLog(@"Subsonic error %@:  %@", errorCode, message);
}


- (BOOL) insertSong:(Song *)aSong intoGenreTable:(NSString *)table
{
	[databaseControls.genresDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (md5, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", table], [NSString md5:aSong.path], aSong.title, aSong.songId, aSong.artist, aSong.album, aSong.genre, aSong.coverArtId, aSong.path, aSong.suffix, aSong.transcodedSuffix, aSong.duration, aSong.bitRate, aSong.track, aSong.year, aSong.size];
	
	if ([databaseControls.genresDb hadError]) {
		NSLog(@"Err inserting song into genre table %d: %@", [databaseControls.genresDb lastErrorCode], [databaseControls.genresDb lastErrorMessage]);
	}
	
	return [databaseControls.genresDb hadError];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	/*CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Subsonic Error" message:[NSString stringWithFormat:@"An error occured reading the response from Subsonic.\n\nIf you are loading the artist list, this can mean the server URL is wrong\n\nError: %@", parseError.localizedDescription] delegate:appDelegate cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	[alert show];
	[alert release];*/
	NSLog(@"%@", [NSString stringWithFormat:@"An error occured reading the response from Subsonic.\n\nIf you are loading the artist list, this can mean the server URL is wrong\n\nError: %@", parseError.localizedDescription]);
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName 
	attributes:(NSDictionary *)attributeDict {
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	if([elementName isEqualToString:@"error"])
	{
		[self subsonicErrorCode:[attributeDict objectForKey:@"code"] message:[attributeDict objectForKey:@"message"]];
	}
	else if([elementName isEqualToString:@"directory"])
	{
		// Set the artist name and id
		viewObjects.allSongsCurrentAlbumName = nil; viewObjects.allSongsCurrentAlbumName = [attributeDict objectForKey:@"name"];
		viewObjects.allSongsCurrentAlbumId = nil; viewObjects.allSongsCurrentAlbumId = [attributeDict objectForKey:@"id"];
		
		//Initialize the arrays and lookup dictionaries for automatic directory caching
		viewObjects.allSongsListOfAlbums = nil; viewObjects.allSongsListOfAlbums = [NSMutableArray arrayWithCapacity:1];
		viewObjects.allSongsListOfSongs = nil; viewObjects.allSongsListOfSongs = [NSMutableArray arrayWithCapacity:1];
		//viewObjects.allSongsListOfAlbums = nil; viewObjects.allSongsListOfAlbums = [[NSMutableArray alloc] init];
		//viewObjects.allSongsListOfSongs = nil; viewObjects.allSongsListOfSongs = [[NSMutableArray alloc] init];
		
		[databaseControls.albumListCacheDb beginTransaction];
		[databaseControls.albumListCacheDb executeUpdate:@"DELETE FROM albumsCache WHERE folderId = ?", [NSString md5:viewObjects.allSongsCurrentAlbumId]];
		[databaseControls.albumListCacheDb executeUpdate:@"DELETE FROM songsCache WHERE folderId = ?", [NSString md5:viewObjects.allSongsCurrentAlbumId]];
		[databaseControls.albumListCacheDb commit];
		
	}
	else if([elementName isEqualToString:@"child"]) 
	{
		if ([[attributeDict objectForKey:@"isDir"] isEqualToString:@"true"])
		{
			//Initialize the Album.
			Album *anAlbum = [[Album alloc] init];
			
			//Extract the attributes here.
			anAlbum.title = [attributeDict objectForKey:@"title"];
			anAlbum.albumId = [attributeDict objectForKey:@"id"];
			if([attributeDict objectForKey:@"coverArt"])
				anAlbum.coverArtId = [attributeDict objectForKey:@"coverArt"];
			anAlbum.artistName = [viewObjects.allSongsCurrentArtistName copy];
			anAlbum.artistId = [viewObjects.allSongsCurrentArtistId copy];
			
			//Add album object to the subalbums table to be processed in the next iteration
			if (![anAlbum.title isEqualToString:@".AppleDouble"])
			{
				[databaseControls insertAlbum:anAlbum intoTable:[NSString stringWithFormat:@"subalbums%i", iteration] inDatabase:databaseControls.allAlbumsDb];
			}
			
			/*//Add album object to lookup dictionary and list array for caching
			if (![anAlbum.title isEqualToString:@".AppleDouble"])
			{
				//[viewObjects.allSongsListOfAlbums addObject:anAlbum];
				[databaseControls insertAlbumIntoFolderCache:anAlbum forId:viewObjects.allSongsCurrentAlbumId];
			}*/
			
			// Update the loading screen message
			[self performSelectorOnMainThread:@selector(updateMessage) withObject:nil waitUntilDone:NO];
			
			[anAlbum.artistName release];
			[anAlbum.artistId release];
			[anAlbum release];
		}
		else
		{
			if (![[attributeDict objectForKey:@"isVideo"] isEqualToString:@"true"])
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
				
				/*//Add song object to lookup dictionary
				 if (aSong.path)
				 {
				 //[viewObjects.allSongsListOfSongs addObject:aSong];
				 [databaseControls insertSongIntoFolderCache:aSong forId:viewObjects.allSongsCurrentAlbumId];
				 }*/
				
				// Add song object to the allSongs and genre databases
				if (![aSong.title isEqualToString:@".AppleDouble"])
				{
					if (aSong.path)
					{
						[databaseControls insertSong:aSong intoTable:@"allSongsTemp" inDatabase:databaseControls.allSongsDb];
						
						if (aSong.genre)
						{
							// Check if the genre has a table in the database yet, if not create it and add the new genre to the genres table
							if ([databaseControls.genresDb intForQuery:@"SELECT COUNT(*) FROM genresTemp WHERE genre = ?", aSong.genre] == 0)
							{							
								[databaseControls.genresDb executeUpdate:@"INSERT INTO genresTemp (genre) VALUES (?)", aSong.genre];
								if ([databaseControls.genresDb hadError]) { NSLog(@"Err adding the genre %d: %@", [databaseControls.genresDb lastErrorCode], [databaseControls.genresDb lastErrorMessage]); }
							}
							
							// Insert the song object into the appropriate genre table
							[self insertSong:aSong intoGenreTable:@"genresSongs"];
							
							// Insert the song into the genresLayout table
							NSArray *splitPath = [aSong.path componentsSeparatedByString:@"/"];
							if ([splitPath count] <= 9)
							{
								NSMutableArray *segments = [[NSMutableArray alloc] initWithArray:splitPath];
								while ([segments count] < 9)
								{
									[segments addObject:@""];
								}
								
								NSString *query = @"INSERT INTO genresLayout (md5, genre, segs, seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8, seg9) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
								[databaseControls.genresDb executeUpdate:query, [NSString md5:aSong.path], aSong.genre, [NSNumber numberWithInt:[splitPath count]], [segments objectAtIndex:0], [segments objectAtIndex:1], [segments objectAtIndex:2], [segments objectAtIndex:3], [segments objectAtIndex:4], [segments objectAtIndex:5], [segments objectAtIndex:6], [segments objectAtIndex:7], [segments objectAtIndex:8]];
								
								[segments release];
							}
						}
					}
				}
				
				// Update the loading screen message
				viewObjects.allSongsLoadingProgress++;
				[self performSelectorOnMainThread:@selector(updateMessage) withObject:nil waitUntilDone:NO];
				
				[aSong release];
				[numberFormatter release];
			}
		}
	}
	
	[pool release];
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
	/*// After finished processing an album folder, add the lists and dicts to the album list cache
	[databaseControls.albumListCacheDb executeUpdate:@"INSERT OR REPLACE INTO albumListCache (id, data) VALUES (?, ?)", [NSString md5:viewObjects.allSongsCurrentAlbumId], [NSKeyedArchiver archivedDataWithRootObject:[NSArray arrayWithObjects:viewObjects.allSongsListOfAlbums, viewObjects.allSongsListOfSongs, nil]]];
	if ([databaseControls.albumListCacheDb hadError]) {
		NSLog(@"Err %d: %@", [databaseControls.albumListCacheDb lastErrorCode], [databaseControls.albumListCacheDb lastErrorMessage]);
	}*/
}


- (void) dealloc 
{
	[currentElementValue release];
	[albumName release];
	[super dealloc];
}

@end
