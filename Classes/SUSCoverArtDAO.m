//
//  SUSCoverArtLargeDAO.m
//  iSub
//
//  Created by Benjamin Baron on 11/22/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSCoverArtDAO.h"
#import "FMDatabaseAdditions.h"

#import "DatabaseSingleton.h"
#import "NSString+md5.h"
#import "SUSCoverArtLoader.h"

@implementation SUSCoverArtDAO
@synthesize delegate, isLarge, coverArtId, loader;

- (id)initWithDelegate:(NSObject<SUSLoaderDelegate> *)theDelegate
{
	if ((self = [super init]))
	{
		delegate = theDelegate;
	}
	return self;
}

- (id)initWithDelegate:(NSObject<SUSLoaderDelegate> *)theDelegate coverArtId:(NSString *)artId isLarge:(BOOL)large
{
	if ((self = [super init]))
	{
		delegate = theDelegate;
		isLarge = large;
		coverArtId = [artId copy];
	}
	return self;
}

- (void)dealloc
{
	[self cancelLoad];
	[super dealloc];
}

#pragma mark - Private DB Methods

- (FMDatabase *)db
{
	if (isLarge)
		return IS_IPAD() ? databaseS.coverArtCacheDb540 : databaseS.coverArtCacheDb320;
	else
		return databaseS.coverArtCacheDb60;
}

#pragma mark - Public DAO methods

- (UIImage *)coverArtImage
{
    NSData *imageData = [self.db dataForQuery:@"SELECT data FROM coverArtCache WHERE id = ?", [coverArtId md5]];
    return imageData ? [UIImage imageWithData:imageData] : self.defaultCoverArtImage;
}

- (UIImage *)defaultCoverArtImage
{	
	if (isLarge)
		return IS_IPAD() ? [UIImage imageNamed:@"default-album-art-ipad.png"] : [UIImage imageNamed:@"default-album-art.png"];
	else
		return [UIImage imageNamed:@"default-album-art-small.png"];
}

- (BOOL)isCoverArtCached
{
	if (!coverArtId) 
		return NO;
	
    return [self.db stringForQuery:@"SELECT id FROM coverArtCache WHERE id = ?", [coverArtId md5]] ? YES : NO;
}

- (void)downloadArtIfNotExists
{
	if (coverArtId)
	{
		if (!self.isCoverArtCached)
			[self startLoad];
	}
}

#pragma mark - Loader Manager Methods

- (void)restartLoad
{
	[self cancelLoad];
    [self startLoad];
}

- (void)startLoad
{	
    self.loader = [[[SUSCoverArtLoader alloc] initWithDelegate:self coverArtId:self.coverArtId isLarge:self.isLarge] autorelease];
    [self.loader startLoad];
}

- (void)cancelLoad
{
    [self.loader cancelLoad];
	self.loader.delegate = nil;
    self.loader = nil;
}

#pragma mark - Loader Delegate Methods

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error
{
	self.loader.delegate = nil;
	self.loader = nil;
	
	if ([self.delegate respondsToSelector:@selector(loadingFailed:withError:)])
	{
		[self.delegate loadingFailed:nil withError:error];
	}
}

- (void)loadingFinished:(SUSLoader*)theLoader
{
	self.loader.delegate = nil;
	self.loader = nil;
		
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[self.delegate loadingFinished:nil];
	}
}


@end
