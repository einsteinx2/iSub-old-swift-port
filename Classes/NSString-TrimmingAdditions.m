//
//  NSString-TrimmingAdditions.m
//  iSub
//
//  Created by Ben Baron on 7/31/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "NSString-TrimmingAdditions.h"

@implementation NSString (TrimmingAdditions)

- (NSString *)stringByTrimmingLeadingCharactersInSet:(NSCharacterSet *)characterSet 
{
    NSUInteger location = 0;
    NSUInteger length = [self length];
    unichar charBuffer[length];    
    [self getCharacters:charBuffer];
	
    for (NSUInteger location = 0; location < length; location++) 
	{
        if (![characterSet characterIsMember:charBuffer[location]]) 
		{
            break;
        }
    }
	
    return [self substringWithRange:NSMakeRange(location, length - location)];
}

- (NSString *)stringByTrimmingTrailingCharactersInSet:(NSCharacterSet *)characterSet 
{
    NSUInteger location = 0;
    NSUInteger length = [self length];
    unichar charBuffer[length];    
    [self getCharacters:charBuffer];
	
    for (NSUInteger length = [self length]; length > 0; length--) 
	{
        if (![characterSet characterIsMember:charBuffer[length - 1]]) 
		{
            break;
        }
    }
	
    return [self substringWithRange:NSMakeRange(location, length - location)];
}

- (NSString *)stringByTrimmingLeadingWhitespace 
{
    return [self stringByTrimmingLeadingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (NSString *)stringByTrimmingTrailingWhitespace 
{
    return [self stringByTrimmingTrailingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (NSString *)stringByTrimmingLeadingAndTrailingWhitespace
{
	return [[self stringByTrimmingLeadingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] 
			stringByTrimmingTrailingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (NSString *)stringByTrimmingLeadingWhitespaceAndNewline 
{
    return [self stringByTrimmingLeadingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)stringByTrimmingTrailingWhitespaceAndNewline 
{
    return [self stringByTrimmingTrailingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end
