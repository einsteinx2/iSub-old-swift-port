//
//  SUSLyricsLoader.m
//  iSub
//
//  Created by Benjamin Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLyricsLoader.h"
#import "TBXML.h"
#import "DatabaseSingleton.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueueAdditions.h"


@implementation SUSLyricsLoader

@synthesize loadedLyrics, artist, title;

- (FMDatabaseQueue *)dbQueue
{
    return databaseS.lyricsDbQueue;
}

- (ISMSLoaderType)type
{
    return ISMSLoaderType_Lyrics;
}

- (NSURLRequest *)createRequest
{
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:n2N(self.artist), @"artist", n2N(self.title), @"title", nil];
    return [NSMutableURLRequest requestWithSUSAction:@"getLyrics" parameters:parameters];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
    [super connection:theConnection didFailWithError:error];
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LyricsFailed];
}	

- (void)processResponse
{	    
    // Parse the data
	//
	NSError *error;
    TBXML *tbxml = [[TBXML alloc] initWithXMLData:self.receivedData error:&error];
	if (error)
	{
		NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NoLyricsElement];
		[self informDelegateLoadingFailed:error];
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LyricsFailed];
	}
	else
	{
		TBXMLElement *root = tbxml.rootXMLElement;

		TBXMLElement *error = [TBXML childElementNamed:@"error" parentElement:root];
		if (error)
		{
			NSString *code = [TBXML valueOfAttributeNamed:@"code" forElement:error];
			NSString *message = [TBXML valueOfAttributeNamed:@"message" forElement:error];
			[self subsonicErrorCode:[code intValue] message:message];
			
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LyricsFailed];
		}
		else
		{
			TBXMLElement *lyrics = [TBXML childElementNamed:@"lyrics" parentElement:root];
			if (lyrics)
			{
				self.loadedLyrics = [TBXML textForElement:lyrics];
				if ([self.loadedLyrics isEqualToString:@""])
				{
					DLog(@"lyrics tag found, but it's empty");
					self.loadedLyrics = nil;
					NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NoLyricsFound];
					[self informDelegateLoadingFailed:error];
				}
				else
				{
					DLog(@"lyrics tag found, and it's got lyrics! \\o/");
					[self insertLyricsIntoDb];
					[self informDelegateLoadingFinished];
					
					[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LyricsDownloaded];
				}
			}
			else
			{
				DLog(@"no lyrics tag found");
				self.loadedLyrics = nil;
				NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NoLyricsElement];
				[self informDelegateLoadingFailed:error];
				
				[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LyricsFailed];
			}
		}
	}
	
	self.receivedData = nil;
	self.connection = nil;
}

- (void)insertLyricsIntoDb
{
	[self.dbQueue inDatabase:^(FMDatabase *db)
	 {
		 [db executeUpdate:@"INSERT INTO lyrics (artist, title, lyrics) VALUES (?, ?, ?)", self.artist, self.title, self.loadedLyrics];
		 if ([db hadError]) 
			 DLog(@"Err inserting lyrics %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	 }];
}

@end
