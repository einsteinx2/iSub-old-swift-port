//
//  PMSQueueAllLoader.m
//  iSub
//
//  Created by Benjamin Baron on 6/14/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "PMSQueueAllLoader.h"
#import "SBJson.h"
#import "CustomUIAlertView.h"
#import "Album.h"
#import "Artist.h"
#import "Song.h"

@implementation PMSQueueAllLoader

- (void)loadAlbumFolder
{		
	if (self.isCancelled)
		return;
	
	NSString *folderId = [self.folderIds objectAtIndexSafe:0];
	DLog(@"Loading folderid: %@", folderId);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithPMSAction:@"folders" item:folderId];
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		self.receivedData = [NSMutableData data];
	}
}

- (void)process
{
	NSString *responseString = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
	DLog(@"queue all: %@", responseString);
	NSDictionary *response = [responseString JSONValue];
	
	NSArray *folders = [response objectForKey:@"folders"];
	NSArray *songs = [response objectForKey:@"songs"];
	
	for (NSDictionary *folder in folders)
	{
		@autoreleasepool 
		{
			Album *anAlbum = [[Album alloc] initWithPMSDictionary:folder];
			[self.listOfAlbums addObject:anAlbum];
		}
	}
	DLog(@"folders: %@", folders);
	DLog(@"listOfAlbums: %@", self.listOfAlbums);

	for (NSDictionary *song in songs)
	{
		@autoreleasepool 
		{
			Song *aSong = [[Song alloc] initWithPMSDictionary:song];
			[self.listOfSongs addObject:aSong];
		}
	}
}

@end
