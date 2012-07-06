//
//  SUSQueueAllLoader.m
//  iSub
//
//  Created by Benjamin Baron on 6/14/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSQueueAllLoader.h"
#import "TBXML.h"
#import "CustomUIAlertView.h"
#import "Album.h"
#import "Artist.h"
#import "Song.h"
#import "NSNotificationCenter+MainThread.h"

@implementation SUSQueueAllLoader

- (void)loadAlbumFolder
{		
	if (self.isCancelled)
		return;
	
	NSString *folderId = [self.folderIds objectAtIndexSafe:0];
	//DLog(@"Loading folderid: %@", folderId);
    
	NSDictionary *parameters = [NSDictionary dictionaryWithObject:folderId forKey:@"id"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getMusicDirectory" parameters:parameters];
	
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		self.receivedData = [NSMutableData data];
	}
}

- (void)process
{
	NSError *error;
    TBXML *tbxml = [[TBXML alloc] initWithXMLData:self.receivedData error:&error];
	if (error)
	{
		[self informDelegateLoadingFailed:error];
	}
	else
    {
		TBXMLElement *error = [TBXML childElementNamed:@"error" parentElement:tbxml.rootXMLElement];
		if (error)
		{
			NSString *code = [TBXML valueOfAttributeNamed:@"code" forElement:error];
			NSString *message = [TBXML valueOfAttributeNamed:@"message" forElement:error];
			[self subsonicErrorCode:code.intValue message:message];
		}
		else 
		{
			TBXMLElement *directory = [TBXML childElementNamed:@"directory" parentElement:tbxml.rootXMLElement];
			if (directory)
			{
				TBXMLElement *child = [TBXML childElementNamed:@"child" parentElement:directory];
				while (child != nil)
				{
					BOOL isDir = [[TBXML valueOfAttributeNamed:@"isDir" forElement:child] boolValue];
					if (isDir)
					{
						Album *anAlbum = [[Album alloc] initWithTBXMLElement:child artistId:self.myArtist.artistId artistName:self.myArtist.name];
						
						//Add album object to lookup dictionary and list array
						if (![anAlbum.title isEqualToString:@".AppleDouble"])
						{
							[self.listOfAlbums addObject:anAlbum];
						}
					}
					else
					{
						BOOL isVideo = [[TBXML valueOfAttributeNamed:@"isVideo" forElement:child] boolValue];
						if (!isVideo)
						{
							Song *aSong = [[Song alloc] initWithTBXMLElement:child];
							if (aSong.path)
							{
								[self.listOfSongs addObject:aSong];
							}
						}
					}
				}
			}
		}
	}	
}

@end
