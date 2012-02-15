//
//  ISMSUpdateChecker.h
//  iSub
//
//  Created by Ben Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ISMSUpdateChecker : NSObject

@property (nonatomic, retain) NSMutableData *receivedData;
@property (nonatomic, retain) NSURLRequest *request;
@property (nonatomic, retain) NSURLConnection *connection;

@property (nonatomic, copy) NSString *theNewVersion;
@property (nonatomic, copy) NSString *message;

- (void)checkForUpdate;

@end