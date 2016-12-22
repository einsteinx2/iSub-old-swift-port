//
//  SUSCoverArtDAO.h
//  iSub
//
//  Created by Benjamin Baron on 11/22/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoaderManager.h"
#import "ISMSLoaderDelegate.h"

@class FMDatabase, ISMSCoverArtLoader, UIImage;
@interface SUSCoverArtDAO : NSObject <ISMSLoaderDelegate, ISMSLoaderManager>

@property (weak) NSObject<ISMSLoaderDelegate> *delegate;
@property (strong) ISMSCoverArtLoader *loader;

@property (copy) NSString *coverArtId;
@property BOOL isLarge;

#ifdef IOS
- (UIImage *)coverArtImage;
- (UIImage *)defaultCoverArtImage;
+ (UIImage *)defaultCoverArtImageForSize:(BOOL)large;
#else
- (NSImage *)coverArtImage;
- (NSImage *)defaultCoverArtImage;
+ (NSImage *)defaultCoverArtImageForSize:(BOOL)large;
#endif
@property (readonly) BOOL isCoverArtCached;

- (instancetype)initWithDelegate:(NSObject<ISMSLoaderDelegate> *)theDelegate;
- (instancetype)initWithDelegate:(NSObject<ISMSLoaderDelegate> *)delegate coverArtId:(NSString *)artId isLarge:(BOOL)large;

- (void)downloadArtIfNotExists;

@end
