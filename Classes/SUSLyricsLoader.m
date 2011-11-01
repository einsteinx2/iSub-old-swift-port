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
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString-rfcEncode.h"

@implementation SUSLyricsLoader

@synthesize loadedLyrics, artist, title;

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
    return [DatabaseSingleton sharedInstance].lyricsDb;
}

#pragma mark - Loader Methods

- (void)startLoad
{
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:n2N(artist), @"artist", n2N(title), @"title", nil];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getLyrics" andParameters:parameters];
    
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		self.receivedData = [NSMutableData data];
	} 
	else 
	{
		NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
		[self.delegate loadingFailed:self withError:error]; 
	}
}

- (void)cancelLoad
{
    
}

#pragma mark - Connection Delegate

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
    self.loadedLyrics = nil;
    
	[self.delegate loadingFailed:self withError:error];
	
	[super connection:theConnection didFailWithError:error];
}	

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
			TBXMLElement *lyrics = [TBXML childElementNamed:@"lyrics" parentElement:root];
			if (lyrics)
			{
                self.loadedLyrics = [TBXML textForElement:lyrics];
                [self.delegate loadingFinished:self];
			}
            else
            {
                self.loadedLyrics = nil;
                NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NoLyricsElement];
                [self.delegate loadingFailed:self withError:error];
            }
		}
	}
	
	[super connectionDidFinishLoading:theConnection];
}

@end
