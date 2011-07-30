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
	id <LoaderDelegate> delegate_;
	NSDictionary *results;
}

@property (readonly) NSError *loadError;
@property (readonly) NSDictionary *results;

- (id)initWithDelegate:(id <LoaderDelegate>)delegate;

- (void)startLoad;
- (void)cancelLoad;
- (void)setDelegate:(id <LoaderDelegate>)delegate;
- (id <LoaderDelegate>)delegate;
- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message;
- (NSString *)getBaseUrlString:(NSString *)action;

@end
