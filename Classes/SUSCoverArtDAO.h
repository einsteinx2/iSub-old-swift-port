//
//  SUSCoverArtDAO.h
//  iSub
//
//  Created by Benjamin Baron on 11/22/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLoaderDelegate.h"
#import "SUSLoaderManager.h"

@class FMDatabase, SUSCoverArtLoader;
@interface SUSCoverArtDAO : NSObject <SUSLoaderDelegate, SUSLoaderManager>

@property (assign) NSObject<SUSLoaderDelegate> *delegate;
@property (retain) SUSCoverArtLoader *loader;
@property (readonly) FMDatabase *db;

@property (copy) NSString *coverArtId;
@property BOOL isLarge;

@property (readonly) UIImage *coverArtImage;
@property (readonly) UIImage *defaultCoverArtImage;
@property (readonly) BOOL isCoverArtCached;

- (id)initWithDelegate:(NSObject<SUSLoaderDelegate> *)theDelegate;
- (id)initWithDelegate:(NSObject<SUSLoaderDelegate> *)delegate coverArtId:(NSString *)artId isLarge:(BOOL)large;

- (void)downloadArtIfNotExists;

@end
