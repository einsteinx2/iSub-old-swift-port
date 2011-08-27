//
//  Loader.h
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LoaderDelegate.h"

@interface Loader : NSObject 
{
	NSError *loadError;
	id<LoaderDelegate> delegate;
	NSDictionary *results;
}

@property (nonatomic, retain) id<LoaderDelegate> delegate;

@property (readonly) NSError *loadError;
@property (readonly) NSDictionary *results;

- (id)initWithDelegate:(id <LoaderDelegate>)theDelegate;

- (void)startLoad;
- (void)cancelLoad;
- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message;
- (NSString *)getBaseUrlString:(NSString *)action;

@end
