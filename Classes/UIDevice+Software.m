//
//  UIDevice+Software.m
//  iSub
//
//  Created by Ben Baron on 12/31/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "UIDevice+Software.h"
#import <sys/sysctl.h>

@implementation UIDevice (Software)

- (NSString *)systemBuild 
{
	int mib[2] = {CTL_KERN, KERN_OSVERSION};
	size_t size = 0;
	
	// Get the size for the buffer
	sysctl(mib, 2, NULL, &size, NULL, 0);
	
	char *answer = malloc(size);
	sysctl(mib, 2, answer, &size, NULL, 0);
	
	NSString *results = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
	free(answer);
	return results;  
}

- (NSString *)completeVersionString
{
	return [NSString stringWithFormat:@"%@ %@ (%@)", [self systemName], [self systemVersion], [self systemBuild]];
}

@end
