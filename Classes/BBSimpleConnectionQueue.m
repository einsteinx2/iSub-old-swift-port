//
//  BBSimpleConnectionQueue.m
//  iSub
//
//  Created by Ben Baron on 12/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "BBSimpleConnectionQueue.h"

@implementation BBSimpleConnectionQueue

- (id)init
{
	if ((self = [super init]))
	{
		_connectionStack = [[NSMutableArray alloc] init];
		_isRunning = NO;
	}
	
	return self;
}


- (void)registerConnection:(NSURLConnection *)connection
{
	[self.connectionStack addObject:connection];
	//DLog(@"CONNECTION QUEUE REGISTER: %i connections registered", [connectionStack count]);
}

- (void)connectionFinished:(NSURLConnection *)connection
{
	if ([self.connectionStack count] > 0)
		[self.connectionStack removeObjectAtIndex:0];
	
	//DLog(@"CONNECTION QUEUE FINISHED: %i connections registered", [connectionStack count]);
	
	if (self.isRunning && [self.connectionStack count] > 0)
	{
		NSURLConnection *connection = [self.connectionStack objectAtIndexSafe:0];
		[connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
		[connection start];
	}
	else
	{
		_isRunning = NO;
		[self.delegate connectionQueueDidFinish:self];
	}
}

- (void)startQueue
{	
	if (self.connectionStack.count > 0 && !self.isRunning)
	{
		_isRunning = YES;

		NSURLConnection *connection = [self.connectionStack objectAtIndexSafe:0];
		[connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
		[connection start];
	}
}

- (void)stopQueue
{
	_isRunning = NO;
}

- (void)clearQueue
{
	[self stopQueue];
	
	for (NSURLConnection *connection in self.connectionStack)
	{
		[connection cancel];
	}
	
	[self.connectionStack removeAllObjects];
}

@end
