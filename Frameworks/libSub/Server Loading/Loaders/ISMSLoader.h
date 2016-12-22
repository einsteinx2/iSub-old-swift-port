//
//  Loader.h
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoaderDelegate.h"

typedef NS_ENUM(NSInteger, ISMSLoaderState) {
    ISMSLoaderState_New,
    ISMSLoaderState_Loading,
    ISMSLoaderState_Canceled,
    ISMSLoaderState_Failed,
    ISMSLoaderState_Finished
};

// Loader callback block, make sure to always check success bool, not error, as error can be nil when success is NO
typedef void (^LoaderCallback)(BOOL success,  NSError * _Nullable error, ISMSLoader * _Nonnull loader);

@interface ISMSLoader : NSObject <NSURLConnectionDelegate>

@property (nullable, weak) NSObject<ISMSLoaderDelegate> *delegate;
@property (nullable, copy) LoaderCallback callbackBlock;

@property (readonly) ISMSLoaderType type;

@property (nullable, readonly) NSURL *redirectUrl;
// TODO: See if this conversion logic is necessary, pulled from old iSubAppDelegate code
@property (nullable, readonly) NSString *redirectUrlString;

@property (readonly) ISMSLoaderState loaderState;


- (nullable instancetype)initWithDelegate:(nullable NSObject<ISMSLoaderDelegate> *)theDelegate;
- (nullable instancetype)initWithCallbackBlock:(nullable LoaderCallback)theBlock;

- (void)startLoad;
- (void)cancelLoad;

- (void)subsonicErrorCode:(NSInteger)errorCode message:(nullable NSString *)message;

- (void)informDelegateLoadingFailed:(nullable NSError *)error;
- (void)informDelegateLoadingFinished;

@end