//
//  JukeboxSingleton.m
//  iSub
//
//  Created by Ben Baron on 2/24/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "JukeboxSingleton.h"
#import "iSub-Swift.h"
#import "JukeboxConnectionDelegate.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"

@implementation JukeboxSingleton

#pragma mark - Jukebox Control methods

- (void)jukeboxPlaySongAtPosition:(NSNumber *)position
{
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
	
    NSString *positionString = [position stringValue];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"skip", @"action", n2N(positionString), @"index", nil];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" parameters:parameters];
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
        // TODO: Figure out how to handle this for Jukebox mode
		//[PlayQueue sharedInstance].currentIndex = [position intValue];
		
		[self.connectionQueue registerConnection:connection];
		[self.connectionQueue startQueue];
	} 
	else 
	{
		// Inform the user that the connection failed.
#ifdef IOS
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
#endif
	}
	
}


- (void)jukeboxPlay
{
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
	
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:@"start" forKey:@"action"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" parameters:parameters];
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
		[self.connectionQueue registerConnection:connection];
		[self.connectionQueue startQueue];
	}
	else
	{
		// Inform the user that the connection failed.
#ifdef IOS
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
#endif
	}
	
	
	self.jukeboxIsPlaying = YES;
}

- (void)jukeboxStop
{
	
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:@"stop" forKey:@"action"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" parameters:parameters];
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
		[self.connectionQueue registerConnection:connection];
		[self.connectionQueue startQueue];
	}
	else
	{
		// Inform the user that the connection failed.
#ifdef IOS
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
#endif
	}
	
	self.jukeboxIsPlaying = NO;
}

- (void)jukeboxPrevSong
{
    NSInteger index = [PlayQueue sharedInstance].previousIndex;
    if (index >= 0)
    {
        [self jukeboxPlaySongAtPosition:@(index)];
        
        self.jukeboxIsPlaying = YES;
    }
    else
    {
        [self jukeboxStop];
    }
}

- (void)jukeboxNextSong
{
    NSInteger index = [PlayQueue sharedInstance].nextIndex;
    if (index <= ([[PlayQueue sharedInstance] songCount] - 1))
    {
        [self jukeboxPlaySongAtPosition:@(index)];
        
        self.jukeboxIsPlaying = YES;
    }
    else
    {
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackEnded];
        [self jukeboxStop];
        
        self.jukeboxIsPlaying = NO;
    }
}

- (void)jukeboxSetVolume:(float)level
{
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
    
    NSString *gainString = [NSString stringWithFormat:@"%f", level];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"setGain", @"action", n2N(gainString), @"gain", nil];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" parameters:parameters];
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
		[self.connectionQueue registerConnection:connection];
		[self.connectionQueue startQueue];
	}
	else
	{
		// Inform the user that the connection failed.
#ifdef IOS
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
#endif
	}
	
}

- (void)jukeboxAddSong:(NSString*)songId
{
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"add", @"action", n2N(songId), @"id", nil];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" parameters:parameters];
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
		[self.connectionQueue registerConnection:connection];
		[self.connectionQueue startQueue];
	}
	else
	{
		// Inform the user that the connection failed.
#ifdef IOS
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
#endif
	}
	
}

- (void)jukeboxAddSongs:(NSArray*)songIds
{
	if ([songIds count] > 0)
	{
        JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
        
        NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObject:@"add" forKey:@"action"];
		[parameters setObject:n2N(songIds) forKey:@"id"];
		
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" parameters:parameters];
		
        NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
		if (connection)
		{
			[self.connectionQueue registerConnection:connection];
			[self.connectionQueue startQueue];
		}
		else
		{
			// Inform the user that the connection failed.
#ifdef IOS
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
			[alert show];
#endif
		}
		
	}
}

- (void)jukeboxReplacePlaylistWithLocal
{
	[self jukeboxClearRemotePlaylist];
    
    NSArray *localSongs = [[ISMSPlaylist playQueue] songs];
    NSMutableArray *songIds = [[NSMutableArray alloc] initWithCapacity:localSongs.count];
    for (ISMSSong *song in localSongs)
    {
        [songIds addObject:song.songId];
    }

	[self jukeboxAddSongs:songIds];
}


- (void)jukeboxRemoveSong:(NSString*)songId
{
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"remove", @"action", n2N(songId), @"id", nil];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" parameters:parameters];
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
		[self.connectionQueue registerConnection:connection];
		[self.connectionQueue startQueue];
	}
	else
	{
		// Inform the user that the connection failed.
#ifdef IOS
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
#endif
	}
	
}

- (void)jukeboxClearPlaylist
{
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:@"clear" forKey:@"action"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" parameters:parameters];
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
        [[ISMSPlaylist playQueue] removeAllSongs:YES];
        
		[self.connectionQueue registerConnection:connection];
		[self.connectionQueue startQueue];
	}
	else
	{
		// Inform the user that the connection failed.
#ifdef IOS
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
#endif
	}
	
}

- (void)jukeboxClearRemotePlaylist
{
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:@"clear" forKey:@"action"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" parameters:parameters];
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
		[self.connectionQueue registerConnection:connection];
		[self.connectionQueue startQueue];
	}
	else
	{
		// Inform the user that the connection failed.
#ifdef IOS
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
#endif
	}
	
}

- (void)jukeboxShuffle
{
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
	
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:@"shuffle" forKey:@"action"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" parameters:parameters];
    
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
        [[ISMSPlaylist playQueue] removeAllSongs:YES];
		
		[self.connectionQueue registerConnection:connection];
		[self.connectionQueue startQueue];
	}
	else
	{
		// Inform the user that the connection failed.
#ifdef IOS
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
#endif
	}
	
}

- (void)jukeboxGetInfoInternal
{
	if (!settingsS.isJukeboxEnabled)
		return;
	
	JukeboxConnectionDelegate *connDelegate = [[JukeboxConnectionDelegate alloc] init];
	connDelegate.isGetInfo = YES;
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:@"get" forKey:@"action"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" parameters:parameters];
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
	if (connection)
	{
        [[ISMSPlaylist playQueue] removeAllSongs:YES];
		
		[self.connectionQueue registerConnection:connection];
		[self.connectionQueue startQueue];
	}
	else
	{
		// Inform the user that the connection failed.
#ifdef IOS
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"There was an error controlling the Jukebox.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
#endif
	}
	
	// Keep reloading every 30 seconds if there is no activity so that the player stays updated if visible
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(jukeboxGetInfoInternal) object:nil];
	[self performSelector:@selector(jukeboxGetInfoInternal) withObject:nil afterDelay:30.];
}

- (void)jukeboxGetInfo
{	
	// Make sure this doesn't run a bunch of times in a row
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(jukeboxGetInfoInternal) object:nil];
	[self performSelector:@selector(jukeboxGetInfoInternal) withObject:nil afterDelay:0.5];
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
//DLog(@"received memory warning");
	
	
}

#pragma mark - Singleton methods

- (void)setup
{
	_connectionQueue = [[EX2SimpleConnectionQueue alloc] init];
    _connectionQueue.numberOfConcurrentConnections = 1;

#ifdef IOS
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
}

+ (instancetype)sharedInstance
{
    static JukeboxSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
