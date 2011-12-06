//
//  SocialControlsSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//



#import "SA_OAuthTwitterController.h"

@class SA_OAuthTwitterEngine, Song;

@interface SocialSingleton : NSObject <SA_OAuthTwitterControllerDelegate>
{
	SA_OAuthTwitterEngine *twitterEngine;
}

@property (nonatomic, retain) SA_OAuthTwitterEngine *twitterEngine;


@property (nonatomic, retain) NSTimer *tweetTimer;
@property BOOL shouldInvalidateTweetTimer;
@property (nonatomic, retain) NSTimer *scrobbleTimer;
@property BOOL shouldInvalidateScrobbleTimer;

+ (SocialSingleton*)sharedInstance;

- (void) createTwitterEngine;

- (void)scrobbleSong:(Song *)aSong isSubmission:(BOOL)isSubmission;

@end
