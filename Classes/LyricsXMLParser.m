//
//  LyricsXMLParser.m
//  iSub
//
//  Created by Ben Baron on 7/11/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


#import "LyricsXMLParser.h"
#import "iSubAppDelegate.h"
#import "MusicControlsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "NSString-md5.h"
#import "Song.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

@implementation LyricsXMLParser

@synthesize artist, title;

- (LyricsXMLParser *) initXMLParser 
{	
	if ((self = [super init]))
	{
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		musicControls = [MusicControlsSingleton sharedInstance];
		databaseControls = [DatabaseControlsSingleton sharedInstance];
		currentElementValue = nil;
		artist = nil;
		title = nil;
	}
	
	return self;
}


- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	if ([artist isEqualToString:musicControls.currentSongObject.artist] && [title isEqualToString:musicControls.currentSongObject.title])
	{
		musicControls.currentSongLyrics = [NSString stringWithFormat:@"Subsonic Error Code: %@\n\nError Message: %@", errorCode, message];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"lyricsDoneLoading" object:nil];
	}
}


- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	if ([artist isEqualToString:musicControls.currentSongObject.artist] && [title isEqualToString:musicControls.currentSongObject.title])
	{
		musicControls.currentSongLyrics = [NSString stringWithFormat:@"There was an error parsing the XML response.\n\nError Code: %i", parseError.code];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"lyricsDoneLoading" object:nil];
	}
}


- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName 
	attributes:(NSDictionary *)attributeDict 
{
	if([elementName isEqualToString:@"error"])
	{
		[self subsonicErrorCode:[attributeDict objectForKey:@"code"] message:[attributeDict objectForKey:@"message"]];
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
	if ([elementName isEqualToString:@"lyrics"])
	{
		if ([[NSString md5:currentElementValue] isEqualToString:@"74773FBA4937369782A559EE0DEA974F"])
		{
			if ([artist isEqualToString:musicControls.currentSongObject.artist] && [title isEqualToString:musicControls.currentSongObject.title])
			{
				//DLog(@"------------------ no lyrics found for %@ - %@ -------------------", artist, title);
				musicControls.currentSongLyrics = @"\n\nNo lyrics found";
				[[NSNotificationCenter defaultCenter] postNotificationName:@"lyricsDoneLoading" object:nil];
			}
		}
		else
		{
			if ([artist isEqualToString:musicControls.currentSongObject.artist] && [title isEqualToString:musicControls.currentSongObject.title])
			{
				//DLog(@"------------------ lyrics found! for %@ - %@ -------------------", artist, title);
				musicControls.currentSongLyrics = currentElementValue;
				[[NSNotificationCenter defaultCenter] postNotificationName:@"lyricsDoneLoading" object:nil];
			}
			
			[databaseControls.lyricsDb executeUpdate:@"INSERT INTO lyrics (artist, title, lyrics) VALUES (?, ?, ?)", artist, title, currentElementValue];
			if ([databaseControls.lyricsDb hadError]) { DLog(@"Err inserting lyrics %d: %@", [databaseControls.lyricsDb lastErrorCode], [databaseControls.lyricsDb lastErrorMessage]); }
		}	
	}
}


- (void) dealloc 
{
	[artist release];
	[title release];
	[currentElementValue release];
	[super dealloc];
}

@end
