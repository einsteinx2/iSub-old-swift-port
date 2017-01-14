//
//  SocialControlsSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SocialSingleton.h"
#import "iSub-Swift.h"
#import "BassGaplessPlayer.h"
#import "ISMSStreamManager.h"
#import <Twitter/Twitter.h>

// Twitter secret keys
#define kOAuthConsumerKey				@"nYKAEcLstFYnI9EEnv6g"
#define kOAuthConsumerSecret			@"wXSWVvY7GN1e8Z2KFaR9A5skZKtHzpchvMS7Elpu0"

//LOG_LEVEL_ISUB_DEFAULT

@implementation SocialSingleton

#pragma mark -
#pragma mark Class instance methods

- (void)playerClearSocial
{
	self.playerHasTweeted = NO;
	self.playerHasScrobbled = NO;
    self.playerHasSubmittedNowPlaying = NO;
    self.playerHasNotifiedSubsonic = NO;
}

- (void)playerHandleSocial
{
    // TODO: I don't think this works anymore
    double progress = PlayQueue.si.currentSongProgress;
    if (!self.playerHasNotifiedSubsonic && progress >= SocialSingleton.si.subsonicDelay)
    {
        if (SavedSettings.si.currentServer.type == ServerTypeSubsonic)
        {
            [EX2Dispatch runInMainThreadAsync:^{
                [self notifySubsonic];
            }];
        }
        
        self.playerHasNotifiedSubsonic = YES;
    }
    
	if (!self.playerHasTweeted && progress >= SocialSingleton.si.tweetDelay)
	{
		self.playerHasTweeted = YES;
		
		[EX2Dispatch runInMainThreadAsync:^{
			[self tweetSong];
		}];
	}
	
	if (!self.playerHasScrobbled && progress >= SocialSingleton.si.scrobbleDelay)
	{
		self.playerHasScrobbled = YES;
		[EX2Dispatch runInMainThreadAsync:^{
			[self scrobbleSongAsSubmission];
		}];
	}
    
    if (!self.playerHasSubmittedNowPlaying)
    {
        self.playerHasSubmittedNowPlaying = YES;
        [EX2Dispatch runInMainThreadAsync:^{
			[self scrobbleSongAsPlaying];
		}];
    }
}

- (NSTimeInterval)scrobbleDelay
{
	// Scrobble in 30 seconds (or settings amount) if not canceled
	ISMSSong *currentSong = PlayQueue.si.currentSong;
	NSTimeInterval scrobbleDelay = 30.0;
	if (currentSong.duration != nil)
	{
		float scrobblePercent = SavedSettings.si.scrobblePercent;
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

- (void)notifySubsonic
{
    // TODO: Reimplement
//	if (!SavedSettings.si.isOfflineMode)
//	{
//		// If this song wasn't just cached, then notify Subsonic of the playback
//		ISMSSong *lastCachedSong = ISMSStreamManager.si.lastCachedSong;
//		ISMSSong *currentSong = PlayQueue.si.currentSong;
//		if (![lastCachedSong isEqualToSong:currentSong])
//		{
//			NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(currentSong.songId), @"id", nil];
//            NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"stream" parameters:parameters fragment:nil byteOffset:0];
//			NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
//            if (conn)
//            {
//                DDLogVerbose(@"notified Subsonic about cached song %@", currentSong.title);
//            }
//		}
//	}
}

#pragma mark - Scrobbling -

- (void)scrobbleSongAsSubmission
{	
    //DLog(@"Asked to scrobble %@ as submission", playlistS.currentSong.title);
	if (SavedSettings.si.isScrobbleEnabled && !SavedSettings.si.isOfflineMode)
	{
		ISMSSong *currentSong = PlayQueue.si.currentSong;
		[self scrobbleSong:currentSong isSubmission:YES];
	//DLog(@"Scrobbled %@ as submission", currentSong.title);
	}
}

- (void)scrobbleSongAsPlaying
{
    //DLog(@"Asked to scrobble %@ as playing", playlistS.currentSong.title);
	// If scrobbling is enabled, send "now playing" call
	if (SavedSettings.si.isScrobbleEnabled && !SavedSettings.si.isOfflineMode)
	{
		ISMSSong *currentSong = PlayQueue.si.currentSong;
		[self scrobbleSong:currentSong isSubmission:NO];
	//DLog(@"Scrobbled %@ as playing", currentSong.title);
	}
}

- (void)scrobbleSong:(ISMSSong*)aSong isSubmission:(BOOL)isSubmission
{
    // TODO: Reimplement
//	if (SavedSettings.si.isScrobbleEnabled && !SavedSettings.si.isOfflineMode)
//    {
//		ISMSScrobbleLoader *loader = [[ISMSScrobbleLoader alloc] initWithCallbackBlock:^(BOOL success, NSError *error, ApiLoader *loader)
//        {
//            ALog(@"Scrobble successfully completed for song: %@", aSong.title);
//        }];
//        
//        loader.aSong = aSong;
//        loader.isSubmission = isSubmission;
//        
//        [loader startLoad];
//	}
}

#pragma mark - Twitter -

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)tweetSong
{
#ifdef IOS
	ISMSSong *currentSong = PlayQueue.si.currentSong;
	
    //DLog(@"Asked to tweet %@", currentSong.title);
	
	if (SavedSettings.si.currentTwitterAccount && SavedSettings.si.isTwitterEnabled && !SavedSettings.si.isOfflineMode)
	{
		if (currentSong.artistDisplayName && currentSong.title)
		{
			//DLog(@"------------- tweeting song --------------");
			NSString *tweet = [NSString stringWithFormat:@"is listening to \"%@\" by %@ #isubapp", currentSong.title, currentSong.artistDisplayName];
            if (tweet.length > 140)
                tweet = [tweet substringToIndex:140];
            
            NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/update.json"];

            TWRequest *request = [[TWRequest alloc] initWithURL:url parameters:@{@"status": tweet} requestMethod:TWRequestMethodPOST];
                        
            ACAccountStore *store = [[ACAccountStore alloc] init];
            ACAccount *account = [store accountWithIdentifier: SavedSettings.si.currentTwitterAccount];
            
            if (account)
            {
                request.account = account;
                [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error)
                {
                    if (error)
                    {
                        ALog(@"Twitter error: %@", error);
                    }
                    else
                    {
                        ALog(@"Successfully tweeted: %@", tweet);
                    }
                }];
            }
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
#endif
}
#pragma clang diagnostic pop

#pragma mark - Singleton methods

+ (instancetype)si
{
    static SocialSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
	});
    return sharedInstance;
}

@end
