//
//  AsynchronousImageView.h
//  GLOSS
//
//  Created by Слава on 22.10.09.
//  Copyright 2009 Slava Bushtruk. All rights reserved.
//

#import <libSub/ISMSLoaderDelegate.h>

@protocol AsynchronousImageViewDelegate;
@class SUSCoverArtDAO;
@interface AsynchronousImageView : UIImageView <ISMSLoaderDelegate>

@property (nullable, weak) IBOutlet NSObject<AsynchronousImageViewDelegate> *delegate;
@property (nullable, copy) NSString *coverArtId;
@property (nullable, strong) SUSCoverArtDAO *coverArtDAO;
@property BOOL isLarge;
@property (nullable, strong) UIActivityIndicatorView *activityIndicator;

- (nonnull instancetype)initWithFrame:(CGRect)frame coverArtId:(nonnull NSString *)artId isLarge:(BOOL)large delegate:(nonnull NSObject<AsynchronousImageViewDelegate> *)theDelegate;

@end
