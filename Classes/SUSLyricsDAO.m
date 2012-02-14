//
//  SUSLyricsDAO.m
//  iSub
//
//  Created by Benjamin Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLyricsDAO.h"
#import "FMDatabaseAdditions.h"

#import "DatabaseSingleton.h"
#import "SUSLyricsLoader.h"
#import <QuartzCore/QuartzCore.h>
#import "SavedSettings.h"

@implementation SUSLyricsDAO
@synthesize loader, delegate;

- (id)initWithDelegate:(NSObject <SUSLoaderDelegate> *)theDelegate
{
    if ((self = [super init]))
    {
        delegate = theDelegate;
		loader = nil;
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
    return [DatabaseSingleton sharedInstance].lyricsDb;
}

#pragma mark - Public DAO Methods

- (NSString *)lyricsForArtist:(NSString *)artist andTitle:(NSString *)title
{	
    return [self.db stringForQuery:@"SELECT lyrics FROM lyrics WHERE artist = ? AND title = ?", artist, title];
}

- (NSString *)loadLyricsForArtist:(NSString *)artist andTitle:(NSString *)title
{
	[self cancelLoad];

    NSString *lyrics = [self lyricsForArtist:artist andTitle:title];
	if (lyrics)
	{
		return lyrics;
	}
    else if ([SavedSettings sharedInstance].isLyricsEnabled) 
    {
		self.loader = [[[SUSLyricsLoader alloc] initWithDelegate:self] autorelease];
        loader.artist = artist;
        loader.title = title;
        [loader startLoad];
    }
	else
	{
		return @"No lyrics saved for this song";
	}
    
    return nil;
}

#pragma mark - SUSLoader manager

- (void)startLoad
{
	DLog(@"this shouldn't be called");
}

- (void)cancelLoad
{
	[loader cancelLoad];
	loader.delegate = nil;
	self.loader = nil;
}

#pragma mark - SUSLoader delegate

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
	loader.delegate = nil;
	self.loader = nil;
	
	if ([delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[delegate loadingFinished:nil];
	}
}

@end
