//
//  SUSStreamConnectionDelegate.h
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SUSStreamHandler : NSObject <NSURLConnectionDelegate>

- (id)initWithSongId:(NSString *)songId;

@property (nonatomic, copy) NSString *songId;

@property long bytesTransferred;
@property (nonatomic, retain) NSDate *throttlingDate;

@property (readonly) NSUInteger currentSongBitrate;
@property (readonly) NSUInteger nextSongBitrate;

@end
