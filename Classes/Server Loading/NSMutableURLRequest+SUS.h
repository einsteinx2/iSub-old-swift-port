//
//  NSMutableURLRequest+SUS.h
//  iSub
//
//  Created by Benjamin Baron on 10/31/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableURLRequest (SUS)

+ (nonnull NSMutableURLRequest *)requestWithSUSAction:(nonnull NSString *)action urlString:(nonnull NSString *)url username:(nonnull NSString *)user password:(nonnull NSString *)pass parameters:(nullable NSDictionary *)parameters fragment:(nullable NSString *)fragment byteOffset:(NSInteger)offset;
+ (nonnull NSMutableURLRequest *)requestWithSUSAction:(nonnull NSString *)action parameters:(nullable NSDictionary *)parameters fragment:(nullable NSString *)fragment byteOffset:(NSInteger)offset;
+ (nonnull NSMutableURLRequest *)requestWithSUSAction:(nonnull NSString *)action parameters:(nullable NSDictionary *)parameters fragment:(nullable NSString *)fragment;
+ (nonnull NSMutableURLRequest *)requestWithSUSAction:(nonnull NSString *)action parameters:(nullable NSDictionary *)parameters;

@end
