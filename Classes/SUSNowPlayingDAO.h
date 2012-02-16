//
//  SUSNowPlayingDAO.h
//  iSub
//
//  Created by Ben Baron on 1/24/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSLoaderDelegate.h"
#import "SUSLoaderManager.h"

@class SUSNowPlayingLoader, Song;
@interface SUSNowPlayingDAO : NSObject <SUSLoaderDelegate, SUSLoaderManager>

@property (assign) id<SUSLoaderDelegate> delegate;
@property (retain) SUSNowPlayingLoader *loader;

@property (retain) NSArray *nowPlayingSongDicts;

@property (readonly) NSUInteger count;

- (id)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate;

- (Song *)songForIndex:(NSUInteger)index;
- (NSString *)playTimeForIndex:(NSUInteger)index;
- (NSString *)usernameForIndex:(NSUInteger)index;
- (NSString *)playerNameForIndex:(NSUInteger)index;
- (void)playSongAtIndex:(NSUInteger)index;

@end
