//
//  SUSStreamConnectionDelegate.h
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SUSStreamConnectionDelegate : NSObject <NSURLConnectionDelegate>

@property (nonatomic, retain) NSMutableData *receivedData;

@end
