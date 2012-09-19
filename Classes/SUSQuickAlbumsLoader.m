//
//  SUSQuickAlbumsLoader.m
//  iSub
//
//  Created by Ben Baron on 9/15/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSQuickAlbumsLoader.h"

@implementation SUSQuickAlbumsLoader

#pragma mark - Lifecycle

- (ISMSLoaderType)type
{
    return ISMSLoaderType_NowPlaying;
}

#pragma mark - Loader Methods

- (NSURLRequest *)createRequest
{
	NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"20", @"size", n2N(self.modifier), @"type", nil];
    return [NSMutableURLRequest requestWithSUSAction:@"getAlbumList" parameters:parameters];
}

- (void)processResponse
{
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
            TBXMLElement *albumList = [TBXML childElementNamed:@"albumList" parentElement:root];
			if (albumList)
			{
                self.listOfAlbums = [NSMutableArray arrayWithCapacity:0];
                
                // Loop through the songs
				TBXMLElement *album = [TBXML childElementNamed:@"album" parentElement:albumList];
				while (album != nil)
				{
					@autoreleasepool
					{
						ISMSAlbum *anAlbum = [[ISMSAlbum alloc] initWithTBXMLElement:album];
                        
                        //Add album object to lookup dictionary and list array
                        if (![anAlbum.title isEqualToString:@".AppleDouble"])
                        {
                            [self.listOfAlbums addObject:anAlbum];
                        }
                        
						// Get the next message
						album = [TBXML nextSiblingNamed:@"album" searchFromElement:album];
					}
				}
                
                // Notify the delegate that the loading is finished
                [self informDelegateLoadingFinished];
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
}

@end
