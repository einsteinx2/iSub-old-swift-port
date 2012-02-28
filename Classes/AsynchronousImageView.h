//
//  AsynchronousImageView.h
//  GLOSS
//
//  Created by Слава on 22.10.09.
//  Copyright 2009 Slava Bushtruk. All rights reserved.
//
#import "SUSLoaderDelegate.h"

@protocol AsynchronousImageViewDelegate;
@class SUSCoverArtDAO;
@interface AsynchronousImageView : UIImageView <SUSLoaderDelegate>

@property (assign) NSObject<AsynchronousImageViewDelegate> *delegate;
@property (copy) NSString *coverArtId;
@property (retain) SUSCoverArtDAO *coverArtDAO;
@property BOOL isLarge;
@property (retain) UIActivityIndicatorView *activityIndicator;

- (id)initWithFrame:(CGRect)frame coverArtId:(NSString *)artId isLarge:(BOOL)large delegate:(NSObject<AsynchronousImageViewDelegate> *)theDelegate;

@end
