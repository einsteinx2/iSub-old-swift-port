//
//  QueueAll.m
//  iSub
//
//  Created by Ben Baron on 1/16/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSQueueAllLoader.h"
#import "iSubAppDelegate.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "ViewObjectsSingleton.h"
#import "QueueAlbumXMLParser.h"
#import "Album.h"
#import "Song.h"
#import "FMDatabaseAdditions.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
#import "NSMutableURLRequest+SUS.h"
#import "ISMSStreamManager.h"
#import "PlaylistSingleton.h"
#import "NSArray+Additions.h"
#import "JukeboxSingleton.h"
#import "AudioEngine.h"
#import "NSNotificationCenter+MainThread.h"

@implementation SUSQueueAllLoader

@synthesize currentPlaylist, shufflePlaylist, myArtist, folderIds;
@synthesize isQueue, isShuffleButton, doShowPlayer, isCancelled;

- (id)init
{
	if ((self = [super init]))
	{
		folderIds = [[NSMutableArray alloc] initWithCapacity:10];
		isCancelled = NO;
	}

	return self;
}

- (void)loadAlbumFolder
{		
	if (self.isCancelled)
		return;
	
	NSString *folderId = [self.folderIds objectAtIndexSafe:0];
	//DLog(@"Loading folderid: %@", folderId);
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:folderId forKey:@"id"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getMusicDirectory" andParameters:parameters];
    
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		self.receivedData = [NSMutableData data];
	}
}

- (void)startLoad
{
	DLog(@"must use loadData:artist:");
}

- (void)cancelLoad
{
	DLog(@"cancelLoad called");
	self.isCancelled = YES;
	[super cancelLoad];
	[viewObjectsS hideLoadingScreen];
}

- (void)finishLoad
{	
	if (self.isCancelled)
		return;
	
	// Continue the iteration
	if ([self.folderIds count] > 0)
	{
		[self loadAlbumFolder];
	}
	else 
	{
		if (self.isShuffleButton)
		{
			// Perform the shuffle
			[databaseS shufflePlaylist];
		}
		
		if (self.isQueue)
		{
			if (settingsS.isJukeboxEnabled)
			{
				//[jukeboxS jukeboxReplacePlaylistWithLocal];
			}
			else
			{
				[streamManagerS fillStreamQueue:audioEngineS.isStarted];
			}
		}
		
		[viewObjectsS hideLoadingScreen];
		
		if (self.doShowPlayer)
		{
			[musicS showPlayer];
		}
		
		if (settingsS.isJukeboxEnabled)
		{
			playlistS.isShuffle = NO;
		}
	}
}

- (void)loadData:(NSString *)folderId artist:(Artist *)theArtist //isQueue:(BOOL)queue 
{	
	self.isCancelled = NO;
	
	[self.folderIds addObject:folderId];
	self.myArtist = theArtist;
	
	//jukeboxSongIds = [[NSMutableArray alloc] init];
	
	if (settingsS.isJukeboxEnabled)
	{
		self.currentPlaylist = @"jukeboxCurrentPlaylist";
		self.shufflePlaylist = @"jukeboxShufflePlaylist";
	}
	else
	{
		self.currentPlaylist = @"currentPlaylist";
		self.shufflePlaylist = @"shufflePlaylist";
	}
	
	[self loadAlbumFolder];
}

- (void)queueData:(NSString *)folderId artist:(Artist *)theArtist
{
	self.isQueue = YES;
	self.isShuffleButton = NO;
	self.doShowPlayer = NO;
	[self loadData:folderId artist:theArtist];
}

- (void)cacheData:(NSString *)folderId artist:(Artist *)theArtist
{
	self.isQueue = NO;
	self.isShuffleButton = NO;
	self.doShowPlayer = NO;
	[self loadData:folderId artist:theArtist];
}

- (void)playAllData:(NSString *)folderId artist:(Artist *)theArtist
{
	self.isQueue = YES;
	self.isShuffleButton = NO;
	self.doShowPlayer = YES;
	[self loadData:folderId artist:theArtist];
}

- (void)shuffleData:(NSString *)folderId artist:(Artist *)theArtist
{
	self.isQueue = YES;
	self.isShuffleButton = YES;
	self.doShowPlayer = YES;
	[self loadData:folderId artist:theArtist];
}

#pragma mark Connection Delegate

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
	// Inform the user that the connection failed.
	NSString *message = [NSString stringWithFormat:@"There was an error loading the album.\n\nError %i: %@", [error code], [error localizedDescription]];
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
		
	self.receivedData = nil;
	self.connection = nil;
	
	// Remove the processed folder from array
	[self.folderIds removeObjectAtIndex:0];
	
	// Continue the iteration
	[self finishLoad];
	
	DLog(@"QueueAll CONNECTION FAILED!!!");
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	DLog(@"connectionDidFinishLoading");
	NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:self.receivedData];
	QueueAlbumXMLParser *parser = (QueueAlbumXMLParser *)[[QueueAlbumXMLParser alloc] initXMLParser];
	parser.myArtist = myArtist;
	[xmlParser setDelegate:parser];
	[xmlParser parse];
		
	// Add each song to playlist
	for (Song *aSong in parser.listOfSongs)
	{
		@autoreleasepool 
		{
			if (self.isQueue)
			{
				[aSong addToCurrentPlaylistDbQueue];
			}
			else
			{
				[aSong addToCacheQueueDbQueue];
			}
		}
	}
	
	// Remove the processed folder from array
	if ([self.folderIds count] > 0)
		[self.folderIds removeObjectAtIndex:0];
	
	NSUInteger maxIndex = [parser.listOfAlbums count] - 1;
	for (int i = maxIndex; i >= 0; i--)
	{
		NSString *albumId = [[parser.listOfAlbums objectAtIndexSafe:i] albumId];
		[self.folderIds insertObject:albumId atIndex:0];
	}
	
	self.receivedData = nil;
	self.connection = nil;
	
	// Continue the iteration
	//[self performSelector:@selector(finishLoad) withObject:nil afterDelay:0.05];
	if (self.isQueue)
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	
	[self finishLoad];
}

@end
