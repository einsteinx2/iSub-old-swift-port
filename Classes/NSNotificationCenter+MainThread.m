//
//  NSNotificationCenter+MainThread.m
//  iSub
//
//  Created by Benjamin Baron on 11/22/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NSNotificationCenter+MainThread.h"

@implementation NSNotificationCenter (MainThread)

+ (void)postNotificationInternal:(NSDictionary *)info
{
    NSString *name = [info objectForKey:@"name"];
    id object = [info objectForKey:@"object"];
    NSDictionary *userInfo = [info objectForKey:@"userInfo"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:name object:object userInfo:userInfo];
}

+ (void)postNotificationToMainThreadWithName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo
{
	@autoreleasepool 
	{
		if (name == nil)
			return;
		
		NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:name forKey:@"name"];
		if (object)
			[info setObject:object forKey:@"object"];
		if (userInfo)
			[info setObject:userInfo forKey:@"userInfo"];
		
		[NSNotificationCenter performSelectorOnMainThread:@selector(postNotificationInternal:) withObject:info waitUntilDone:NO];
	}
}

+ (void)postNotificationToMainThreadWithName:(NSString *)name userInfo:(NSDictionary *)userInfo
{
    [self postNotificationToMainThreadWithName:name object:nil userInfo:userInfo];
}

+ (void)postNotificationToMainThreadWithName:(NSString *)name object:(id)object
{
    [self postNotificationToMainThreadWithName:name object:object userInfo:nil];
}

+ (void)postNotificationToMainThreadWithName:(NSString *)name
{
    [self postNotificationToMainThreadWithName:name object:nil userInfo:nil];
}

@end
