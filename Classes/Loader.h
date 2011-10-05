//
//  Loader.h
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

//#import <Foundation/Foundation.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER
#import "LoaderDelegate.h"

@interface Loader : NSObject 
{
	NSError *loadError;
	id<LoaderDelegate> delegate;
	
	NSURLConnection *connection;
	NSMutableData *receivedData;
}

@property (nonatomic, retain) id<LoaderDelegate> delegate;

@property (readonly) NSError *loadError;

- (id)initWithDelegate:(id <LoaderDelegate>)theDelegate;

- (void)startLoad; // Override this
- (void)cancelLoad; // Override this
- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message;
- (NSString *)getBaseUrlString:(NSString *)action;

@end
