//
//  SUSCoverArtLoader.m
//  iSub
//
//  Created by Ben Baron on 11/1/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSCoverArtLoader.h"
#import "DatabaseSingleton.h"
#import "ViewObjectsSingleton.h"
#import "NSString-md5.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

@implementation SUSCoverArtLoader

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

#pragma mark - Private DB Methods

- (BOOL)isPlayerArtCached
{
	return [[databaseControls coverArtCacheDb320] intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [coverArtId md5]] >= 0;
}

- (BOOL)isTableCellArtCached
{
	return [[databaseControls coverArtCacheDb60] intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [coverArtId md5]] >= 0;
}

#pragma mark - Data loading

- (void)startLoad
{
	// Cache the album art if it exists
	if (coverArtId && !viewObjects.isOfflineMode)
	{
		NSString *size = nil;

		if (![self isPlayerArtCached])
		{
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
		}
		
		if (![self isTableCellArtCached])
		{
			if (SCREEN_SCALE() == 2.0)
			{
				size = @"120";
			}
			else
			{	
				size = @"60";
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
    
	
	[super connectionDidFinishLoading:theConnection];
}


if (![aRequest error])
{
	if([UIImage imageWithData:[aRequest responseData]])
	{
		//DLog(@"image is good so caching it");
		[[databaseControlsRef coverArtCacheDb320] executeUpdate:@"INSERT INTO coverArtCache (id, data) VALUES (?, ?)", [NSString md5:coverArtId], [aRequest responseData]];
	}
}

if (![aRequest error])
{
	if([UIImage imageWithData:[aRequest responseData]])
	{
		//DLog(@"image is good so caching it");
		[[databaseControlsRef coverArtCacheDb60] executeUpdate:@"INSERT INTO coverArtCache (id, data) VALUES (?, ?)", [NSString md5:coverArtId], [aRequest responseData]];
	}
}
@end
