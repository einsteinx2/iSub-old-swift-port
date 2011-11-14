//
//  SUSStreamHandlerDelegate.h
//  iSub
//
//  Created by Ben Baron on 11/13/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

@class SUSStreamHandler;
@protocol SUSStreamHandlerDelegate <NSObject>

- (void)SUSStreamHandlerStartPlayback:(SUSStreamHandler *)handler;
- (void)SUSStreamHandlerConnectionFinished:(SUSStreamHandler *)handler;
- (void)SUSStreamHandlerConnectionFailed:(SUSStreamHandler *)handler withError:(NSError *)error;

@end
