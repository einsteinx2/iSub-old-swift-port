//
//  SubsonicServerEditViewController.h
//  iSub
//
//  Created by Ben Baron on 3/3/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ISMSLoaderDelegate.h"
#import "ServerEditDelegate.h"

@class ServerTypeViewController, ISMSServer;
@interface SubsonicServerEditViewController : UIViewController <ISMSLoaderDelegate>

@property (nullable, nonatomic, weak) id<ServerEditDelegate> delegate;

@property (nullable, nonatomic, strong) ISMSServer *server;
@property (nullable, nonatomic, copy) NSString *redirectUrl;

- (nonnull instancetype)initWithServer:(nullable ISMSServer *)server;

@end
