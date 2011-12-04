//
//  QueueAll.m
//  iSub
//
//  Created by Ben Baron on 1/16/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSQueueAllDAO.h"
#import "iSubAppDelegate.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "ViewObjectsSingleton.h"
#import "QueueAlbumXMLParser.h"
#import "Album.h"
#import "Song.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
#import "NSMutableURLRequest+SUS.h"

@implementation SUSQueueAllDAO

@synthesize currentPlaylist, shufflePlaylist, myArtist, folderIds;

- (id)init
{
	if ((self = [super init]))
	{
		appDelegate = [iSubAppDelegate sharedInstance];
		musicControls = [MusicSingleton sharedInstance];
		databaseControls = [DatabaseSingleton sharedInstance];
		viewObjects = [ViewObjectsSingleton sharedInstance];
		
		connection = nil;
		receivedData = nil;
		myArtist = nil;
		folderIds = [[NSMutableArray arrayWithCapacity:1] retain]; 
	}

	return self;
}

- (void)loadAlbumFolder
{	
	NSString *folderId = [folderIds objectAtIndex:0];
	//DLog(@"Loading folderid: %@", folderId);
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:folderId forKey:@"id"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getMusicDirectory" andParameters:parameters];
    
	connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
		receivedData = [[NSMutableData data] retain];
	}
}
   
- (void)finishLoad
{
	// Remove the processed folder from array
    if ([folderIds count] > 0)
        [folderIds removeObjectAtIndex:0];
	
	// Continue the iteration
	if ([folderIds count] > 0)
	{
		[self loadAlbumFolder];
	}
	else 
	{
		//if (musicControls.isShuffle)
		if (isShuffleButton)
		{
			// Perform the shuffle
			[databaseControls shufflePlaylist];
		}
		
		if (isQueue)
		{
			if ([SavedSettings sharedInstance].isJukeboxEnabled)
			{
				[musicControls jukeboxReplacePlaylistWithLocal];
			}
		}
		else
		{
			if (musicControls.isQueueListDownloading == NO)
			{
				[musicControls downloadNextQueuedSong];
			}
		}
		
		[viewObjects hideLoadingScreen];
		
		if (doShowPlayer)
		{
			[musicControls showPlayer];
		}
		
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
		{
			musicControls.isShuffle = NO;
		}
	}
}

- (void)loadData:(NSString *)folderId artist:(Artist *)theArtist //isQueue:(BOOL)queue 
{	
	[folderIds addObject:folderId];
	self.myArtist = theArtist;
	
	
	//jukeboxSongIds = [[NSMutableArray alloc] init];
	
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
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
	isQueue = YES;
	isShuffleButton = NO;
	doShowPlayer = NO;
	[self loadData:folderId artist:theArtist];
}

- (void)cacheData:(NSString *)folderId artist:(Artist *)theArtist
{
	isQueue = NO;
	isShuffleButton = NO;
	doShowPlayer = NO;
	[self loadData:folderId artist:theArtist];
}

- (void)playAllData:(NSString *)folderId artist:(Artist *)theArtist
{
	isQueue = YES;
	isShuffleButton = NO;
	doShowPlayer = YES;
	[self loadData:folderId artist:theArtist];
}

- (void)shuffleData:(NSString *)folderId artist:(Artist *)theArtist
{
	isQueue = YES;
	isShuffleButton = YES;
	doShowPlayer = YES;
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
	[receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	// Inform the user that the connection failed.
	NSString *message = [NSString stringWithFormat:@"There was an error loading the album.\n\nError %i: %@", [error code], [error localizedDescription]];
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
	[alert release];
		
	[theConnection release]; theConnection = nil;
	[receivedData release]; receivedData = nil;
	
	// Remove the processed folder from array
	[folderIds removeObjectAtIndex:0];
	
	// Continue the iteration
	[self finishLoad];
	
	DLog(@"QueueAll CONNECTION FAILED!!!");
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:receivedData];
	QueueAlbumXMLParser *parser = (QueueAlbumXMLParser *)[[QueueAlbumXMLParser alloc] initXMLParser];
	parser.myArtist = myArtist;
	[xmlParser setDelegate:parser];
	[xmlParser parse];
		
	// Add each song to playlist
	for (Song *aSong in parser.listOfSongs)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		if (isQueue)
		{
			[aSong addToPlaylistQueue];
		}
		else
		{
			[aSong addToCacheQueue];
		}
		
		[pool release];
	}
	
	//DLog(@"parser.listOfSongs = %@", parser.listOfSongs);
	//DLog(@"Playlist count: %i", [databaseControls.currentPlaylistDb intForQuery:@"SELECT COUNT(*) FROM jukeboxCurrentPlaylist"]);
	
	for (Album *anAlbum in parser.listOfAlbums)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		[folderIds addObject:anAlbum.albumId];
		
		[pool release];
	}
	
	[parser release];
	[xmlParser release];
	
	[theConnection release]; theConnection = nil;
	[receivedData release]; receivedData = nil;
	
	// Continue the iteration
	[self finishLoad];
}


#pragma mark Memory Management

- (void)dealloc
{
	[currentPlaylist release]; currentPlaylist = nil;
	[shufflePlaylist release]; shufflePlaylist = nil;
	[myArtist release]; myArtist = nil;
	
	
	[super dealloc];
}


@end
