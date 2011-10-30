//
//  ServerURLChecker.h
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ServerURLChecker;
@protocol ServerURLCheckerDelegate <NSObject>
- (void)serverURLCheckFailed:(ServerURLChecker *)checker withError:(NSError *)error;
- (void)serverURLCheckPassed:(ServerURLChecker *)checker;
@end


@interface ServerURLChecker : NSObject

@property (nonatomic, assign) NSObject<ServerURLCheckerDelegate> *delegate;
@property (nonatomic, retain) NSMutableData *receivedData;

- (id)initWithDelegate:(NSObject<ServerURLCheckerDelegate> *)theDelegate;

- (void)checkURL:(NSURL *)url;

@end