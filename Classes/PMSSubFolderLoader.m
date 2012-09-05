//
//  PMSSubFolderLoader.m
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "PMSSubFolderLoader.h"
#import "SBJson.h"
#import "Album.h"
#import "Song.h"

@implementation PMSSubFolderLoader

#pragma mark - Loader Methods

- (NSURLRequest *)createRequest
{
    return [NSMutableURLRequest requestWithPMSAction:@"folders" itemId:self.myId];
}

- (void)processResponse
{	            
	NSString *responseString = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
    //DLog(@"%@", [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);
	
	NSDictionary *response = [responseString JSONValue];
	
	[self resetDb];
	
	//NSArray *albums = [response objectForKey:@"albums"];
	
	NSArray *folders = [response objectForKey:@"folders"];
	NSArray *mediaItems = [response objectForKey:@"mediaItems"];

	self.albumsCount = folders.count;
	for (NSDictionary *folder in folders)
	{
		@autoreleasepool 
		{
			Album *anAlbum = [[Album alloc] initWithPMSDictionary:folder];
			[self insertAlbumIntoFolderCache:anAlbum];
		}
	}
	
	self.folderLength = 0;
    int i = 0;
	for (NSDictionary *mediaItem in mediaItems)
	{
		@autoreleasepool 
		{
            // Only parse songs
            if ([[mediaItem objectForKey:@"itemTypeId"] isEqual:[NSNumber numberWithInt:3]])
            {
                Song *aSong = [[Song alloc] initWithPMSDictionary:mediaItem];
                //DLog(@"aSong: %@", aSong);
                self.folderLength += aSong.duration.intValue;
                [self insertSongIntoFolderCache:aSong];
                i++;
            }
		}
	}
    self.songsCount = i;
	
	[self insertAlbumsCount];
	[self insertSongsCount];
	[self insertFolderLength];
	
	self.receivedData = nil;
	self.connection = nil;
	
	// Notify the delegate that the loading is finished
	[self informDelegateLoadingFinished];
}


@end
