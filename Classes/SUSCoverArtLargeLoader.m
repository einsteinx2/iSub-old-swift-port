//
//  SUSCoverArtLargeLoader.m
//  iSub
//
//  Created by Benjamin Baron on 11/22/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSCoverArtLargeLoader.h"
#import "DatabaseSingleton.h"
#import "NSString+md5.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSNotificationCenter+MainThread.h"

@implementation SUSCoverArtLargeLoader
@synthesize coverArtId;

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
    if (IS_IPAD())
        return [DatabaseSingleton sharedInstance].coverArtCacheDb540;
    else
        return [DatabaseSingleton sharedInstance].coverArtCacheDb320;
}

- (SUSLoaderType)type
{
    return SUSLoaderType_ServerPlaylist;
}

#pragma mark - Loader Methods

- (void)startLoad
{
    [self loadCoverArtId:self.coverArtId];
}

- (void)loadCoverArtId:(NSString *)artId
{
	self.coverArtId = artId;
	
	NSString *size = nil;
	if (IS_IPAD())
        size = @"540";
	else
		if (SCREEN_SCALE() == 2.0)
            size = @"640";
		else
            size = @"320";
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:n2N(size), @"size", n2N(artId), @"id", nil];
	DLog(@"parameters: %@", parameters);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getCoverArt" andParameters:parameters];
	
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	self.receivedData = [NSMutableData data];
}

#pragma mark - Connection delegate

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{    
    DLog(@"art loading failed for: %@", coverArtId);
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_AlbumArtLargeFailed];
	
    [super connection:theConnection didFailWithError:error];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	// Check to see if the data is a valid image. If so, use it; if not, use the default image.
	if([UIImage imageWithData:self.receivedData])
	{
        DLog(@"art loading completed for: %@", coverArtId);
        [self.db executeUpdate:@"INSERT OR REPLACE INTO coverArtCache (id, data) VALUES (?, ?)", [coverArtId md5], self.receivedData];
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_AlbumArtLargeDownloaded];
        [super connectionDidFinishLoading:theConnection];
	}
    else
    {
        DLog(@"art loading failed for: %@", coverArtId);
        [self connection:theConnection didFailWithError:nil];
    }
}

@end
