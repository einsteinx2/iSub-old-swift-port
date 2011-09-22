//
//  BBSimpleConnectionQueue.h
//  iSub
//
//  Created by Ben Baron on 12/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <Foundation/Foundation.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

@protocol BBSimpleConnectionQueueDelegate;

@interface BBSimpleConnectionQueue : NSObject 
{
	NSMutableArray *connectionStack;
		
	BOOL isRunning;
	
	id <BBSimpleConnectionQueueDelegate> delegate;
}

@property (readonly) NSMutableArray *connectionStack;
@property (readonly) BOOL isRunning;
@property (nonatomic, assign) id <BBSimpleConnectionQueueDelegate> delegate;

- (void)registerConnection:(NSURLConnection *)connection;
- (void)connectionFinished:(NSURLConnection *)connection;
- (void)startQueue;
- (void)stopQueue;
- (void)clearQueue;

@end

@protocol BBSimpleConnectionQueueDelegate <NSObject>
@optional
- (void)connectionQueueDidFinish:(BBSimpleConnectionQueue *)connectionQueue;
@end
