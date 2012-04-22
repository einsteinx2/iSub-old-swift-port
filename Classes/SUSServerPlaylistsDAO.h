//
//  SUSServerPlaylistsDAO.h
//  iSub
//
//  Created by Benjamin Baron on 11/1/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLoaderDelegate.h"
#import "SUSLoaderManager.h"

@class SUSServerPlaylistsLoader, FMDatabase;
@interface SUSServerPlaylistsDAO : NSObject <SUSLoaderDelegate, SUSLoaderManager>

@property (unsafe_unretained, readonly) FMDatabase *db;

@property (unsafe_unretained) NSObject <SUSLoaderDelegate> *delegate;
@property (strong) SUSServerPlaylistsLoader *loader;

#pragma mark - Public DAO Methods

@property (strong) NSArray *serverPlaylists;

@end
