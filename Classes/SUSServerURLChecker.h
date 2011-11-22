//
//  ServerURLChecker.h
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SUSServerURLChecker;
@protocol SUSServerURLCheckerDelegate <NSObject>
- (void)SUSServerURLCheckFailed:(SUSServerURLChecker *)checker withError:(NSError *)error;
- (void)SUSServerURLCheckPassed:(SUSServerURLChecker *)checker;
@optional
- (void)SUSServerURLCheckRedirected:(SUSServerURLChecker *)checker redirectUrl:(NSURL *)url;
@end


@interface SUSServerURLChecker : NSObject

@property (nonatomic, assign) NSObject<SUSServerURLCheckerDelegate> *delegate;
@property (nonatomic, retain) NSMutableData *receivedData;
@property (nonatomic, retain) NSURLRequest *request;

- (id)initWithDelegate:(NSObject<SUSServerURLCheckerDelegate> *)theDelegate;

- (void)checkURL:(NSURL *)url;

@end