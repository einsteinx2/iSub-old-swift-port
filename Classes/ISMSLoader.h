//
//  Loader.h
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//


#import "ISMSLoaderDelegate.h"
#import "NSError+ISMSError.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"
#import "Server.h"

@interface ISMSLoader : NSObject <NSURLConnectionDelegate>

@property (unsafe_unretained) NSObject<ISMSLoaderDelegate> *delegate;

@property (strong) NSURLConnection *connection;
@property (strong) NSMutableData *receivedData;
@property (readonly) ISMSLoaderType type;

+ (id)loader;
+ (id)loaderWithDelegate:(id <ISMSLoaderDelegate>)theDelegate;

- (void)setup;
- (id)initWithDelegate:(NSObject<ISMSLoaderDelegate> *)theDelegate;

- (void)startLoad; // Override this
- (void)cancelLoad; // Override this

- (void) subsonicErrorCode:(NSInteger)errorCode message:(NSString *)message;

- (BOOL)informDelegateLoadingFailed:(NSError *)error;
- (BOOL)informDelegateLoadingFinished;

@end