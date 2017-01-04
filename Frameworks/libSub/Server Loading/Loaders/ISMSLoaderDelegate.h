//
//  LoaderDelegate.h
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

@class ISMSLoader;
@protocol ISMSLoaderDelegate <NSObject>

@optional
- (void)loadingRedirected:(nonnull ISMSLoader *)theLoader redirectUrl:(nonnull NSURL *)url;

@required
- (void)loadingFailed:(nonnull ISMSLoader*)theLoader withError:(nonnull NSError *)error;
- (void)loadingFinished:(nonnull ISMSLoader*)theLoader;

@end
