//
//  PMSSubFolderLoader.m
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "PMSSubFolderLoader.h"

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
	NSArray *songs = [response objectForKey:@"songs"];
    NSArray *videos = [response objectForKey:@"videos"];

	self.albumsCount = folders.count;
	for (NSDictionary *folder in folders)
	{
		@autoreleasepool 
		{
			ISMSAlbum *anAlbum = [[ISMSAlbum alloc] initWithPMSDictionary:folder];
			[self insertAlbumIntoFolderCache:anAlbum];
		}
	}
	
	self.folderLength = 0;
	for (NSDictionary *song in songs)
	{
		@autoreleasepool 
		{
            ISMSSong *aSong = [[ISMSSong alloc] initWithPMSDictionary:song];
            //DLog(@"aSong: %@", aSong);
            self.folderLength += aSong.duration.intValue;
            [self insertSongIntoFolderCache:aSong];
		}
	}
    
    for (NSDictionary *video in videos)
	{
		@autoreleasepool
		{
            ISMSSong *aSong = [[ISMSSong alloc] initWithPMSDictionary:video];
            aSong.isVideo = YES;
            //DLog(@"aSong: %@", aSong);
            self.folderLength += aSong.duration.intValue;
            [self insertSongIntoFolderCache:aSong];
		}
	}
    
    self.songsCount = songs.count + videos.count;
	
	[self insertAlbumsCount];
	[self insertSongsCount];
	[self insertFolderLength];
	
	self.receivedData = nil;
	self.connection = nil;
	
	// Notify the delegate that the loading is finished
	[self informDelegateLoadingFinished];
}


@end
