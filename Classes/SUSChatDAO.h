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

@property (nonatomic, retain) SUSChatLoader *loader;
@property (nonatomic, assign) NSObject <SUSLoaderDelegate> *delegate;

@property (nonatomic, retain) NSArray *chatMessages;

@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSMutableData *receivedData;

- (void)sendChatMessage:(NSString *)message;

- (id)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate;

@end
