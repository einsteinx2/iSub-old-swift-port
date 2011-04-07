//
//  BBSimpleConnectionQueue.m
//  iSub
//
//  Created by Ben Baron on 12/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "BBSimpleConnectionQueue.h"

@implementation BBSimpleConnectionQueue

@synthesize connectionStack, isRunning, delegate;

- (id) init
{
	if ((self = [super init]))
	{
		connectionStack = [[NSMutableArray alloc] init];
		
		isRunning = NO;
		
		delegate = nil;
	}
	
	return self;
}

- (void)dealloc
{
	[connectionStack release];
	
	[super dealloc];
}

- (void)registerConnection:(NSURLConnection *)connection
{
	[connectionStack addObject:connection];
	//NSLog(@"CONNECTION QUEUE REGISTER: %i connections registered", [connectionStack count]);
}

- (void)connectionFinished:(NSURLConnection *)connection
{
	if ([connectionStack count] > 0)
		[connectionStack removeObjectAtIndex:0];
	
	//NSLog(@"CONNECTION QUEUE FINISHED: %i connections registered", [connectionStack count]);
	
	if (isRunning && [connectionStack count] > 0)
	{
		NSURLConnection *connection = [connectionStack objectAtIndex:0];
		[connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
		[connection start];
	}
	else
	{
		isRunning = NO;
		
		[delegate connectionQueueDidFinish:self];
	}
}

- (void)startQueue
{	
	if ([connectionStack count] > 0 && !isRunning)
	{
		isRunning = YES;

		NSURLConnection *connection = [connectionStack objectAtIndex:0];
		[connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
		[connection start];
	}
}

- (void)stopQueue
{
	isRunning = NO;
}

- (void)clearQueue
{
	[self stopQueue];
	
	for (NSURLConnection *connection in connectionStack)
	{
		[connection release];
	}
	
	[connectionStack removeAllObjects];
}

@end
