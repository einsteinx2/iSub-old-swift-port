//
//  NSString+Clean.m
//  iSub
//
//  Created by Ben Baron on 2/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "NSString+Clean.h"
#import "GTMNSString+HTML.h"

@implementation NSString (Clean)

- (NSString *)cleanString
{
	return [[self gtm_stringByUnescapingFromHTML] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

@end
