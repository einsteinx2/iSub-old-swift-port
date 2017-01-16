//
//  NSURL+QueryParameterDictionary.h
//  EX2Kit
//
//  Created by Benjamin Baron on 10/29/12.
//
//

#import <Foundation/Foundation.h>

@interface NSURL (QueryParameterDictionary)

- (nonnull NSDictionary<NSString*,NSString*> *)queryParameterDictionary;

@end
