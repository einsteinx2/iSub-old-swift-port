//
//  SocialControlsSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SocialSingleton.h"
#import "SA_OAuthTwitterEngine.h"
#import "SA_OAuthTwitterController.h"
#import "CustomUIAlertView.h"
#import "BassGaplessPlayer.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "Song.h"
#import "NSMutableURLRequest+SUS.h"
#import "ISMSStreamManager.h"
#import "ViewObjectsSingleton.h"
#import "AudioEngine.h"

// Twitter secret keys
#define kOAuthConsumerKey				@"nYKAEcLstFYnI9EEnv6g"
#define kOAuthConsumerSecret			@"wXSWVvY7GN1e8Z2KFaR9A5skZKtHzpchvMS7Elpu0"

@implementation SocialSingleton

@synthesize twitterEngine, playerHasScrobbled, playerHasTweeted;

#pragma mark -
#pragma mark Class instance methods

- (void)playerClearSocial
{
	self.playerHasTweeted = NO;
	self.playerHasScrobbled = NO;
}

- (void)playerHandleSocial
{
	if (!self.playerHasTweeted && audioEngineS.player.progress >= socialS.tweetDelay)
	{
		self.playerHasTweeted = YES;
		
		[EX2Dispatch runInMainThread:^{
			[self tweetSong];
		}];
	}
	
	if (!self.playerHasScrobbled && audioEngineS.player.progress >= socialS.scrobbleDelay)
	{
		self.playerHasScrobbled = YES;
		[EX2Dispatch runInMainThread:^{
			[self scrobbleSongAsSubmission];
		}];
	}
}

- (NSTimeInterval)scrobbleDelay
{
	// Scrobble in 30 seconds (or settings amount) if not canceled
	//Song *currentSong = playlistS.currentSong;
	Song *currentSong = audioEngineS.player.currentStream.song;
	NSTimeInterval scrobbleDelay = 30.0;
	if (currentSong.duration != nil)
	{
		float scrobblePercent = settingsS.scrobblePercent;
		float duration = [currentSong.duration floatValue];
		scrobbleDelay = scrobblePercent * duration;
	}
	
	return scrobbleDelay;
}

- (NSTimeInterval)subsonicDelay
{
	return 10.0;
}

- (NSTimeInterval)tweetDelay
{
	return 30.0;
}

/*- (void)songStarted
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	// Notify Subsonic of play in 10 seconds if not canceled
	[self performSelector:@selector(notifySubsonic) withObject:nil afterDelay:10.0];
	
	// Tweet in 30 seconds if not canceled
	[self performSelector:@selector(tweetSong) withObject:nil afterDelay:30.0];

	// Scrobble in 30 seconds (or settings amount) if not canceled
	Song *currentSong = playlistS.currentSong;
	NSTimeInterval scrobbleDelay = 30.0;
	if (currentSong.duration != nil)
	{
		float scrobblePercent = settingsS.scrobblePercent;
		float duration = [currentSong.duration floatValue];
		scrobbleDelay = scrobblePercent * duration;
	}
	[self performSelector:@selector(scrobbleSong) withObject:nil afterDelay:scrobbleDelay];
	
	// If scrobbling is enabled, send "now playing" call
	if (settingsS.isScrobbleEnabled)
	{
		[self scrobbleSong:currentSong isSubmission:NO];
	}
}*/

- (void)notifySubsonic
{
	if (!viewObjectsS.isOfflineMode)
	{
		// If this song wasn't just cached, then notify Subsonic of the playback
		Song *lastCachedSong = streamManagerS.lastCachedSong;
		Song *currentSong = playlistS.currentSong;
		//DLog(@"Asked to notify Subsonic about %@ ", currentSong.title);
		if (![lastCachedSong isEqualToSong:currentSong])
		{
			NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(currentSong.songId), @"id", nil];
			NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"stream" parameters:parameters byteOffset:0];
			NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
			NSLog(@"%@", conn);
			//DLog(@"notified Subsonic about %@", currentSong.title);
		}
	}
}

#pragma mark - Scrobbling -

- (void)scrobbleSongAsSubmission
{	
//DLog(@"Asked to scrobble %@ as submission", playlistS.currentSong.title);
	if (settingsS.isScrobbleEnabled && !viewObjectsS.isOfflineMode)
	{
		Song *currentSong = playlistS.currentSong;
		[self scrobbleSong:currentSong isSubmission:YES];
	//DLog(@"Scrobbled %@ as submission", currentSong.title);
	}
}

- (void)scrobbleSongAsPlaying
{
//DLog(@"Asked to scrobble %@ as playing", playlistS.currentSong.title);
	// If scrobbling is enabled, send "now playing" call
	if (settingsS.isScrobbleEnabled && !viewObjectsS.isOfflineMode)
	{
		Song *currentSong = playlistS.currentSong;
		[self scrobbleSong:currentSong isSubmission:NO];
	//DLog(@"Scrobbled %@ as playing", currentSong.title);
	}
}

- (void)scrobbleSong:(Song*)aSong isSubmission:(BOOL)isSubmission
{
	if (settingsS.isScrobbleEnabled && !viewObjectsS.isOfflineMode)
	{
		NSString *isSubmissionString = [NSString stringWithFormat:@"%i", isSubmission];
		NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:n2N(aSong.songId), @"id", n2N(isSubmissionString), @"submission", nil];
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"scrobble" parameters:parameters];
		
		NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
		NSLog(@"%@", conn);
	}
}

#pragma mark Subsonic chache notification hack and Last.fm scrobbling connection delegate

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
	// Do nothing
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
	if ([incrementalData length] > 0)
	{
		// Subsonic has been notified, cancel the connection
	//DLog(@"Subsonic has been notified, cancel the connection");
		[theConnection cancel];
	}
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	//DLog(@"Subsonic cached song play notification failed\n\nError: %@", [error localizedDescription]);
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
}

#pragma mark - Twitter -

- (void)tweetSong
{
	Song *currentSong = playlistS.currentSong;
	
//DLog(@"Asked to tweet %@", currentSong.title);
	
	if (self.twitterEngine.isAuthorized && settingsS.isTwitterEnabled && !viewObjectsS.isOfflineMode)
	{
		if (currentSong.artist && currentSong.title)
		{
			//DLog(@"------------- tweeting song --------------");
			NSString *tweet = [NSString stringWithFormat:@"is listening to \"%@\" by %@", currentSong.title, currentSong.artist];
			if ([tweet length] <= 140)
				[self.twitterEngine sendUpdate:tweet];
			else
				[self.twitterEngine sendUpdate:[tweet substringToIndex:140]];
			
		//DLog(@"Tweeted: %@", tweet);
		}
		else 
		{
			//DLog(@"------------- not tweeting song because either no artist or no title --------------");
		}
	}
	else 
	{
		//DLog(@"------------- not tweeting song because no engine or not enabled --------------");
	}
}

- (void)createTwitterEngine
{
	if (twitterEngine)
		return;
	
	self.twitterEngine = [[SA_OAuthTwitterEngine alloc] initOAuthWithDelegate: self];
	self.twitterEngine.consumerKey = kOAuthConsumerKey;
	self.twitterEngine.consumerSecret = kOAuthConsumerSecret;
	
	// Needed to load saved twitter auth info
	[self.twitterEngine isAuthorized];
}

//=============================================================================================================================

- (void)destroyTwitterEngine
{
	[self.twitterEngine endUserSession];
	self.twitterEngine = nil;
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObjectForKey:@"twitterAuthData"];
	[defaults synchronize];
}

// SA_OAuthTwitterEngineDelegate
- (void)storeCachedTwitterOAuthData:(NSString *)data forUsername:(NSString *)username 
{
	//DLog(@"storeCachedTwitterOAuthData: %@ for %@", data, username);
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	[defaults setObject:data forKey:@"twitterAuthData"];
	[defaults synchronize];
}

- (NSString *) cachedTwitterOAuthDataForUsername:(NSString *)username 
{
	//DLog(@"cachedTwitterOAuthDataForUsername for %@", username);
	return [[NSUserDefaults standardUserDefaults] objectForKey:@"twitterAuthData"];
}

//=============================================================================================================================
// SA_OAuthTwitterControllerDelegate
- (void)OAuthTwitterController:(SA_OAuthTwitterController *)controller authenticatedWithUsername:(NSString *)username 
{
	//DLog(@"Authenicated for %@", username);
	[NSNotificationCenter postNotificationToMainThreadWithName:@"twitterAuthenticated"];
}

- (void)OAuthTwitterControllerFailed:(SA_OAuthTwitterController *)controller 
{
	//DLog(@"Authentication Failed!");
	self.twitterEngine = nil;
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Twitter Error" message:@"Failed to authenticate user. Try logging in again." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
}

- (void)OAuthTwitterControllerCanceled:(SA_OAuthTwitterController *)controller 
{
	//DLog(@"Authentication Canceled.");
	self.twitterEngine = nil;
}

//=============================================================================================================================
// TwitterEngineDelegate
- (void)requestSucceeded:(NSString *)requestIdentifier 
{
	//DLog(@"Request %@ succeeded", requestIdentifier);
}

- (void)requestFailed:(NSString *)requestIdentifier withError:(NSError *) error 
{
	//DLog(@"Request %@ failed with error: %@", requestIdentifier, error);
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
//DLog(@"received memory warning");
	
	
}

#pragma mark - Singleton methods

- (void)setup
{
	//initialize here
	[self createTwitterEngine];
	
	//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(songStarted) name:ISMSNotification_SongPlaybackStarted object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(didReceiveMemoryWarning) 
												 name:UIApplicationDidReceiveMemoryWarningNotification 
											   object:nil];
}

+ (id)sharedInstance
{
    static SocialSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
