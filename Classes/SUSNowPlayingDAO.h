//
//  SUSNowPlayingDAO.h
//  iSub
//
//  Created by Ben Baron on 1/24/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "ISMSLoaderDelegate.h"
#import "ISMSLoaderManager.h"

@class SUSNowPlayingLoader, Song;
@interface SUSNowPlayingDAO : NSObject <ISMSLoaderDelegate, ISMSLoaderManager>

@property (unsafe_unretained) id<ISMSLoaderDelegate> delegate;
@property (strong) SUSNowPlayingLoader *loader;

@property (strong) NSArray *nowPlayingSongDicts;

@property (readonly) NSUInteger count;

- (id)initWithDelegate:(id <ISMSLoaderDelegate>)theDelegate;

- (Song *)songForIndex:(NSUInteger)index;
- (NSString *)playTimeForIndex:(NSUInteger)index;
- (NSString *)usernameForIndex:(NSUInteger)index;
- (NSString *)playerNameForIndex:(NSUInteger)index;
- (void)playSongAtIndex:(NSUInteger)index;

@end
