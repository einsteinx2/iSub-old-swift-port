//
//  NSString+URLEncode.m
//  iSub
//
//  Created by Benjamin Baron on 10/31/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NSString+URLEncode.h"

@implementation NSString (URLEncode)

+ (NSString *)URLEncodeString:(NSString *)string 
{ 
    NSString *result = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, 
                    (CFStringRef)string, NULL, CFSTR(";/?:@&=$+{}[]<>,"), kCFStringEncodingUTF8); 
    
    return [result autorelease]; 
} 

- (NSString *)URLEncodeString 
{ 
    return [NSString URLEncodeString:self]; 
} 

@end
