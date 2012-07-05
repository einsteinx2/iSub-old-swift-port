//
//  ServerURLChecker.h
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ISMSServerChecker;
@protocol ISMSServerCheckerDelegate <NSObject>
- (void)ISMSServerURLCheckFailed:(ISMSServerChecker *)checker withError:(NSError *)error;
- (void)ISMSServerURLCheckPassed:(ISMSServerChecker *)checker;
@optional
- (void)ISMSServerURLCheckRedirected:(ISMSServerChecker *)checker redirectUrl:(NSURL *)url;
@end


@interface ISMSServerChecker : NSObject <NSURLConnectionDelegate>

@property (unsafe_unretained) id<ISMSServerCheckerDelegate> delegate;
@property (strong) NSMutableData *receivedData;
@property (strong) NSURLRequest *request;
@property (strong) NSURLConnection *connection;
@property BOOL isNewSearchAPI;
@property NSUInteger majorVersion;
@property NSUInteger minorVersion;
@property (copy) NSString *versionString;

- (id)initWithDelegate:(id<ISMSServerCheckerDelegate>)theDelegate;

- (void)checkServerUrlString:(NSString *)urlString username:(NSString *)username password:(NSString *)password;

- (void)cancelLoad;

@end