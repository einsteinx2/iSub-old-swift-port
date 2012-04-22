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

@property (strong) SUSChatLoader *loader;
@property (unsafe_unretained) NSObject <SUSLoaderDelegate> *delegate;

@property (strong) NSArray *chatMessages;

@property (strong) NSURLConnection *connection;
@property (strong) NSMutableData *receivedData;

- (void)sendChatMessage:(NSString *)message;

- (id)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate;

@end
