//
//  Loader.h
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//


#import "SUSLoaderDelegate.h"
#import "NSError+ISMSError.h"
#import "NSMutableURLRequest+SUS.h"

@interface SUSLoader : NSObject <NSURLConnectionDelegate>

@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSMutableData *receivedData;
@property (nonatomic, assign) NSObject<SUSLoaderDelegate> *delegate;
@property (readonly) NSError *loadError;
@property (readonly) SUSLoaderType type;

- (void)setup;
- (id)initWithDelegate:(NSObject<SUSLoaderDelegate> *)theDelegate;

- (void)startLoad; // Override this
- (void)cancelLoad; // Override this

- (void) subsonicErrorCode:(NSInteger)errorCode message:(NSString *)message;

- (BOOL)informDelegateLoadingFailed:(NSError *)error;
- (BOOL)informDelegateLoadingFinished;

@end
