//
//  SUSServerPlaylistDAO.m
//  iSub
//
//  Created by Benjamin Baron on 11/1/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSServerPlaylistsDAO.h"
#import "FMDatabaseAdditions.h"
#import "DatabaseSingleton.h"
#import "SUSServerPlaylistsLoader.h"

@implementation SUSServerPlaylistsDAO
@synthesize delegate, serverPlaylists, loader;

- (id)initWithDelegate:(NSObject <SUSLoaderDelegate> *)theDelegate
{
    if ((self = [super init]))
    {
        delegate = theDelegate;
    }
    
    return self;
}

- (void)dealloc
{
	loader.delegate = nil;
    [loader release]; loader = nil;
    [super dealloc];
}

- (FMDatabase *)db
{
    return [DatabaseSingleton sharedInstance].localPlaylistsDb;
}

#pragma mark - Loader Manager Methods

- (void)restartLoad
{
    [self startLoad];
}

- (void)startLoad
{	
    self.loader = [[[SUSServerPlaylistsLoader alloc] initWithDelegate:self] autorelease];
    [loader startLoad];
}

- (void)cancelLoad
{
    [loader cancelLoad];
	loader.delegate = nil;
    self.loader = nil;
}

#pragma mark - Loader Delegate Methods

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error
{
	loader.delegate = nil;
    self.loader = nil;
	
	if ([delegate respondsToSelector:@selector(loadingFailed:withError:)])
	{
		[delegate loadingFailed:nil withError:error];
	}
}

- (void)loadingFinished:(SUSLoader*)theLoader
{
	self.serverPlaylists = [NSArray arrayWithArray:loader.serverPlaylists];
	
	loader.delegate = nil;
	self.loader = nil;
    
	if ([delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[delegate loadingFinished:nil];
	}
}

@end
