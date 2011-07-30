//
//  LoaderDelegate.h
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Loader;

@protocol LoaderDelegate <NSObject>

@required
- (void)loadingFailed:(Loader*)loader;
- (void)loadingFinished:(Loader*)loader;

@end
