//
//  NSString-rfcEncode.m
//  iSub
//
//  Created by Ben Baron on 12/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "NSString+rfcEncode.h"


@implementation NSString (RFC3875)
- (NSString *)stringByAddingRFC3875PercentEscapesUsingEncoding:(NSStringEncoding)encoding 
{
	/*CFStringEncoding cfEncoding = CFStringConvertNSStringEncodingToEncoding(encoding);
	NSString *urlEscaped = [self stringByAddingPercentEscapesUsingEncoding:encoding];
	NSString *rfcEscaped = (NSString *)CFURLCreateStringByAddingPercentEscapes(
																			   NULL, 
																			   (CFStringRef)urlEscaped,
																			   NULL, 
																			   (CFStringRef)@";/?:@&=$+{}<>,",
																			   cfEncoding);
	return [rfcEscaped autorelease];*/
	
	CFStringEncoding cfEncoding = CFStringConvertNSStringEncodingToEncoding(encoding);
	// NSString *urlEscaped = [self stringByAddingPercentEscapesUsingEncoding:encoding];
	NSString *rfcEscaped = (NSString *)CFURLCreateStringByAddingPercentEscapes(
																			   NULL, 
																			   (CFStringRef)self,
																			   NULL, 
																			   (CFStringRef)@";/?:@&=$+{}<>,",
																			   cfEncoding);
	return [rfcEscaped autorelease];
}

@end
