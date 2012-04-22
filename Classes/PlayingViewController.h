//
//  PlayingViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SUSLoaderDelegate.h"

@class SUSNowPlayingDAO, EGORefreshTableHeaderView;

@interface PlayingViewController : UITableViewController <SUSLoaderDelegate>
{
	BOOL isNothingPlayingScreenShowing;
	UIImageView *nothingPlayingScreen;
	
	NSMutableData *receivedData;
	
	EGORefreshTableHeaderView *refreshHeaderView;
	BOOL _reloading;
}

@property (strong) UIImageView *nothingPlayingScreen;

@property (strong) SUSNowPlayingDAO *dataModel;

@property(assign,getter=isReloading) BOOL reloading;

- (void)cancelLoad;

@end
