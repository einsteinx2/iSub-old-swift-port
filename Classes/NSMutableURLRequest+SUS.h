//
//  NSMutableURLRequest+SUS.h
//  iSub
//
//  Created by Benjamin Baron on 10/31/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableURLRequest (SUS)

+ (NSMutableURLRequest *)requestWithSUSAction:(NSString *)action andParameters:(NSDictionary *)parameters;

@end
