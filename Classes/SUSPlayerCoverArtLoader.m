//
//  SUSCoverArtLoader.m
//  iSub
//
//  Created by Ben Baron on 11/1/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSPlayerCoverArtLoader.h"
#import "DatabaseSingleton.h"
#import "ViewObjectsSingleton.h"
#import "NSString-md5.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

@implementation SUSPlayerCoverArtLoader

@synthesize coverArtId;

#pragma mark - Lifecycle

- (void)setup
{
    [super setup];
	databaseControls = [DatabaseSingleton sharedInstance];
	viewObjects = [ViewObjectsSingleton sharedInstance];
}

- (void)dealloc
{
	[super dealloc];
}

- (SUSLoaderType)type
{
    return SUSLoaderType_PlayerCoverArt;
}

#pragma mark - Private DB Methods

#pragma mark - Properties

- (FMDatabase *)db
{
    if (IS_IPAD())
        return [databaseControls coverArtCacheDb540];
    else
        return [databaseControls coverArtCacheDb320];
}

- (BOOL)isCoverArtCached
{
    return [self.db intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [coverArtId md5]] >= 0;
}

#pragma mark - Data loading

- (void)startLoad
{
	// Cache the album art if it exists
	if (coverArtId && !viewObjects.isOfflineMode)
	{
		NSString *size = nil;

        if (IS_IPAD())
        {
            size = @"540";
        }
        else
        {
            if (SCREEN_SCALE() == 2.0)
            {
                size = @"640";
            }
            else
            {	
                size = @"320";
            }
        }
		
		NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:n2N(size), @"size", n2N(coverArtId), @"id", nil];
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getCoverArt" andParameters:parameters];
		
		self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
		if (self.connection)
		{
			self.receivedData = [NSMutableData data];
		} 
		else 
		{
			// Inform the delegate that the loading failed.
			NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
			[self.delegate loadingFailed:self withError:error];
		}
	}
}

// TODO Add cancel load
- (void)cancelLoad
{
    [super cancelLoad];
}

#pragma mark - Connection Delegate

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{    
	[self.delegate loadingFailed:self withError:error];
	
	[super connection:theConnection didFailWithError:error];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	    
    if([UIImage imageWithData:self.receivedData])
	{
		[self.db executeUpdate:@"INSERT INTO coverArtCache (id, data) VALUES (?, ?)", [coverArtId md5], self.receivedData];
	}
	
	[super connectionDidFinishLoading:theConnection];
}

@end
