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

@interface ISMSLoader : NSObject <NSURLConnectionDelegate>

@property (weak) NSObject<ISMSLoaderDelegate> *delegate;

@property (strong) NSURLConnection *connection;
@property (strong) NSURLRequest *request;
@property (strong) NSMutableData *receivedData;
@property (readonly) ISMSLoaderType type;

+ (id)loader;
+ (id)loaderWithDelegate:(id <ISMSLoaderDelegate>)theDelegate;

- (void)setup; // Override this
- (id)initWithDelegate:(NSObject<ISMSLoaderDelegate> *)theDelegate;

- (void)startLoad;
- (void)cancelLoad;
- (NSURLRequest *)createRequest; // Override this
- (void)processResponse; // Override this

- (void)subsonicErrorCode:(NSInteger)errorCode message:(NSString *)message;

- (BOOL)informDelegateLoadingFailed:(NSError *)error;
- (BOOL)informDelegateLoadingFinished;

@end

#import "ISMSLoaders.h"