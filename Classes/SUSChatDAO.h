//
//  SUSChatDAO.h
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLoaderDelegate.h"
#import "SUSLoaderManager.h"

@class SUSChatLoader;
@interface SUSChatDAO : NSObject <SUSLoaderManager, SUSLoaderDelegate>

@property (retain) SUSChatLoader *loader;
@property (assign) NSObject <SUSLoaderDelegate> *delegate;

@property (retain) NSArray *chatMessages;

@property (retain) NSURLConnection *connection;
@property (retain) NSMutableData *receivedData;

- (void)sendChatMessage:(NSString *)message;

- (id)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate;

@end
