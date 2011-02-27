//
//  BBSimpleConnectionQueue.h
//  iSub
//
//  Created by Ben Baron on 12/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface BBSimpleConnectionQueue : NSObject 
{
	NSMutableArray *connectionStack;
		
	BOOL isRunning;
}

@property (readonly) NSMutableArray *connectionStack;
@property (readonly) BOOL isRunning;

- (void)registerConnection:(NSURLConnection *)connection;
- (void)connectionFinished:(NSURLConnection *)connection;
- (void)startQueue;
- (void)stopQueue;

@end
