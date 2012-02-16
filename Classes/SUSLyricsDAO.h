//
//  SUSLyricsDAO.h
//  iSub
//
//  Created by Benjamin Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLoaderDelegate.h"
#import "SUSLoaderManager.h"

@class SUSLyricsLoader, FMDatabase;
@interface SUSLyricsDAO : NSObject <SUSLoaderDelegate, SUSLoaderManager>

@property (readonly) FMDatabase *db;

@property (assign) NSObject <SUSLoaderDelegate> *delegate;
@property (retain) SUSLyricsLoader *loader;

- (id)initWithDelegate:(NSObject <SUSLoaderDelegate> *)theDelegate;
- (NSString *)loadLyricsForArtist:(NSString *)artist andTitle:(NSString *)title;

#pragma mark - Public DAO Methods
- (NSString *)lyricsForArtist:(NSString *)artist andTitle:(NSString *)title;

@end
