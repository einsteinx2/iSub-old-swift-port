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
#import "NSString+md5.h"
#import "FMDatabaseAdditions.h"
#import "NSNotificationCenter+MainThread.h"

@implementation SUSCoverArtLoader

static NSMutableArray *loadingImageNames;
static NSObject *syncObject;

__attribute__((constructor))
static void initialize_navigationBarImages() 
{
	loadingImageNames = [[NSMutableArray alloc] init];
	syncObject = [[NSObject alloc] init];
}

#define ISMSNotification_CoverArtFinishedInternal @"ISMS cover art finished internal notification"
#define ISMSNotification_CoverArtFailedInternal @"ISMS cover art failed internal notification"

@synthesize coverArtId, isLarge;

#pragma mark - Lifecycle

- (id)initWithDelegate:(NSObject<SUSLoaderDelegate>*)delegate coverArtId:(NSString *)artId isLarge:(BOOL)large
{
	if ((self = [super initWithDelegate:delegate]))
	{
		isLarge = large;
		coverArtId = [artId copy];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(coverArtDownloadFinished:) name:ISMSNotification_CoverArtFinishedInternal object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(coverArtDownloadFailed:) name:ISMSNotification_CoverArtFailedInternal object:nil];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CoverArtFinishedInternal object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CoverArtFailedInternal object:nil];
}

- (SUSLoaderType)type
{
    return SUSLoaderType_CoverArt;
}

- (void)coverArtDownloadFinished:(NSNotification *)notification
{
	if ([notification.object isKindOfClass:[NSString class]])
	{
		if ([self.coverArtId isEqualToString:notification.object])
		{
			// My art download finished, so notify my delegate
			[self informDelegateLoadingFinished];
			
			if (isLarge)
				[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_AlbumArtLargeDownloaded];
		}
	}
}

- (void)coverArtDownloadFailed:(NSNotification *)notification
{
	if ([notification.object isKindOfClass:[NSString class]])
	{
		if ([self.coverArtId isEqualToString:notification.object])
		{
			// My art download failed, so notify my delegate
			[self informDelegateLoadingFailed:nil];
		}
	}
}

#pragma mark - Private DB Methods

#pragma mark - Properties

- (FMDatabase *)db
{
	if (isLarge)
	{
		if (IS_IPAD())
			return [databaseS coverArtCacheDb540];
		else
			return [databaseS coverArtCacheDb320];
	}
	else
	{
		return [databaseS coverArtCacheDb60];
	}
}

- (BOOL)isCoverArtCached
{
	return [self.db stringForQuery:@"SELECT id FROM coverArtCache WHERE id = ?", [self.coverArtId md5]] ? YES : NO;
}

#pragma mark - Data loading

- (BOOL)downloadArtIfNotExists
{
	if (coverArtId)
	{
		if (![self isCoverArtCached])
		{
			[self startLoad];
			return YES;
		}
	}
	return NO;
}

- (void)startLoad
{
	@synchronized(syncObject)
	{
		if (self.coverArtId && !viewObjectsS.isOfflineMode)
		{
			if (![self isCoverArtCached])
			{
				if (![loadingImageNames containsObject:self.coverArtId])
				{
					// This art is not loading, so start loading it
					
					NSString *size = nil;
					if (isLarge)
					{
						if (IS_IPAD())
							size = SCREEN_SCALE() == 2.0 ? @"1080" : @"540";
						else
							size = SCREEN_SCALE() == 2.0 ? @"640" : @"320";
					}
					else
					{
						size = SCREEN_SCALE() == 2.0 ? @"120" : @"60";
					}
					
					NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:n2N(size), @"size", n2N(self.coverArtId), @"id", nil];
					NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getCoverArt" andParameters:parameters];
					
					self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
					if (self.connection)
					{
						self.receivedData = [NSMutableData data];
					} 
					else 
					{
						// Inform the delegate that the loading failed.
						NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
						[self informDelegateLoadingFailed:error];
					}
				}
			}
		}
	}
}

#pragma mark - Connection Delegate

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [self.receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{  
	self.receivedData = nil;
	self.connection = nil;
	
	// Inform the delegate that loading failed
	//[self informDelegateLoadingFailed:error];
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CoverArtFinishedInternal object:[self.coverArtId copy]];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{
	// Check to see if the data is a valid image. If so, use it; if not, use the default image.
	if([UIImage imageWithData:self.receivedData])
	{
        DLog(@"art loading completed for: %@", self.coverArtId);
        [self.db executeUpdate:@"REPLACE INTO coverArtCache (id, data) VALUES (?, ?)", [self.coverArtId md5], self.receivedData];
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CoverArtFinishedInternal object:[self.coverArtId copy]];
		
		/*if (isLarge)
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_AlbumArtLargeDownloaded];
        
		// Notify the delegate that the loading is finished
		[self informDelegateLoadingFinished];*/
	}
    else
    {
        DLog(@"art loading failed for: %@", self.coverArtId);
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CoverArtFinishedInternal object:[self.coverArtId copy]];
		
       /* // Inform the delegate that loading failed
		[self informDelegateLoadingFailed:nil];*/
    }

	self.receivedData = nil;
	self.connection = nil;
}

@end
