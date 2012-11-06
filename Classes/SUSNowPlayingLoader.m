//
//  SUSNowPlayingLoader.m
//  iSub
//
//  Created by Ben Baron on 1/24/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSNowPlayingLoader.h"

@implementation SUSNowPlayingLoader

#pragma mark - Lifecycle

- (ISMSLoaderType)type
{
    return ISMSLoaderType_NowPlaying;
}

#pragma mark - Loader Methods

- (NSURLRequest *)createRequest
{
	return [NSMutableURLRequest requestWithSUSAction:@"getNowPlaying" parameters:nil];
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
            self.nowPlayingSongDicts = [[NSMutableArray alloc] initWithCapacity:0];
            
			TBXMLElement *nowPlaying = [TBXML childElementNamed:@"nowPlaying" parentElement:root];
			if (nowPlaying)
			{
				// Loop through the songs
				TBXMLElement *entry = [TBXML childElementNamed:@"entry" parentElement:nowPlaying];
				while (entry != nil)
				{
					@autoreleasepool 
					{
						NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:0];
						
						[dict setObjectSafe:[[ISMSSong alloc] initWithTBXMLElement:entry] forKey:@"song"];
						[dict setObjectSafe:[TBXML valueOfAttributeNamed:@"username" forElement:entry] forKey:@"username"];
						[dict setObjectSafe:[TBXML valueOfAttributeNamed:@"minutesAgo" forElement:entry] forKey:@"minutesAgo"];
						[dict setObjectSafe:[TBXML valueOfAttributeNamed:@"playerId" forElement:entry] forKey:@"playerId"];
						[dict setObjectSafe:[TBXML valueOfAttributeNamed:@"playerName" forElement:entry] forKey:@"playerName"];
						
						[self.nowPlayingSongDicts addObject:dict];
						
						// Get the next message
						entry = [TBXML nextSiblingNamed:@"entry" searchFromElement:entry];
					}
				}
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
