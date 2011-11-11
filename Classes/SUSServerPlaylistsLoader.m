//
//  SUSServerPlaylistLoader.m
//  iSub
//
//  Created by Benjamin Baron on 11/6/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSServerPlaylistsLoader.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "DatabaseSingleton.h"
#import "TBXML.h"
#import "SUSServerPlaylist.h"

@implementation SUSServerPlaylistsLoader
@synthesize serverPlaylists;

#pragma mark - Lifecycle

- (void)setup
{
	[super setup];
}

- (void)dealloc
{
	[super dealloc];
}

- (FMDatabase *)db
{
    return [DatabaseSingleton sharedInstance].localPlaylistsDb;
}

- (SUSLoaderType)type
{
    return SUSLoaderType_ServerPlaylist;
}

#pragma mark - Private DB Methods

#pragma mark - Loader Methods

- (void)startLoad
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getPlaylists" andParameters:nil];
    
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		self.receivedData = [NSMutableData data];
        self.serverPlaylists = nil;
	} 
	else 
	{
		NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
		[self.delegate loadingFailed:self withError:error]; 
	}
}

#pragma mark - Connection Delegate

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection
{
    // Parse the data
	//
	TBXML *tbxml = [[TBXML alloc] initWithXMLData:self.receivedData];
    TBXMLElement *root = tbxml.rootXMLElement;
    if (root) 
	{
		TBXMLElement *error = [TBXML childElementNamed:@"error" parentElement:root];
		if (error)
		{
			NSString *code = [TBXML valueOfAttributeNamed:@"code" forElement:error];
			NSString *message = [TBXML valueOfAttributeNamed:@"message" forElement:error];
			[self subsonicErrorCode:[code intValue] message:message];
		}
		else
		{
			TBXMLElement *playlists = [TBXML childElementNamed:@"playlists" parentElement:root];
			if (playlists)
			{
                NSMutableArray *tempArray = [NSMutableArray arrayWithCapacity:0];
                
				TBXMLElement *playlist = [TBXML childElementNamed:@"playlist" parentElement:playlists];
				while (playlist != nil)
				{
					NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
                    
                    SUSServerPlaylist *serverPlaylist = [[SUSServerPlaylist alloc] initWithTBXMLElement:playlist];
                    [tempArray addObject:serverPlaylist];
                    [serverPlaylist release];
					
					// Get the next message
					playlist = [TBXML nextSiblingNamed:@"playlist" searchFromElement:playlist];
					
					[pool release];
				}
                
                // Sort the array
                self.serverPlaylists = [tempArray sortedArrayUsingSelector:@selector(compare:)];
			}
            
            [super connectionDidFinishLoading:theConnection];
		}
	}
}

@end
