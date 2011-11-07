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

@property (readonly) FMDatabase *db;

@property (nonatomic, assign) NSObject <SUSLoaderDelegate> *delegate;
@property (nonatomic, retain) SUSServerPlaylistsLoader *loader;

#pragma mark - Public DAO Methods

@property (nonatomic, retain) NSArray *serverPlaylists;

@end
