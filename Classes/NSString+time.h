//
//  NSString-time.h
//  iSub
//
//  Created by Benjamin Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

@interface NSString (time)

+ (NSString *)formatTime:(float)seconds;
+ (NSString *)relativeTime:(NSDate *)date;

@end
