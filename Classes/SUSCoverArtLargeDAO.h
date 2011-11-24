//
//  SUSCoverArtLargeDAO.h
//  iSub
//
//  Created by Benjamin Baron on 11/22/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLoaderDelegate.h"
#import "SUSLoaderManager.h"

@class FMDatabase;
@interface SUSCoverArtLargeDAO : NSObject

@property (readonly) FMDatabase *db;
@property (readonly) UIImage *defaultCoverArt;

+ (SUSCoverArtLargeDAO *)dataModel;
- (UIImage *)coverArtImageForId:(NSString *)coverArtId;
- (BOOL)coverArtExistsForId:(NSString *)coverArtId;

@end
