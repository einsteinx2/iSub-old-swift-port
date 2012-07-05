//
//  NSMutableURLRequest+PMS.h
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableURLRequest (PMS)

+ (NSMutableURLRequest *)requestWithPMSAction:(NSString *)action item:(NSString *)item forUrlString:(NSString *)url username:(NSString *)user password:(NSString *)pass andParameters:(NSDictionary *)parameters byteOffset:(NSUInteger)offset;
+ (NSMutableURLRequest *)requestWithPMSAction:(NSString *)action item:(NSString *)item forUrlString:(NSString *)url username:(NSString *)user password:(NSString *)pass andParameters:(NSDictionary *)parameters;
+ (NSMutableURLRequest *)requestWithPMSAction:(NSString *)action item:(NSString *)item andParameters:(NSDictionary *)parameters byteOffset:(NSUInteger)offset;
+ (NSMutableURLRequest *)requestWithPMSAction:(NSString *)action item:(NSString *)item andParameters:(NSDictionary *)parameters;
+ (NSMutableURLRequest *)requestWithPMSAction:(NSString *)action item:(NSString *)item;

@end
