//
//  SubsonicServerEditViewController.h
//  iSub
//
//  Created by Ben Baron on 3/3/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ISMSLoaderDelegate.h"

@class ServerTypeViewController, ISMSServer;
@interface SubsonicServerEditViewController : UIViewController <ISMSLoaderDelegate>

@property (nonatomic, strong) ISMSServer *server;
@property (nonatomic, copy) NSString *redirectUrl;

- (instancetype)initWithServer:(ISMSServer *)server;

@end
