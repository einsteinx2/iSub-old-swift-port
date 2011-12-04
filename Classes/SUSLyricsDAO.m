//
//  SUSLyricsDAO.m
//  iSub
//
//  Created by Benjamin Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLyricsDAO.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "DatabaseSingleton.h"
#import "SUSLyricsLoader.h"
#import <QuartzCore/QuartzCore.h>

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
	
	self.loader = [[[SUSLyricsLoader alloc] initWithDelegate:self] autorelease];
    NSString *lyrics = [self lyricsForArtist:artist andTitle:title];
	if (lyrics)
	{
		return lyrics;
	}
    else
    {
        loader.artist = artist;
        loader.title = title;
        [loader startLoad];
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
	[loader release]; loader = nil;
}

#pragma mark - SUSLoader delegate

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error
{
	[loader release]; loader = nil;
	[delegate loadingFailed:nil withError:error];
}

- (void)loadingFinished:(SUSLoader*)theLoader
{
	[loader release]; loader = nil;
	[delegate loadingFinished:nil];
}

/*
 if ([elementName isEqualToString:@"lyrics"])
 {
 if ([[NSString md5:currentElementValue] isEqualToString:@"74773FBA4937369782A559EE0DEA974F"])
 {
 if ([artist isEqualToString:musicControls.currentSongObject.artist] && [title isEqualToString:musicControls.currentSongObject.title])
 {
 //DLog(@"------------------ no lyrics found for %@ - %@ -------------------", artist, title);
 musicControls.currentSongLyrics = @"\n\nNo lyrics found";
 [[NSNotificationCenter defaultCenter] postNotificationName:@"lyricsDoneLoading" object:nil];
 }
 }
 else
 {
 if ([artist isEqualToString:musicControls.currentSongObject.artist] && [title isEqualToString:musicControls.currentSongObject.title])
 {
 //DLog(@"------------------ lyrics found! for %@ - %@ -------------------", artist, title);
 musicControls.currentSongLyrics = currentElementValue;
 [[NSNotificationCenter defaultCenter] postNotificationName:@"lyricsDoneLoading" object:nil];
 }
 
 [databaseControls.lyricsDb executeUpdate:@"INSERT INTO lyrics (artist, title, lyrics) VALUES (?, ?, ?)", artist, title, currentElementValue];
 if ([databaseControls.lyricsDb hadError]) { DLog(@"Err inserting lyrics %d: %@", [databaseControls.lyricsDb lastErrorCode], [databaseControls.lyricsDb lastErrorMessage]); }
 }	
 }*/

@end
