//
//  NSString+URLEncode.m
//  EX2Kit
//
//  Created by Benjamin Baron on 10/31/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NSString+URLEncode.h"

@implementation NSString (URLEncode)

+ (NSString *)URLEncodeString:(NSString *)string 
{
    NSCharacterSet *charSet = [NSCharacterSet characterSetWithCharactersInString:@";/?:@&=$+{}[]<>,"];
    return [string stringByAddingPercentEncodingWithAllowedCharacters:charSet];
} 

- (NSString *)URLEncodeString 
{ 
    return [NSString URLEncodeString:self]; 
}

- (NSString *)URLDecode
{
    return (__bridge_transfer NSString *)CFURLCreateStringByReplacingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)self, CFSTR(""));
}

@end
