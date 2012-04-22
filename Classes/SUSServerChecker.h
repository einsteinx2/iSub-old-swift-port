//
//  ServerURLChecker.h
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SUSServerChecker;
@protocol SUSServerURLCheckerDelegate <NSObject>
- (void)SUSServerURLCheckFailed:(SUSServerChecker *)checker withError:(NSError *)error;
- (void)SUSServerURLCheckPassed:(SUSServerChecker *)checker;
@optional
- (void)SUSServerURLCheckRedirected:(SUSServerChecker *)checker redirectUrl:(NSURL *)url;
@end


@interface SUSServerChecker : NSObject

@property (unsafe_unretained) NSObject<SUSServerURLCheckerDelegate> *delegate;
@property (strong) NSMutableData *receivedData;
@property (strong) NSURLRequest *request;
@property (strong) NSURLConnection *connection;
@property BOOL isNewSearchAPI;
@property NSUInteger majorVersion;
@property NSUInteger minorVersion;
@property (copy) NSString *versionString;

- (id)initWithDelegate:(NSObject<SUSServerURLCheckerDelegate> *)theDelegate;

- (void)checkServerUrlString:(NSString *)urlString username:(NSString *)username password:(NSString *)password;

@end