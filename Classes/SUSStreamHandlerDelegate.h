//
//  SUSStreamHandlerDelegate.h
//  iSub
//
//  Created by Ben Baron on 11/13/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

@class SUSStreamHandler;
@protocol SUSStreamHandlerDelegate <NSObject>

@optional
- (void)SUSStreamHandlerStarted:(SUSStreamHandler *)handler;
- (void)SUSStreamHandlerStartPlayback:(SUSStreamHandler *)handler byteOffset:(unsigned long long)bytes secondsOffset:(double)seconds;
- (void)SUSStreamHandlerConnectionFinished:(SUSStreamHandler *)handler;
- (void)SUSStreamHandlerConnectionFailed:(SUSStreamHandler *)handler withError:(NSError *)error;
- (void)SUSStreamHandlerPartialPrecachePaused:(SUSStreamHandler *)handler;
- (void)SUSStreamHandlerPartialPrecacheUnpaused:(SUSStreamHandler *)handler;

@end
