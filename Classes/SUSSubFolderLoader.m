//
//  SUSSubFolderLoader.m
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSSubFolderLoader.h"

@implementation SUSSubFolderLoader

#pragma mark - Loader Methods

- (NSURLRequest *)createRequest
{
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(self.myId) forKey:@"id"];
    return [NSMutableURLRequest requestWithSUSAction:@"getMusicDirectory" parameters:parameters];
}

- (void)processResponse
{	            
    DLog(@"%@", [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);
	
    // Parse the data
	//
	NSError *error;
    TBXML *tbxml = [[TBXML alloc] initWithXMLData:self.receivedData error:&error];
	if (error)
	{
		[self informDelegateLoadingFailed:error];
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
		}
		else
		{
			TBXMLElement *directory = [TBXML childElementNamed:@"directory" parentElement:root];
			if (directory)
			{
                [self resetDb];
                self.albumsCount = 0;
                self.songsCount = 0;
                self.folderLength = 0;
                
                NSMutableArray *albums = [[NSMutableArray alloc] initWithCapacity:0];
                
				TBXMLElement *child = [TBXML childElementNamed:@"child" parentElement:directory];
				while (child != nil)
				{
					@autoreleasepool 
					{
						if ([[TBXML valueOfAttributeNamed:@"isDir" forElement:child] boolValue])
						{
							ISMSAlbum *anAlbum = [[ISMSAlbum alloc] initWithTBXMLElement:child artistId:self.myArtist.artistId artistName:self.myArtist.name];
							if (![anAlbum.title isEqualToString:@".AppleDouble"])
							{
								/*[self insertAlbumIntoFolderCache:anAlbum];
								self.albumsCount++;*/
                                [albums addObject:anAlbum];
							}
						}
						else
						{
							ISMSSong *aSong = [[ISMSSong alloc] initWithTBXMLElement:child];
                            if (aSong.path && (settingsS.isVideoSupported || !aSong.isVideo))
                            {
                                [self insertSongIntoFolderCache:aSong];
                                self.songsCount++;
                                self.folderLength += [aSong.duration intValue];
                            }
						}
						
						// Get the next message
						child = [TBXML nextSiblingNamed:@"child" searchFromElement:child];
					}
				}
                
                // Hack for Subsonic 4.7 breaking alphabetical order
                [albums sortUsingComparator:^NSComparisonResult(ISMSAlbum *obj1, ISMSAlbum *obj2) {
                    return [obj1.title caseInsensitiveCompareWithoutIndefiniteArticles:obj2.title];
                }];
                for (ISMSAlbum *anAlbum in albums)
                {
                    [self insertAlbumIntoFolderCache:anAlbum];
                }
                self.albumsCount = albums.count;
                //
                
                [self insertAlbumsCount];
                [self insertSongsCount];
                [self insertFolderLength];
			}
            else
            {
                // TODO create error
                //NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NoLyricsElement];
                [self informDelegateLoadingFailed:nil];
            }
		}
	}
	
	self.receivedData = nil;
	self.connection = nil;
	
	// Notify the delegate that the loading is finished
	[self informDelegateLoadingFinished];
}


@end
